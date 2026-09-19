from datetime import timedelta
from sqlalchemy import select
from app import models as m
from app.auth import otp_hash
from app.config import settings
from test_commerce import headers, reserve, checkout_data


def test_otp_code_is_hidden_once_a_real_sms_provider_is_set(client):
    # Even on the live deployment, the OTP code must never appear in the API
    # response once sms_provider stops being 'development' — that would leak
    # the code to anyone who can see the network response.
    original = settings().sms_provider
    settings().sms_provider = 'twilio'
    try:
        start = client.post('/api/v1/auth/otp', json={'phone': '+255711111112'})
        assert start.status_code == 200
        assert 'development_code' not in start.json()
    finally:
        settings().sms_provider = original


def test_otp_failed_attempts_persist_and_code_single_use(client, sessions):
    start = client.post('/api/v1/auth/otp', json={'phone': '+255711111111'})
    assert start.status_code == 200
    challenge = start.json()
    assert client.post('/api/v1/auth/otp', json={'phone': '+255711111111'}).status_code == 429
    wrong = '000000' if challenge['development_code'] != '000000' else '111111'
    payload = {'challenge_id': challenge['challenge_id'], 'code': wrong}
    assert client.post('/api/v1/auth/verify', json=payload).status_code == 400
    with sessions() as db:
        assert db.get(m.OtpChallenge, challenge['challenge_id']).attempts == 1
    payload['code'] = challenge['development_code']
    response = client.post('/api/v1/auth/verify', json=payload)
    assert response.status_code == 200 and response.json()['access_token']
    assert client.post('/api/v1/auth/verify', json=payload).status_code == 400


def test_expired_checkout_persists_release(client, sessions, seeded):
    id = reserve(sessions, seeded)
    with sessions.begin() as db:
        db.get(m.StockReservation, id).expires_at = m.now() - timedelta(seconds=1)
    response = client.post('/api/v1/orders', headers=headers(), json=checkout_data(seeded, id).model_dump(mode='json'))
    assert response.status_code == 409
    with sessions() as db:
        assert db.get(m.StockReservation, id).status == 'expired'
        assert db.get(m.Listing, seeded['listing']).quantity_reserved == 0


def test_address_ownership_and_order_delivery_snapshot(client, sessions, seeded):
    id = reserve(sessions, seeded)
    payload = checkout_data(seeded, id).model_dump(mode='json')
    response = client.post('/api/v1/orders', headers=headers(), json=payload)
    assert response.status_code == 200
    address = {'label': 'New', 'recipient_name': 'New Person', 'phone': '+255711111111', 'region': 'Dar', 'district_area': 'Area', 'address_text': 'New location'}
    assert client.put(f"/api/v1/addresses/{seeded['address']}", headers=headers('other'), json=address).status_code == 404
    assert client.put(f"/api/v1/addresses/{seeded['address']}", headers=headers(), json=address).status_code == 200
    order = client.get(f"/api/v1/orders/{response.json()['id']}", headers=headers()).json()
    assert order['delivery_address']['address_text'] == 'Secret buyer address'


def test_business_buyer_identity_derived_from_session(client, sessions, seeded):
    data = {'business_type': 'butchery', 'area': 'Dar', 'budget_range': '500000–1000000', 'has_premises': False, 'wants_stock': True, 'target_start_date': 'Next month'}
    response = client.post('/api/v1/business-opportunities', headers=headers(), json=data)
    assert response.status_code == 200
    assert client.post('/api/v1/business-opportunities', headers=headers(), json=data).json()['id'] == response.json()['id']
    with sessions() as db:
        assert db.get(m.BusinessOpportunity, response.json()['id']).buyer_id == seeded['buyer']
    assert client.post('/api/v1/business-opportunities', headers=headers(), json=data | {'buyer_id': seeded['other']}).status_code == 422


def test_sourcing_contract_hides_internal_progress(client, sessions, seeded):
    data = {'category': 'broilers', 'unit_type': 'bird', 'quantity': '5', 'needed_by_date': (m.now() + timedelta(days=1)).date().isoformat(), 'delivery_area': 'Dar'}
    response = client.post('/api/v1/requests', headers=headers(), json=data)
    assert response.status_code == 200
    id = response.json()['id']
    with sessions.begin() as db:
        row = db.get(m.SourcingRequest, id)
        row.quantity_secured = 3; row.admin_notes = 'Private matching detail'; row.status = 'converted'
    result = client.get(f'/api/v1/requests/{id}', headers=headers()).json()
    assert result['status'] == 'confirmed'
    assert 'quantity_secured' not in result and 'admin_notes' not in result
    assert client.get(f'/api/v1/requests/{id}', headers=headers('other')).status_code == 404


def test_reservation_http_replay_and_payload_conflict(client, sessions, seeded):
    data = {'listing_id': seeded['listing'], 'quantity': '3'}
    first = client.post('/api/v1/reservations', headers=headers(), json=data)
    again = client.post('/api/v1/reservations', headers=headers(), json=data)
    assert first.status_code == 200 and again.json()['id'] == first.json()['id']
    assert client.post('/api/v1/reservations', headers=headers(), json=data | {'quantity': '2'}).status_code == 409
    with sessions() as db:
        assert db.get(m.Listing, seeded['listing']).quantity_reserved == 3


def test_upload_strips_metadata_and_enforces_owner(client, sessions, seeded, tmp_path):
    from PIL import Image
    from io import BytesIO
    from app.config import settings
    settings().media_directory = str(tmp_path)
    image = Image.new('RGB', (20, 20), 'green')
    metadata = Image.Exif(); metadata[270] = 'Private farm coordinates'
    output = BytesIO(); image.save(output, 'JPEG', exif=metadata)
    response = client.post('/api/v1/media', headers=headers('supplier'), files={'file': ('farm.jpg', output.getvalue(), 'image/jpeg')})
    assert response.status_code == 200
    url = response.json()['url']
    own = client.get('/api/v1' + url, headers=headers('supplier'))
    assert own.status_code == 200
    assert not Image.open(BytesIO(own.content)).getexif()
    assert client.get('/api/v1' + url, headers=headers()).status_code == 404
    with sessions.begin() as db:
        db.get(m.Listing, seeded['listing']).photos = [url]
    assert client.get('/api/v1' + url, headers=headers()).status_code == 200
    with sessions.begin() as db:
        db.get(m.Listing, seeded['listing']).confirmation_due_at = m.now() - timedelta(seconds=1)
    assert client.get('/api/v1' + url, headers=headers()).status_code == 404
    invalid = client.post('/api/v1/media', headers=headers('supplier'), files={'file': ('fake.jpg', b'not an image', 'image/jpeg')})
    assert invalid.status_code == 422


def test_partial_reconciliation_records_receipts_once(client, sessions, seeded):
    from test_commerce import order
    from app import services as s, contracts as c
    id = order(sessions, seeded)
    with sessions.begin() as db:
        row = db.get(m.Order, id)
        for status in ['pickup_scheduled', 'collected', 'quality_checked', 'in_transit', 'delivered']:
            s.advance(db, row, c.Progress(internal_status=status, actual_quantity=4, rejected_quantity=0))
    def reconcile(key, amount, reference):
        return client.post(f'/api/v1/ops/orders/{id}/reconcile', headers={'X-Ops-Token': 'test-operator-secret', 'Idempotency-Key': key}, json={'amount': amount, 'payment_reference': reference})
    first = reconcile('first-receipt-key', '10000', 'cash-receipt-one')
    assert first.status_code == 200 and first.json()['status'] == 'partial'
    assert reconcile('first-receipt-key', '10000', 'cash-receipt-one').json()['received_amount'] == '10000.00'
    assert reconcile('second-receipt-key', '38000', 'cash-receipt-two').json()['status'] == 'paid'
    assert reconcile('third-receipt-key', '1', 'cash-receipt-three').status_code == 422
    with sessions() as db:
        assert len(db.scalars(select(m.PaymentReceipt)).all()) == 2
        assert db.get(m.Order, id).payment_status == 'paid'


def test_operator_source_conversion_is_idempotent(client, sessions, seeded):
    with sessions.begin() as db:
        request = m.SourcingRequest(buyer_id=seeded['buyer'], category='broilers', unit_type='bird', quantity=4, needed_by_date='2027-01-01', delivery_area='Dar', status='confirmed')
        db.add(request); db.flush(); id = request.id
    ops = {'X-Ops-Token': 'test-operator-secret', 'Idempotency-Key': 'source-hold-key'}
    hold = client.post(f'/api/v1/ops/requests/{id}/reserve', headers=ops, json={'listing_id': seeded['listing'], 'quantity': '4'})
    assert hold.status_code == 200
    payload = checkout_data(seeded, hold.json()['id']).model_dump(mode='json')
    ops['Idempotency-Key'] = 'source-convert-key'
    first = client.post(f'/api/v1/ops/requests/{id}/convert', headers=ops, json=payload)
    assert first.status_code == 200
    again = client.post(f'/api/v1/ops/requests/{id}/convert', headers=ops, json=payload)
    assert again.json()['id'] == first.json()['id']
    assert client.post(f'/api/v1/ops/requests/{id}/convert', headers=ops, json=payload | {'delivery_address_id': 'different'}).status_code == 409


def test_operator_rejection_releases_active_holds(client, sessions, seeded):
    reserve(sessions, seeded, 3)
    result = client.patch(f"/api/v1/ops/listings/{seeded['listing']}/status", headers={'X-Ops-Token': 'test-operator-secret', 'Idempotency-Key': 'listing-review-key'}, json={'status': 'rejected'})
    assert result.status_code == 200
    with sessions() as db:
        assert db.get(m.Listing, seeded['listing']).quantity_reserved == 0
    assert client.get('/api/v1/listings', headers=headers()).json() == []


def test_ops_collection_photos_never_cross_mobile_boundary(client, sessions, seeded, tmp_path):
    from PIL import Image
    from io import BytesIO
    from test_commerce import order
    from app.config import settings
    settings().media_directory = str(tmp_path)
    id = order(sessions, seeded)
    raw = BytesIO(); Image.new('RGB', (10, 10)).save(raw, 'JPEG')
    response = client.post(f'/api/v1/ops/orders/{id}/photos', headers={'X-Ops-Token': 'test-operator-secret', 'Idempotency-Key': 'collection-photo-key'}, files={'file': ('collection.jpg', raw.getvalue(), 'image/jpeg')})
    assert response.status_code == 200
    for role in ['buyer', 'supplier']:
        assert client.get('/api/v1' + response.json()['url'], headers=headers(role)).status_code == 404
    buyer_response = client.get(f'/api/v1/orders/{id}', headers=headers()).json()
    assert 'collection_photos' not in buyer_response


def test_supplier_submission_to_buyer_approval_boundary(client, seeded):
    data = {'category': 'broilers', 'unit_type': 'bird', 'region': 'Pwani', 'quantity_total': '25', 'farmer_asking_price_per_unit': '10000', 'photos': [], 'specs': {'avg_weight_kg': '2', 'breed_type': 'Cobb 500', 'age_weeks': '6', 'live_or_dressed': 'live', 'ready_date': '2027-01-01'}}
    response = client.post('/api/v1/supplier/stock', headers=headers('supplier'), json=data)
    assert response.status_code == 200
    id = response.json()['id']
    assert response.json()['listing_status'] == 'pending_review'
    assert 'buyer_price_per_unit' not in response.json()
    assert client.get(f'/api/v1/listings/{id}', headers=headers()).status_code == 404
    approved = client.post(f'/api/v1/ops/listings/{id}/approve', headers={'X-Ops-Token': 'test-operator-secret'}, json={'buyer_price_per_unit': '13000', 'public_alias': 'Green Supply Partner'})
    assert approved.status_code == 200
    result = client.get(f'/api/v1/listings/{id}', headers=headers()).json()
    assert result['buyer_price_per_unit'] == '13000.00'
    assert result['quantity_available'] == '25.000'
    # A supplier cannot insert a contact number into public specifications.
    data['specs']['breed_type'] = '+255712345678'
    assert client.post('/api/v1/supplier/stock', headers=headers('supplier', 'another-stock-key'), json=data).status_code == 422


def test_eggs_listing_uses_tray_specs_and_rejects_bad_tray_size(client, seeded):
    data = {'category': 'eggs', 'unit_type': 'tray', 'region': 'Pwani', 'quantity_total': '40',
            'farmer_asking_price_per_unit': '9000', 'photos': [],
            'specs': {'tray_size': '30', 'egg_size': 'medium', 'ready_date': '2027-01-01'}}
    response = client.post('/api/v1/supplier/stock', headers=headers('supplier'), json=data)
    assert response.status_code == 200
    id = response.json()['id']
    approved = client.post(f'/api/v1/ops/listings/{id}/approve',
        headers={'X-Ops-Token': 'test-operator-secret'},
        json={'buyer_price_per_unit': '10000', 'public_alias': 'Egg Partner'})
    assert approved.status_code == 200
    result = client.get(f'/api/v1/listings/{id}', headers=headers()).json()
    assert result['unit_type'] == 'tray'
    assert result['quantity_available'] == '40.000'

    # A fractional tray count is rejected, like birds and animals.
    fractional = {**data, 'quantity_total': '40.5'}
    assert client.post('/api/v1/supplier/stock', headers=headers('supplier', 'egg-key-2'),
        json=fractional).status_code == 422

    # Only 12/24/30-egg trays are accepted.
    bad_size = {**data, 'specs': {**data['specs'], 'tray_size': '20'}}
    assert client.post('/api/v1/supplier/stock', headers=headers('supplier', 'egg-key-3'),
        json=bad_size).status_code == 422


def test_stale_checkout_view_releases_hold_and_zeroes_availability(client, sessions, seeded):
    from decimal import Decimal
    id = reserve(sessions, seeded)
    with sessions.begin() as db:
        db.get(m.Listing, seeded['listing']).confirmation_due_at = m.now() - timedelta(seconds=1)
    response = client.get(f'/api/v1/reservations/{id}', headers=headers())
    assert response.status_code == 200
    assert response.json()['status'] == 'released'
    assert Decimal(response.json()['listing']['quantity_available']) == 0
    with sessions() as db:
        assert db.get(m.Listing, seeded['listing']).quantity_reserved == 0


def test_collection_date_is_explicit_not_inferred_from_delivery(client, sessions, seeded):
    from test_commerce import order
    id = order(sessions, seeded)
    view = client.get('/api/v1/supplier/orders', headers=headers('supplier')).json()
    assert view[0]['expected_collection_date'] is None
    response = client.post(f'/api/v1/ops/orders/{id}/progress', headers={'X-Ops-Token': 'test-operator-secret', 'Idempotency-Key': 'pickup-schedule-key'}, json={'internal_status': 'pickup_scheduled', 'expected_collection_date': '2027-01-01'})
    assert response.status_code == 200
    view = client.get('/api/v1/supplier/orders', headers=headers('supplier')).json()
    assert view[0]['expected_collection_date'] == '2027-01-01'
