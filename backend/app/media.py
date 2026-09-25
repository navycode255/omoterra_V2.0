from io import BytesIO
from pathlib import Path
from PIL import Image, ImageOps, UnidentifiedImageError
from fastapi import HTTPException
from .config import settings
from . import models as m

Image.MAX_IMAGE_PIXELS = 25_000_000


VIDEO_TYPES = {'video/mp4': 'mp4', 'video/quicktime': 'mov', 'video/webm': 'webm', 'video/3gpp': '3gp'}


def validate_owned_media(db, urls, owner_id, allow_unowned=False, video=False):
    for url in urls:
        asset = db.get(m.MediaAsset, url.removeprefix('/media/'))
        if not asset or (asset.owner_id != owner_id and not (allow_unowned and asset.owner_id is None)):
            raise HTTPException(422, 'A video is unavailable. Upload your own stock video again.' if video
                else 'A photo is unavailable. Upload your own stock photo again.')
        if asset.content_type.startswith('video/') != video:
            raise HTTPException(422, 'Add photos as photos and the video as a video.')


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
        raise HTTPException(422, 'Use an MP4, MOV, WebM or 3GP video.')
    id = m.identifier()
    root = Path(settings().media_directory)
    root.mkdir(parents=True, exist_ok=True)
    name = f'{id}.{VIDEO_TYPES[content_type]}'
    size = len(head)
    try:
        with open(root / name, 'wb') as out:
            out.write(head)
            while chunk := await upload.read(1024 * 1024):
                size += len(chunk)
                if size > limit:
                    raise HTTPException(413, f'Choose a video smaller than {limit // (1024 * 1024)} MB.')
                out.write(chunk)
    except BaseException:
        (root / name).unlink(missing_ok=True)
        raise
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
            original.load()
            # Re-encode pixel data: strip GPS/EXIF, filenames and other metadata.
            image = ImageOps.exif_transpose(original).convert('RGB')
            image.thumbnail((1600, 1600))
            clean = Image.new('RGB', image.size)
            clean.paste(image)
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError, Image.DecompressionBombWarning):
        raise HTTPException(422, 'Use a valid JPEG, PNG or WebP photo under 25 megapixels.')
    id = m.identifier()
    root = Path(settings().media_directory)
    root.mkdir(parents=True, exist_ok=True)
    name = f'{id}.jpg'
    clean.save(root / name, 'JPEG', quality=88)
    asset = m.MediaAsset(id=id, owner_id=owner_id, storage_name=name)
    db.add(asset)
    db.flush()
    return {'id': id, 'url': f'/media/{id}'}
