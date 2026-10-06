"""Money accounts and reconciliation (build plan M2.3, audit F05, decision D6).

Each account's balance is its verified opening balance at the cutoff plus
the money assigned to it after the cutoff. Transfers between accounts net
to zero; a count or statement that differs is an exception, never an
adjustment; unassigned money never changes an account's balance; and money
dated on or before the cutoff is inside the opening balance."""
from datetime import timedelta
from decimal import Decimal

from sqlalchemy import select

from app import classify_accounts as ca, contracts as c, finance_exceptions as fx, models as m
from test_finance import API, OPS, STAFF, post, receivable, sale

DAY = c.business_today()
D = {n: DAY - timedelta(days=n) for n in range(10)}
CUTOFF = D[5]


def get(client, path, **params):
    response = client.get(API + path, params=params, headers=OPS)
    assert response.status_code == 200, response.text
    return response.json()


def account(client, name, kind='cash', opening='100000', headers=OPS, **extra):
    return post(client, '/accounts', {'name': name, 'kind': kind, 'cutoff_on': CUTOFF.isoformat(), 'opening_balance': opening,
        'opening_evidence': 'Counted on the cutoff day by two staff', 'verified_by': 'Maternus Joshua', **extra}, headers)


def owed(client, amount='50000'):
    body = sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '1', 'unit_price': amount,
        'unit_cost': '1000'}])
    return receivable(body)['id']


def pay(client, debt_id, amount, on=DAY, **extra):
    return post(client, f'/ledger/debts/{debt_id}/payments', {'amount': amount, 'paid_on': on.isoformat(),
        'method': 'cash', **extra})


def balance(client, account_id):
    return Decimal(get(client, f'/accounts/{account_id}')['balance'])


def sections(engine):
    return {s['key']: s for s in fx.build_report(engine)['sections']}


def test_setting_up_accounts_then_every_new_entry_names_one(client):
    debt = owed(client)
    # Before any account exists, money is recorded and stays unassigned.
    assert pay(client, debt, '1000').status_code == 201
    assert account(client, 'Petty cash', headers=STAFF).status_code == 403
    box = account(client, 'Petty cash').json()
    assert Decimal(box['balance']) == Decimal('100000') and box['cutoff_on'] == CUTOFF.isoformat()
    assert account(client, 'petty cash').status_code == 409
    # Now a new payment must say which account.
    refused = pay(client, debt, '2000')
    assert refused.status_code == 422 and 'account' in refused.json()['detail']
    assert pay(client, debt, '2000', money_account_id=box['id']).status_code == 201
    assert balance(client, box['id']) == Decimal('102000')
    book = get(client, '/ledger/payments')
    names = {Decimal(r['amount']): r['account_name'] for r in book['items']}
    assert names == {Decimal('1000'): None, Decimal('2000'): 'Petty cash'}
    assert book['summary']['unassigned_count'] == 1 and Decimal(book['summary']['unassigned_in']) == Decimal('1000')
    only = get(client, '/ledger/payments', account=box['id'])['items']
    assert [Decimal(r['amount']) for r in only] == [Decimal('2000')]


def test_an_internal_transfer_nets_to_zero_and_its_fee_is_an_expense(client):
    box = account(client, 'Petty cash').json()
    bank = account(client, 'CRDB bank', kind='bank', opening='500000', number='0150 1234 5678').json()
    before = get(client, '/ledger/payments')['summary']
    moved = post(client, '/accounts/transfers', {'from_account_id': bank['id'], 'to_account_id': box['id'],
        'amount': '50000', 'transferred_on': DAY.isoformat(), 'fee': '1500', 'reference': 'WD-778'})
    assert moved.status_code == 201, moved.text
    assert balance(client, box['id']) == Decimal('150000')
    assert balance(client, bank['id']) == Decimal('448500')
    after = get(client, '/ledger/payments')['summary']
    # Only the fee is money leaving the business; the transfer itself is not.
    assert Decimal(after['money_in']) == Decimal(before['money_in'])
    assert Decimal(after['money_out']) - Decimal(before['money_out']) == Decimal('1500')
    profit = get(client, '/finance/profit', start=DAY.isoformat(), end=DAY.isoformat())
    assert Decimal(profit['expenses']) == Decimal('1500')
    listed = get(client, '/accounts')
    assert Decimal(listed['total']) == Decimal('598500')
    # The bank's statement: newest first, with the balance after each line.
    lines = get(client, f"/accounts/{bank['id']}")['movements']['items']
    assert [(r['kind'], r['flow'], Decimal(r['amount']), Decimal(r['balance'])) for r in lines] == [
        ('fee', 'out', Decimal('1500'), Decimal('448500')), ('account_transfer', 'out', Decimal('50000'), Decimal('450000'))]
    # Into the opening balance's period, a transfer is refused.
    early = post(client, '/accounts/transfers', {'from_account_id': bank['id'], 'to_account_id': box['id'],
        'amount': '1', 'transferred_on': CUTOFF.isoformat()})
    assert early.status_code == 422


def test_a_count_difference_is_an_exception_never_an_adjustment(client, engine):
    box = account(client, 'Petty cash').json()
    debt = owed(client)
    assert pay(client, debt, '20000', money_account_id=box['id']).status_code == 201
    checked = post(client, f"/accounts/{box['id']}/checks", {'kind': 'count', 'checked_on': DAY.isoformat(),
        'balance': '118000', 'evidence': 'Cash box counted by Asha and Juma at close'})
    assert checked.status_code == 201, checked.text
    body = checked.json()
    assert (Decimal(body['expected']), Decimal(body['difference'])) == (Decimal('120000'), Decimal('-2000'))
    # The balance is still what the records say.
    assert balance(client, box['id']) == Decimal('120000')
    [row] = sections(engine)['account_differences']['records']
    assert row['difference'] == Decimal('-2000.00')
    view = get(client, '/accounts')['items'][0]
    assert view['open_differences'] == 1 and view['reconciled_through'] is None
    assert post(client, f"/account-checks/{body['id']}/resolve", {'reason': 'Bus fare paid from the box'}, STAFF).status_code == 403
    assert post(client, f"/account-checks/{body['id']}/resolve", {'reason': 'Bus fare paid from the box'}).status_code == 200
    assert sections(engine)['account_differences']['count'] == 0
    assert balance(client, box['id']) == Decimal('120000')
    # A matching count marks the account reconciled through that day.
    post(client, f"/accounts/{box['id']}/checks", {'kind': 'count', 'checked_on': DAY.isoformat(), 'balance': '120000',
        'evidence': 'Recounted after entering the fare'})
    assert get(client, '/accounts')['items'][0]['reconciled_through'] == DAY.isoformat()


def test_unassigned_money_never_changes_a_reconciled_balance(client, engine):
    debt = owed(client)
    assert pay(client, debt, '7000', on=D[2]).status_code == 201
    box = account(client, 'Petty cash').json()
    assert balance(client, box['id']) == Decimal('100000')
    unassigned = get(client, '/accounts/unassigned')
    [row] = unassigned['items']
    assert Decimal(row['amount']) == Decimal('7000') and unassigned['summary']['count'] == 1
    assert sections(engine)['unassigned_money']['count'] == 1
    # Assigned with evidence, it counts: it is dated after the cutoff.
    body = {'source_table': row['source_table'], 'source_id': row['id'], 'account_id': box['id'],
        'evidence': 'Cash book page 14, receipt 0031'}
    assert post(client, '/accounts/assign', body, STAFF).status_code == 403
    assert post(client, '/accounts/assign', {**body, 'evidence': ''}).status_code == 422
    assert post(client, '/accounts/assign', body).status_code == 201
    assert post(client, '/accounts/assign', body).status_code == 409
    assert balance(client, box['id']) == Decimal('107000')
    assert sections(engine)['unassigned_money']['count'] == 0


def test_money_dated_before_the_cutoff_is_inside_the_opening_balance(client, engine):
    debt = owed(client)
    assert pay(client, debt, '3000', on=D[7]).status_code == 201  # history, before accounts
    box = account(client, 'Petty cash').json()
    row = get(client, '/accounts/unassigned')['items'][0]
    post(client, '/accounts/assign', {'source_table': row['source_table'], 'source_id': row['id'], 'account_id': box['id'],
        'evidence': 'Cash book page 9'})
    # Before the cutoff: history, not counted again, not an exception.
    assert balance(client, box['id']) == Decimal('100000')
    assert sections(engine)['pre_cutoff_adjustments']['count'] == 0
    # Entered now but dated before the cutoff: an exception until explained.
    assert pay(client, debt, '4000', on=D[6], money_account_id=box['id']).status_code == 201
    assert balance(client, box['id']) == Decimal('100000')
    [late] = sections(engine)['pre_cutoff_adjustments']['records']
    assert late['amount'] == Decimal('4000.00')
    path = f"/account-assignments/{late['assignment_id']}/pre-cutoff"
    restated = post(client, path, {'resolution': 'restated', 'note': 'Missed in the cutoff count; receipt 0029'})
    assert restated.status_code == 200, restated.text
    assert Decimal(restated.json()['balance']) == Decimal('104000')
    assert post(client, path, {'resolution': 'inside_opening', 'note': 'again'}).status_code == 409
    assert sections(engine)['pre_cutoff_adjustments']['count'] == 0


def test_the_dry_run_proposes_only_from_evidence_and_apply_assigns_one(client, sessions, engine):
    debt = owed(client, '90000')
    assert pay(client, debt, '5000', method='mpesa', reference='QX12AB34CD').status_code == 201
    assert pay(client, debt, '6000').status_code == 201  # cash, no evidence
    assert pay(client, debt, '7000', method='bank_transfer', reference='Dep slip 12345678').status_code == 201
    wallet = account(client, 'M-Pesa till', kind='mobile_wallet', provider='M-Pesa').json()
    bank = account(client, 'CRDB bank', kind='bank', number='12345678').json()
    with sessions() as db:
        report = ca.dry_run(db)
    proposed = {Decimal(r['amount']): r['account_id'] for r in report['proposed']}
    assert proposed == {Decimal('5000'): wallet['id'], Decimal('7000'): bank['id']}
    assert [Decimal(r['amount']) for r in report['unresolved']] == [Decimal('6000')]
    item = next(r['item'] for r in report['proposed'] if r['account_id'] == wallet['id'])
    assert ca.main(['--apply', item, '--account', wallet['id'], '--evidence', 'M-Pesa statement line',
        '--by', 'Maternus Joshua', '--confirm', item], bind=engine) == 0
    assert balance(client, wallet['id']) == Decimal('105000')
    with sessions() as db:
        assert db.scalar(select(m.AccountAssignment.how).where(m.AccountAssignment.account_id == wallet['id'])) == 'historical'
    assert ca.main(['--apply', item, '--account', wallet['id'], '--evidence', 'again', '--by', 'Maternus Joshua',
        '--confirm', item], bind=engine) == 2
