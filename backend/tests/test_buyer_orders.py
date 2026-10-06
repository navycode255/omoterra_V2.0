"""Orders staff take for a buyer by phone or in person (build plan M2.5,
decision D7, confirmed 6 October 2026): a commitment until delivered (not a
sale, nothing owed, no stock taken); "Mark delivered" records a direct sale
dated the delivery day through the normal sale path, taking stock and cost
then; a deposit is money in held for the buyer and applied on delivery."""
from datetime import timedelta
from decimal import Decimal

from sqlalchemy import select

from app import contracts as c, lots, models as m, reporting as rp
from test_batch_sales import batch
from test_delivery_losses import receive
from test_finance import API, OPS, STAFF, key, post

DAY = c.business_today()
TODAY = DAY.isoformat()


def take_order(client, headers=OPS, deposit=None, **overrides):
    body = {'new_buyer': {'business_name': 'Hoteli ya Bahari', 'phone': '0754 222 333'},
            'ordered_on': (DAY - timedelta(days=2)).isoformat(), 'expected_on': TODAY, 'notes': 'Phoned in by Juma',
            'items': [{'category': 'broilers', 'unit': 'bird', 'quantity': '6', 'unit_price': '9000'}]}
    if deposit:
        body['deposit'] = deposit
    body.update(overrides)
    response = post(client, '/buyer-orders', body, headers)
    assert response.status_code == 201, response.text
    return response.json()


def deliver(client, order, items, on=TODAY, headers=OPS, **extra):
    return post(client, f"/buyer-orders/{order['id']}/deliver", {'buyer_profile_id': order['buyer_profile_id'],
        'sold_on': on, 'items': items, **extra}, headers)


def get(client, path, **params):
    response = client.get(API + path, params=params, headers=OPS)
    assert response.status_code == 200, response.text
    return response.json()


def on_hand(sessions, note_id):
    with sessions() as db:
        return lots.on_hand(lots.movements(db, 'supplier_collections', [note_id])).get(('supplier_collections', note_id), 0)


def cash_in(client, on=TODAY):
    return Decimal(get(client, '/ledger/payments', start=on, end=on)['summary']['money_in'])


def test_an_order_is_a_commitment_until_delivered_then_a_sale_on_its_delivery_day(client, sessions, seeded):
    note_id = receive(client, seeded, batch(sessions, seeded, 50), 10, on=(DAY - timedelta(days=3)).isoformat())
    order = take_order(client, STAFF, deposit={'amount': '20000', 'paid_on': TODAY, 'method': 'mpesa', 'reference': 'QDEP1'})
    assert order['order_number'].startswith('BO-') and order['status'] == 'open'
    assert Decimal(order['total_amount']) == Decimal('54000') and Decimal(order['deposit_held']) == Decimal('20000')
    # Before delivery: no sale, nothing owed, no stock taken; a commitment.
    with sessions() as db:
        assert db.scalar(select(m.Sale.id)) is None
        assert rp.receivables(db)['total'] == 0
        pending = rp.commitments(db)
        assert pending['ledger'] == Decimal('54000') and pending['deposits'] == Decimal('20000')
        assert pending['unpaid'] == Decimal('34000')
        assert rp.revenue(db, DAY - timedelta(days=5), DAY)['total'] == 0
    assert on_hand(sessions, note_id) == 10
    summary = get(client, '/finance/summary')
    assert Decimal(summary['commitments']['ledger']) == Decimal('54000') and summary['commitments']['ledger_count'] == 1
    assert Decimal(summary['owed_to_me']['total']) == 0
    # The deposit is money in on the day it came, once.
    assert cash_in(client) == Decimal('20000')
    listed = get(client, '/buyer-orders', status='open')
    assert listed['total'] == 1 and Decimal(listed['summary']['total']) == Decimal('54000')
    assert Decimal(listed['summary']['deposits']) == Decimal('20000')
    assert get(client, '/buyer-orders', q='bahari')['total'] == 1 and get(client, '/buyer-orders', q='nobody')['total'] == 0

    # Delivered yesterday, from the delivery note: a sale dated that day.
    yesterday = (DAY - timedelta(days=1)).isoformat()
    done = deliver(client, order, [{'quantity': '6', 'unit_price': '9000', 'supplier_collection_id': note_id}], on=yesterday)
    assert done.status_code == 201, done.text
    sale = done.json()
    assert sale['sold_on'] == yesterday and Decimal(sale['total_amount']) == Decimal('54000')
    assert sale['buyer_order']['id'] == order['id']
    assert Decimal(sale['received_amount']) == Decimal('20000') and Decimal(sale['balance']) == Decimal('34000')
    assert on_hand(sessions, note_id) == 4
    detail = get(client, f"/buyer-orders/{order['id']}")
    assert detail['status'] == 'delivered' and detail['sale_id'] == sale['id'] and detail['delivered_on'] == yesterday
    assert [p['state'] for p in detail['payments']] == ['applied']
    with sessions() as db:
        assert rp.commitments(db)['count'] == 0
        sold = rp.revenue(db, DAY - timedelta(days=1), DAY - timedelta(days=1))
        assert sold['direct'] == Decimal('54000')
        assert rp.cost_of_goods(db, DAY - timedelta(days=1), DAY - timedelta(days=1))['direct'] == Decimal('39000')
        assert rp.receivables(db)['ledger'] == Decimal('34000')
        # The deposit is now a payment on the sale with the same day and code.
        [payment] = db.scalars(select(m.LedgerPayment)).all()
        assert (payment.paid_on, payment.reference, payment.amount) == (DAY, 'QDEP1', Decimal('20000'))
        [claim] = db.scalars(select(m.MoneyReference)).all()
        assert (claim.source_table, claim.source_id) == ('ledger_payments', payment.id)
    # Still counted once in the cash book, on the day it was paid.
    assert cash_in(client) == Decimal('20000')
    rows = get(client, '/ledger/payments', start=TODAY, end=TODAY)['items']
    assert [(r['source_table'], Decimal(r['amount'])) for r in rows] == [('ledger_payments', Decimal('20000'))]
    # It shows in Sales on the delivery day.
    sales = get(client, '/sales', start=yesterday, end=yesterday)
    assert [s['id'] for s in sales['items']] == [sale['id']]
    # Delivered orders cannot be edited, cancelled or delivered again.
    assert post(client, f"/buyer-orders/{order['id']}/cancel", {'reason': 'Too late'}).status_code == 409
    assert deliver(client, order, [{'quantity': '1', 'unit_price': '9000', 'supplier_collection_id': note_id}]).status_code == 409


def test_edit_cancel_with_a_reason_and_deposits_given_back(client, sessions, seeded):
    order = take_order(client, deposit={'amount': '10000', 'paid_on': TODAY, 'method': 'cash'})
    edited = client.put(API + f"/buyer-orders/{order['id']}", json={'buyer_profile_id': order['buyer_profile_id'],
        'ordered_on': order['ordered_on'], 'expected_on': None, 'notes': 'Now 8 birds',
        'items': [{'category': 'broilers', 'unit': 'bird', 'quantity': '8', 'unit_price': '9000'}]}, headers=OPS)
    assert edited.status_code == 200, edited.text
    assert Decimal(edited.json()['total_amount']) == Decimal('72000') and edited.json()['notes'] == 'Now 8 birds'
    # Below the deposit held, or half a bird: refused.
    for items in ([{'category': 'broilers', 'unit': 'bird', 'quantity': '1', 'unit_price': '5000'}],
                  [{'category': 'broilers', 'unit': 'bird', 'quantity': '1.5', 'unit_price': '9000'}]):
        refused = client.put(API + f"/buyer-orders/{order['id']}", json={'buyer_profile_id': order['buyer_profile_id'],
            'ordered_on': order['ordered_on'], 'items': items}, headers=OPS)
        assert refused.status_code == 422
    # A deposit is held: cancelling is refused until it is given back.
    cancel = post(client, f"/buyer-orders/{order['id']}/cancel", {'reason': 'Buyer changed their mind'})
    assert cancel.status_code == 409 and 'TZS 10,000' in cancel.json()['detail']
    [deposit] = get(client, f"/buyer-orders/{order['id']}")['payments']
    back = post(client, f"/buyer-orders/{order['id']}/deposits/{deposit['id']}/refund",
        {'paid_on': TODAY, 'method': 'cash', 'note': 'Handed back at the shop'})
    assert back.status_code == 201, back.text
    book = get(client, '/ledger/payments', start=TODAY, end=TODAY)['summary']
    # In and out are both recorded: R3, the outflow is its own record.
    assert (Decimal(book['money_in']), Decimal(book['money_out'])) == (Decimal('10000'), Decimal('10000'))
    assert post(client, f"/buyer-orders/{order['id']}/cancel", {'reason': 'x'}).status_code == 422  # reason too short
    done = post(client, f"/buyer-orders/{order['id']}/cancel", {'reason': 'Buyer changed their mind'})
    assert done.status_code == 200 and done.json()['status'] == 'cancelled'
    assert done.json()['cancel_reason'] == 'Buyer changed their mind'
    with sessions() as db:
        assert rp.commitments(db)['count'] == 0
    assert client.put(API + f"/buyer-orders/{order['id']}", json={'buyer_profile_id': order['buyer_profile_id'],
        'ordered_on': order['ordered_on'], 'items': [{'category': 'broilers', 'unit': 'bird', 'quantity': '8',
        'unit_price': '9000'}]}, headers=OPS).status_code == 409


def test_a_deposit_entered_by_mistake_is_voided_by_an_admin(client, sessions, seeded):
    order = take_order(client, deposit={'amount': '5000', 'paid_on': TODAY, 'method': 'mpesa', 'reference': 'QVOID'})
    [deposit] = order['payments']
    path = f"/buyer-orders/{order['id']}/deposits/{deposit['id']}/void"
    assert client.post(API + path, json={'reason': 'Typed on the wrong order'}, headers=STAFF).status_code == 403
    assert client.post(API + path, json={'reason': 'Typed on the wrong order'}, headers=OPS).status_code == 200
    assert cash_in(client) == 0
    # Its reference is free again.
    again = post(client, f"/buyer-orders/{order['id']}/deposits", {'amount': '5000', 'paid_on': TODAY, 'method': 'mpesa',
        'reference': 'QVOID'})
    assert again.status_code == 201, again.text
    assert Decimal(again.json()['deposit_held']) == Decimal('5000')
    # More than the order total: refused.
    over = post(client, f"/buyer-orders/{order['id']}/deposits", {'amount': '60000', 'paid_on': TODAY, 'method': 'cash'})
    assert over.status_code == 422


def test_delivery_follows_the_sale_rules(client, sessions, seeded):
    """R8, late entries, batch collection confirmation and cost states all
    apply when an order is delivered; a refused delivery leaves it open."""
    note_id = receive(client, seeded, batch(sessions, seeded, 50), 5, on=(DAY - timedelta(days=10)).isoformat())
    order = take_order(client, ordered_on=(DAY - timedelta(days=9)).isoformat(), expected_on=None)
    line = lambda n: [{'quantity': str(n), 'unit_price': '9000', 'supplier_collection_id': note_id}]
    # More than is on hand (R8).
    assert deliver(client, order, line(6)).status_code == 422
    # Before the order was taken.
    assert deliver(client, order, line(2), on=(DAY - timedelta(days=10)).isoformat()).status_code == 422
    # Delivered 5 days ago: a late entry, admin with a reason only.
    late_day = (DAY - timedelta(days=lots.LATE_ENTRY_DAYS + 2)).isoformat()
    assert deliver(client, order, line(2), on=late_day, headers=STAFF, late_reason='Paper book found').status_code == 422
    assert deliver(client, order, line(2), on=late_day).status_code == 422
    # A batch line needs the collection confirmed (M1.6).
    unconfirmed = [{'category': 'broilers', 'unit': 'bird', 'quantity': '2', 'unit_price': '9000',
        'supplier_id': seeded['supplier'], 'supplier_batch_id': batch(sessions, seeded, 20), 'unit_cost': '6000'}]
    assert deliver(client, order, unconfirmed).status_code == 422
    # Own stock needs a cost or "cost unknown" (M1.3).
    own = [{'category': 'broilers', 'unit': 'bird', 'quantity': '2', 'unit_price': '9000'}]
    assert deliver(client, order, own).status_code == 422
    # Another buyer: refused.
    other = post(client, f"/buyer-orders/{order['id']}/deliver", {'new_buyer': {'business_name': 'Someone else'},
        'sold_on': TODAY, 'items': line(2)})
    assert other.status_code == 422
    with sessions() as db:
        assert db.scalar(select(m.Sale.id)) is None and db.get(m.BuyerOrder, order['id']).status == 'open'
    assert on_hand(sessions, note_id) == 5
    done = deliver(client, order, line(2), on=late_day, late_reason='Paper delivery book found in the van')
    assert done.status_code == 201, done.text
    with sessions() as db:
        [late] = db.scalars(select(m.LateEntry)).all()
        assert (late.entity_table, late.entity_id) == ('sales', done.json()['id'])
    assert on_hand(sessions, note_id) == 3
    # An unknown own-stock cost keeps the sale provisional (R5).
    second = take_order(client)
    unknown = deliver(client, second, [{'category': 'broilers', 'unit': 'bird', 'quantity': '6', 'unit_price': '9000',
        'cost_unknown': True}])
    assert unknown.status_code == 201 and unknown.json()['cost_state'] == 'unknown'


def test_a_retry_of_mark_delivered_records_one_sale(client, sessions, seeded):
    order = take_order(client)
    body = {'buyer_profile_id': order['buyer_profile_id'], 'sold_on': TODAY,
            'items': [{'category': 'broilers', 'unit': 'bird', 'quantity': '6', 'unit_price': '9000', 'unit_cost': '6000'}]}
    retry = key()
    first = post(client, f"/buyer-orders/{order['id']}/deliver", body, idem=retry)
    second = post(client, f"/buyer-orders/{order['id']}/deliver", body, idem=retry)
    assert first.status_code == second.status_code == 201 and first.json()['id'] == second.json()['id']
    with sessions() as db:
        assert len(db.scalars(select(m.Sale)).all()) == 1
