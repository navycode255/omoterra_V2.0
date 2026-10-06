"""One customer payment, entered once, pays their oldest debts first.

The cash book shows it as one movement of money; each debt it reached shows
its own part, so balances stay right debt by debt."""
from datetime import timedelta
from decimal import Decimal

from app import contracts as c
from test_finance import API, OPS, post

DAY = c.business_today()
PHONE = '0754 222 333'


def get(client, path, **params):
    response = client.get(API + path, params=params, headers=OPS)
    assert response.status_code == 200, response.text
    return response.json()


def owe(client, amount, days_ago, phone=PHONE, name='Mama Neema'):
    response = post(client, '/sales', {'new_buyer': {'business_name': name, 'phone': phone},
        'sold_on': (DAY - timedelta(days=days_ago)).isoformat(),
        'items': [{'category': 'local_chicken', 'unit': 'bird', 'quantity': '1', 'unit_price': amount, 'cost_unknown': True}]})
    assert response.status_code == 201, response.text
    body = response.json()
    return body['buyer_profile_id'], next(d['id'] for d in body['debts'] if d['direction'] == 'receivable')


def receive(client, buyer, amount, idem=None, **extra):
    return post(client, f'/ledger/buyers/{buyer}/payments',
        {'amount': amount, 'paid_on': DAY.isoformat(), 'method': 'mpesa', **extra}, idem=idem)


def debt(client, id):
    return get(client, f'/ledger/debts/{id}')


def test_one_payment_pays_the_oldest_debt_first_and_is_one_cash_book_row(client):
    buyer, newest = owe(client, '20000', 1)
    _, oldest = owe(client, '20000', 3)
    _, middle = owe(client, '20000', 2)
    listed = get(client, f'/ledger/buyers/{buyer}/open-debts')
    assert [d['id'] for d in listed['debts']] == [oldest, middle, newest]
    assert Decimal(listed['balance']) == Decimal('60000')

    paid = receive(client, buyer, '35000', reference='QK7A1')
    assert paid.status_code == 201, paid.text
    parts = {a['debt_id']: Decimal(a['amount']) for a in paid.json()['allocations']}
    assert parts == {oldest: Decimal('20000'), middle: Decimal('15000')}

    assert debt(client, oldest)['status'] == 'settled'
    assert Decimal(debt(client, middle)['balance']) == Decimal('5000')
    assert Decimal(debt(client, newest)['balance']) == Decimal('20000')
    group = paid.json()['id']
    assert debt(client, middle)['payments'][0]['buyer_payment_id'] == group

    rows = get(client, '/ledger/payments')['items']
    assert len(rows) == 1
    row = rows[0]
    assert row['kind'] == 'buyer_payment' and row['flow'] == 'in' and row['invoices'] == 2
    assert Decimal(row['amount']) == Decimal('35000') and row['reference'] == 'QK7A1'
    assert row['debt_id'] == oldest and row['party_name'] == 'Mama Neema'
    assert Decimal(get(client, '/ledger/payments')['summary']['money_in']) == Decimal('35000')


def test_customer_list_shows_who_owes_largest_first(client):
    small, _ = owe(client, '5000', 1, phone='0754 999 000', name='Small Shop')
    big, _ = owe(client, '30000', 1)
    owe(client, '10000', 2)
    items = get(client, '/ledger/buyer-balances')['items']
    assert [(i['id'], Decimal(i['balance']), i['debts']) for i in items] == [
        (big, Decimal('40000'), 2), (small, Decimal('5000'), 1)]
    receive(client, small, '5000')
    assert [i['id'] for i in get(client, '/ledger/buyer-balances')['items']] == [big]


def test_more_than_owed_is_refused_and_a_retry_records_once(client):
    buyer, first = owe(client, '20000', 2)
    _, second = owe(client, '10000', 1)
    over = receive(client, buyer, '30000.01')
    assert over.status_code == 422 and '30,000.00' in over.json()['detail']
    key = 'buyer-payment-retry'
    assert receive(client, buyer, '25000', idem=key).status_code == 201
    again = receive(client, buyer, '25000', idem=key)
    assert again.status_code == 201
    assert Decimal(debt(client, second)['balance']) == Decimal('5000')
    assert len(get(client, '/ledger/payments')['items']) == 1


def test_same_reference_twice_is_refused(client):
    buyer, _ = owe(client, '20000', 1)
    assert receive(client, buyer, '1000', reference='QX9').status_code == 201
    assert receive(client, buyer, '1000', reference='QX9').status_code == 409


def test_reversing_one_part_lowers_the_payment_and_reopens_that_debt(client):
    buyer, first = owe(client, '20000', 2)
    _, second = owe(client, '20000', 1)
    receive(client, buyer, '30000')
    part = debt(client, second)['payments'][0]
    reversed_ = client.post(f"{API}/ledger/payments/{part['id']}/reverse", json={'reason': 'Typed the wrong amount'},
        headers={**OPS, 'Idempotency-Key': 'reverse-part'})
    assert reversed_.status_code == 200, reversed_.text
    assert Decimal(debt(client, second)['balance']) == Decimal('20000')
    book = get(client, '/ledger/payments')
    live = [r for r in book['items'] if not r['reversed']]
    assert len(live) == 1 and Decimal(live[0]['amount']) == Decimal('20000')
    assert any(r['reversed'] and r['id'] == part['id'] for r in book['items'])
    assert Decimal(book['summary']['money_in']) == Decimal('20000')


def test_the_payment_goes_through_one_money_account(client):
    from test_accounts import account, balance
    buyer, _ = owe(client, '20000', 2)
    owe(client, '20000', 1)
    box = account(client, 'Till').json()
    assert receive(client, buyer, '25000').status_code == 422
    assert receive(client, buyer, '25000', money_account_id=box['id']).status_code == 201
    assert balance(client, box['id']) == Decimal('125000')
    row = get(client, '/ledger/payments')['items'][0]
    assert row['account_id'] == box['id']
