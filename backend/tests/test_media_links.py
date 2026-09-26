"""Signed media links and resumable video uploads, against LocalStorage."""
import time
from urllib.parse import parse_qs, urlsplit

from app import models as m
from app import storage as store
from app.config import settings
from app.storage import PART_SIZE
from test_commerce import headers
from test_stock_media_location import MP4, photo, video

OPS = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin'}


def link(client, url, role='supplier'):
    return client.get('/api/v1' + url, headers=headers(role))


def test_media_answers_with_a_short_lived_signed_link(client, tmp_path):
    settings().media_directory = str(tmp_path)
    url = photo(client)
    signed = link(client, url).json()
    assert signed['url'].startswith('/media/local/') and signed['content_type'] == 'image/jpeg'
    expires = int(parse_qs(urlsplit(signed['url']).query)['expires'][0])
    assert 590 <= expires - time.time() <= 600
    # The link itself needs no sign-in; the signature is the permission.
    file = client.get('/api/v1' + signed['url'])
    assert file.status_code == 200 and file.content[:2] == b'\xff\xd8'
    assert file.headers['cache-control'] == 'private, max-age=31536000, immutable'
    assert client.get('/api/v1' + signed['url'].replace('signature=', 'signature=0')).status_code == 403
    ops = client.get('/api/v1/ops' + url, headers=OPS).json()
    assert client.get('/api/v1' + ops['url']).status_code == 200
    clip = video(client).json()['url']
    clip_link = link(client, clip).json()
    assert 1790 <= int(parse_qs(urlsplit(clip_link['url']).query)['expires'][0]) - time.time() <= 1800
    ranged = client.get('/api/v1' + clip_link['url'], headers={'Range': 'bytes=4-11'})
    assert ranged.status_code == 206 and ranged.content == MP4[4:12]


def test_expired_link_stops_working(client, tmp_path, monkeypatch):
    settings().media_directory = str(tmp_path)
    signed = link(client, photo(client)).json()['url']
    later = time.time() + 601
    monkeypatch.setattr(store.time, 'time', lambda: later)
    assert client.get('/api/v1' + signed).status_code == 403


def test_api_refuses_to_sign_media_the_user_may_not_see(client, sessions, seeded, tmp_path):
    settings().media_directory = str(tmp_path)
    url = photo(client)
    for role in ('buyer', 'other'):
        refused = link(client, url, role)
        assert refused.status_code == 404 and 'url' not in refused.json()
    assert link(client, '/media/' + m.identifier()).status_code == 404
    assert client.get('/api/v1/ops/media/' + m.identifier(), headers=OPS).status_code == 404
    with sessions.begin() as db:
        db.get(m.Listing, seeded['listing']).photos = [url]
    assert link(client, url, 'buyer').status_code == 200
    with sessions.begin() as db:
        db.get(m.Listing, seeded['listing']).listing_status = 'pending_review'
    assert link(client, url, 'buyer').status_code == 404
    # Names outside the media folder are never served, even with a valid signature.
    query = store.signed_query('get', '..%2F.env', seconds=60)
    assert client.get(f'/api/v1/media/local/..%2F.env?{query}').status_code in (403, 404)


def start(client, size, role='supplier'):
    return client.post('/api/v1/media/video/uploads', headers=headers(role), json={'size': size})


def put_parts(client, upload, chunks, numbers=None):
    numbers = numbers or list(range(1, len(chunks) + 1))
    signed = client.post(f'/api/v1/media/video/uploads/{upload}/parts', headers=headers('supplier'), json={'numbers': numbers})
    assert signed.status_code == 200, signed.text
    etags = []
    for part in signed.json()['parts']:
        response = client.put('/api/v1' + part['url'], content=chunks[part['number'] - 1])
        assert response.status_code == 200, response.text
        etags.append({'number': part['number'], 'etag': response.headers['etag']})
    return etags


def finish(client, upload, parts):
    return client.post(f'/api/v1/media/video/uploads/{upload}/complete', headers=headers('supplier'), json={'parts': parts})


def confirm(client, upload, role='supplier'):
    return client.post('/api/v1/media/video/confirm', headers=headers(role), json={'upload_id': upload})


def test_resumable_video_upload_confirms_into_a_media_asset(client, sessions, tmp_path):
    settings().media_directory = str(tmp_path)
    first, second = MP4 + b'\x00' * (PART_SIZE - len(MP4)), b'last part'
    started = start(client, PART_SIZE + len(second))
    assert started.status_code == 200, started.text
    upload = started.json()['id']
    assert started.json()['parts'] == 2 and started.json()['part_size'] == PART_SIZE
    done = put_parts(client, upload, [first, second], [1])
    # A dropped connection resumes from the parts already stored.
    status = client.get(f'/api/v1/media/video/uploads/{upload}', headers=headers('supplier')).json()
    assert [part['number'] for part in status['uploaded']] == [1] and not status['completed']
    assert confirm(client, upload).status_code == 409
    assert finish(client, upload, done).status_code == 422
    done += put_parts(client, upload, [first, second], [2])
    assert finish(client, upload, [done[0], {**done[1], 'etag': '"stale"'}]).status_code == 409
    assert finish(client, upload, done).status_code == 200
    confirmed = confirm(client, upload)
    assert confirmed.status_code == 200, confirmed.text
    url = confirmed.json()['url']
    with sessions() as db:
        asset = db.get(m.MediaAsset, url.removeprefix('/media/'))
        assert asset.content_type == 'video/mp4' and asset.storage_name.endswith('.mp4')
        assert db.get(m.MediaUpload, upload) is None
    signed = link(client, url).json()
    file = client.get('/api/v1' + signed['url'])
    assert file.headers['content-type'] == 'video/mp4' and file.content == first + second
    assert not list((tmp_path / '.uploads').iterdir())
    assert confirm(client, upload).status_code == 404


def test_confirm_rejects_a_file_that_is_not_a_video(client, sessions, tmp_path):
    settings().media_directory = str(tmp_path)
    fake = b'<html>not a video</html>'
    upload = start(client, len(fake)).json()['id']
    assert finish(client, upload, put_parts(client, upload, [fake])).status_code == 200
    rejected = confirm(client, upload)
    assert rejected.status_code == 422 and 'MP4' in rejected.json()['detail']
    with sessions() as db:
        assert db.query(m.MediaAsset).count() == 0
    assert not [path for path in (tmp_path / '.uploads').iterdir()]


def test_confirm_rejects_a_size_other_than_announced(client, tmp_path):
    settings().media_directory = str(tmp_path)
    upload = start(client, len(MP4) + 10).json()['id']
    assert finish(client, upload, put_parts(client, upload, [MP4])).status_code == 200
    assert confirm(client, upload).status_code == 422


def test_uploads_belong_to_their_supplier(client, sessions, seeded, tmp_path):
    settings().media_directory = str(tmp_path)
    assert start(client, 100, 'buyer').status_code == 403
    assert start(client, settings().stock_video_max_bytes + 1).status_code == 413
    upload = start(client, len(MP4)).json()['id']
    with sessions.begin() as db:
        db.get(m.User, seeded['other']).roles = ['supplier']
    for path in (f'/media/video/uploads/{upload}', ):
        assert client.get('/api/v1' + path, headers=headers('other')).status_code == 404
    assert client.post(f'/api/v1/media/video/uploads/{upload}/parts', headers=headers('other'), json={'numbers': [1]}).status_code == 404
    assert confirm(client, upload, 'other').status_code == 404
    assert client.post(f'/api/v1/media/video/uploads/{upload}/parts', headers=headers('supplier'), json={'numbers': [2]}).status_code == 422
    part = client.post(f'/api/v1/media/video/uploads/{upload}/parts', headers=headers('supplier'), json={'numbers': [1]}).json()['parts'][0]
    # A part link only works for its own upload and part number.
    assert client.put('/api/v1' + part['url'].replace('/1?', '/2?'), content=MP4).status_code == 403
    assert client.put('/api/v1' + part['url'], content=b'\x00' * (PART_SIZE + 1)).status_code == 413


def test_stale_uploads_are_pruned(client, sessions, tmp_path):
    from datetime import timedelta
    from app.media import prune_stale_uploads
    settings().media_directory = str(tmp_path)
    upload = start(client, len(MP4)).json()['id']
    put_parts(client, upload, [MP4])
    with sessions.begin() as db:
        db.get(m.MediaUpload, upload).created_at = m.now() - timedelta(days=2)
    with sessions.begin() as db:
        assert prune_stale_uploads(db) == 1
    assert not list((tmp_path / '.uploads').iterdir())
