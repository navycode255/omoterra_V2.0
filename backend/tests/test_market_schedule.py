"""Market Schedule capacity, ownership, deadlines and batch integration."""
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from decimal import Decimal

from app import contracts as c, models as m
from app.reminders import remind_market_deliveries

OPS = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin'}
STAFF = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-staff'}
SUPPLIER = {'Authorization': 'Bearer supplier'}
OTHER = {'Authorization': 'Bearer other'}
API = '/api/v1'
TODAY = c.business_today()


def slot_body(quantity='1000', deadline=10, delivery=30, **overrides):
    body = {'category': 'broilers', 'delivery_date': str(TODAY + timedelta(days=delivery)),
        'reservation_deadline': str(TODAY + timedelta(days=deadline)), 'quantity_required': quantity,
        'unit_type': 'bird', 'region': 'Pwani', 'collection_point': 'Kibaha',
        'minimum_weight_kg': '1.8', 'maximum_weight_kg': '2.2', 'supply_type': 'live',
        'price_per_unit': '7500', 'collection_method': 'omoterra_collects', 'status': 'open',
        'internal_note': 'Confirmed future market'}
    body.update(overrides)
    return body


def create_slot(client, key='market-slot-0001', **overrides):
    response = client.post(API + '/ops/market-slots', headers={**OPS, 'Idempotency-Key': key},
        json=slot_body(**overrides))
    assert response.status_code == 201, response.text
    return response.json()


def request(client, slot, quantity='500', choice='planned', batch=None, role=SUPPLIER, key='market-request-0001'):
    return client.post(API + f'/market-schedule/{slot}/reservations',
        headers={**role, 'Idempotency-Key': key}, json={'quantity': quantity, 'production_choice': choice,
            'supplier_batch_id': batch})


def review(client, reservation, quantity='500', action='approve', key='market-review-0001', reason='Cannot meet this market'):
    return client.post(API + f'/ops/market-reservations/{reservation}/review',
        headers={**OPS, 'Idempotency-Key': key}, json={'action': action,
            'approved_quantity': quantity if action == 'approve' else None, 'reason': reason})


def make_other_supplier(sessions, seeded):
    with sessions.begin() as db:
        user = db.get(m.User, seeded['other'])
        user.roles = ['buyer', 'supplier']
        db.add(m.SupplierProfile(user_id=user.id, legal_name='Second Farm', internal_pickup_address='Bagamoyo farm',
            public_alias='Second Farm', alias_approved=True, status='approved', categories=['broilers'],
            primary_category='broilers', region='Pwani', district='Bagamoyo',
            production_profile={'broilers': {'capacity': '1500', 'unit': 'bird', 'frequency': '6 weeks'}},
            production_frequency='6 weeks'))


def test_admin_creates_slot_supplier_views_and_requests_planned_batch(client, sessions, seeded):
    forbidden = client.post(API + '/ops/market-slots', headers={**STAFF, 'Idempotency-Key': 'staff-create'}, json=slot_body())
    assert forbidden.status_code == 403
    slot = create_slot(client)
    public = client.get(API + '/market-schedule', headers=SUPPLIER).json()
    assert [row['id'] for row in public] == [slot['id']]
    assert public[0]['remaining_quantity'] == '1000.000' and public[0]['reservations_open'] is True

    response = request(client, slot['id'])
    assert response.status_code == 201, response.text
    reservation = response.json()
    assert reservation['status'] == 'requested' and Decimal(reservation['quantity_requested']) == Decimal('500')
    assert reservation['batch']['category'] == 'broilers'
    assert reservation['batch']['expected_ready_date'] == slot['delivery_date']
    with sessions() as db:
        batch = db.get(m.SupplierBatch, reservation['supplier_batch_id'])
        assert batch.supplier_id == seeded['supplier'] and batch.reserved_quantity == 0


def test_approval_decreases_remaining_becomes_full_and_preserves_requested(client, seeded):
    slot = create_slot(client, quantity='500')
    reservation = request(client, slot['id'], quantity='500').json()
    approved = review(client, reservation['id'], quantity='500')
    assert approved.status_code == 200, approved.text
    row = approved.json()
    assert Decimal(row['quantity_requested']) == Decimal('500') and Decimal(row['quantity_approved']) == Decimal('500')
    refreshed = client.get(API + f"/ops/market-slots/{slot['id']}", headers=OPS).json()
    assert Decimal(refreshed['remaining_quantity']) == 0 and refreshed['status'] == 'full'
    blocked = request(client, slot['id'], quantity='1', key='market-request-full')
    assert blocked.status_code == 409 and 'fully booked' in blocked.json()['detail'].lower()


def test_approval_cannot_exceed_remaining_and_can_approve_less_than_requested(client, sessions, seeded):
    make_other_supplier(sessions, seeded)
    slot = create_slot(client, quantity='1000')
    first = request(client, slot['id'], quantity='900').json()
    assert review(client, first['id'], quantity='900').status_code == 200
    second = request(client, slot['id'], quantity='200', role=OTHER, key='other-request').json()
    too_much = review(client, second['id'], quantity='200', key='other-review-too-much')
    assert too_much.status_code == 409 and 'Only 100' in too_much.json()['detail']
    approved = review(client, second['id'], quantity='100', key='other-review-right').json()
    assert Decimal(approved['quantity_requested']) == Decimal('200') and Decimal(approved['quantity_approved']) == Decimal('100')


def test_concurrent_approvals_cannot_oversubscribe(client, sessions, seeded):
    make_other_supplier(sessions, seeded)
    slot = create_slot(client, quantity='1000')
    first = request(client, slot['id'], quantity='700').json()
    second = request(client, slot['id'], quantity='700', role=OTHER, key='concurrent-request-other').json()
    def approve(item):
        return review(client, item[0], quantity='700', key=item[1]).status_code
    with ThreadPoolExecutor(max_workers=2) as pool:
        statuses = list(pool.map(approve, [(first['id'], 'concurrent-review-a'), (second['id'], 'concurrent-review-b')]))
    assert sorted(statuses) == [200, 409]
    refreshed = client.get(API + f"/ops/market-slots/{slot['id']}", headers=OPS).json()
    assert Decimal(refreshed['committed_quantity']) == Decimal('700')


def test_supplier_only_accesses_own_reservation(client, sessions, seeded):
    make_other_supplier(sessions, seeded)
    slot = create_slot(client)
    reservation = request(client, slot['id']).json()
    assert client.get(API + f"/supplier/market-reservations/{reservation['id']}", headers=SUPPLIER).status_code == 200
    assert client.get(API + f"/supplier/market-reservations/{reservation['id']}", headers=OTHER).status_code == 404
    assert client.get(API + '/supplier/market-reservations', headers=OTHER).json() == []


def test_deadline_and_closed_slot_block_requests(client):
    expired = create_slot(client, key='expired-slot', deadline=-1, delivery=10)
    response = request(client, expired['id'], key='expired-request')
    assert response.status_code == 409 and 'closed' in response.json()['detail'].lower()
    closed = create_slot(client, key='closed-slot')
    changed = client.post(API + f"/ops/market-slots/{closed['id']}/status",
        headers={**OPS, 'Idempotency-Key': 'close-slot'}, json={'status': 'closed'})
    assert changed.status_code == 200
    assert request(client, closed['id'], key='closed-request').status_code == 409


def test_cancellation_and_reduction_restore_capacity_and_batch_quantity(client, sessions, seeded):
    slot = create_slot(client)
    reservation = request(client, slot['id'], quantity='600').json()
    review(client, reservation['id'], quantity='600')
    reduced = review(client, reservation['id'], quantity='350', key='reduce-approved')
    assert reduced.status_code == 200 and reduced.json()['quantity_requested'] == '600.000'
    refreshed = client.get(API + f"/ops/market-slots/{slot['id']}", headers=OPS).json()
    assert refreshed['remaining_quantity'] == '650.000'
    cancelled = client.post(API + f"/supplier/market-reservations/{reservation['id']}/cancel",
        headers={**SUPPLIER, 'Idempotency-Key': 'cancel-market-reservation'})
    assert cancelled.status_code == 200 and cancelled.json()['status'] == 'cancelled'
    refreshed = client.get(API + f"/ops/market-slots/{slot['id']}", headers=OPS).json()
    assert refreshed['remaining_quantity'] == '1000.000'
    with sessions() as db:
        assert db.get(m.SupplierBatch, reservation['supplier_batch_id']).reserved_quantity == 0


def test_existing_matching_batch_links_and_reserves_only_after_approval(client, sessions, seeded):
    slot = create_slot(client)
    with sessions.begin() as db:
        batch = m.SupplierBatch(supplier_id=seeded['supplier'], category='broilers', initial_quantity=800,
            current_quantity=800, expected_ready_date=slot['delivery_date'], form='live', region='Pwani', status='growing')
        db.add(batch); db.flush(); batch_id = batch.id
    reservation = request(client, slot['id'], quantity='400', choice='existing', batch=batch_id).json()
    with sessions() as db:
        assert db.get(m.SupplierBatch, batch_id).reserved_quantity == 0
    assert review(client, reservation['id'], quantity='400').status_code == 200
    with sessions() as db:
        assert db.get(m.SupplierBatch, batch_id).reserved_quantity == 400


def test_upcoming_delivery_reminder_is_sent_once(client, sessions, seeded):
    slot = create_slot(client, delivery=2, deadline=1)
    reservation = request(client, slot['id'], quantity='100').json()
    assert review(client, reservation['id'], quantity='100').status_code == 200
    with sessions.begin() as db:
        assert remind_market_deliveries(db, m.now()) == 1
        assert remind_market_deliveries(db, m.now()) == 0
    with sessions() as db:
        rows = db.query(m.Notification).filter_by(user_id=seeded['supplier'], kind='market_delivery_soon').all()
        assert len(rows) == 1
