from sqlalchemy import select, func
from app import models as m
from test_commerce import headers, order, reserve


def test_buyer_deletes_account_and_can_sign_up_again_with_same_phone(client, sessions, seeded):
    original_phone = '+255712345678'
    deleted = client.delete('/api/v1/me', headers=headers('buyer'))
    assert deleted.status_code == 204

    # The session used for the request no longer authenticates.
    assert client.get('/api/v1/me', headers=headers('buyer')).status_code == 401

    with sessions() as db:
        user = db.get(m.User, seeded['buyer'])
        assert user.deleted is True and user.deleted_at is not None
        assert user.name == '' and user.region == '' and user.roles == []
        assert user.phone != original_phone
        addresses = db.scalars(select(m.Address).where(m.Address.user_id == user.id)).all()
        assert all(a.deleted and a.address_text == '' and a.recipient_name == 'Deleted account' for a in addresses)

    # The original phone number is free for a brand new signup.
    challenge = client.post('/api/v1/auth/otp', json={'phone': original_phone}).json()
    signed_in = client.post('/api/v1/auth/verify', json={
        'challenge_id': challenge['challenge_id'], 'code': challenge['development_code']})
    assert signed_in.status_code == 200
    assert signed_in.json()['user']['id'] != seeded['buyer']
    assert signed_in.json()['user']['name'] == ''


def test_buyer_with_an_open_order_cannot_delete_yet(client, sessions, seeded):
    order(sessions, seeded)
    response = client.delete('/api/v1/me', headers=headers('buyer'))
    assert response.status_code == 409, response.text
    with sessions() as db:
        assert db.get(m.User, seeded['buyer']).deleted is False


def test_supplier_deletes_account_and_stock_drops_from_buyers(client, sessions, seeded):
    with sessions.begin() as db:
        db.add(m.SupplierPhoto(supplier_id=seeded['supplier'], image_url='/media/keepsake'))
        db.add(m.SupplierVideo(supplier_id=seeded['supplier'], youtube_video_id='abc12345678',
            youtube_url='https://youtu.be/abc12345678', thumbnail_url='https://i.ytimg.com/vi/abc12345678/hqdefault.jpg'))

    assert client.get(f"/api/v1/listings/{seeded['listing']}", headers=headers()).status_code == 200

    deleted = client.delete('/api/v1/me', headers=headers('supplier'))
    assert deleted.status_code == 204

    assert client.get(f"/api/v1/listings/{seeded['listing']}", headers=headers()).status_code == 404

    with sessions() as db:
        profile = db.get(m.SupplierProfile, seeded['supplier'])
        assert profile.status == 'suspended'
        assert profile.legal_name == 'Deleted account'
        assert profile.internal_pickup_address == '' and profile.public_alias == ''
        assert profile.farm_latitude is None
        assert db.scalar(select(func.count()).select_from(m.SupplierPhoto).where(
            m.SupplierPhoto.supplier_id == seeded['supplier'])) == 0
        assert db.scalar(select(func.count()).select_from(m.SupplierVideo).where(
            m.SupplierVideo.supplier_id == seeded['supplier'])) == 0
        listing = db.get(m.Listing, seeded['listing'])
        assert listing.listing_status == 'paused'


def test_supplier_with_reserved_stock_cannot_delete_yet(client, sessions, seeded):
    reserve(sessions, seeded, quantity=2)
    response = client.delete('/api/v1/me', headers=headers('supplier'))
    assert response.status_code == 409, response.text
    with sessions() as db:
        assert db.get(m.User, seeded['supplier']).deleted is False


def test_supplier_with_a_pending_payout_cannot_delete_yet(client, sessions, seeded):
    with sessions.begin() as db:
        order_row = m.Order(buyer_id=seeded['buyer'], delivery_snapshot={}, preferred_delivery_date='2027-01-01',
            payment_method='pay_on_delivery', internal_status='completed', expected_quantity=1, total_amount=12000,
            idempotency_key='settlement-seed-01')
        db.add(order_row); db.flush()
        item = m.OrderItem(order_id=order_row.id, listing_id=seeded['listing'], quantity=1, unit_price=12000, subtotal=12000, asking_snapshot=10000, payout_snapshot=9000)
        db.add(item); db.flush()
        db.add(m.Settlement(supplier_id=seeded['supplier'], order_item_id=item.id, farmer_asking_price_per_unit=9000,
            supplier_payout_price_per_unit=9000, commission_amount_per_unit=3000, quantity=1, total_payable=9000, status='pending'))
    response = client.delete('/api/v1/me', headers=headers('supplier'))
    assert response.status_code == 409, response.text
