"""One reporting layer (build plan M1.7, F01): every finance headline equals
the sum of its drilldown rows, with direct-only, marketplace-only and mixed
data; one economic event is counted once however many records reach it; app
orders count on their delivery date (D2); and the M1 exit scenario."""
from datetime import datetime, time, timedelta, timezone
from decimal import Decimal

import pytest
from sqlalchemy import select

from app import contracts as c, models as m, reporting as rp, services as s, transfers as tr
from test_batch_sales import batch
from test_commerce import order
from test_finance import API, OPS, TODAY, expense, key, pay, post, receivable, sale

DAY = c.business_today()
EAT = timezone(timedelta(hours=3))
STEPS = ['pickup_scheduled', 'collected', 'quality_checked', 'in_transit', 'delivered']


def get(client, path, **params):
    response = client.get(API + path, params=params, headers=OPS)
    assert response.status_code == 200, response.text
    return response.json()


def app_order(sessions, seeded, quantity, idem, accepted=None, deliver=True, delivered_on=None, created_on=None):
    """An app order (pay on delivery), delivered with `accepted` birds unless
    `deliver` is False; its delivery dated `delivered_on` when given."""
    accepted = quantity if accepted is None else accepted
    id = order(sessions, seeded, quantity, idem)
    with sessions.begin() as db:
        row = db.get(m.Order, id)
        if created_on:
            row.created_at = datetime.combine(created_on, time(10), tzinfo=EAT)
        if deliver:
            for status in STEPS:
                s.advance(db, row, c.Progress(internal_status=status, actual_quantity=accepted,
                    rejected_quantity=quantity - accepted))
        if delivered_on:
            at = datetime.combine(delivered_on, time(15), tzinfo=EAT).isoformat()
            row.activity = [{**entry, 'at': at} if entry['label'] == 'Delivered' else entry for entry in row.activity]
            row.recognized_on = delivered_on  # M2.5: the stored recognition date
    return id


def reconcile(client, order_id, amount, reference):
    response = client.post(API + f'/orders/{order_id}/reconcile', json={'amount': amount, 'payment_reference': reference},
        headers={**OPS, 'Idempotency-Key': key()})
    assert response.status_code == 200, response.text


def settlement_of(sessions, order_id):
    with sessions() as db:
        return db.scalar(select(m.Settlement).join(m.OrderItem, m.OrderItem.id == m.Settlement.order_item_id)
            .where(m.OrderItem.order_id == order_id))


def pay_settlement(client, sessions, order_id, reference):
    row = settlement_of(sessions, order_id)
    response = client.post(API + f'/settlements/{row.id}/pay', json={'amount': str(row.total_payable),
        'payment_reference': reference}, headers={**OPS, 'Idempotency-Key': key()})
    assert response.status_code == 200, response.text


def direct_data(client, sessions, seeded):
    # A sale to a buyer who paid part; its stock owed to an unregistered party.
    first = sale(client, items=[{'category': 'local_chicken', 'unit': 'bird', 'quantity': '10', 'unit_price': '15000',
        'supplier_name': 'Mzee Juma', 'unit_cost': '10000'}], payment={'amount': '60000', 'paid_on': TODAY, 'method': 'mpesa'})
    payable = next(d for d in first['debts'] if d['direction'] == 'payable')
    assert pay(client, payable['id'], '40000').status_code == 201
    # A registered supplier paid by transfer; the allocation moved to credit
    # and re-allocated: cash out stays the transfer.
    second = sale(client, new_buyer={'business_name': 'Hotel Bahari'}, items=[{'category': 'broilers', 'unit': 'bird',
        'quantity': '5', 'unit_price': '12000', 'supplier_id': seeded['supplier'], 'unit_cost': '9000'}])
    paid = post(client, f"/ledger/suppliers/{seeded['supplier']}/payments",
        {'amount': '30000', 'paid_on': TODAY, 'method': 'mpesa', 'reference': 'TR-1'})
    assert paid.status_code == 201, paid.text
    with sessions() as db:
        allocation = db.scalar(select(m.LedgerPayment).where(m.LedgerPayment.supplier_payment_id == paid.json()['id']))
    assert post(client, f'/ledger/payments/{allocation.id}/reverse', {'reason': 'Wrong invoice'}).status_code == 200
    assert post(client, f"/ledger/suppliers/{seeded['supplier']}/credit/apply", {'amount': '30000'}).status_code == 201
    # Received stock: a delivery note (its payable), 4 sold from it, 1 lost.
    note = post(client, f"/suppliers/{seeded['supplier']}/collections", {'batch_id': batch(sessions, seeded, 50),
        'received_on': TODAY, 'delivered_quantity': '10', 'accepted_quantity': '10', 'unit_cost': '6000'})
    assert note.status_code == 201, note.text
    sale(client, new_buyer={'business_name': 'Duka la Kuku'}, items=[{'quantity': '4', 'unit_price': '8000',
        'supplier_collection_id': note.json()['id']}], payment={'amount': '32000', 'paid_on': TODAY, 'method': 'cash'})
    assert post(client, f"/supplier-collections/{note.json()['id']}/losses", {'quantity': '1', 'lost_on': TODAY,
        'reason': 'died'}).status_code == 201
    # Expenses, paid and owed; a manual loan to someone, overdue.
    expense(client)
    expense(client, category='transport', description='Truck to market', amount='20000', payment=None)
    loan = post(client, '/ledger/debts', {'direction': 'receivable', 'party_name': 'Juma (driver)',
        'description': 'Advance on salary', 'amount': '50000', 'incurred_on': TODAY, 'due_on': '2020-01-01'})
    assert loan.status_code == 201
    assert pay(client, receivable(second)['id'], '10000').status_code == 201


def marketplace_data(client, sessions, seeded):
    # Delivered, part paid on delivery, payout pending.
    first = app_order(sessions, seeded, 4, 'report-order-1', accepted=3)
    reconcile(client, first, '10000', 'RC-1')
    # Delivered, fully paid, payout sent.
    second = app_order(sessions, seeded, 3, 'report-order-2')
    reconcile(client, second, '36000', 'RC-2')
    pay_settlement(client, sessions, second, 'PO-2')
    # Ordered, not delivered: a commitment only.
    app_order(sessions, seeded, 2, 'report-order-3', deliver=False)


def staff_order_data(client, sessions, seeded):
    """Orders staff took for buyers (M2.5): one open with a deposit (a
    commitment; its deposit is money in), one delivered today with its
    deposit applied to the sale."""
    open_ = post(client, '/buyer-orders', {'new_buyer': {'business_name': 'Kibanda cha Mama'}, 'ordered_on': TODAY,
        'items': [{'category': 'local_chicken', 'unit': 'bird', 'quantity': '2', 'unit_price': '20000'}],
        'deposit': {'amount': '15000', 'paid_on': TODAY, 'method': 'cash'}})
    assert open_.status_code == 201, open_.text
    taken = post(client, '/buyer-orders', {'new_buyer': {'business_name': 'Hoteli Njema'}, 'ordered_on': TODAY,
        'items': [{'category': 'broilers', 'unit': 'bird', 'quantity': '3', 'unit_price': '10000'}],
        'deposit': {'amount': '10000', 'paid_on': TODAY, 'method': 'mpesa', 'reference': 'QSTAFF1'}}).json()
    done = post(client, f"/buyer-orders/{taken['id']}/deliver", {'buyer_profile_id': taken['buyer_profile_id'],
        'sold_on': TODAY, 'items': [{'category': 'broilers', 'unit': 'bird', 'quantity': '3', 'unit_price': '10000',
        'unit_cost': '7000'}]})
    assert done.status_code == 201, done.text


def payout_attempt_data(client, sessions, seeded):
    """Payout attempts (M2.7) on top of the marketplace data: the first
    order's payout sent but not confirmed (in flight: still owed, not money
    out); a fourth order (2 birds, 18,000) paid, reported not received,
    resent with a second admin's approval and part refunded, all today."""
    from test_payout_attempts import make_second_admin, not_received
    with sessions.begin() as db:
        db.get(m.Listing, seeded['listing']).quantity_total = 20
    marketplace_data(client, sessions, seeded)
    with sessions() as db:
        # The first order's payout: the only one still pending.
        first = db.scalar(select(m.Settlement).where(m.Settlement.status == 'pending'))
    sent = post(client, f'/settlements/{first.id}/attempts', {'amount': '27000', 'payment_reference': 'PO-1-SENT'})
    assert sent.status_code == 201, sent.text
    fourth = app_order(sessions, seeded, 2, 'report-order-4')
    pay_settlement(client, sessions, fourth, 'PO-4A')
    row = settlement_of(sessions, fourth)
    not_received(client, row.id)
    asked = post(client, f'/settlements/{row.id}/approvals', {'amount': '18000', 'reason': 'Never arrived',
        'acknowledge_two_outflows': True}).json()
    second = make_second_admin(sessions)
    assert client.post(API + f"/approvals/{asked['id']}/approve", json={}, headers=second).status_code == 200
    resent = post(client, f'/settlements/{row.id}/attempts', {'amount': '18000', 'payment_reference': 'PO-4B',
        'debited': True, 'evidence': 'Statement', 'approval_id': asked['id']})
    assert resent.status_code == 201, resent.text
    first_attempt = resent.json()['attempts'][1]['id']
    refund = post(client, f'/settlement-transfers/{first_attempt}/refunds', {'amount': '5000', 'refunded_on': TODAY,
        'reference': 'PO-4A-BACK', 'evidence': 'Reversal SMS'})
    assert refund.status_code == 201, refund.text


def deposit_move_data(client, sessions, seeded):
    """7 October 2026: on top of the staff orders, part of the open
    order's 15,000 deposit is given back (5,000 out today) and 4,000 of it
    moved to a second open order of the same buyer (no money moves)."""
    with sessions() as db:
        order = db.scalar(select(m.BuyerOrder).where(m.BuyerOrder.status == 'open'))
        deposit = db.scalar(select(m.BuyerOrderPayment).where(m.BuyerOrderPayment.buyer_order_id == order.id))
    back = post(client, f'/buyer-orders/{order.id}/deposits/{deposit.id}/refund', {'amount': '5000', 'paid_on': TODAY,
        'method': 'cash'})
    assert back.status_code == 201, back.text
    second = post(client, '/buyer-orders', {'buyer_profile_id': order.buyer_profile_id, 'ordered_on': TODAY,
        'items': [{'category': 'local_chicken', 'unit': 'bird', 'quantity': '1', 'unit_price': '20000'}]})
    assert second.status_code == 201, second.text
    moved = post(client, f'/buyer-orders/{order.id}/deposits/{deposit.id}/move', {'to_order_id': second.json()['id'],
        'amount': '4000', 'reason': 'Buyer asked to use it on the next order'})
    assert moved.status_code == 201, moved.text


def payout_resolution_data(client, sessions, seeded):
    """7 October 2026: on top of the payout attempts, the fourth order's
    13,000 possibly paid twice is resolved today with a second admin's
    approval: 8,000 written off (a "Payout loss" expense, no money moves)
    and 5,000 kept by the supplier as payout credit."""
    from test_payout_attempts import make_second_admin
    second = make_second_admin(sessions)
    with sessions() as db:
        row = db.scalar(select(m.Settlement).join(m.SettlementTransfer, m.SettlementTransfer.settlement_id == m.Settlement.id)
            .where(m.SettlementTransfer.attempt_no == 2))
    for kind, amount in (('write_off', '8000'), ('supplier_credit', '5000')):
        asked = post(client, f'/settlements/{row.id}/resolutions/approvals', {'kind': kind, 'amount': amount,
            'evidence': 'Provider statement checked'})
        assert asked.status_code == 201, asked.text
        assert client.post(API + f"/approvals/{asked.json()['id']}/approve", json={}, headers=second).status_code == 200
        done = post(client, f'/settlements/{row.id}/resolutions', {'approval_id': asked.json()['id']})
        assert done.status_code == 201, done.text


DATA = {'direct': (direct_data,), 'marketplace': (marketplace_data,), 'mixed': (direct_data, marketplace_data),
        'staff_orders': (direct_data, staff_order_data), 'payout_attempts': (payout_attempt_data,),
        'deposit_moves': (direct_data, staff_order_data, deposit_move_data),
        'payout_resolutions': (payout_attempt_data, payout_resolution_data)}


def drill(client, metric, **params):
    """Every page of a headline's drilldown: its rows, and its sum."""
    items, page = [], 1
    while True:
        body = get(client, '/finance/rows', metric=metric, page=page, page_size=3, **params)
        items += body['items']
        if page * 3 >= body['total']:
            break
        page += 1
    assert len(items) == body['total']
    keys = [row['key'] for row in items]
    assert len(keys) == len(set(keys)), f'{metric}: a record counted twice'
    assert sum((Decimal(row['amount']) for row in items), Decimal(0)) == Decimal(body['amount'])
    return items, Decimal(body['amount'])


def amount(rows, source=None):
    return sum((Decimal(row['amount']) for row in rows if source is None or row['source'] == source), Decimal(0))


def every_page(client, path, **params):
    items, page = [], 1
    while True:
        body = get(client, path, page=page, page_size=10, **params)
        items += body['items']
        if page * 10 >= body['total']:
            return items
        page += 1


@pytest.mark.parametrize('data', DATA)
def test_every_headline_equals_its_drilldown(client, sessions, seeded, data):
    for build in DATA[data]:
        build(client, sessions, seeded)
    summary = get(client, '/finance/summary')
    profit = get(client, '/finance/profit', start=TODAY, end=TODAY)

    # 1, 4. Owed to me: ledger plus delivered app orders, every page.
    rows, owed = drill(client, 'receivables')
    assert owed == Decimal(summary['owed_to_me']['total'])
    assert amount(rows, 'ledger') == Decimal(summary['owed_to_me']['ledger'])
    assert amount(rows, 'marketplace') == Decimal(summary['owed_to_me']['marketplace'])
    debts = every_page(client, '/ledger/debts', status='owed_to_me')
    assert sum((Decimal(d['balance']) for d in debts), Decimal(0)) == Decimal(summary['owed_to_me']['ledger'])
    assert sum((Decimal(p['balance']) for p in summary['debtors']), Decimal(0)) == owed
    assert Decimal(summary['trends']['owed_to_me'][-1]) == owed
    # 3. Overdue, per direction.
    _late, overdue = drill(client, 'receivables', overdue='true')
    assert overdue == Decimal(summary['owed_to_me']['overdue'])

    # 2, 5. I owe: ledger payables plus pending app payouts.
    rows, owe = drill(client, 'payables')
    assert owe == Decimal(summary['i_owe']['total'])
    assert amount(rows, 'ledger') == Decimal(summary['i_owe']['ledger'])
    assert amount(rows, 'marketplace') == Decimal(summary['i_owe']['marketplace'])
    debts = every_page(client, '/ledger/debts', status='i_owe')
    assert sum((Decimal(d['balance']) for d in debts), Decimal(0)) == Decimal(summary['i_owe']['ledger'])
    assert sum((Decimal(p['balance']) for p in summary['creditors']), Decimal(0)) == owe
    assert Decimal(summary['trends']['i_owe'][-1]) == owe
    payouts = get(client, '/settlements')['totals']
    assert Decimal(payouts['pending']) == Decimal(summary['i_owe']['marketplace'])

    # 17. Supplier payments: registered suppliers' invoices, app payouts beside.
    balances = get(client, '/ledger/supplier-balances', page_size=100)
    registered = [row for row in rows if row['source'] == 'ledger' and row['supplier_id']]
    assert Decimal(balances['summary']['total_owed']) == amount(registered)
    assert Decimal(balances['summary']['settlements_pending']) == amount(rows, 'marketplace')

    # Commitments: undelivered app orders, never inside owed to me or sales.
    rows, pending = drill(client, 'commitments')
    assert pending == Decimal(summary['commitments']['total'])
    assert not {row['source_id'] for row in rows} & {row['order_id'] for row in drill(client, 'receivables')[0]
        if row['source'] == 'marketplace'}

    # 6, 7. Sales today: the same on Finance, Profit and Sales.
    rows, sold = drill(client, 'revenue', start=TODAY, end=TODAY)
    sales_page = get(client, '/sales', start=TODAY, end=TODAY)['summary']
    assert sold == Decimal(summary['today']['sales']) == Decimal(profit['revenue']) == Decimal(sales_page['sales_total'])
    assert amount(rows, 'ledger') == Decimal(profit['sales']) == Decimal(sales_page['direct_total'])
    assert amount(rows, 'marketplace') == Decimal(profit['marketplace_sales']) == Decimal(sales_page['marketplace_total'])
    listed = every_page(client, '/sales', start=TODAY, end=TODAY)
    assert sum((Decimal(row['total_amount']) for row in listed if row['status'] == 'active'), Decimal(0)) \
        == Decimal(sales_page['direct_total'])

    # 13, 15. Cost of goods, dated with its revenue.
    rows, cost = drill(client, 'cost_of_goods', start=TODAY, end=TODAY)
    assert cost == Decimal(profit['cost_of_goods'])
    assert amount(rows, 'ledger') == Decimal(profit['stock_cost'])
    assert amount(rows, 'marketplace') == Decimal(profit['marketplace_cost'])

    # 14, 16. Expenses, stock lost and the operating result.
    spent_rows, spent = drill(client, 'expenses', start=TODAY, end=TODAY)
    assert spent == Decimal(profit['expenses'])
    # The Expenses page lists recorded expenses; a payout written off (7
    # October 2026) is an expense in Profit beside them.
    assert amount([r for r in spent_rows if r['source_table'] == 'ledger_debts']) \
        == Decimal(get(client, '/expenses', start=TODAY, end=TODAY)['summary']['incurred'])
    assert amount([r for r in spent_rows if r['source_table'] == 'settlement_resolutions']) \
        == (Decimal('8000') if data == 'payout_resolutions' else 0)
    _rows, lost = drill(client, 'stock_lost', start=TODAY, end=TODAY)
    assert lost == Decimal(profit['stock_lost'])
    net = sold - cost - spent - lost
    assert net == Decimal(profit['net_profit']) == Decimal(summary['profit_today']['net_profit'])
    assert Decimal(summary['trends']['net_profit'][-1]) == net

    # 8, 12. Money moved today: the cash book's rows, every page.
    book = get(client, '/ledger/payments', start=TODAY, end=TODAY)['summary']
    moved = [row for row in every_page(client, '/ledger/payments', start=TODAY, end=TODAY) if not row['reversed']]
    for flow, field in (('in', 'money_in'), ('out', 'money_out')):
        total = sum((Decimal(row['amount']) for row in moved if row['flow'] == flow), Decimal(0))
        assert total == Decimal(book[field]) == Decimal(summary['today'][field])
    assert sum((Decimal(row['in']) for row in summary['by_method']), Decimal(0)) == Decimal(summary['all_time']['money_in'])
    assert sum((Decimal(row['out']) for row in summary['by_method']), Decimal(0)) == Decimal(summary['all_time']['money_out'])
    # 11. The recorded net cash movement: cash-method rows, all time.
    cash = [row for row in every_page(client, '/ledger/payments', method='cash') if not row['reversed']]
    assert sum((Decimal(row['amount']) * (1 if row['flow'] == 'in' else -1) for row in cash), Decimal(0)) \
        == Decimal(book['recorded_net_cash'])

    expected = {
        'direct': {'owed': '190000', 'owe': '155000', 'sold': '242000', 'cost': '169000', 'in': '102000', 'out': '100000'},
        'marketplace': {'owed': '26000', 'owe': '27000', 'sold': '72000', 'cost': '54000', 'in': '46000', 'out': '27000'},
    }
    expected['mixed'] = {k: str(Decimal(expected['direct'][k]) + Decimal(expected['marketplace'][k])) for k in expected['direct']}
    # Staff orders: the delivered one is a 30,000 sale costing 21,000 with
    # 20,000 still owed; both deposits (15,000 held, 10,000 applied) are in.
    staff = {'owed': '20000', 'owe': '0', 'sold': '30000', 'cost': '21000', 'in': '25000', 'out': '0'}
    expected['staff_orders'] = {k: str(Decimal(expected['direct'][k]) + Decimal(staff[k])) for k in staff}
    # Payout attempts: the fourth order adds 24,000 sold and owed to me and
    # 18,000 cost; its two debited attempts are 36,000 out and the refund
    # 5,000 in. The first order's payout in flight is still owed, not out.
    extra = {'owed': '24000', 'owe': '0', 'sold': '24000', 'cost': '18000', 'in': '5000', 'out': '36000'}
    expected['payout_attempts'] = {k: str(Decimal(expected['marketplace'][k]) + Decimal(extra[k])) for k in extra}
    # Resolving the 13,000 moves no money and changes no balance.
    expected['payout_resolutions'] = expected['payout_attempts']
    # Deposits: 5,000 given back today; the move changes nothing.
    expected['deposit_moves'] = {**expected['staff_orders'], 'out': str(Decimal(expected['staff_orders']['out']) + 5000)}
    if data in ('payout_attempts', 'payout_resolutions'):
        exposure = Decimal('13000') if data == 'payout_attempts' else 0
        assert (Decimal(payouts['in_flight']), Decimal(payouts['disputed'])) == (Decimal('27000'), exposure)
        assert Decimal(summary['i_owe']['payouts_in_flight']) == Decimal('27000')
        assert Decimal(summary['i_owe']['disputed']) == exposure
        assert (Decimal(book['payouts_in_flight']), Decimal(book['disputed_out'])) == (Decimal('27000'), Decimal('18000'))
        assert Decimal(payouts['paid']) == Decimal('27000') + Decimal('31000')
    want = {k: Decimal(v) for k, v in expected[data].items()}
    assert (owed, owe, sold, cost) == (want['owed'], want['owe'], want['sold'], want['cost'])
    assert (Decimal(book['money_in']), Decimal(book['money_out'])) == (want['in'], want['out'])
    assert Decimal(summary['commitments']['total']) == {'direct': 0, 'staff_orders': Decimal('40000'),
        'deposit_moves': Decimal('60000')}.get(data, Decimal('24000'))
    assert Decimal(summary['commitments']['deposits']) == {'staff_orders': Decimal('15000'),
        'deposit_moves': Decimal('10000')}.get(data, 0)
    if data == 'payout_resolutions':
        assert Decimal(summary['i_owe']['payout_credit']) == Decimal('5000')
        assert Decimal(profit['expenses']) - Decimal('8000') == Decimal(get(client, '/expenses', start=TODAY,
            end=TODAY)['summary']['incurred'])


def test_one_event_reached_from_two_records_counts_once(client, sessions, seeded):
    # A transfer over two invoices: one outflow, not two allocations; moving
    # one allocation to credit and back changes nothing.
    first = sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '5', 'unit_price': '12000',
        'supplier_id': seeded['supplier'], 'unit_cost': '9000'}])
    sale(client, new_buyer={'business_name': 'Hotel Bahari'}, items=[{'category': 'broilers', 'unit': 'bird',
        'quantity': '5', 'unit_price': '12000', 'supplier_id': seeded['supplier'], 'unit_cost': '9000'}])
    transfer = post(client, f"/ledger/suppliers/{seeded['supplier']}/payments",
        {'amount': '90000', 'paid_on': TODAY, 'method': 'mpesa', 'reference': 'TR-ONCE'}).json()
    with sessions() as db:
        allocations = db.scalars(select(m.LedgerPayment).where(m.LedgerPayment.supplier_payment_id == transfer['id'])).all()
    assert len(allocations) == 2
    assert post(client, f'/ledger/payments/{allocations[0].id}/reverse', {'reason': 'Wrong invoice'}).status_code == 200
    assert post(client, f"/ledger/suppliers/{seeded['supplier']}/credit/apply", {'amount': '45000'}).status_code == 201
    # A pay-on-delivery order paid in full: a receipt row and the payment's
    # own received amount and date, counted once from the receipt.
    paid = app_order(sessions, seeded, 3, 'once-order-1')
    reconcile(client, paid, '36000', 'RC-ONCE')
    # A pay-now order confirmed by the provider: no receipt rows, the payment
    # itself is the inflow.
    from app.main import apply_provider_confirmation
    from app.payments import ProviderConfirmation
    now = order(sessions, seeded, 2, 'once-order-2')
    with sessions.begin() as db:
        db.get(m.Order, now).payment_method = 'pay_now'
        db.scalar(select(m.Payment).where(m.Payment.order_id == now)).method = 'pay_now'
    with sessions.begin() as db:
        apply_provider_confirmation(db, ProviderConfirmation('MPESA-NOW-1', now, Decimal('24000'), 'paid'), 'provider-once-1')

    book = get(client, '/ledger/payments', start=TODAY, end=TODAY)
    assert Decimal(book['summary']['money_out']) == Decimal('90000')
    assert Decimal(book['summary']['money_in']) == Decimal('36000') + Decimal('24000')
    rows = [row for row in every_page(client, '/ledger/payments') if not row['reversed']]
    assert [row['kind'] for row in rows if row['flow'] == 'out'] == ['transfer']
    assert sorted((row['kind'], row['source']) for row in rows if row['flow'] == 'in') == [
        ('receipt', 'marketplace'), ('receipt', 'marketplace')]
    with sessions() as db:
        assert tr.buckets(db, [transfer['id']])[transfer['id']]['transferred'] == Decimal('90000')
        # The prepaid undelivered order is a deposit inside commitments, never a receivable.
        pending = rp.commitments(db)
        assert pending['deposits'] == Decimal('24000') and pending['unpaid'] == 0
        assert all(row['source'] != 'marketplace' for row in rp.receivables(db)['rows'])
        # Received stock: the delivery note's payable is the only liability
        # and the sale line the only cost, never the note as well.
        note = post(client, f"/suppliers/{seeded['supplier']}/collections", {'batch_id': batch(sessions, seeded, 50),
            'received_on': TODAY, 'delivered_quantity': '10', 'accepted_quantity': '10', 'unit_cost': '6000'}).json()
    sale(client, new_buyer={'business_name': 'Duka'}, items=[{'quantity': '4', 'unit_price': '8000',
        'supplier_collection_id': note['id']}])
    with sessions() as db:
        tables = {row['source_table'] for row in rp.payables(db)['rows']}
        assert 'supplier_collections' not in tables
        cost = rp.cost_of_goods(db, DAY, DAY)
        assert cost['total'] == Decimal('90000') + Decimal('24000') + Decimal('27000')  # + the delivered order's payout
        for metric in rp.METRICS:
            keys = [row['key'] for row in rp.rows_for(db, metric, DAY, DAY)]
            assert len(keys) == len(set(keys)), metric
    # Rows naming the same record are counted once.
    twice = [rp._row('ledger', 'sales', 'x', DAY, Decimal('5')), rp._row('ledger', 'sales', 'x', DAY, Decimal('5'))]
    assert rp.total(rp.dedupe(twice)) == Decimal('5')


def test_app_order_counts_on_its_delivery_date(client, sessions, seeded):
    """D2: ordered in period A, delivered in period B: revenue and cost in B.
    Before delivery it is a commitment, never revenue or owed to Omoterra."""
    ordered, delivered = DAY - timedelta(days=40), DAY - timedelta(days=5)
    id = app_order(sessions, seeded, 4, 'd2-order', deliver=False, created_on=ordered)
    with sessions() as db:
        assert [row['source_id'] for row in rp.commitments(db)['rows']] == [id]
        assert rp.receivables(db)['marketplace'] == 0
        assert rp.revenue(db, ordered, DAY)['marketplace'] == 0
    with sessions.begin() as db:
        row = db.get(m.Order, id)
        for status in STEPS:
            s.advance(db, row, c.Progress(internal_status=status, actual_quantity=3, rejected_quantity=1))
        # M2.5: marked delivered today; stored as the business day it
        # happened (here moved to `delivered`, as if marked then).
        assert row.recognized_on == DAY
        row.recognized_on = delivered
    in_a = get(client, '/finance/profit', start=ordered.isoformat(), end=ordered.isoformat())
    in_b = get(client, '/finance/profit', start=delivered.isoformat(), end=delivered.isoformat())
    assert Decimal(in_a['marketplace_sales']) == 0 and Decimal(in_a['marketplace_cost']) == 0
    assert Decimal(in_b['marketplace_sales']) == Decimal('36000') and Decimal(in_b['marketplace_cost']) == Decimal('27000')
    sales = get(client, '/sales', start=delivered.isoformat(), end=delivered.isoformat())['summary']
    assert Decimal(sales['marketplace_total']) == Decimal('36000') and sales['marketplace_count'] == 1
    summary = get(client, '/finance/summary')
    assert Decimal(summary['owed_to_me']['marketplace']) == Decimal('36000')
    assert Decimal(summary['commitments']['total']) == 0
    # Due dates (finance owner, 5 October): the buyer owes on delivery, so
    # 5 days later it is overdue; the payout is due 7 days after delivery.
    with sessions() as db:
        [owed] = [r for r in rp.receivables(db)['rows'] if r['source'] == 'marketplace']
        assert owed['due_on'] == delivered and owed['overdue'] is True
        payouts = [r for r in rp.payables(db)['rows'] if r['source_table'] == 'settlements']
        assert payouts and all(r['due_on'] == delivered + timedelta(days=7) and not r['overdue'] for r in payouts)
    with sessions.begin() as db:
        row = db.get(m.Order, id)
        row.recognized_on = DAY - timedelta(days=8)
    with sessions() as db:
        assert all(r['overdue'] for r in rp.payables(db)['rows'] if r['source_table'] == 'settlements')
    # A delivered order whose delivery has no date (history too ambiguous
    # to backfill, M2.5) is unresolved: owed now, but in no period's revenue.
    with sessions.begin() as db:
        row = db.get(m.Order, id)
        row.recognized_on = None
    with sessions() as db:
        sold = rp.revenue(db, ordered, DAY)
        assert sold['marketplace'] == 0 and sold['unresolved']['count'] == 1
        assert sold['unresolved']['amount'] == Decimal('36000')
        assert rp.receivables(db)['marketplace'] == Decimal('36000')
        assert rp.cost_of_goods(db, ordered, DAY)['marketplace'] == 0


def test_m1_exit_scenario(client, sessions, seeded):
    """500 declared; 100 received at 6,500; 20 sold at 7,500; one TZS 200,000
    transfer re-allocated once: 20,000 margin, 450,000 payable, 80 birds worth
    520,000, cash out exactly 200,000, transfer total unchanged."""
    declared = batch(sessions, seeded, 500)
    note = post(client, f"/suppliers/{seeded['supplier']}/collections", {'batch_id': declared, 'received_on': TODAY,
        'delivered_quantity': '100', 'accepted_quantity': '100', 'unit_cost': '6500'})
    assert note.status_code == 201, note.text
    note_id = note.json()['id']
    sold = sale(client, items=[{'quantity': '20', 'unit_price': '7500', 'supplier_collection_id': note_id}])
    assert Decimal(sold['margin']) == Decimal('20000')
    transfer = post(client, f"/ledger/suppliers/{seeded['supplier']}/payments",
        {'amount': '200000', 'paid_on': TODAY, 'method': 'bank_transfer', 'reference': 'M1-EXIT'}).json()
    with sessions() as db:
        [allocation] = db.scalars(select(m.LedgerPayment).where(m.LedgerPayment.supplier_payment_id == transfer['id'])).all()
    # Re-allocated once: off the invoice to credit, then onto it again.
    assert post(client, f'/ledger/payments/{allocation.id}/reverse', {'reason': 'Allocated by mistake'}).status_code == 200
    assert post(client, f"/ledger/suppliers/{seeded['supplier']}/credit/apply", {'amount': '200000'}).status_code == 201

    profit = get(client, '/finance/profit', start=TODAY, end=TODAY)
    assert Decimal(profit['gross_profit']) == Decimal('20000')
    statement = get(client, f"/ledger/suppliers/{seeded['supplier']}/statement")
    assert Decimal(statement['owed']) == Decimal('450000') and Decimal(statement['bought']) == Decimal('650000')
    assert Decimal(get(client, '/finance/summary')['i_owe']['total']) == Decimal('450000')
    assert Decimal(statement['transferred']) == Decimal('200000')
    book = get(client, '/ledger/payments', start=TODAY, end=TODAY)['summary']
    assert Decimal(book['money_out']) == Decimal('200000')
    with sessions() as db:
        stock = rp.stock_on_hand(db)
        assert stock['quantity'] == 80 and stock['total'] == Decimal('520000')
        held = tr.buckets(db, [transfer['id']])[transfer['id']]
        assert held['amount'] == held['transferred'] == Decimal('200000') and tr.balanced(held)
        # The declaration is never stock: 400 birds are still the supplier's.
        assert db.get(m.SupplierBatch, declared).available_to_commit == 400


def test_a_disputed_payout_stays_money_out_and_is_shown_beside_it(client, sessions, seeded):
    """Finance owner, 5 October: a payout the supplier says never arrived is
    still money out (R3): since M2.7 a debited attempt never becomes failed,
    only a refund brings money back. The Cash book shows how much of its
    money out is disputed."""
    from test_commerce import headers
    id = app_order(sessions, seeded, 4, 'disputed-payout', delivered_on=DAY)
    pay_settlement(client, sessions, id, 'MP-1')
    amount = settlement_of(sessions, id).total_payable
    book = lambda: get(client, '/ledger/payments', start=DAY.isoformat(), end=DAY.isoformat())['summary']
    before = book()
    assert Decimal(before['money_out']) == amount and Decimal(before['disputed_out']) == 0 and before['disputed_out_count'] == 0
    answer = client.post(f'/api/v1/supplier/payouts/{settlement_of(sessions, id).id}/confirm', headers=headers('supplier'),
        json={'received': False})
    assert answer.status_code == 200, answer.text
    after = book()
    assert Decimal(after['money_out']) == amount
    assert Decimal(after['disputed_out']) == amount and after['disputed_out_count'] == 1