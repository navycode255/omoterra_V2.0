from datetime import date
from decimal import Decimal
from types import SimpleNamespace

from app import contracts as c
from app.locations import depreciation_rows
from test_finance import post, expense, OPS, STAFF, API, TODAY
from test_purchasing import marked  # noqa: F401 (pytest fixture)


def loc(client, name='Kitchen A'):
    response = post(client, '/locations', {'name': name, 'daily_target': '20'})
    assert response.status_code == 201, response.text
    return response.json()['id']


def allocate(client, id, **changes):
    payload = {'allocated_on': TODAY, 'category': 'broilers', 'unit': 'bird', 'quantity': '20', 'unit_cost': '10000'}
    payload.update(changes)
    response = post(client, f'/locations/{id}/allocations', payload, OPS)
    assert response.status_code == 201, response.text
    return response.json()['id']


def test_location_profit_matches_business_ledger_and_stock(client):
    id = loc(client)
    other = loc(client, 'Kitchen B')
    allocation = allocate(client, id)
    allocate(client, other, quantity='30')
    sold = post(client, f'/locations/{id}/sales', {'allocation_id': allocation, 'sold_on': TODAY, 'quantity': '12', 'unit_price': '15000',
        'payment': {'amount': '180000', 'paid_on': TODAY, 'method': 'cash'}}, STAFF)
    assert sold.status_code == 201, sold.text
    assert Decimal(sold.json()['cost_amount']) == 120000
    assert len(sold.json()['debts']) == 1
    expense(client, location_id=id, category='labour', amount='12000', payment=None)
    expense(client, sale_id=sold.json()['id'], category='fuel', amount='8000', payment=None)
    event = post(client, f'/locations/{id}/stock-events?allocation_id={allocation}', {'occurred_on': TODAY, 'kind': 'lost', 'quantity': '1', 'note': 'Spoiled at kitchen'})
    assert event.status_code == 201, event.text
    body = client.get(API + f'/locations/{id}?start={TODAY}&end={TODAY}', headers=OPS).json()
    assert Decimal(body['revenue']) == 180000
    assert Decimal(body['stock_cost']) == 120000
    assert Decimal(body['labour']) == 12000
    assert Decimal(body['running_costs']) == 8000
    assert Decimal(body['stock_lost']) == 10000
    assert Decimal(body['net_profit']) == 30000
    ledger = client.get(API + f'/expenses?location_id={id}', headers=OPS).json()
    assert ledger['total'] == 2 and Decimal(ledger['summary']['incurred']) == 20000
    assert Decimal(body['on_hand']['broilers:bird']) == 7
    assert Decimal(body['days'][0]['allocated']['broilers:bird']) == 20
    profit = client.get(API + f'/finance/profit?start={TODAY}&end={TODAY}', headers=OPS).json()
    assert Decimal(profit['net_profit']) == 30000
    assert Decimal(client.get(API + f'/locations/{other}', headers=OPS).json()['revenue']) == 0
    assert post(client, f'/locations/{id}/sales', {'allocation_id': allocation, 'sold_on': TODAY, 'quantity': '8', 'unit_price': '15000'}).status_code == 422
    assert post(client, f'/locations/{other}/sales', {'allocation_id': allocation, 'sold_on': TODAY, 'quantity': '1', 'unit_price': '15000'}).status_code == 422


def test_asset_investment_and_depreciation_are_separate(client):
    id = loc(client)
    first = c.business_today().replace(day=1).isoformat()
    response = post(client, f'/locations/{id}/assets', {'name': 'BBQ stove', 'purchased_on': first, 'depreciation_start': first,
        'cost': '360000', 'residual_value': '0', 'useful_months': 12})
    assert response.status_code == 201, response.text
    assert post(client, f'/locations/{id}/investments', {'invested_on': first, 'description': 'Kitchen fit-out excluding stove', 'amount': '100000'}).status_code == 201
    body = client.get(API + f'/locations/{id}?start={first}&end={TODAY}', headers=OPS).json()
    assert Decimal(body['investment']) == 460000
    assert Decimal(body['assets'][0]['monthly_depreciation']) == 30000
    assert Decimal(body['net_profit']) == -Decimal(body['depreciation'])
    business = client.get(API + f'/finance/profit?start={first}&end={TODAY}', headers=OPS).json()
    assert Decimal(business['expenses']) == Decimal(body['depreciation'])
    assert business['expenses_by_category'][0]['category'] == 'depreciation'
    assert Decimal(body['assets'][0]['book_value']) == 360000 - Decimal(body['depreciation'])


def test_location_permissions_dates_and_idempotency(client):
    assert post(client, '/locations', {'name': 'Kitchen X'}, STAFF).status_code == 403
    id = loc(client)
    payload = {'allocated_on': TODAY, 'category': 'broilers', 'unit': 'bird', 'quantity': '20', 'unit_cost': '10000'}
    first = post(client, f'/locations/{id}/allocations', payload, idem='allocation-retry')
    again = post(client, f'/locations/{id}/allocations', payload, idem='allocation-retry')
    assert first.status_code == again.status_code == 201
    assert first.json()['id'] == again.json()['id']
    assert post(client, f'/locations/{id}/allocations', {**payload, 'quantity': '1.5'}).status_code == 422
    assert post(client, f'/locations/{id}/allocations', {**payload, 'allocated_on': '2999-01-01'}).status_code == 422
    assert post(client, f'/locations/{id}/allocations', {**payload, 'unit_cost': None}).status_code == 422
    assert post(client, f'/locations/{id}/allocations', payload, STAFF).status_code == 403


def test_cancelled_location_sale_records_loss_once(client):
    id = loc(client)
    allocation = allocate(client, id)
    response = post(client, f'/locations/{id}/sales', {'allocation_id': allocation, 'sold_on': TODAY, 'quantity': '5', 'unit_price': '15000'})
    assert response.status_code == 201, response.text
    cancelled = post(client, f"/sales/{response.json()['id']}/cancel", {'reason': 'Never paid, goods gone', 'goods': 'not_recovered'})
    assert cancelled.status_code == 200, cancelled.text
    body = client.get(API + f'/locations/{id}', headers=OPS).json()
    assert Decimal(body['on_hand']['broilers:bird']) == 15
    assert Decimal(body['stock_lost']) == 50000
    assert Decimal(body['revenue']) == 0


def test_depreciation_prorates_caps_and_is_additive():
    asset = SimpleNamespace(id='stove', location_id='a', cost=Decimal('1200'), residual_value=Decimal('120'), useful_months=12,
                            depreciation_start=date(2024, 1, 31), retired_on=None, name='Stove')
    total = lambda start, end: sum((r['amount'] for r in depreciation_rows([asset], start, end)), Decimal(0))
    assert total(date(2024, 1, 31), date(2025, 1, 30)) == Decimal('1080')
    assert total(date(2024, 1, 31), date(2030, 1, 1)) == Decimal('1080')
    assert total(date(2024, 1, 31), date(2024, 2, 28)) == Decimal('90')
    assert total(date(2024, 2, 1), date(2024, 2, 29)) == total(date(2024, 2, 1), date(2024, 2, 15)) + total(date(2024, 2, 16), date(2024, 2, 29))
    asset.retired_on = date(2024, 2, 15)
    assert total(date(2024, 2, 15), date(2024, 3, 1)) == 0


def test_delivery_note_transfer_preserves_cost_and_central_stock(client, sessions, seeded):
    from test_batch_sales import batch
    from app import models as m, reporting as rp
    from app.batch_stock import record_note, collection_stock
    batch_id = batch(sessions, seeded)
    with sessions.begin() as db:
        note = record_note(db, db.get(m.SupplierBatch, batch_id), db.get(m.User, seeded['supplier']),
            received_on=c.business_today(), delivered=Decimal('50'), accepted=Decimal('50'), unit_cost=Decimal('6500'),
            notes='', recorded_by=seeded['operator_admin'])
        note_id = note.id
    id = loc(client)
    allocation = allocate(client, id, quantity='20', unit_cost=None, supplier_collection_id=note_id)
    with sessions() as db:
        assert collection_stock(db, note_id)['on_hand'] == 30
        assert rp.stock_on_hand(db)['total'] == Decimal('325000')
    sold = post(client, f'/locations/{id}/sales', {'allocation_id': allocation, 'sold_on': TODAY, 'quantity': '12', 'unit_price': '10000'})
    assert sold.status_code == 201, sold.text
    assert Decimal(sold.json()['cost_amount']) == 78000
    returned = post(client, f'/locations/{id}/stock-events?allocation_id={allocation}', {'occurred_on': TODAY, 'kind': 'returned', 'quantity': '3', 'note': 'Returned fresh and accepted'})
    assert returned.status_code == 201, returned.text
    with sessions() as db:
        assert collection_stock(db, note_id)['on_hand'] == 33
        assert rp.stock_on_hand(db)['total'] == Decimal('247000')
    assert post(client, f'/locations/{id}/allocations', {'allocated_on': TODAY, 'supplier_collection_id': note_id, 'quantity': '34'}).status_code == 422


def test_lpo_transfer_keeps_receipt_unit_cost(client, seeded, marked):
    from test_purchasing import draft, issue, receive
    lpo = issue(client, draft(client, seeded))
    received = receive(client, lpo, '50', '50')
    assert received.status_code == 201, received.text
    line_id = lpo['lines'][0]['id']
    id = loc(client)
    allocation = allocate(client, id, lpo_line_id=line_id, unit_cost=None, quantity='20')
    stock = client.get(API + '/lpos/stock', headers=OPS).json()
    assert Decimal(stock[0]['on_hand']) == 30
    sold = post(client, f'/locations/{id}/sales', {'allocation_id': allocation, 'sold_on': TODAY, 'quantity': '12', 'unit_price': '10000'})
    assert sold.status_code == 201, sold.text
    assert Decimal(sold.json()['cost_amount']) == 78000


def test_opening_stock_returns_can_be_reallocated_without_duplicating_value(client, sessions):
    from app import reporting as rp
    first = loc(client)
    second = loc(client, 'Kitchen B')
    allocation = allocate(client, first)
    response = post(client, f'/locations/{first}/stock-events?allocation_id={allocation}', {'occurred_on': TODAY, 'kind': 'returned', 'quantity': '5', 'note': 'Fresh stock returned centrally'})
    assert response.status_code == 201, response.text
    with sessions() as db:
        assert rp.stock_on_hand(db)['total'] == 200000
    stock = client.get(API + '/location-opening-stock', headers=OPS).json()
    assert Decimal(stock[0]['on_hand']) == 5
    response = post(client, f'/locations/{second}/allocations', {'allocated_on': TODAY, 'quantity': '3', 'opening_source_id': allocation})
    assert response.status_code == 201, response.text
    assert Decimal(response.json()['unit_cost']) == 10000
    with sessions() as db:
        assert rp.stock_on_hand(db)['total'] == 200000
    assert Decimal(client.get(API + '/location-opening-stock', headers=OPS).json()[0]['on_hand']) == 2


def test_retirement_stops_depreciation_and_retries_safely(client):
    id = loc(client)
    first = c.business_today().replace(day=1).isoformat()
    response = post(client, f'/locations/{id}/assets', {'name': 'Stove', 'purchased_on': first, 'depreciation_start': first, 'cost': '360000', 'useful_months': 12})
    assert response.status_code == 201
    asset = response.json()['id']
    payload = {'retired_on': TODAY, 'reason': 'Equipment no longer usable'}
    response = post(client, f'/assets/{asset}/retire', payload, idem='retire-retry')
    assert response.status_code == 200, response.text
    assert post(client, f'/assets/{asset}/retire', payload, idem='retire-retry').status_code == 200
    assert post(client, f'/assets/{asset}/retire', {'retired_on': '2999-01-01', 'reason': 'Wrong date'}).status_code == 422
    body = client.get(API + f'/locations/{id}?start={TODAY}&end={TODAY}', headers=OPS).json()
    assert Decimal(body['depreciation']) == 0
