from decimal import Decimal
from app import models as m
from test_finance import API, OPS, TODAY, post, sale


def batch(sessions, seeded, quantity=300):
    with sessions.begin() as db:
        row = m.SupplierBatch(supplier_id=seeded['supplier'], category='broilers', initial_quantity=quantity,
            current_quantity=quantity, status='ready', approved_at=m.now())
        db.add(row); db.flush()
        return row.id


def state(sessions, id):
    with sessions() as db:
        row = db.get(m.SupplierBatch, id)
        return row.sold_quantity, row.externally_sold_quantity, row.available_to_commit, row.status


def line(seeded, batch_id, quantity):
    return {'category': 'broilers', 'unit': 'bird', 'quantity': str(quantity), 'unit_price': '7000',
            'supplier_id': seeded['supplier'], 'unit_cost': '6500', 'supplier_batch_id': batch_id}


def test_selling_from_a_batch_reduces_it_and_edits_or_cancels_give_back(client, sessions, seeded):
    id = batch(sessions, seeded)
    first = sale(client, items=[line(seeded, id, 20)])
    sale(client, items=[line(seeded, id, 40)])
    assert state(sessions, id)[:3] == (Decimal('60'), 0, Decimal('240'))
    payable = next(d for d in first['debts'] if d['direction'] == 'payable')
    assert Decimal(payable['amount']) == Decimal('130000')  # still owed to the supplier as before

    changed = client.put(API + f"/sales/{first['id']}", headers=OPS, json={
        'buyer_profile_id': first['buyer_profile_id'], 'sold_on': TODAY, 'items': [line(seeded, id, 25)]})
    assert changed.status_code == 200, changed.text
    assert state(sessions, id)[0] == Decimal('65')

    cancelled = post(client, f"/sales/{first['id']}/cancel", {'reason': 'Entered twice'})
    assert cancelled.status_code == 200, cancelled.text
    assert state(sessions, id)[0] == Decimal('40')


def test_cannot_sell_more_than_is_left_or_from_another_suppliers_batch(client, sessions, seeded):
    id = batch(sessions, seeded, 30)
    too_many = post(client, '/sales', {'new_buyer': {'business_name': 'Shop', 'phone': '0754 000 111', 'region': 'dar'},
        'sold_on': TODAY, 'items': [line(seeded, id, 31)]})
    assert too_many.status_code == 422 and '30' in too_many.text
    with sessions.begin() as db:
        db.get(m.SupplierBatch, id).supplier_id = seeded['other']
    wrong = post(client, '/sales', {'new_buyer': {'business_name': 'Shop', 'phone': '0754 000 111', 'region': 'dar'},
        'sold_on': TODAY, 'items': [line(seeded, id, 1)]})
    assert wrong.status_code == 422


def test_staff_record_sold_elsewhere_and_close_the_batch(client, sessions, seeded):
    id = batch(sessions, seeded, 700)
    sale(client, items=[line(seeded, id, 100)])
    elsewhere = post(client, f'/batches/{id}/sold-elsewhere', {'quantity': '450', 'notes': 'Sold at the farm'})
    assert elsewhere.status_code == 200, elsewhere.text
    body = elsewhere.json()
    assert Decimal(body['remaining']) == Decimal('150') and Decimal(body['sold_elsewhere']) == Decimal('450')
    assert body['elsewhere_history'][0]['by_staff'] is True
    closed = post(client, f'/batches/{id}/close', {'notes': ''})
    assert closed.status_code == 200, closed.text
    assert state(sessions, id) == (Decimal('100'), Decimal('600'), Decimal('0'), 'sold')
    assert post(client, f'/batches/{id}/close', {'notes': ''}).status_code == 409
    listed = client.get(API + '/supplier-batches/open', headers=OPS).json()
    assert id not in [row['id'] for row in listed]


def test_not_from_a_batch_is_saved_without_one(client, sessions, seeded):
    body = sale(client, items=[{**line(seeded, '', 5)}])
    assert body['items'][0]['supplier_batch_id'] is None
