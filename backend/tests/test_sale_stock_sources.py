"""Receipt payment status on sales (build plan M2.4, audit F08).

A sale line that sold received stock shows where the stock came from and
how far the supplier side of that receipt is paid. It is information only:
the receipt's payable belongs to the receipt (R1, M1.6), so paying it, or not,
never changes any of the sale's own figures."""
from decimal import Decimal

from test_batch_sales import batch
from test_cost_states import opening
from test_delivery_losses import receive
from test_finance import API, OPS, TODAY, post, sale
from test_purchasing import draft, issue, marked, receive as receive_lpo  # noqa: F401

SALE_FIGURES = ('total_amount', 'cost_amount', 'margin', 'balance', 'received_amount', 'supplier_balance')


def detail(client, id):
    response = client.get(API + f'/sales/{id}', headers=OPS)
    assert response.status_code == 200, response.text
    return response.json()


def figures(body):
    return {k: body[k] for k in SALE_FIGURES}


def source(client, sale_id, n=0):
    return detail(client, sale_id)['items'][n]['stock_source']


def test_delivery_note_status_follows_its_invoice_and_never_the_sale(client, sessions, seeded):
    note_id = receive(client, seeded, batch(sessions, seeded, 100), 80)
    body = sale(client, items=[{'quantity': '10', 'unit_price': '9000', 'supplier_collection_id': note_id}])
    before = figures(detail(client, body['id']))
    assert Decimal(before['supplier_balance']) == 0
    src = source(client, body['id'])
    assert src['kind'] == 'delivery_note' and src['id'] == note_id and src['number'].startswith('DN-')
    assert src['state'] == 'unpaid' and Decimal(src['balance']) == Decimal('520000')
    [invoice] = src['invoices']
    receipt_debt = invoice['debt_id']
    supplier = seeded['supplier']

    # Part paid by a transfer.
    paid = post(client, f'/ledger/suppliers/{supplier}/payments', {'amount': '200000', 'paid_on': TODAY,
        'method': 'mpesa', 'reference': 'QF08PART', 'debt_ids': [receipt_debt]})
    assert paid.status_code == 201, paid.text
    src = source(client, body['id'])
    assert src['state'] == 'part_paid'
    assert (Decimal(src['paid_amount']), Decimal(src['balance'])) == (Decimal('200000'), Decimal('320000'))
    assert Decimal(src['invoices'][0]['paid_by_transfer']) == Decimal('200000')
    assert figures(detail(client, body['id'])) == before

    # Supplier credit: money they hold from another invoice's payment taken off.
    other = sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '5', 'unit_price': '9000',
        'supplier_id': supplier, 'unit_cost': '6000'}])
    other_debt = next(d for d in other['debts'] if d['direction'] == 'payable')
    moved = post(client, f"/ledger/debts/{other_debt['id']}/payments", {'amount': '30000', 'paid_on': TODAY,
        'method': 'mpesa', 'reference': 'QF08OTHER'})
    assert moved.status_code == 201, moved.text
    allocation = next(p for p in moved.json()['payments'] if not p['reversed'])
    assert post(client, f"/ledger/payments/{allocation['id']}/reverse", {'reason': 'Paid on the wrong invoice'}).status_code == 200
    src = source(client, body['id'])
    assert Decimal(src['supplier_credit']) == Decimal('30000') and src['state'] == 'part_paid'

    # The credit is used on the receipt: paid from credit, no new money.
    used = post(client, f'/ledger/suppliers/{supplier}/credit/apply', {'amount': '30000', 'debt_ids': [receipt_debt]})
    assert used.status_code == 201, used.text
    src = source(client, body['id'])
    assert Decimal(src['invoices'][0]['paid_from_credit']) == Decimal('30000')
    assert Decimal(src['paid_amount']) == Decimal('230000') and Decimal(src['supplier_credit']) == 0

    # Paid in full.
    rest = post(client, f'/ledger/suppliers/{supplier}/payments', {'amount': '290000', 'paid_on': TODAY,
        'method': 'mpesa', 'reference': 'QF08REST', 'debt_ids': [receipt_debt]})
    assert rest.status_code == 201, rest.text
    src = source(client, body['id'])
    assert src['state'] == 'paid' and Decimal(src['balance']) == 0
    # None of it touched the sale.
    assert figures(detail(client, body['id'])) == before


def test_opening_stock_has_no_supplier_invoice(client):
    entry = opening(client)
    assert entry.status_code == 201, entry.text
    body = sale(client, items=[{'quantity': '2', 'unit_price': '9000', 'opening_stock_id': entry.json()['id']}])
    src = source(client, body['id'])
    assert src['kind'] == 'opening_stock' and src['state'] == 'no_invoice' and src['invoices'] == []
    assert src['number'] == entry.json()['receipt_number']


def test_lpo_line_shows_each_receipt_invoice(client, seeded, marked):  # noqa: F811
    lpo = issue(client, draft(client, seeded))
    assert receive_lpo(client, lpo, '20', '20').status_code == 201
    lpo = receive_lpo(client, lpo, '10', '10').json()
    line = lpo['lines'][0]['id']
    body = sale(client, items=[{'quantity': '3', 'unit_price': '9000', 'lpo_line_id': line}])
    before = figures(detail(client, body['id']))
    src = source(client, body['id'])
    assert src['kind'] == 'lpo' and src['lpo_id'] == lpo['id'] and src['number'] == lpo['lpo_number']
    assert len(src['invoices']) == 2 and src['state'] == 'unpaid'
    first = src['invoices'][0]
    assert post(client, f"/ledger/debts/{first['debt_id']}/payments", {'amount': first['amount'], 'paid_on': TODAY,
        'method': 'bank_transfer', 'reference': 'LPO-PAY-1'}).status_code == 201
    src = source(client, body['id'])
    assert src['state'] == 'part_paid' and [i['status'] for i in src['invoices']] == ['settled', 'open']
    assert figures(detail(client, body['id'])) == before


def test_a_line_not_from_received_stock_has_no_source(client, seeded):
    body = sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '1', 'unit_price': '9000',
        'supplier_id': seeded['supplier'], 'unit_cost': '6000'}])
    assert source(client, body['id']) is None
