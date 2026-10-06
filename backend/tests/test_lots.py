"""Received lots and their dated movements (build plan M2.1, audit F09).

On hand on any date is the sum of a lot's movements up to that date, read
from the records that hold each physical event (rule R2). The supplier's
registered batch is their declaration, never stock."""
from datetime import timedelta
from decimal import Decimal

from sqlalchemy import select

from app import contracts as c, lots, models as m
from test_batch_sales import batch, cancel
from test_delivery_losses import lose, receive
from test_finance import API, OPS, STAFF, post, sale

DAY = c.business_today()
D = {n: DAY - timedelta(days=n) for n in range(6)}


def get(client, path, **params):
    response = client.get(API + path, params=params, headers=OPS)
    assert response.status_code == 200, response.text
    return response.json()


def sell(client, note_id, quantity, on):
    return sale(client, sold_on=on.isoformat(), items=[{'quantity': str(quantity), 'unit_price': '7500',
        'supplier_collection_id': note_id}])


def test_500_declared_100_received_20_sold_3_dead_2_returned_reconciles_every_day(client, sessions, seeded):
    declared = batch(sessions, seeded, 500)
    note_id = receive(client, seeded, declared, 100, on=D[4].isoformat())
    sell(client, note_id, 20, D[3])
    assert lose(client, note_id, '3', on=D[2].isoformat()).status_code == 201
    returned = post(client, f'/supplier-collections/{note_id}/returns',
        {'quantity': '2', 'returned_on': D[1].isoformat(), 'reason': 'Underweight'})
    assert returned.status_code == 201, returned.text
    # A second sale of 5 three days ago, cancelled today: the buyer brought
    # them back, so they were out from the sale date until today.
    extra = sell(client, note_id, 5, D[3])
    assert cancel(client, extra['id'], 'buyer_return_accepted', goods_note='Healthy, same weight').status_code == 200

    expected = {D[5]: 0, D[4]: 100, D[3]: 75, D[2]: 72, D[1]: 70, D[0]: 75}
    with sessions() as db:
        moves = lots.movements(db, 'supplier_collections', [note_id])
        for day, quantity in expected.items():
            assert lots.on_hand(moves, day).get(('supplier_collections', note_id), 0) == quantity, day
        now = lots.summary(moves)
    assert now == {'received': 100, 'corrected': 0, 'sold': 20, 'returned_by_buyers': 5, 'not_recovered': 0,
        'died': 3, 'lost': 0, 'returned_to_supplier': 2, 'at_locations': 0, 'counted': 0, 'on_hand': 75}

    # The API agrees, on every date, with the movements' running balance.
    for day, quantity in expected.items():
        detail = get(client, f'/lots/supplier_collections/{note_id}', as_of=day.isoformat())
        assert Decimal(detail['on_hand']) == quantity, day
    detail = get(client, f'/lots/supplier_collections/{note_id}')
    assert [(r['kind'], Decimal(r['delta']), r['date']) for r in detail['movements']] == [
        ('received', 100, D[4].isoformat()),
        ('sold', -20, D[3].isoformat()), ('sold', -5, D[3].isoformat()),
        ('mortality', -3, D[2].isoformat()),
        ('returned_to_supplier', -2, D[1].isoformat()),
        ('buyer_return_accepted', 5, D[0].isoformat())]
    assert [Decimal(r['on_hand']) for r in detail['movements']] == [100, 80, 75, 72, 70, 75]
    assert detail['movements'][1]['sale_number'] and detail['unit'] == 'bird'

    # The stock list values each lot at its cost; the batch is not stock.
    listed = get(client, '/lots', as_of=D[1].isoformat())
    [row] = listed['items']
    assert (Decimal(row['on_hand']), Decimal(row['value_on_hand'])) == (70, Decimal('455000'))
    assert Decimal(listed['summary']['on_hand_value']) == Decimal('455000')
    assert listed['total'] == 1 and Decimal(listed['summary']['on_hand']['bird']) == 70
    assert get(client, '/lots', as_of=D[5].isoformat())['total'] == 0
    assert get(client, '/lots', as_of=D[5].isoformat(), show='all')['total'] == 0
    assert get(client, '/lots', q='nothing like this')['total'] == 0
    # The batch: 500 declared, 100 received, of which 20 sold, 3 died, 2
    # returned and 75 still at Omoterra; 400 left with the supplier. The
    # same figures for staff and for the supplier.
    flow = {'registered': 500, 'reserved': 0, 'received': 100, 'sold': 20, 'lost': 3, 'returned': 2,
        'at_kitchens': 0, 'at_omoterra': 75, 'sold_elsewhere': 0, 'left': 400}
    staff = get(client, f"/suppliers/{seeded['supplier']}")
    [batch_row] = [b for b in staff['batches'] if b['id'] == declared]
    assert {k: Decimal(v) for k, v in batch_row['flow'].items()} == flow
    mine = client.get('/api/v1/supplier/batches', headers={'Authorization': 'Bearer supplier'}).json()
    [batch_row] = [b for b in mine if b['id'] == declared]
    assert {k: Decimal(v) for k, v in batch_row['flow'].items()} == flow
    # The delivery note's own figures are the same model.
    note = get(client, f'/supplier-collections/{note_id}')
    assert (Decimal(note['on_hand']), Decimal(note['sold']), Decimal(note['lost']), Decimal(note['returned'])) == (75, 20, 3, 2)


def test_not_recovered_left_on_the_sale_date(client, sessions, seeded):
    note_id = receive(client, seeded, batch(sessions, seeded, 50), 10, on=D[3].isoformat())
    body = sell(client, note_id, 4, D[2])
    assert cancel(client, body['id'], 'not_recovered').status_code == 200
    with sessions() as db:
        moves = lots.movements(db, 'supplier_collections', [note_id])
        assert [lots.on_hand(moves, D[n])[('supplier_collections', note_id)] for n in (3, 2, 0)] == [10, 6, 6]
        assert lots.summary(moves)['not_recovered'] == 4 and lots.summary(moves)['sold'] == 0


def test_goods_that_never_left_are_history_only(client, sessions, seeded):
    note_id = receive(client, seeded, batch(sessions, seeded, 50), 10, on=D[3].isoformat())
    body = sell(client, note_id, 4, D[2])
    assert cancel(client, body['id'], 'never_left').status_code == 200
    detail = get(client, f'/lots/supplier_collections/{note_id}')
    assert [(r['kind'], Decimal(r['delta'])) for r in detail['movements']] == [
        ('received', 10), ('sale_cancelled_never_left', 0)]
    assert Decimal(detail['movements'][1]['quantity']) == 4 and Decimal(detail['on_hand']) == 10


def test_unknown_lot_is_not_found(client):
    response = client.get(API + '/lots/supplier_batches/x', headers=OPS)
    assert response.status_code == 404
    assert client.get(API + '/lots', params={'table': 'supplier_batches'}, headers=OPS).status_code == 404


def count(client, table, lot_id, counted, on, headers=OPS, **extra):
    return post(client, f'/lots/{table}/{lot_id}/counts', {'counted_quantity': str(counted), 'counted_on': on.isoformat(),
        'reason': 'Monthly count at the Tegeta pen', 'evidence': 'Count sheet signed by two staff', **extra}, headers)


def stock_lost(client, day):
    return Decimal(get(client, '/finance/profit', start=day.isoformat(), end=day.isoformat())['stock_lost'])


def test_a_count_records_its_difference_and_counts_as_stock_lost(client, sessions, seeded):
    note_id = receive(client, seeded, batch(sessions, seeded, 50), 40, on=D[4].isoformat())
    sell(client, note_id, 10, D[3])
    before = stock_lost(client, D[2])
    # Counted 28 on D2 where the records expect 30: 2 short, at 6,500 each.
    assert count(client, 'supplier_collections', note_id, 28, D[2], STAFF).status_code == 403
    assert count(client, 'supplier_collections', note_id, 30, D[2]).status_code == 422  # matches the records
    assert count(client, 'supplier_collections', note_id, 28, D[5]).status_code == 422  # before the receipt
    body = count(client, 'supplier_collections', note_id, 28, D[2]).json()
    assert Decimal(body['on_hand']) == 28 and Decimal(body['counted']) == -2
    move = body['movements'][-1]
    assert (move['kind'], Decimal(move['delta']), Decimal(move['counted_quantity'])) == ('count_adjustment', -2, 28)
    assert move['evidence'] == 'Count sheet signed by two staff'
    assert stock_lost(client, D[2]) - before == Decimal('13000')
    # The delivery note page reads the same model.
    assert Decimal(get(client, f'/supplier-collections/{note_id}')['on_hand']) == 28


def test_r8_no_change_leaves_any_later_day_below_zero(client, sessions, seeded):
    """A lot of 10: 6 sold on D3, 4 sold on D1. Counting 8 on D4 (2 short)
    is refused, because D1 would end at -2, though D4 alone has stock."""
    note_id = receive(client, seeded, batch(sessions, seeded, 50), 10, on=D[5].isoformat())
    sell(client, note_id, 6, D[3])
    sell(client, note_id, 4, D[1])
    refused = count(client, 'supplier_collections', note_id, 8, D[4])
    assert refused.status_code == 422 and D[1].isoformat() in refused.json()['detail']
    # A surplus is fine, and cancelling it is refused once later stock relies on it.
    assert count(client, 'supplier_collections', note_id, 12, D[4]).status_code == 201
    sell(client, note_id, 2, D[0])
    with sessions() as db:
        adjustment = db.scalar(select(m.LotAdjustment))
        assert lots.first_negative(lots.movements(db, 'supplier_collections', [note_id])) is None
    path = f'/lot-adjustments/{adjustment.id}/cancel'
    assert post(client, path, {'reason': 'Counted the wrong pen'}).status_code == 422


def test_opening_stock_losses_and_cancelling_a_mistake(client, sessions):
    entry = post(client, '/opening-stock', {'category': 'local_chicken', 'unit': 'bird', 'quantity': '20',
        'unit_cost': '6000', 'as_of': D[3].isoformat(), 'evidence': 'Counted at the pen', 'valued_by': 'Maternus Joshua'})
    assert entry.status_code == 201, entry.text
    lot_id = entry.json()['id']
    path = f'/lots/opening_stock/{lot_id}/losses'
    loss = {'quantity': '3', 'lost_on': D[2].isoformat(), 'reason': 'died', 'note': 'Heat'}
    assert post(client, path, {**loss, 'lost_on': D[4].isoformat()}).status_code == 422
    assert post(client, path, {**loss, 'quantity': '21'}).status_code == 422
    body = post(client, path, loss, STAFF).json()
    assert Decimal(body['on_hand']) == 17 and Decimal(body['died']) == 3
    assert stock_lost(client, D[2]) == Decimal('18000')
    # Selling from it sees the loss.
    assert Decimal(get(client, '/opening-stock/available')[0]['on_hand']) == 17
    adjustment_id = body['movements'][-1]['source_id']
    assert post(client, f'/lot-adjustments/{adjustment_id}/cancel', {'reason': 'Recorded twice'}, STAFF).status_code == 403
    after = post(client, f'/lot-adjustments/{adjustment_id}/cancel', {'reason': 'Recorded twice'})
    assert after.status_code == 200 and Decimal(after.json()['on_hand']) == 20
    assert after.json()['cancelled_adjustments'][0]['cancel_reason'] == 'Recorded twice'
    assert stock_lost(client, D[2]) == 0


def test_a_delivery_names_the_reservation_it_fills(client, sessions, seeded):
    """Receiving no longer uses up reservations anonymously: birds a buyer's
    allocation holds are received only against that allocation, and
    cancelling it later releases only what is still outstanding."""
    with sessions.begin() as db:
        row = m.SupplierBatch(supplier_id=seeded['supplier'], category='broilers', initial_quantity=10,
            current_quantity=10, expected_ready_date=DAY.isoformat(), expected_min_weight_kg=1.8,
            expected_max_weight_kg=2.2, asking_price_per_unit=10000, region='Dar es Salaam', status='ready')
        db.add(row); db.flush(); batch_id = row.id
    assert post(client, f'/batches/{batch_id}/verify', {'verified_quantity': '10', 'readiness_confirmed': True,
        'location_confirmed': True, 'buyer_price_per_unit': '12000', 'supplier_payout_price_per_unit': '9000'}).status_code == 200
    demand = post(client, '/requirements', {'category': 'broilers', 'unit_type': 'bird', 'quantity': '6',
        'needed_by_date': DAY.isoformat(), 'delivery_area': 'Masaki', 'delivery_region': 'Dar es Salaam',
        'buyer': {'business_name': 'Reservation Buyer', 'region': 'Dar es Salaam', 'area': 'Masaki'}}).json()
    allocated = post(client, f"/requirements/{demand['id']}/allocations",
        {'allocations': [{'supplier_batch_id': batch_id, 'allocated_quantity': '6'}]})
    assert allocated.status_code == 200, allocated.text
    allocation_id = allocated.json()[0]['id']
    [held] = [b for b in get(client, f"/suppliers/{seeded['supplier']}")['batches'] if b['id'] == batch_id]
    assert [(r['kind'], r['id'], Decimal(r['outstanding'])) for r in held['commitments']] == [
        ('demand_allocation', allocation_id, 6)]

    path = f"/suppliers/{seeded['supplier']}/collections"
    body = {'batch_id': batch_id, 'received_on': DAY.isoformat(), 'delivered_quantity': '6', 'accepted_quantity': '6',
        'unit_cost': '9000'}
    refused = post(client, path, body)
    assert refused.status_code == 422 and 'reservation' in refused.json()['detail']
    named = post(client, path, {**body, 'commitment_kind': 'demand_allocation', 'commitment_id': allocation_id})
    assert named.status_code == 201, named.text
    with sessions() as db:
        batch_row = db.get(m.SupplierBatch, batch_id)
        assert (batch_row.reserved_quantity, batch_row.sold_quantity, batch_row.available_to_commit) == (0, 6, 4)
        [fill] = db.scalars(select(m.CommitmentFulfilment)).all()
        assert (fill.commitment_id, fill.quantity) == (allocation_id, 6)
    # Filled: it can no longer be reduced below what was received, nor
    # turned into an app order; cancelling it releases nothing more.
    patch = lambda body, key: client.patch(API + f'/allocations/{allocation_id}', json=body,
        headers={**OPS, 'Idempotency-Key': key})
    assert patch({'allocated_quantity': '5'}, 'reduce-below-fill').status_code == 422
    assert patch({'status': 'cancelled'}, 'cancel-after-fill').status_code == 200
    with sessions() as db:
        assert db.get(m.SupplierBatch, batch_id).reserved_quantity == 0
    # The 4 unreserved birds can be received without naming anything.
    assert post(client, path, {**body, 'delivered_quantity': '4', 'accepted_quantity': '4'}).status_code == 201
