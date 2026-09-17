from concurrent.futures import ThreadPoolExecutor
from datetime import date, timedelta
from decimal import Decimal
import json
import pytest
from fastapi import HTTPException
from sqlalchemy import select, func
from app import models as m, contracts as c, services as s
from app.main import apply_provider_confirmation
from app.payments import ProviderConfirmation


def reserve(sessions, seeded, quantity=4, buyer=None):
    with sessions.begin() as db:
        return s.reserve(db, buyer or seeded['buyer'], c.Reserve(listing_id=seeded['listing'], quantity=quantity)).id


def checkout_data(seeded, hold):
    return c.Checkout(reservation_id=hold, delivery_address_id=seeded['address'], preferred_delivery_date=date.today(), payment_method='pay_on_delivery')


def order(sessions, seeded, quantity=4, key='checkout-key-0001'):
    hold = reserve(sessions, seeded, quantity)
    with sessions.begin() as db:
        return s.checkout(db, seeded['buyer'], checkout_data(seeded, hold), key).id


def headers(role='buyer', key='request-key-0001'):
    return {'Authorization': f'Bearer {role}', 'Idempotency-Key': key}


def test_concurrent_holds_cannot_oversell(sessions, seeded):
    def attempt(buyer):
        try:
            return reserve(sessions, seeded, 7, buyer)
        except HTTPException as e:
            assert e.status_code == 409
            return None
    with ThreadPoolExecutor(max_workers=2) as workers:
        result = list(workers.map(attempt, [seeded['buyer'], seeded['other']]))
    assert sum(r is not None for r in result) == 1
    with sessions() as db:
        listing = db.get(m.Listing, seeded['listing'])
        assert listing.quantity_reserved == 7
        assert listing.quantity_available == 3


def test_expiry_releases_only_expired_hold(sessions, seeded):
    first = reserve(sessions, seeded, 4)
    second = reserve(sessions, seeded, 3, seeded['other'])
    with sessions.begin() as db:
        db.get(m.StockReservation, first).expires_at = m.now() - timedelta(seconds=1)
    with sessions.begin() as db:
        s.commerce_lock(db)
        listing = db.get(m.Listing, seeded['listing'])
        s.refresh_listing(db, listing)
        s.refresh_listing(db, listing)
        assert listing.quantity_reserved == 3
        assert listing.quantity_available == 7
        assert db.get(m.StockReservation, first).status == 'expired'
        assert db.get(m.StockReservation, second).status == 'active'


def test_order_idempotency_and_snapshot(sessions, seeded):
    hold = reserve(sessions, seeded)
    payload = checkout_data(seeded, hold)
    with sessions.begin() as db:
        first = s.checkout(db, seeded['buyer'], payload, 'same-order-key').id
    with sessions.begin() as db:
        listing = db.get(m.Listing, seeded['listing'])
        listing.buyer_price_per_unit = 18000
    with sessions.begin() as db:
        again = s.checkout(db, seeded['buyer'], payload, 'same-order-key')
        assert again.id == first
        assert again.total_amount == 48000
        assert db.scalar(select(func.count()).select_from(m.Order)) == 1
        assert db.scalar(select(func.count()).select_from(m.Payment)) == 1
    with sessions.begin() as db, pytest.raises(HTTPException):
        s.checkout(db, seeded['buyer'], payload.model_copy(update={'delivery_address_id': 'other'}), 'same-order-key')


@pytest.mark.parametrize('status', ['cancelled', 'payment_failed'])
def test_failure_releases_exact_confirmed_hold(sessions, seeded, status):
    id = order(sessions, seeded, 4)
    reserve(sessions, seeded, 3, seeded['other'])
    with sessions.begin() as db:
        row = db.get(m.Order, id)
        s.advance(db, row, c.Progress(internal_status=status))
        s.advance(db, row, c.Progress(internal_status=status))
        assert db.get(m.Listing, seeded['listing']).quantity_reserved == 3
        assert s.buyer_order(db, row)['customer_status'] == 'cancelled'
        if status == 'payment_failed':
            assert 'Payment failed' in s.buyer_order(db, row)['message']


def test_settlement_does_not_double_deduct_commission(sessions, seeded):
    id = order(sessions, seeded, 4)
    with sessions.begin() as db:
        row = db.get(m.Order, id)
        for status in ['pickup_scheduled', 'collected', 'quality_checked', 'in_transit', 'delivered']:
            s.advance(db, row, c.Progress(internal_status=status, actual_quantity=3, rejected_quantity=1))
        s.advance(db, row, c.Progress(internal_status='delivered'))
        payout = db.scalar(select(m.Settlement))
        assert payout.commission_amount_per_unit == 1000
        assert payout.total_payable == 27000
        assert row.total_amount == 36000
        listing = db.get(m.Listing, seeded['listing'])
        assert listing.quantity_reserved == 0 and listing.quantity_sold == 3 and listing.quantity_available == 7
        assert db.scalar(select(func.count()).select_from(m.Settlement)) == 1


def test_stale_and_pending_inventory_hidden_at_query_time(client, sessions, seeded):
    with sessions.begin() as db:
        db.get(m.Listing, seeded['listing']).confirmation_due_at = m.now() - timedelta(seconds=1)
    response = client.get('/api/v1/listings', headers=headers())
    assert response.status_code == 200 and response.json() == []
    assert client.get(f"/api/v1/listings/{seeded['listing']}", headers=headers()).status_code == 404
    assert client.post('/api/v1/reservations', headers=headers(), json={'listing_id': seeded['listing'], 'quantity': 1}).status_code == 409
    with sessions.begin() as db:
        row = db.get(m.Listing, seeded['listing'])
        row.listing_status = 'pending_review'; row.confirmation_due_at = m.now() + timedelta(days=2)
    assert client.get('/api/v1/listings', headers=headers()).json() == []


def test_privacy_allowlists(client, sessions, seeded):
    id = order(sessions, seeded)
    buyer_data = client.get(f"/api/v1/listings/{seeded['listing']}", headers=headers()).json()
    assert buyer_data['supplier']['public_alias'] == 'Green Pastures'
    for forbidden in ['supplier_id', 'legal_name', 'internal_pickup_address', 'farmer_asking_price_per_unit', 'supplier_payout_price_per_unit', 'phone']:
        assert forbidden not in json.dumps(buyer_data)
    cards = client.get('/api/v1/listings', headers=headers()).json()
    assert 'supplier' not in cards[0]
    supplier_data = client.get('/api/v1/supplier/orders', headers=headers('supplier')).json()
    for forbidden in ['buyer_id', 'delivery_address', 'phone', 'Private Buyer', seeded['buyer'], 'unit_price', 'total_amount']:
        assert forbidden not in json.dumps(supplier_data)
    stock = client.get('/api/v1/supplier/stock', headers=headers('supplier')).json()
    assert 'buyer_price' not in json.dumps(stock) and 'commission' not in json.dumps(stock)
    buyer_order = client.get(f'/api/v1/orders/{id}', headers=headers()).json()
    assert 'internal_status' not in buyer_order and 'supplier_id' not in json.dumps(buyer_order)
    assert client.get(f'/api/v1/orders/{id}', headers=headers('other')).status_code == 404


def test_no_self_service_staff_or_price_changes(client, seeded):
    payload = {'name': 'Test', 'region': 'Dar', 'roles': ['agent'], 'language': 'en'}
    assert client.put('/api/v1/me', headers=headers(), json=payload).status_code == 422
    assert client.patch(f"/api/v1/supplier/stock/{seeded['listing']}", headers=headers('supplier'), json={'action': 'update', 'buyer_price_per_unit': 1}).status_code == 422
    assert client.get('/api/v1/supplier/stock', headers=headers()).status_code == 403


def test_pending_stock_cannot_self_approve(client, sessions, seeded):
    with sessions.begin() as db:
        row = db.get(m.Listing, seeded['listing']); row.approved_at = None; row.listing_status = 'pending_review'
    response = client.patch(f"/api/v1/supplier/stock/{seeded['listing']}", headers=headers('supplier'), json={'action': 'confirm'})
    assert response.status_code == 409


def test_database_constraint_rejects_invalid_inventory(sessions, seeded):
    from sqlalchemy.exc import IntegrityError
    with pytest.raises(IntegrityError), sessions.begin() as db:
        db.get(m.Listing, seeded['listing']).quantity_reserved = 11
        db.flush()


def test_provider_callbacks_idempotent(sessions, seeded):
    id = order(sessions, seeded)
    with sessions.begin() as db:
        db.get(m.Order, id).payment_method = 'pay_now'
        db.scalar(select(m.Payment)).method = 'pay_now'
    confirmation = ProviderConfirmation('provider-transaction-1', id, Decimal('48000'), 'paid')
    with sessions.begin() as db:
        apply_provider_confirmation(db, confirmation, 'callback-key-001')
    with sessions.begin() as db:
        apply_provider_confirmation(db, confirmation, 'callback-key-001')
        apply_provider_confirmation(db, confirmation, 'callback-key-002')
        assert db.get(m.Order, id).payment_status == 'paid'
        assert db.scalar(select(func.count()).select_from(m.Payment)) == 1


def test_pay_now_disabled_and_webhook_fails_closed(client, sessions, seeded):
    hold = reserve(sessions, seeded)
    payload = checkout_data(seeded, hold).model_dump(mode='json') | {'payment_method': 'pay_now'}
    assert client.post('/api/v1/orders', headers=headers(), json=payload).status_code == 422
    assert client.post('/api/v1/payments/webhook', headers=headers(), json={'status': 'paid'}).status_code == 503


def test_price_rounding_and_status_mapping():
    assert s.money(Decimal('10.005')) == Decimal('10.01')
    assert s.STATUS['quality_checked'] == 'preparing'
    assert s.STATUS['in_transit'] == 'on_the_way'
    assert s.STATUS['completed'] == 'delivered'
    assert s.STATUS['payment_failed'] == 'cancelled'
