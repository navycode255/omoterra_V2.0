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


# ---- finance owner, 7 October 2026: part refunds and moving a deposit --------------

def book(client, on):
    body = get(client, '/ledger/payments', start=on.isoformat(), end=on.isoformat())['summary']
    return Decimal(body['money_in']), Decimal(body['money_out'])


def held(client, order):
    return Decimal(get(client, f"/buyer-orders/{order['id']}")['deposit_held'])


def deposit_of(client, order):
    return next(p for p in get(client, f"/buyer-orders/{order['id']}")['payments'] if p['kind'] == 'deposit')


def give_back(client, order, deposit, amount=None, on=TODAY, **extra):
    body = {'paid_on': on, 'method': 'cash', **extra}
    if amount is not None:
        body['amount'] = str(amount)
    return post(client, f"/buyer-orders/{order['id']}/deposits/{deposit['id']}/refund", body)


def move(client, order, deposit, target, amount=None, reason='Buyer wants it on the next order', headers=OPS):
    body = {'to_order_id': target['id'], 'reason': reason}
    if amount is not None:
        body['amount'] = str(amount)
    return post(client, f"/buyer-orders/{order['id']}/deposits/{deposit['id']}/move", body, headers)


def test_a_deposit_is_given_back_in_parts_each_on_its_own_day(client, sessions, seeded):
    paid, first, second = DAY - timedelta(days=2), DAY - timedelta(days=1), DAY
    order = take_order(client, deposit={'amount': '30000', 'paid_on': paid.isoformat(), 'method': 'cash'})
    deposit = deposit_of(client, order)
    assert give_back(client, order, deposit, 10000, on=first.isoformat()).status_code == 201
    assert give_back(client, order, deposit, 5000, on=second.isoformat(), method='mpesa', reference='QPART2').status_code == 201
    # Each refund is money out on its own day; the deposit stays money in on its day.
    assert book(client, paid) == (Decimal('30000'), 0)
    assert book(client, first) == (0, Decimal('10000'))
    assert book(client, second) == (0, Decimal('5000'))
    assert held(client, order) == Decimal('15000')
    view = deposit_of(client, order)
    assert view['state'] == 'held' and Decimal(view['held']) == Decimal('15000') and Decimal(view['given_back']) == Decimal('15000')
    # More than is still held: refused. A reference is claimed like other money.
    over = give_back(client, order, deposit, 15001)
    assert over.status_code == 422 and 'TZS 15,000' in over.json()['detail']
    assert give_back(client, order, deposit, 100, method='mpesa', reference='QPART2').status_code == 409
    with sessions() as db:
        assert rp.commitments(db)['deposits'] == Decimal('15000')
    # Cancel still needs nothing held.
    assert post(client, f"/buyer-orders/{order['id']}/cancel", {'reason': 'Buyer changed their mind'}).status_code == 409
    assert give_back(client, order, deposit).status_code == 201  # the rest
    assert held(client, order) == 0 and deposit_of(client, order)['state'] == 'given_back'
    assert book(client, DAY) == (0, Decimal('20000'))
    # Nothing left: a further refund or a void is refused.
    assert give_back(client, order, deposit, 1).status_code == 409
    assert client.post(API + f"/buyer-orders/{order['id']}/deposits/{deposit['id']}/void",
        json={'reason': 'Typed twice'}, headers=OPS).status_code == 409
    assert post(client, f"/buyer-orders/{order['id']}/cancel", {'reason': 'Buyer changed their mind'}).status_code == 200


def test_a_deposit_moves_to_another_open_order_of_the_same_buyer_and_moves_no_money(client, sessions, seeded):
    paid = DAY - timedelta(days=2)
    with sessions.begin() as db:
        account = m.MoneyAccount(name='M-Pesa till', kind='mobile_wallet', cutoff_on=DAY - timedelta(days=30),
            opening_balance=0, opening_evidence='Statement', verified_by='Finance owner')
        db.add(account); db.flush()
        account_id = account.id
    first = take_order(client, deposit={'amount': '20000', 'paid_on': paid.isoformat(), 'method': 'mpesa',
        'reference': 'QMOVE1', 'money_account_id': account_id})
    buyer = {'buyer_profile_id': first['buyer_profile_id']}
    second = take_order(client, **buyer, new_buyer=None,
        items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '2', 'unit_price': '9000'}])
    other_buyer = take_order(client, new_buyer={'business_name': 'Mgahawa Mwingine', 'phone': '0754 999 888'})
    delivered = take_order(client, **buyer, new_buyer=None)
    own = lambda n: [{'category': 'broilers', 'unit': 'bird', 'quantity': str(n), 'unit_price': '9000', 'unit_cost': '6000'}]
    assert deliver(client, delivered, own(6)).status_code == 201
    deposit = deposit_of(client, first)
    before = {on: book(client, on) for on in (paid, DAY)}

    # Refused: another buyer, a delivered order, the same order, above what is held.
    assert move(client, first, deposit, other_buyer, 1000).status_code == 422
    assert move(client, first, deposit, delivered, 1000).status_code == 422
    assert move(client, first, deposit, first, 1000).status_code == 422
    assert move(client, first, deposit, second, 20001).status_code == 422
    # Above the target order's total (18,000): refused too.
    assert move(client, first, deposit, second, 18001).status_code == 422
    # Staff may move part of it, with a reason; it is logged.
    moved = move(client, first, deposit, second, 8000, headers=STAFF)
    assert moved.status_code == 201, moved.text
    [log] = moved.json()['moves']
    assert (log['direction'], Decimal(log['amount']), log['to_order_number']) == ('out', Decimal('8000'), second['order_number'])
    assert log['reason'] == 'Buyer wants it on the next order' and log['moved_by'] == 'Test Staff'
    assert (held(client, first), held(client, second)) == (Decimal('12000'), Decimal('8000'))
    # No money moved: no cash book row, no account movement.
    assert {on: book(client, on) for on in (paid, DAY)} == before
    with sessions() as db:
        from app import accounts
        assert accounts.balance(db, db.get(m.MoneyAccount, account_id)) == Decimal('20000')
        assert rp.commitments(db)['deposits'] == Decimal('20000')
    there = deposit_of(client, second)
    assert there['state'] == 'held' and there['origin_order_number'] == first['order_number']
    assert Decimal(there['held']) == Decimal('8000') and there['reference'] == 'QMOVE1'
    # The moved part can be given back from the order it is on, not more.
    assert give_back(client, second, there, 8001).status_code == 422
    # Cancelling the first order still needs its deposit gone.
    assert post(client, f"/buyer-orders/{first['id']}/cancel", {'reason': 'Merged into the other'}).status_code == 409

    # The second order is delivered: the moved part becomes a payment on its
    # sale with the deposit's day, method, reference and account, once.
    done = deliver(client, second, own(2))
    assert done.status_code == 201, done.text
    assert Decimal(done.json()['received_amount']) == Decimal('8000')
    assert held(client, first) == Decimal('12000')
    assert book(client, paid) == before[paid]
    # Then the first: the rest of the deposit is applied there.
    done = deliver(client, first, own(6))
    assert done.status_code == 201, done.text
    assert Decimal(done.json()['received_amount']) == Decimal('12000')
    with sessions() as db:
        payments = db.scalars(select(m.LedgerPayment).order_by(m.LedgerPayment.amount)).all()
        assert [(p.amount, p.paid_on, p.reference) for p in payments] == [
            (Decimal('8000.00'), paid, 'QMOVE1'), (Decimal('12000.00'), paid, 'QMOVE1')]
        from app import accounts
        assert accounts.balance(db, db.get(m.MoneyAccount, account_id)) == Decimal('20000')
        assert rp.commitments(db)['deposits'] == 0
    rows = get(client, '/ledger/payments', start=paid.isoformat(), end=paid.isoformat())['items']
    assert sorted((r['source_table'], Decimal(r['amount'])) for r in rows) == [
        ('ledger_payments', Decimal('8000')), ('ledger_payments', Decimal('12000'))]
    assert book(client, paid) == before[paid]
    assert [p['state'] for p in get(client, f"/buyer-orders/{first['id']}")['payments']] == ['applied']


def test_migration_046_keeps_deposits_applied_before_it_applied(tmp_path, monkeypatch):
    """A deposit applied to its sale before 046 (applied_payment_id) becomes
    one application of its whole amount: held stays 0 and the cash book
    still counts the payment once."""
    import os
    import shutil
    import uuid
    import pytest
    from sqlalchemy import create_engine, text
    from sqlalchemy.orm import Session
    from app import migrations
    url = os.environ.get('OMOTERRA_TEST_DATABASE_URL')
    if not url:
        pytest.skip('Set OMOTERRA_TEST_DATABASE_URL to a disposable PostgreSQL database')
    schema = 'omoterra_m046_' + uuid.uuid4().hex
    admin = create_engine(url)
    with admin.begin() as db:
        db.execute(text(f'CREATE SCHEMA {schema}'))
    engine = create_engine(url, connect_args={'options': f'-csearch_path={schema}'})
    try:
        files = migrations.files()
        for path in files:
            if path.name < '046':
                shutil.copy(path, tmp_path / path.name)
        monkeypatch.setattr(migrations, 'DIRECTORY', tmp_path)
        migrations.apply(engine)
        with Session(engine) as db, db.begin():
            profile = m.BuyerProfile(business_name='Hoteli')
            db.add(profile); db.flush()
            sale = m.Sale(sale_number='SL-OLD1', sold_on=DAY, buyer_profile_id=profile.id, buyer_name='Hoteli',
                total_amount=30000)
            db.add(sale); db.flush()
            debt = m.LedgerDebt(direction='receivable', party_kind='buyer', party_name='Hoteli', amount=30000,
                paid_amount=10000, incurred_on=DAY, source='sale', sale_id=sale.id, buyer_profile_id=profile.id)
            db.add(debt); db.flush()
            payment = m.LedgerPayment(debt_id=debt.id, amount=10000, paid_on=DAY, method='cash')
            db.add(payment); db.flush()
            order = m.BuyerOrder(order_number='BO-OLD1', buyer_profile_id=profile.id, buyer_name='Hoteli',
                ordered_on=DAY, total_amount=30000, status='delivered', sale_id=sale.id, delivered_on=DAY)
            db.add(order); db.flush()
            deposit = m.BuyerOrderPayment(buyer_order_id=order.id, kind='deposit', amount=10000, paid_on=DAY,
                method='cash', applied_payment_id=payment.id)
            db.add(deposit); db.flush()
            ids = (order.id, deposit.id, payment.id)
        for path in files:
            if path.name >= '046':
                shutil.copy(path, tmp_path / path.name)
        migrations.apply(engine)
        with Session(engine) as db:
            [applied] = db.scalars(select(m.BuyerOrderDepositApplication)).all()
            assert (applied.buyer_order_id, applied.deposit_id, applied.ledger_payment_id, applied.amount) == (
                *ids, Decimal('10000.00'))
            assert rp.held_deposits(db) == {}
            assert rp.cash_movements(db, DAY, DAY)['money_in'] == Decimal('10000.00')
    finally:
        engine.dispose()
        with admin.begin() as db:
            db.execute(text(f'DROP SCHEMA {schema} CASCADE'))
        admin.dispose()
