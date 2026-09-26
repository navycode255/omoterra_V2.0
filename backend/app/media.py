import logging
import tempfile
from datetime import timedelta
from io import BytesIO
from pathlib import Path
from PIL import Image, ImageOps, UnidentifiedImageError
from .i18n import error, fail
from fastapi.concurrency import run_in_threadpool
from sqlalchemy import event, exists, select
from .storage import PART_SIZE, storage
from . import models as m

Image.MAX_IMAGE_PIXELS = 25_000_000


VIDEO_TYPES = {'video/mp4': 'mp4', 'video/quicktime': 'mov', 'video/webm': 'webm', 'video/3gpp': '3gp'}


def validate_owned_media(db, urls, owner_id, allow_unowned=False, video=False):
    for url in urls:
        asset = db.get(m.MediaAsset, url.removeprefix('/media/'))
        if not asset or (asset.owner_id != owner_id and not (allow_unowned and asset.owner_id is None)):
            fail('err.video_unavailable_upload_own' if video else 'err.photo_unavailable_upload_own', 422)
        if asset.content_type.startswith('video/') != video:
            fail('err.add_photos_as_photos_video', 422)


def video_type(head: bytes):
    """Identify a phone video by its container signature, not its filename."""
    if head[4:8] == b'ftyp':
        brand = head[8:12]
        if brand.startswith(b'3g'):
            return 'video/3gpp'
        return 'video/quicktime' if brand == b'qt  ' else 'video/mp4'
    if head[:4] == b'\x1a\x45\xdf\xa3':
        return 'video/webm'
    return None


async def save_video(db, owner_id, upload, limit):
    head = await upload.read(16)
    content_type = video_type(head)
    if content_type is None:
        fail('err.use_mp4_mov_webm_3gp', 422)
    id = m.identifier()
    name = f'{id}.{VIDEO_TYPES[content_type]}'
    target = storage()
    size = len(head)
    with tempfile.NamedTemporaryFile(dir=target.scratch(), suffix='.part', delete=False) as out:
        part = Path(out.name)
    try:
        with open(part, 'wb') as out:
            out.write(head)
            while chunk := await upload.read(1024 * 1024):
                size += len(chunk)
                if size > limit:
                    raise _too_big(limit)
                out.write(chunk)
        # A 60 MB upload to R2 must not stall every other request on this worker.
        await run_in_threadpool(target.put_file, name, part, content_type)
    finally:
        part.unlink(missing_ok=True)
    asset = m.MediaAsset(id=id, owner_id=owner_id, storage_name=name, content_type=content_type)
    db.add(asset)
    db.flush()
    return {'id': id, 'url': f'/media/{id}'}


def save_photo(db, owner_id, raw):
    try:
        with Image.open(BytesIO(raw)) as original:
            if original.format not in ['JPEG', 'PNG', 'WEBP']:
                raise ValueError('Unsupported image format')
            if original.width * original.height > Image.MAX_IMAGE_PIXELS:
                raise ValueError('Image dimensions are too large')
            if original.format == 'JPEG':
                # Decode straight at 1/2, 1/4 or 1/8 scale when that still
                # covers 1600px: a phone photo then costs a fraction of the
                # CPU and memory of a full decode.
                original.draft('RGB', (1600, 1600))
            original.load()
            # Re-encode pixel data: strip GPS/EXIF, filenames and other metadata.
            image = ImageOps.exif_transpose(original).convert('RGB')
            image.thumbnail((1600, 1600))
            clean = Image.new('RGB', image.size)
            clean.paste(image)
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError, Image.DecompressionBombWarning):
        fail('err.use_valid_jpeg_png_webp', 422)
    id = m.identifier()
    name = f'{id}.jpg'
    encoded = BytesIO()
    clean.save(encoded, 'JPEG', quality=88)
    storage().put_bytes(name, encoded.getvalue(), 'image/jpeg')
    asset = m.MediaAsset(id=id, owner_id=owner_id, storage_name=name)
    db.add(asset)
    db.flush()
    return {'id': id, 'url': f'/media/{id}'}


log = logging.getLogger(__name__)


def in_use(db, url):
    """True while any record still shows this photo or video (an index lookup)."""
    return db.scalar(select(exists().where(m.MediaReference.media_id == url.removeprefix('/media/'))))


def release_media(db, urls):
    """Delete media nothing points to any more: the record now, the stored
    file (on disk or in R2) once the transaction commits, so a rolled-back
    request never loses a file its records still use."""
    names = []
    for url in {url for url in urls if url}:
        asset = db.get(m.MediaAsset, url.removeprefix('/media/'))
        if asset and not in_use(db, f'/media/{asset.id}'):
            names.append(asset.storage_name)
            db.delete(asset)
    if names:
        db.flush()
        target = storage()

        def remove_files(session):
            for name in names:
                try:
                    target.delete(name)
                except Exception:
                    log.exception('Could not delete media file %s', name)
        event.listen(db, 'after_commit', remove_files, once=True)
    return len(names)


def prune_unused_media(db, older_than=timedelta(days=1), batch=500):
    """Uploads that were never saved onto anything (the form was abandoned):
    one anti-join on media_references, at most [batch] per run."""
    ids = db.scalars(select(m.MediaAsset.id).where(m.MediaAsset.created_at < m.now() - older_than,
        ~exists().where(m.MediaReference.media_id == m.MediaAsset.id))
        .order_by(m.MediaAsset.created_at).limit(batch)).all()
    # release_media re-checks each one inside this transaction.
    return release_media(db, [f'/media/{id}' for id in ids])


def visible_to_buyers(db, id):
    """On a live, fresh listing: the only way media crosses to other members."""
    return db.scalar(select(exists().where(m.MediaReference.media_id == id,
        m.MediaReference.owner_table == 'listings', m.Listing.id == m.MediaReference.owner_id,
        m.Listing.listing_status == 'live', m.Listing.confirmation_due_at > m.now())))


# Signed links: long enough to load a screen or watch a clip, short enough
# that a leaked link soon stops working. Every new view asks for a fresh one.
PHOTO_LINK_SECONDS = 10 * 60
VIDEO_LINK_SECONDS = 30 * 60
TYPES_BY_EXTENSION = {'jpg': 'image/jpeg', **{extension: type for type, extension in VIDEO_TYPES.items()}}


def signed_link(asset):
    seconds = VIDEO_LINK_SECONDS if asset.content_type.startswith('video/') else PHOTO_LINK_SECONDS
    return {'url': storage().signed_get(asset.storage_name, asset.content_type, seconds),
        'expires_at': m.now() + timedelta(seconds=seconds), 'content_type': asset.content_type}


# Resumable video uploads: start -> sign parts -> PUT each part straight to
# storage -> complete -> confirm. Only confirm creates the MediaAsset, after
# checking the stored object's size and container signature.
def _pending(row):
    return f'pending/{row.id}'


def _part_count(size):
    return -(-size // PART_SIZE)


def _upload(db, owner_id, id):
    row = db.get(m.MediaUpload, id)
    if not row or row.owner_id != owner_id:
        fail('err.upload_expired_choose_video_again', 404)
    return row


def _too_big(limit):
    return error('err.choose_video_smaller', 413, mb=limit // (1024 * 1024))


def start_video_upload(db, owner_id, size, limit):
    if size > limit:
        raise _too_big(limit)
    if size < 16:
        fail('err.use_mp4_mov_webm_3gp', 422)
    row = m.MediaUpload(owner_id=owner_id, size=size)
    db.add(row)
    db.flush()
    row.upload_id = storage().start_multipart(_pending(row))
    return {'id': row.id, 'size': size, 'part_size': PART_SIZE, 'parts': _part_count(size), 'uploaded': []}


def video_upload_status(db, owner_id, id):
    """Parts already stored, so an interrupted upload resumes where it stopped."""
    row = _upload(db, owner_id, id)
    target = storage()
    parts = target.uploaded_parts(_pending(row), row.upload_id)
    return {'id': row.id, 'size': row.size, 'part_size': PART_SIZE, 'parts': _part_count(row.size),
        'uploaded': parts or [], 'completed': parts is None and target.head(_pending(row)) is not None}


def sign_video_parts(db, owner_id, id, numbers):
    row = _upload(db, owner_id, id)
    if any(not 1 <= number <= _part_count(row.size) for number in numbers):
        fail('err.part_not_upload', 422)
    target = storage()
    return {'parts': [{'number': number, 'url': target.sign_part(_pending(row), row.upload_id, number, VIDEO_LINK_SECONDS)}
        for number in sorted(set(numbers))], 'expires_at': m.now() + timedelta(seconds=VIDEO_LINK_SECONDS)}


def complete_video_upload(db, owner_id, id, parts):
    row = _upload(db, owner_id, id)
    parts = sorted(({'number': part.number, 'etag': part.etag} for part in parts), key=lambda part: part['number'])
    if [part['number'] for part in parts] != list(range(1, _part_count(row.size) + 1)):
        fail('err.upload_every_part_video_before', 422)
    if not storage().complete_multipart(_pending(row), row.upload_id, parts):
        fail('err.some_parts_video_did_not', 409)
    return {'id': row.id, 'completed': True}


def confirm_video_upload(db, owner_id, id, limit):
    row = _upload(db, owner_id, id)
    target = storage()
    stored = target.head(_pending(row))
    if stored is None:
        fail('err.finish_uploading_video_first', 409)
    size, head = stored
    content_type = video_type(head)
    if size != row.size or size > limit or content_type is None:
        # Never keep bytes that are not the video that was announced.
        target.delete(_pending(row))
        if size > limit:
            raise _too_big(limit)
        fail('err.use_mp4_mov_webm_3gp', 422)
    asset = m.MediaAsset(owner_id=owner_id, content_type=content_type)
    asset.id = m.identifier()
    asset.storage_name = f'{asset.id}.{VIDEO_TYPES[content_type]}'
    target.promote(_pending(row), asset.storage_name, content_type)
    db.delete(row)
    db.add(asset)
    db.flush()
    return {'id': asset.id, 'url': f'/media/{asset.id}'}


def prune_stale_uploads(db, older_than=timedelta(days=1)):
    """Uploads started but never confirmed. R2's lifecycle rule also removes
    their bytes; this clears the rows and, on local disk, the files."""
    target = storage()
    rows = db.scalars(select(m.MediaUpload).where(m.MediaUpload.created_at < m.now() - older_than)).all()
    for row in rows:
        try:
            target.abort_multipart(_pending(row), row.upload_id)
            target.delete(_pending(row))
        except Exception:
            log.exception('Could not remove pending upload %s', row.id)
        db.delete(row)
    return len(rows)
