from io import BytesIO
from PIL import Image
from app import models as m
from app.config import settings
from test_commerce import headers
from test_supplier_onboarding import supplier_body

MP4 = b'\x00\x00\x00\x18ftypmp42' + b'\x00' * 64


def photo(client, role='supplier'):
    raw = BytesIO(); Image.new('RGB', (10, 10)).save(raw, 'JPEG')
    response = client.post('/api/v1/media', headers=headers(role), files={'file': ('p.jpg', raw.getvalue(), 'image/jpeg')})
    assert response.status_code == 200, response.text
    return response.json()['url']


def video(client, role='supplier', raw=MP4):
    return client.post('/api/v1/media/video', headers=headers(role), files={'file': ('v.mp4', raw, 'video/mp4')})


def self_onboarding(**extra):
    body = supplier_body(phone='+255712345678')
    body.update({'name': 'Buyer Test', 'current_batch': None, **extra})
    for key in ('phone', 'internal_notes', 'verification'):
        body.pop(key)
    return body


def test_supplier_registration_saves_exact_farm_location(client, sessions):
    body = self_onboarding(farm_latitude='-6.792354', farm_longitude='39.208328',
        farm_map_url='https://maps.app.goo.gl/AbCdEf123')
    response = client.post('/api/v1/supplier/onboarding', headers={**headers(), 'Idempotency-Key': 'farm-pin-01'}, json=body)
    assert response.status_code == 200, response.text
    profile = client.get('/api/v1/supplier/profile', headers=headers()).json()
    assert profile['farm_latitude'] == -6.792354 and profile['farm_longitude'] == 39.208328
    assert profile['farm_map_url'] == 'https://maps.app.goo.gl/AbCdEf123'
    ops = client.get(f"/api/v1/ops/suppliers/{response.json()['user']['id']}", headers={'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin'}).json()
    assert float(ops['farm_latitude']) == -6.792354


def test_farm_location_rejects_other_links_and_half_pins(client):
    for extra in ({'farm_map_url': 'https://google.com.evil.io/maps/x'},
                  {'farm_latitude': '-6.79'},
                  {'farm_latitude': '-96', 'farm_longitude': '39'}):
        response = client.post('/api/v1/supplier/onboarding', headers={**headers(), 'Idempotency-Key': f'bad-pin-{len(str(extra))}'}, json=self_onboarding(**extra))
        assert response.status_code == 422, extra


def test_profile_save_without_location_keeps_saved_pin(client, sessions, seeded):
    with sessions.begin() as db:
        profile = db.get(m.SupplierProfile, seeded['supplier'])
        profile.farm_latitude, profile.farm_longitude = -6.5, 38.9
    body = self_onboarding()
    body.pop('name'); body.pop('current_batch'); body.pop('future_batches')
    saved = client.put('/api/v1/supplier/profile', headers=headers('supplier'), json=body)
    assert saved.status_code == 200, saved.text
    assert saved.json()['farm_latitude'] == -6.5


def test_supplier_uploads_video_and_edits_stock_media(client, sessions, seeded, tmp_path):
    settings().media_directory = str(tmp_path)
    uploaded = video(client)
    assert uploaded.status_code == 200, uploaded.text
    clip = uploaded.json()['url']
    picture = photo(client)
    response = client.put(f"/api/v1/supplier/stock/{seeded['listing']}/media", headers=headers('supplier'),
        json={'photos': [picture], 'video': clip})
    assert response.status_code == 200, response.text
    assert response.json()['video'] == clip and response.json()['photos'] == [picture]
    # New media on approved stock goes back to Omoterra review before buyers see it.
    assert response.json()['listing_status'] == 'pending_review'
    assert client.get(f"/api/v1/listings/{seeded['listing']}", headers=headers()).status_code == 404
    assert client.get('/api/v1' + clip, headers=headers()).status_code == 404
    owner = client.get('/api/v1' + clip, headers=headers('supplier'))
    assert owner.status_code == 200 and owner.headers['content-type'] == 'video/mp4'
    approved = client.post(f"/api/v1/ops/listings/{seeded['listing']}/approve", headers={'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin'},
        json={'buyer_price_per_unit': '12000', 'public_alias': 'Green Pastures'})
    assert approved.status_code == 200
    assert client.get(f"/api/v1/listings/{seeded['listing']}", headers=headers()).json()['video'] == clip
    assert client.get('/api/v1' + clip, headers=headers()).status_code == 200


def test_stock_media_rejects_wrong_kinds_and_other_owners(client, seeded, tmp_path):
    settings().media_directory = str(tmp_path)
    assert video(client, raw=b'not a video at all, just text').status_code == 422
    assert video(client, role='buyer').status_code == 403
    picture = photo(client)
    clip = video(client).json()['url']
    url = f"/api/v1/supplier/stock/{seeded['listing']}/media"
    assert client.put(url, headers=headers('supplier'), json={'photos': [clip]}).status_code == 422
    assert client.put(url, headers=headers('supplier'), json={'video': picture}).status_code == 422
    stranger = photo(client, role='buyer')
    assert client.put(url, headers=headers('supplier'), json={'photos': [stranger]}).status_code == 422
    assert client.put(url, headers=headers('buyer'), json={'photos': []}).status_code in (403, 404)


def test_unchanged_media_keeps_stock_live(client, seeded):
    response = client.put(f"/api/v1/supplier/stock/{seeded['listing']}/media", headers=headers('supplier'),
        json={'photos': [], 'video': None})
    assert response.status_code == 200
    assert response.json()['listing_status'] == 'live'


def test_video_over_limit_is_refused_and_not_kept(client, tmp_path):
    settings().media_directory = str(tmp_path)
    limit = settings().stock_video_max_bytes
    settings().stock_video_max_bytes = 1024
    try:
        response = video(client, raw=MP4 + b'\x00' * 4096)
    finally:
        settings().stock_video_max_bytes = limit
    assert response.status_code == 413
    assert list(tmp_path.iterdir()) == []
