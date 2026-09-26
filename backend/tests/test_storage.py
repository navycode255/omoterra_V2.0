import pytest

from app.config import Settings
from app.storage import LocalStorage, R2Storage, key, migrate

boto3 = pytest.importorskip('boto3')
moto = pytest.importorskip('moto')

ACCOUNT = '0123456789abcdef0123456789abcdef'


@pytest.fixture
def bucket(monkeypatch):
    for name in ('AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY'):
        monkeypatch.setenv(name, 'testing')
    with moto.mock_aws():
        from botocore.config import Config
        client = boto3.client('s3', region_name='us-east-1', config=Config(signature_version='s3v4'))
        client.create_bucket(Bucket='omoterra-livestock')
        yield R2Storage(client, 'omoterra-livestock')


def test_r2_stores_a_photo_and_signs_a_short_lived_link(bucket):
    bucket.put_bytes('p.jpg', b'jpeg-bytes', 'image/jpeg')
    stored = bucket.client.head_object(Bucket='omoterra-livestock', Key='livestock/photos/p.jpg')
    assert stored['ContentType'] == 'image/jpeg'
    url = bucket.signed_get('p.jpg', 'image/jpeg', 600)
    assert '/livestock/photos/p.jpg?' in url and 'X-Amz-Expires=600' in url and 'X-Amz-Signature=' in url


def test_r2_resumable_upload_confirms_into_videos(bucket):
    from app.storage import PART_SIZE
    upload = bucket.start_multipart('pending/u1')
    assert 'partNumber=2' in bucket.sign_part('pending/u1', upload, 2, 1800)
    first = bucket.client.upload_part(Bucket='omoterra-livestock', Key='livestock/pending/u1', UploadId=upload, PartNumber=1,
        Body=b'\x00\x00\x00\x18ftypmp42' + b'\x00' * (PART_SIZE - 12))
    assert bucket.uploaded_parts('pending/u1', upload) == [{'number': 1, 'etag': first['ETag'], 'size': PART_SIZE}]
    second = bucket.client.upload_part(Bucket='omoterra-livestock', Key='livestock/pending/u1', UploadId=upload, PartNumber=2, Body=b'tail')
    assert not bucket.complete_multipart('pending/u1', upload, [{'number': 1, 'etag': '"wrong"'}, {'number': 2, 'etag': second['ETag']}])
    assert bucket.complete_multipart('pending/u1', upload, [{'number': 1, 'etag': first['ETag']}, {'number': 2, 'etag': second['ETag']}])
    size, head = bucket.head('pending/u1')
    assert size == PART_SIZE + 4 and head[4:8] == b'ftyp'
    bucket.promote('pending/u1', 'v.mp4', 'video/mp4')
    assert bucket.head('pending/u1') is None
    assert bucket.client.head_object(Bucket='omoterra-livestock', Key='livestock/videos/v.mp4')['ContentType'] == 'video/mp4'


def test_missing_media_is_none_locally(tmp_path):
    assert LocalStorage(tmp_path).response('0' * 36 + '.jpg', 'image/jpeg') is None
    (tmp_path / 'secret.txt').write_text('x')
    assert LocalStorage(tmp_path).response('secret.txt', 'text/plain') is None


def test_migrate_copies_local_files_once(bucket, tmp_path):
    (tmp_path / 'a.jpg').write_bytes(b'photo')
    (tmp_path / 'b.mp4').write_bytes(b'video')
    (tmp_path / 'upload.part').write_bytes(b'half')
    assert migrate(bucket, tmp_path) == 'Copied 2 file(s) to R2, 0 already there.'
    assert migrate(bucket, tmp_path) == 'Copied 0 file(s) to R2, 2 already there.'
    video = bucket.client.head_object(Bucket='omoterra-livestock', Key='livestock/videos/b.mp4')
    assert video['ContentType'] == 'video/mp4'


def r2_settings(**values):
    base = dict(media_storage='r2', r2_account_id=ACCOUNT, r2_access_key_id='key', r2_secret_access_key='secret',
        r2_bucket_livestock='omoterra-livestock', database_url='postgresql://x')
    return Settings(_env_file=None, **{**base, **values})


def test_r2_settings_are_checked_at_startup():
    r2_settings().validate_runtime()
    with pytest.raises(RuntimeError, match='OMOTERRA_R2_SECRET_ACCESS_KEY'):
        r2_settings(r2_secret_access_key='').validate_runtime()
    with pytest.raises(RuntimeError, match='32-character'):
        r2_settings(r2_account_id='not-an-account').validate_runtime()
    with pytest.raises(RuntimeError, match='bucket name, not a URL'):
        r2_settings(r2_bucket_livestock='https://pub-x.r2.dev').validate_runtime()
    with pytest.raises(RuntimeError, match="'local' or 'r2'"):
        r2_settings(media_storage='s3').validate_runtime()


def test_api_keeps_r2_media_private(client, bucket, monkeypatch, tmp_path):
    from app import main, media
    from app.config import settings
    from test_stock_media_location import photo, video
    from test_commerce import headers
    settings().media_directory = str(tmp_path)
    monkeypatch.setattr(media, 'storage', lambda: bucket)
    monkeypatch.setattr(main, 'storage', lambda: bucket)
    url = photo(client)
    name = url.removeprefix('/media/') + '.jpg'
    assert bucket.client.head_object(Bucket='omoterra-livestock', Key=f'livestock/photos/{name}')
    assert not (tmp_path / name).exists()
    own = client.get(f'/api/v1{url}', headers=headers('supplier'))
    assert own.status_code == 200 and f'livestock/photos/{name}' in own.json()['url']
    # The photo is on no live listing, so another user gets no link to it.
    assert client.get(f'/api/v1{url}', headers=headers('buyer')).status_code == 404
    clip = video(client)
    assert clip.status_code == 200, clip.text
    link = client.get(f"/api/v1{clip.json()['url']}", headers=headers('supplier')).json()
    assert '/livestock/videos/' in link['url'] and 'X-Amz-Expires=1800' in link['url']
    assert not list((tmp_path / '.incoming').iterdir())
    # Deleting the upload removes it from the bucket too.
    assert client.delete(f'/api/v1{url}', headers=headers('supplier')).status_code == 204
    listed = bucket.client.list_objects_v2(Bucket='omoterra-livestock', Prefix='livestock/photos/')
    assert listed.get('KeyCount') == 0
