from io import BytesIO
from pathlib import Path
from PIL import Image, ImageOps, UnidentifiedImageError
from fastapi import HTTPException
from .config import settings
from . import models as m

Image.MAX_IMAGE_PIXELS = 25_000_000


def validate_owned_media(db, urls, owner_id):
    for url in urls:
        asset = db.get(m.MediaAsset, url.removeprefix('/media/'))
        if not asset or asset.owner_id != owner_id:
            raise HTTPException(422, 'A photo is unavailable. Upload your own stock photo again.')


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
