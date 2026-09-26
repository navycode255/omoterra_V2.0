"""Where media bytes live: this server's disk, or a private Cloudflare R2 bucket.

The API never streams media. It checks permission, then answers with a
short-lived signed URL: an R2 presigned URL, or with LocalStorage a signed
link to an API route that serves the file only while the signature is valid.
Nothing in the bucket is ever public. In R2 all livestock media sits under
one folder:

    livestock/photos/<id>.jpg
    livestock/videos/<id>.mp4
    livestock/pending/<upload id>    resumable video uploads awaiting confirm

Commands (run from backend/):
    python -m app.storage check     write, read back and delete a test object
    python -m app.storage migrate   copy files from media_directory to R2
"""
import hashlib
import hmac
import os
import re
import shutil
import sys
import time
from functools import lru_cache
from pathlib import Path
from urllib.parse import urlencode

from fastapi.responses import FileResponse

from .config import settings

FOLDER = 'livestock'
# A media id's bytes never change, so the phone's disk cache may keep them for
# good; 'private' keeps shared caches out.
HEADERS = {'Cache-Control': 'private, max-age=31536000, immutable'}
# Resumable video uploads go in parts of this size (the S3 minimum, except the last).
PART_SIZE = 5 * 1024 * 1024
LOCAL_NAME = re.compile(r'[0-9a-f-]{36}\.(jpg|mp4|mov|webm|3gp)')


def key(name):
    if name.startswith('pending/'):
        return f'{FOLDER}/{name}'
    kind = 'photos' if name.endswith('.jpg') else 'videos'
    return f'{FOLDER}/{kind}/{name}'


def signature(*parts):
    """HMAC for LocalStorage links, keyed from the server's OTP secret."""
    secret = hashlib.sha256(b'omoterra-media-link:' + settings().otp_secret.encode()).digest()
    return hmac.new(secret, '|'.join(map(str, parts)).encode(), hashlib.sha256).hexdigest()


def signed_query(*parts, seconds):
    expires = int(time.time()) + seconds
    return urlencode({'expires': expires, 'signature': signature(*parts, expires)})


def signature_valid(expires, given, *parts):
    return expires > time.time() and hmac.compare_digest(signature(*parts, expires), given)


class LocalStorage:
    """Files on this server's disk. Signed URLs are API paths (relative to
    /api/v1, like every other media url) checked by signature_valid()."""
    def __init__(self, root):
        self.root = Path(root)

    def put_bytes(self, name, data, content_type):
        self.root.mkdir(parents=True, exist_ok=True)
        (self.root / name).write_bytes(data)

    def put_file(self, name, path, content_type):
        self.root.mkdir(parents=True, exist_ok=True)
        os.replace(path, self.root / name)

    def delete(self, name):
        if name.startswith('pending/'):
            shutil.rmtree(self.uploads / name.removeprefix('pending/'), ignore_errors=True)
            (self.uploads / (name.removeprefix('pending/') + '.pending')).unlink(missing_ok=True)
        else:
            (self.root / name).unlink(missing_ok=True)

    def scratch(self):
        """Folder for half-written uploads; on the same disk so put_file is a rename."""
        self.root.mkdir(parents=True, exist_ok=True)
        return self.root

    def signed_get(self, name, content_type, seconds):
        return f'/media/local/{name}?' + signed_query('get', name, seconds=seconds)

    def response(self, name, content_type):
        """Serve a file once its signed link was checked; FileResponse answers Range."""
        path = self.root / name
        if not LOCAL_NAME.fullmatch(name) or not path.is_file():
            return None
        return FileResponse(path, media_type=content_type, headers=HEADERS)

    # Resumable uploads: parts are files in .uploads/<upload id>/<number>.
    @property
    def uploads(self):
        return self.root / '.uploads'

    def start_multipart(self, pending):
        upload_id = pending.removeprefix('pending/')
        (self.uploads / upload_id).mkdir(parents=True, exist_ok=True)
        return upload_id

    def sign_part(self, pending, upload_id, number, seconds):
        return f'/media/local/uploads/{upload_id}/{number}?' + signed_query('part', upload_id, number, seconds=seconds)

    def put_part(self, upload_id, number, data):
        folder = self.uploads / upload_id
        if not folder.is_dir():
            return None
        (folder / str(number)).write_bytes(data)
        return '"' + hashlib.md5(data).hexdigest() + '"'

    def uploaded_parts(self, pending, upload_id):
        folder = self.uploads / upload_id
        if not folder.is_dir():
            return None
        return sorted(({'number': int(part.name), 'etag': '"' + hashlib.md5(part.read_bytes()).hexdigest() + '"',
            'size': part.stat().st_size} for part in folder.iterdir() if part.name.isdigit()), key=lambda part: part['number'])

    def complete_multipart(self, pending, upload_id, parts):
        stored = {part['number']: part['etag'] for part in self.uploaded_parts(pending, upload_id) or []}
        if any(stored.get(part['number']) != part['etag'] for part in parts):
            return False
        with open(self.uploads / f'{upload_id}.pending', 'wb') as out:
            for part in parts:
                with open(self.uploads / upload_id / str(part['number']), 'rb') as source:
                    shutil.copyfileobj(source, out)
        shutil.rmtree(self.uploads / upload_id, ignore_errors=True)
        return True

    def abort_multipart(self, pending, upload_id):
        shutil.rmtree(self.uploads / upload_id, ignore_errors=True)

    def head(self, pending, length=16):
        path = self.uploads / (pending.removeprefix('pending/') + '.pending')
        if not path.is_file():
            return None
        with open(path, 'rb') as source:
            return path.stat().st_size, source.read(length)

    def promote(self, pending, name, content_type):
        self.put_file(name, self.uploads / (pending.removeprefix('pending/') + '.pending'), content_type)


class R2Storage:
    def __init__(self, client, bucket):
        self.client = client
        self.bucket = bucket

    def put_bytes(self, name, data, content_type):
        self.client.put_object(Bucket=self.bucket, Key=key(name), Body=data, ContentType=content_type)

    def put_file(self, name, path, content_type):
        # upload_file switches to multipart for large videos.
        self.client.upload_file(str(path), self.bucket, key(name), ExtraArgs={'ContentType': content_type})
        Path(path).unlink(missing_ok=True)

    def delete(self, name):
        self.client.delete_object(Bucket=self.bucket, Key=key(name))

    def scratch(self):
        root = Path(settings().media_directory) / '.incoming'
        root.mkdir(parents=True, exist_ok=True)
        return root

    def signed_get(self, name, content_type, seconds):
        return self.client.generate_presigned_url('get_object', ExpiresIn=seconds, Params={
            'Bucket': self.bucket, 'Key': key(name), 'ResponseContentType': content_type,
            'ResponseCacheControl': HEADERS['Cache-Control']})

    def start_multipart(self, pending):
        return self.client.create_multipart_upload(Bucket=self.bucket, Key=key(pending),
            ContentType='application/octet-stream')['UploadId']

    def sign_part(self, pending, upload_id, number, seconds):
        return self.client.generate_presigned_url('upload_part', ExpiresIn=seconds, Params={
            'Bucket': self.bucket, 'Key': key(pending), 'UploadId': upload_id, 'PartNumber': number})

    def uploaded_parts(self, pending, upload_id):
        from botocore.exceptions import ClientError
        try:
            pages = self.client.get_paginator('list_parts').paginate(Bucket=self.bucket, Key=key(pending), UploadId=upload_id)
            return [{'number': part['PartNumber'], 'etag': part['ETag'], 'size': part['Size']}
                for page in pages for part in page.get('Parts', [])]
        except ClientError as exc:
            if exc.response.get('Error', {}).get('Code') in ('NoSuchUpload', '404'):
                return None
            raise

    def complete_multipart(self, pending, upload_id, parts):
        from botocore.exceptions import ClientError
        try:
            self.client.complete_multipart_upload(Bucket=self.bucket, Key=key(pending), UploadId=upload_id,
                MultipartUpload={'Parts': [{'PartNumber': part['number'], 'ETag': part['etag']} for part in parts]})
        except ClientError as exc:
            if exc.response.get('Error', {}).get('Code') in ('InvalidPart', 'InvalidPartOrder', 'NoSuchUpload', 'EntityTooSmall'):
                return False
            raise
        return True

    def abort_multipart(self, pending, upload_id):
        from botocore.exceptions import ClientError
        try:
            self.client.abort_multipart_upload(Bucket=self.bucket, Key=key(pending), UploadId=upload_id)
        except ClientError:
            pass

    def head(self, pending, length=16):
        from botocore.exceptions import ClientError
        try:
            size = self.client.head_object(Bucket=self.bucket, Key=key(pending))['ContentLength']
            first = self.client.get_object(Bucket=self.bucket, Key=key(pending), Range=f'bytes=0-{length - 1}')['Body'].read()
        except ClientError as exc:
            if exc.response.get('Error', {}).get('Code') in ('NoSuchKey', '404', 'NotFound'):
                return None
            raise
        return size, first

    def promote(self, pending, name, content_type):
        # A server-side copy; confirmed videos are at most stock_video_max_bytes, far under the 5 GB copy limit.
        self.client.copy_object(Bucket=self.bucket, Key=key(name), CopySource={'Bucket': self.bucket, 'Key': key(pending)},
            ContentType=content_type, MetadataDirective='REPLACE')
        self.client.delete_object(Bucket=self.bucket, Key=key(pending))


@lru_cache
def r2_client(account_id, access_key_id, secret_access_key):
    import boto3
    from botocore.config import Config
    return boto3.client('s3', endpoint_url=f'https://{account_id}.r2.cloudflarestorage.com',
        aws_access_key_id=access_key_id, aws_secret_access_key=secret_access_key, region_name='auto',
        config=Config(signature_version='s3v4', retries={'max_attempts': 3, 'mode': 'standard'},
            request_checksum_calculation='when_required', response_checksum_validation='when_required'))


def storage():
    cfg = settings()
    if cfg.media_storage == 'r2':
        return R2Storage(r2_client(cfg.r2_account_id, cfg.r2_access_key_id, cfg.r2_secret_access_key), cfg.r2_bucket_livestock)
    return LocalStorage(cfg.media_directory)


def check(target):
    probe = '_omoterra-check.jpg'
    target.put_bytes(probe, b'ok', 'image/jpeg')
    body = target.client.get_object(Bucket=target.bucket, Key=key(probe))['Body'].read()
    target.client.delete_object(Bucket=target.bucket, Key=key(probe))
    if body != b'ok':
        raise RuntimeError('R2 returned different bytes than were written')
    return f'R2 bucket {target.bucket!r} is writable and readable under {FOLDER}/'


def migrate(target, root):
    """Copy every local media file to R2. Safe to re-run: files already in R2
    with the same size are skipped. Local files are left in place."""
    from botocore.exceptions import ClientError
    copied = skipped = 0
    for path in sorted(Path(root).iterdir()):
        if not path.is_file() or path.name.startswith(('.', '_')) or path.suffix == '.part':
            continue
        size = path.stat().st_size
        try:
            if target.client.head_object(Bucket=target.bucket, Key=key(path.name))['ContentLength'] == size:
                skipped += 1
                continue
        except ClientError as exc:
            if exc.response.get('Error', {}).get('Code') not in ('404', 'NoSuchKey', 'NotFound'):
                raise
        content_type = 'image/jpeg' if path.suffix == '.jpg' else {
            '.mp4': 'video/mp4', '.mov': 'video/quicktime', '.webm': 'video/webm', '.3gp': 'video/3gpp'}.get(path.suffix, 'application/octet-stream')
        target.client.upload_file(str(path), target.bucket, key(path.name), ExtraArgs={'ContentType': content_type})
        if target.client.head_object(Bucket=target.bucket, Key=key(path.name))['ContentLength'] != size:
            raise RuntimeError(f'{path.name} did not arrive in R2 intact')
        copied += 1
    return f'Copied {copied} file(s) to R2, {skipped} already there.'


if __name__ == '__main__':
    cfg = settings()
    cfg.validate_runtime()
    if not cfg.r2_account_id:
        sys.exit('Set the OMOTERRA_R2_* settings first.')
    target = R2Storage(r2_client(cfg.r2_account_id, cfg.r2_access_key_id, cfg.r2_secret_access_key), cfg.r2_bucket_livestock)
    command = sys.argv[1] if len(sys.argv) > 1 else ''
    if command == 'check':
        print(check(target))
    elif command == 'migrate':
        print(migrate(target, cfg.media_directory))
    else:
        sys.exit(__doc__)
