from datetime import date, timedelta
from sqlalchemy import select, func
from app import models as m
from test_commerce import headers

OPS = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin'}


def ops_key(key):
    return {**OPS, 'Idempotency-Key': key}


def supplier_body(phone='+255712345699', current_batch=None):
    return {
        'phone': phone, 'name': 'Farmer Example', 'public_alias': 'JM Poultry Supply',
        'legal_name': 'Example Farmer', 'alternate_phone': '', 'region': 'Pwani',
        'district': 'Kibaha', 'general_area': 'Maili Moja', 'categories': ['broilers', 'layers', 'eggs'],
        'primary_category': 'broilers', 'production_profile': {
            'broilers': {'capacity': '2000', 'unit': 'bird', 'frequency': 'every 6 weeks'},
            'layers': {'capacity': '800', 'unit': 'bird', 'frequency': 'continuous'},
            'eggs': {'capacity': '40', 'unit': 'tray', 'frequency': 'daily'},
        }, 'production_frequency': 'every 6 weeks',
        'internal_pickup_address': 'Private farm road, Maili Moja', 'pickup_instructions': 'Call on arrival',
        'omoterra_pickup': True, 'supplier_transport': False, 'supply_forms': ['live'],
        'preferred_contact_method': 'phone', 'operating_notes': 'Farm opens at 7am',
        'internal_notes': 'Staff introduction visit', 'verification': {},
        'current_batch': current_batch, 'future_batches': [],
    }


def sample_batch():
    return {
        'category': 'broilers', 'subtype': 'Ross 308', 'initial_quantity': '1450',
        'current_age': '24', 'age_unit': 'days',
        'expected_ready_date': (date.today() + timedelta(days=20)).isoformat(),
        'expected_min_weight_kg': '1.8', 'expected_max_weight_kg': '2.2',
        'form': 'live', 'asking_price_per_unit': '12000', 'region': 'Pwani',
        'private_pickup_location': 'Private farm road', 'photos': [],
    }


def test_staff_onboards_canonical_supplier_then_supplier_signin_reuses_phone(client, sessions):
    body = supplier_body(current_batch=sample_batch())
    created = client.post('/api/v1/ops/suppliers', headers=ops_key('supplier-create-01'), json=body)
    assert created.status_code == 201, created.text
    supplier_id = created.json()['id']
    assert created.json()['status'] == 'under_review'
    assert created.json()['batches_created'] == 1
    retried = client.post('/api/v1/ops/suppliers', headers=ops_key('supplier-create-01'), json=body)
    assert retried.status_code == 200

    with sessions() as db:
        profile = db.get(m.SupplierProfile, supplier_id)
        user = db.get(m.User, supplier_id)
        batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.supplier_id == supplier_id))
        assert user.phone == body['phone'] and 'supplier' in user.roles
        assert profile.categories == ['broilers', 'layers', 'eggs']
        assert profile.production_profile['broilers']['capacity'] == '2000'
        assert profile.status == 'under_review'
        assert batch.initial_quantity == 1450 and batch.current_age == 24
        assert batch.expected_min_weight_kg == 1.8 and batch.expected_max_weight_kg == 2.2
        assert batch.private_pickup_location == 'Private farm road'
        assert db.scalar(select(func.count()).select_from(m.SupplierBatch).where(
            m.SupplierBatch.supplier_id == supplier_id)) == 1

    challenge = client.post('/api/v1/auth/otp', json={'phone': body['phone']}).json()
    signed_in = client.post('/api/v1/auth/verify', json={
        'challenge_id': challenge['challenge_id'], 'code': challenge['development_code'],
    })
    assert signed_in.status_code == 200
    assert signed_in.json()['user']['id'] == supplier_id
    owner = client.get('/api/v1/supplier/profile', headers={'Authorization': f"Bearer {signed_in.json()['access_token']}"})
    assert owner.status_code == 200
    assert owner.json()['legal_name'] == 'Example Farmer'
    assert owner.json()['internal_pickup_address'] == 'Private farm road, Maili Moja'
    assert 'internal_notes' not in owner.json() and 'verification' not in owner.json()


def test_supplier_self_onboards_as_additional_buyer_capability_and_can_skip_batch(client, sessions):
    body = supplier_body(phone='+255712345678')
    body.update({'name': 'Buyer Test', 'current_batch': None})
    submitted = client.post('/api/v1/supplier/onboarding', headers={**headers(), 'Idempotency-Key': 'self-onboarding-01'}, json=body)
    assert submitted.status_code == 200, submitted.text
    assert submitted.json()['user']['roles'] == ['buyer', 'supplier']
    assert submitted.json()['batches'] == []
    retried = client.post('/api/v1/supplier/onboarding', headers={**headers(), 'Idempotency-Key': 'self-onboarding-01'}, json=body)
    assert retried.status_code == 200
    with sessions() as db:
        profile = db.get(m.SupplierProfile, db.get(m.User, submitted.json()['user']['id']).id)
        assert profile.status == 'under_review'
        assert profile.production_profile['broilers']['capacity'] == '2000'


def test_operator_approval_is_distinct_and_private_supplier_fields_stay_private(client, sessions, seeded):
    with sessions.begin() as db:
        profile = db.get(m.SupplierProfile, seeded['supplier'])
        profile.status = 'under_review'
    assert client.get('/api/v1/listings', headers=headers()).json() == []
    assert client.get(f"/api/v1/listings/{seeded['listing']}", headers=headers()).status_code == 404
    blocked = client.patch(f"/api/v1/ops/suppliers/{seeded['supplier']}/status", headers=OPS, json={'status': 'approved'})
    assert blocked.status_code == 422
    checks = {'phone_confirmed': True, 'identity_reviewed': True, 'location_confirmed': True,
        'production_seen': True, 'pickup_access_checked': True}
    verified = client.patch(f"/api/v1/ops/suppliers/{seeded['supplier']}/verification", headers=OPS, json={'checks': checks})
    assert verified.status_code == 200, verified.text
    approve = client.patch(f"/api/v1/ops/suppliers/{seeded['supplier']}/status", headers=OPS, json={'status': 'approved'})
    assert approve.status_code == 200, approve.text
    listings = client.get('/api/v1/listings', headers=headers()).json()
    assert len(listings) == 1
    detail = client.get(f"/api/v1/listings/{seeded['listing']}", headers=headers()).json()
    serialized = str(detail)
    for private in ['Secret legal name', 'Secret farm address', '+255712345680', 'internal_notes', 'verification']:
        assert private not in serialized
    ops = client.get(f"/api/v1/ops/suppliers/{seeded['supplier']}", headers=OPS).json()
    assert ops['legal_name'] == 'Secret legal name'
    assert ops['internal_pickup_address'] == 'Secret farm address'


def test_unapproved_supplier_cannot_publish_and_suspension_removes_buyer_supply(client, sessions, seeded):
    with sessions.begin() as db:
        db.get(m.SupplierProfile, seeded['supplier']).status = 'under_review'
    response = client.post(f"/api/v1/ops/listings/{seeded['listing']}/approve", headers=OPS, json={
        'buyer_price_per_unit': '12000', 'public_alias': 'Green Pastures',
    })
    assert response.status_code == 409
    with sessions.begin() as db:
        profile = db.get(m.SupplierProfile, seeded['supplier'])
        profile.status = 'approved'
    suspend = client.patch(f"/api/v1/ops/suppliers/{seeded['supplier']}/status", headers=OPS, json={'status': 'suspended'})
    assert suspend.status_code == 200
    assert client.get('/api/v1/listings', headers=headers()).json() == []


def test_supplier_profile_validates_categories_capacity_weights_and_future_dates(client):
    body = supplier_body()
    body['production_profile']['broilers']['capacity'] = '-1'
    assert client.post('/api/v1/ops/suppliers', headers=ops_key('supplier-bad-capacity'), json=body).status_code == 422
    body = supplier_body(current_batch=sample_batch())
    body['current_batch']['expected_max_weight_kg'] = '1.2'
    assert client.post('/api/v1/ops/suppliers', headers=ops_key('supplier-bad-weight'), json=body).status_code == 422
    body = supplier_body(current_batch=sample_batch())
    body['current_batch']['initial_quantity'] = '0'
    assert client.post('/api/v1/ops/suppliers', headers=ops_key('supplier-bad-qty'), json=body).status_code == 422
    body = supplier_body()
    body['categories'] = []
    assert client.post('/api/v1/ops/suppliers', headers=ops_key('supplier-no-category'), json=body).status_code == 422


def test_ops_supplier_photos_round_trip_through_profile_edits(client):
    from io import BytesIO
    from PIL import Image
    created = client.post('/api/v1/ops/suppliers', headers=ops_key('supplier-photos-01'), json=supplier_body('+255712345611'))
    assert created.is_success, created.text
    supplier_id = created.json()['id']
    raw = BytesIO()
    Image.new('RGB', (40, 30), (40, 120, 60)).save(raw, 'JPEG')
    photo = client.post('/api/v1/ops/suppliers/photos', headers=ops_key('supplier-photo-upload-01'),
        files={'file': ('farm.jpg', raw.getvalue(), 'image/jpeg')})
    assert photo.status_code == 200, photo.text
    profile = {k: v for k, v in supplier_body().items() if k not in ('phone', 'name', 'internal_notes', 'verification', 'current_batch', 'future_batches')}
    saved = client.put(f'/api/v1/ops/suppliers/{supplier_id}', headers=OPS, json={**profile, 'evidence_photos': [photo.json()['url']]})
    assert saved.status_code == 200, saved.text
    # The dashboard rebuilds the whole profile from this response before each
    # section edit, so photos missing here would be wiped by the next save.
    detail = client.get(f'/api/v1/ops/suppliers/{supplier_id}', headers=OPS).json()
    assert detail['evidence_photos'] == [photo.json()['url']]


def _jpeg(color=(40, 120, 60)):
    from io import BytesIO
    from PIL import Image
    raw = BytesIO()
    Image.new('RGB', (40, 30), color).save(raw, 'JPEG')
    return raw.getvalue()


def test_ops_supplier_has_many_photos_added_and_deleted_individually(client, seeded):
    supplier = seeded['supplier']
    files = [('files', (f'farm{i}.jpg', _jpeg((i * 40, 90, 60)), 'image/jpeg')) for i in range(3)]
    added = client.post(f'/api/v1/ops/suppliers/{supplier}/photos', headers=OPS, files=files)
    assert added.status_code == 201, added.text
    photos = added.json()['photos']
    assert len(photos) == 3
    more = client.post(f'/api/v1/ops/suppliers/{supplier}/photos', headers=OPS, files=[('files', ('x.jpg', _jpeg(), 'image/jpeg'))])
    assert len(more.json()['photos']) == 4
    removed = client.delete(f"/api/v1/ops/suppliers/{supplier}/photos/{photos[1]['id']}", headers=OPS)
    assert removed.status_code == 200
    remaining = [p['id'] for p in removed.json()['photos']]
    assert photos[1]['id'] not in remaining and len(remaining) == 3
    assert client.delete(f"/api/v1/ops/suppliers/{supplier}/photos/{photos[1]['id']}", headers=OPS).status_code == 404
    detail = client.get(f'/api/v1/ops/suppliers/{supplier}', headers=OPS).json()
    assert [p['id'] for p in detail['photos']] == remaining
    assert detail['evidence_photos'] == [p['url'] for p in detail['photos']]


def test_profile_edit_without_photos_keeps_existing_photos(client):
    created = client.post('/api/v1/ops/suppliers', headers=ops_key('supplier-photos-keep'), json=supplier_body('+255712345612'))
    supplier = created.json()['id']
    client.post(f'/api/v1/ops/suppliers/{supplier}/photos', headers=OPS, files=[('files', ('a.jpg', _jpeg(), 'image/jpeg'))])
    profile = {k: v for k, v in supplier_body().items() if k not in ('phone', 'name', 'internal_notes', 'verification', 'current_batch', 'future_batches')}
    assert client.put(f'/api/v1/ops/suppliers/{supplier}', headers=OPS, json={**profile, 'evidence_photos': []}).status_code == 200
    assert len(client.get(f'/api/v1/ops/suppliers/{supplier}', headers=OPS).json()['photos']) == 1


def test_supplier_has_at_most_one_video(client, sessions, seeded):
    import pytest
    from sqlalchemy.exc import IntegrityError
    supplier = seeded['supplier']
    url = f'/api/v1/ops/suppliers/{supplier}/video'
    empty = client.get(url, headers=OPS).json()
    assert empty == {'video': None, 'upload_enabled': False}
    first = client.post(url, headers=OPS, json={'youtube_url': 'https://youtu.be/dQw4w9WgXcQ', 'title': 'Farm tour'})
    assert first.status_code == 201, first.text
    assert first.json()['video']['thumbnail_url'] == 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg'
    second = client.post(url, headers=OPS, json={'youtube_url': 'https://www.youtube.com/watch?v=9bZkp7q19f0'})
    assert second.status_code == 409 and second.json()['detail'] == 'Supplier already has a video.'
    replaced = client.put(url, headers=OPS, json={'youtube_url': 'https://www.youtube.com/shorts/9bZkp7q19f0', 'title': 'New tour'})
    assert replaced.status_code == 200, replaced.text
    assert replaced.json()['video']['id'] == first.json()['video']['id']
    assert replaced.json()['video']['youtube_video_id'] == '9bZkp7q19f0'
    with sessions() as db:
        assert db.scalar(select(func.count()).select_from(m.SupplierVideo).where(m.SupplierVideo.supplier_id == supplier)) == 1
    # The database itself refuses a second video row for the same supplier.
    with pytest.raises(IntegrityError):
        with sessions.begin() as db:
            db.add(m.SupplierVideo(supplier_id=supplier, youtube_video_id='aaaaaaaaaaa', youtube_url='x', thumbnail_url='y'))
    assert client.post(url, headers=OPS, json={'youtube_url': 'https://example.com/video'}).status_code == 422
    assert client.delete(url, headers=OPS).status_code == 200
    assert client.get(url, headers=OPS).json()['video'] is None
    assert client.delete(url, headers=OPS).status_code == 404
    upload = client.post(f'{url}/upload', headers=OPS, files={'file': ('tour.mp4', b'0' * 10, 'video/mp4')})
    assert upload.status_code == 503


def test_youtube_links_in_common_forms_are_understood():
    from app.video import youtube_id
    for link in ['https://youtu.be/dQw4w9WgXcQ?t=3', 'youtube.com/watch?v=dQw4w9WgXcQ&list=x', 'https://m.youtube.com/shorts/dQw4w9WgXcQ',
            'https://www.youtube.com/embed/dQw4w9WgXcQ', 'https://www.youtube.com/live/dQw4w9WgXcQ', 'dQw4w9WgXcQ']:
        assert youtube_id(link) == 'dQw4w9WgXcQ', link
