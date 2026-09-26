from datetime import date
from decimal import Decimal

from sqlalchemy import select

from app import models as m
from test_commerce import headers

OPS = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin'}


def idem(key):
    return {**OPS, 'Idempotency-Key': key}


def test_confirmed_multi_supplier_requirement_fulfils_through_order_pipeline(client, sessions, seeded):
    today = date.today().isoformat()
    with sessions.begin() as db:
        first = m.SupplierBatch(supplier_id=seeded['supplier'], category='broilers', subtype='Ross',
            initial_quantity=4, current_quantity=4, current_age=7, age_unit='weeks',
            expected_ready_date=today, expected_min_weight_kg=1.8, expected_max_weight_kg=2.2,
            form='live', asking_price_per_unit=10000, region='Dar es Salaam',
            private_pickup_location='Secret pickup one', status='ready')
        second_supplier = m.User(phone='+255712345681', name='Second Supplier', region='Dar es Salaam', roles=['supplier'])
        third_supplier = m.User(phone='+255712345682', name='Third Supplier', region='Dar es Salaam', roles=['supplier'])
        db.add_all([second_supplier, third_supplier]); db.flush()
        db.add_all([
            m.SupplierProfile(user_id=second_supplier.id, legal_name='Second Private Supplier', internal_pickup_address='Secret pickup two', status='approved', categories=['broilers'], district='Kibaha', production_profile={'broilers': {'capacity': '100', 'unit': 'bird', 'frequency': 'monthly'}}, production_frequency='monthly'),
            m.SupplierProfile(user_id=third_supplier.id, legal_name='Third Private Supplier', internal_pickup_address='Secret pickup three', status='approved', categories=['broilers'], district='Kibaha', production_profile={'broilers': {'capacity': '100', 'unit': 'bird', 'frequency': 'monthly'}}, production_frequency='monthly'),
        ])
        def batch(supplier_id, pickup):
            return m.SupplierBatch(supplier_id=supplier_id, category='broilers', subtype='Ross',
                initial_quantity=4, current_quantity=4, current_age=7, age_unit='weeks',
                expected_ready_date=today, expected_min_weight_kg=1.8, expected_max_weight_kg=2.2,
                form='live', asking_price_per_unit=10000, region='Dar es Salaam',
                private_pickup_location=pickup, status='ready')
        second, third = batch(second_supplier.id, 'Secret pickup two'), batch(third_supplier.id, 'Secret pickup three')
        db.add_all([first, second, third]); db.flush()
        batch_ids = [first.id, second.id, third.id]

    for index, batch_id in enumerate(batch_ids):
        response = client.post(f'/api/v1/ops/batches/{batch_id}/verify', headers=idem(f'batch-verify-{index:03}'), json={
            'verified_quantity': '4', 'rejected_quantity': '0', 'readiness_confirmed': True,
            'location_confirmed': True, 'buyer_price_per_unit': '12000',
            'supplier_payout_price_per_unit': '9000', 'photos': [], 'notes': 'Verified at pickup',
        })
        assert response.status_code == 200, response.text

    requirement = client.post('/api/v1/ops/requirements', headers=idem('req-create-0001'), json={
        'category': 'broilers', 'unit_type': 'bird', 'quantity': '12', 'needed_by_date': today,
        'delivery_area': 'Masaki', 'delivery_region': 'Dar es Salaam',
        'buyer': {'business_name': 'Pilot Restaurant', 'buyer_type': 'restaurant',
            'contact_person': 'Buyer Contact', 'phone': '+255711111111',
            'region': 'Dar es Salaam', 'area': 'Masaki'},
    })
    assert requirement.status_code == 200, requirement.text
    demand_id = requirement.json()['id']

    plan = client.post(f'/api/v1/ops/requirements/{demand_id}/allocations', headers=idem('alloc-plan-0001'), json={
        'allocations': [
            {'supplier_batch_id': batch_ids[0], 'allocated_quantity': '4'},
            {'supplier_batch_id': batch_ids[1], 'allocated_quantity': '4'},
            {'supplier_batch_id': batch_ids[2], 'allocated_quantity': '4'},
        ]
    })
    assert plan.status_code == 200, plan.text
    assert client.patch(f'/api/v1/ops/requirements/{demand_id}/progress', headers=OPS,
        json={'status': 'confirmed', 'internal_notes': ''}).status_code == 200

    converted = client.post(f'/api/v1/ops/requirements/{demand_id}/convert', headers=idem('convert-req-0001'), json={
        'payment_method': 'pay_on_delivery', 'delivery_address_id': None,
    })
    assert converted.status_code == 200, converted.text
    body = converted.json()
    order_id = body['id']
    assert len(body['items']) == 3
    assert Decimal(body['total_amount']) == Decimal('144000.00')
    assert body['delivery_address']['region'] == 'Dar es Salaam'

    def progress(status, key, **extra):
        response = client.post(f'/api/v1/ops/orders/{order_id}/progress', headers=idem(key),
            json={'internal_status': status, **extra})
        assert response.status_code == 200, response.text
        return response.json()

    progress('supply_confirmed', 'progress-sup-0001')
    progress('pickup_scheduled', 'progress-pick-0001')
    progress('collected', 'progress-col-0001')
    quality = progress('quality_checked', 'progress-qua-0001', collection_results=[
        {'order_item_id': body['items'][0]['id'], 'actual_quantity': '3', 'rejected_quantity': '1'},
        {'order_item_id': body['items'][1]['id'], 'actual_quantity': '2', 'rejected_quantity': '2'},
        {'order_item_id': body['items'][2]['id'], 'actual_quantity': '4', 'rejected_quantity': '0'},
    ])
    assert Decimal(quality['actual_quantity']) == Decimal('9')
    assert Decimal(quality['total_amount']) == Decimal('108000.00')
    progress('in_transit', 'progress-tra-0001')
    progress('delivered', 'progress-del-0001')

    payment = client.post(f'/api/v1/ops/orders/{order_id}/reconcile', headers=idem('pay-order-0001'), json={
        'amount': '108000', 'payment_reference': 'PILOT-CASH-001',
    })
    assert payment.status_code == 200, payment.text
    progress('completed', 'progress-done-001')

    with sessions() as db:
        order = db.get(m.Order, order_id)
        assert order.internal_status == 'completed'
        assert db.get(m.SourcingRequest, demand_id).status == 'completed'
        allocations = db.scalars(select(m.DemandAllocation).where(m.DemandAllocation.demand_id == demand_id)).all()
        assert all(row.status == 'delivered' for row in allocations)
        settlements = db.scalars(select(m.Settlement).order_by(m.Settlement.created_at)).all()
        assert sorted(Decimal(row.quantity) for row in settlements) == [Decimal('2'), Decimal('3'), Decimal('4')]
        assert sorted(Decimal(row.total_payable) for row in settlements) == [Decimal('18000.00'), Decimal('27000.00'), Decimal('36000.00')]
        assert all(db.get(m.SupplierBatch, batch_id).current_quantity == 0 for batch_id in batch_ids)


def test_supplier_market_demand_hides_buyer_private_data(client, sessions, seeded):
    with sessions.begin() as db:
        profile = m.BuyerProfile(business_name='Private Buyer Company', buyer_type='restaurant',
            contact_person='Private Person', phone='+255799999999', region='Dar es Salaam', area='Private Area',
            internal_notes='Do not disclose', preferences={'category': 'broilers'})
        db.add(profile); db.flush()
        requirement = m.SourcingRequest(buyer_profile_id=profile.id, buyer_id=None,
            requirement_number='REQ-PRIVACY01', category='broilers', quantity=10, unit_type='bird',
            needed_by_date=date.today().isoformat(), delivery_area='Private Area', delivery_region='Dar es Salaam',
            delivery_notes='Private address details', notes='Private buyer notes', status='open', created_by='operator')
        db.add(requirement)
    response = client.get('/api/v1/supplier/demand', headers=headers('supplier'))
    assert response.status_code == 200
    serialized = str(response.json())
    for private in ['Private Buyer Company', 'Private Person', '+255799999999', 'Private Area',
                    'Private address details', 'Private buyer notes', 'Do not disclose']:
        assert private not in serialized


def test_offer_capacity_and_allocation_reduction_and_cancellation_release_stock(client, sessions, seeded):
    today = date.today().isoformat()
    with sessions.begin() as db:
        batch = m.SupplierBatch(supplier_id=seeded['supplier'], category='broilers',
            initial_quantity=4, current_quantity=4, expected_ready_date=today,
            expected_min_weight_kg=1.8, expected_max_weight_kg=2.2,
            asking_price_per_unit=10000, region='Dar es Salaam', status='ready')
        db.add(batch); db.flush(); batch_id = batch.id
    checked = client.post(f'/api/v1/ops/batches/{batch_id}/verify', headers=idem('verify-limit-001'), json={
        'verified_quantity': '4', 'readiness_confirmed': True, 'location_confirmed': True,
        'buyer_price_per_unit': '12000', 'supplier_payout_price_per_unit': '9000',
    })
    assert checked.status_code == 200, checked.text
    requirement = client.post('/api/v1/ops/requirements', headers=idem('req-limit-0001'), json={
        'category': 'broilers', 'unit_type': 'bird', 'quantity': '4', 'needed_by_date': today,
        'delivery_area': 'Masaki', 'delivery_region': 'Dar es Salaam',
        'buyer': {'business_name': 'Limit Test Buyer', 'region': 'Dar es Salaam', 'area': 'Masaki'},
    })
    demand_id = requirement.json()['id']
    over = client.post(f'/api/v1/supplier/demand/{demand_id}/offers',
        headers={**headers('supplier'), 'Idempotency-Key': 'offer-over-limit'}, json={
            'batch_id': batch_id, 'offered_quantity': '5', 'expected_ready_date': today,
            'expected_min_weight_kg': '1.8', 'expected_max_weight_kg': '2.2',
        })
    assert over.status_code == 422
    offer = client.post(f'/api/v1/supplier/demand/{demand_id}/offers',
        headers={**headers('supplier'), 'Idempotency-Key': 'offer-valid-0001'}, json={
            'batch_id': batch_id, 'offered_quantity': '4', 'expected_ready_date': today,
            'expected_min_weight_kg': '1.8', 'expected_max_weight_kg': '2.2',
        })
    assert offer.status_code == 200, offer.text
    reviewed = client.post(f"/api/v1/ops/offers/{offer.json()['id']}/review", headers=idem('offer-review-001'),
        json={'status': 'accepted', 'accepted_quantity': '4', 'notes': ''})
    assert reviewed.status_code == 200, reviewed.text
    allocation = client.post(f'/api/v1/ops/requirements/{demand_id}/allocations', headers=idem('allocate-limit-01'), json={
        'allocations': [{'supplier_batch_id': batch_id, 'supply_offer_id': offer.json()['id'], 'allocated_quantity': '4'}],
    })
    assert allocation.status_code == 200, allocation.text
    allocation_id = allocation.json()[0]['id']
    reduced = client.patch(f'/api/v1/ops/allocations/{allocation_id}', headers=idem('reduce-limit-001'),
        json={'allocated_quantity': '3'})
    assert reduced.status_code == 200, reduced.text
    with sessions() as db:
        assert Decimal(db.get(m.SupplierBatch, batch_id).reserved_quantity) == Decimal('3')
    cancelled = client.patch(f'/api/v1/ops/allocations/{allocation_id}', headers=idem('cancel-limit-001'),
        json={'status': 'cancelled'})
    assert cancelled.status_code == 200, cancelled.text
    with sessions() as db:
        batch = db.get(m.SupplierBatch, batch_id)
        demand = db.get(m.SourcingRequest, demand_id)
        assert batch.reserved_quantity == 0
        assert batch.available_to_commit == 4
        assert demand.status == 'open'
    external = client.post(f'/api/v1/supplier/batches/{batch_id}/external-sales',
        headers={**headers('supplier'), 'Idempotency-Key': 'external-sale-01'}, json={'quantity': '2', 'notes': 'Local sale'})
    assert external.status_code == 200, external.text
    repeated = client.post(f'/api/v1/supplier/batches/{batch_id}/external-sales',
        headers={**headers('supplier'), 'Idempotency-Key': 'external-sale-01'}, json={'quantity': '2', 'notes': 'Local sale'})
    assert repeated.status_code == 200
    assert Decimal(repeated.json()['externally_sold_quantity']) == Decimal('2.000')
    too_many = client.post(f'/api/v1/supplier/batches/{batch_id}/external-sales',
        headers={**headers('supplier'), 'Idempotency-Key': 'external-sale-02'}, json={'quantity': '3', 'notes': ''})
    assert too_many.status_code == 422


def test_buyer_can_create_recurring_requirement(client, sessions, seeded):
    today = date.today().isoformat()
    response = client.post('/api/v1/requirements', headers={**headers(), 'Idempotency-Key': 'buyer-recurring-001'}, json={
        'category': 'broilers', 'unit_type': 'bird', 'quantity': '50', 'needed_by_date': today,
        'delivery_area': 'Kinondoni', 'delivery_region': 'Dar es Salaam',
        'requirement_type': 'recurring', 'recurrence_frequency': 'weekly',
        'preferred_weekdays': ['monday'], 'minimum_weight_kg': '1.8',
        'maximum_weight_kg': '2.2', 'live_dressed_or_cut': 'live',
    })
    assert response.status_code == 200, response.text
    body = response.json()
    assert body['requirement_type'] == 'recurring'
    assert body['recurrence_frequency'] == 'weekly'
    assert body['preferred_weekdays'] == ['monday']
    with sessions() as db:
        row = db.get(m.SourcingRequest, body['id'])
        assert row.created_by == 'buyer'
        assert row.minimum_weight_kg == Decimal('1.8')
        assert row.maximum_weight_kg == Decimal('2.2')


def _request_body(**changes):
    from datetime import date, timedelta
    body = {'category': 'broilers', 'unit_type': 'bird', 'quantity': '20',
            'needed_by_date': (date.today() + timedelta(days=2)).isoformat(),
            'delivery_area': 'Kinondoni', 'delivery_region': 'Dar es Salaam'}
    return {**body, **changes}


def test_buyer_edits_request_until_supply_is_secured(client, sessions, seeded):
    created = client.post('/api/v1/requests', headers={**headers(), 'Idempotency-Key': 'edit-req-001'},
        json=_request_body())
    assert created.status_code == 200, created.text
    id = created.json()['id']
    assert created.json()['editable'] is True
    edited = client.put(f'/api/v1/requests/{id}', headers=headers(), json=_request_body(quantity='35', delivery_area='Kigamboni'))
    assert edited.status_code == 200, edited.text
    assert edited.json()['quantity'] in ('35', '35.000', 35) and edited.json()['delivery_area'] == 'Kigamboni'
    # Someone else's request can't be edited.
    assert client.put(f'/api/v1/requests/{id}', headers=headers('other'), json=_request_body()).status_code == 404
    # Once confirmed, it is locked.
    with sessions.begin() as db:
        db.get(m.SourcingRequest, id).status = 'confirmed'
    locked = client.put(f'/api/v1/requests/{id}', headers=headers(), json=_request_body(quantity='40'))
    assert locked.status_code == 409
    assert client.get(f'/api/v1/requests/{id}', headers=headers()).json()['editable'] is False


def test_a_member_never_sees_or_supplies_their_own_demand(client, sessions, seeded):
    today = date.today().isoformat()
    with sessions.begin() as db:
        # The seeded supplier also buys: their own request, and one from someone else.
        member = db.get(m.User, seeded['supplier'])
        member.roles = ['buyer', 'supplier']
        db.get(m.SupplierProfile, seeded['supplier']).categories = ['broilers']
        own = m.SourcingRequest(buyer_id=seeded['supplier'], requirement_number='REQ-OWN00001', category='broilers',
            quantity=20, unit_type='bird', needed_by_date=today, delivery_area='Kinondoni', delivery_region='Dar es Salaam', status='open',
            created_by='buyer')
        other = m.SourcingRequest(buyer_id=seeded['buyer'], requirement_number='REQ-OTHER001', category='broilers',
            quantity=10, unit_type='bird', needed_by_date=today, delivery_area='Kinondoni', delivery_region='Dar es Salaam', status='open',
            created_by='buyer')
        ops_made = m.SourcingRequest(buyer_id=None, requirement_number='REQ-OPS00001', category='broilers',
            quantity=5, unit_type='bird', needed_by_date=today, delivery_area='Kinondoni', delivery_region='Dar es Salaam', status='open',
            created_by='operator')
        batch = m.SupplierBatch(supplier_id=seeded['supplier'], category='broilers', initial_quantity=40,
            current_quantity=40, expected_ready_date=today, region='Dar es Salaam', status='ready')
        db.add_all([own, other, ops_made, batch]); db.flush()
        own_id, other_id, ops_id, batch_id = own.id, other.id, ops_made.id, batch.id
    listed = {row['id'] for row in client.get('/api/v1/supplier/demand', headers=headers('supplier')).json()}
    assert own_id not in listed and {other_id, ops_id} <= listed
    assert client.get(f'/api/v1/supplier/demand/{own_id}', headers=headers('supplier')).status_code == 404
    offer = client.post(f'/api/v1/supplier/demand/{own_id}/offers',
        headers={**headers('supplier'), 'Idempotency-Key': 'offer-own-demand'},
        json={'batch_id': batch_id, 'offered_quantity': '5'})
    assert offer.status_code == 404
