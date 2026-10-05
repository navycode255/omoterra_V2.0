"""M1.2 (audit F04): money moved versus money allocated.

A supplier transfer is the only record that money left; allocations spread it
over invoices. Taking an allocation off an invoice makes supplier credit on the
same transfer, never a refund. For every transfer, after every action:
allocated + credit + refunded + entry error + unresolved = amount.
"""
import shutil
import threading
from datetime import date, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app import classify_transfers as ct, finance_exceptions as fx, models as m, transfers as tr
from test_finance import API, OPS, STAFF, TODAY, key, pay, post, sale

YESTERDAY = (date.fromisoformat(TODAY) - timedelta(days=1)).isoformat()


@pytest.fixture(autouse=True)
def always_balanced(request):
    """Every test here ends with every transfer adding up."""
    sessions = request.getfixturevalue('sessions') if 'sessions' in request.fixturenames else None
    yield
    if sessions is not None:
        with sessions() as db:
            for transfer_id, row in tr.buckets(db).items():
                assert tr.balanced(row), (transfer_id, row)


def balanced(sessions):
    with sessions() as db:
        rows = tr.buckets(db)
        assert rows and all(tr.balanced(row) for row in rows.values()), rows
        return rows


def invoices(client, seeded, *costs):
    """One sale per cost, each opening a payable to the registered supplier."""
    debts = []
    for cost in costs:
        body = sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '1', 'unit_price': str(cost + 1000),
            'supplier_id': seeded['supplier'], 'unit_cost': str(cost)}])
        debts.append(next(d for d in body['debts'] if d['direction'] == 'payable'))
    return debts


def transfer(client, seeded, amount, debt_ids=(), **extra):
    response = post(client, f"/ledger/suppliers/{seeded['supplier']}/payments", {
        'amount': str(amount), 'paid_on': TODAY, 'method': 'bank_transfer', 'reference': f'BANK-{key()}',
        'debt_ids': list(debt_ids), **extra})
    assert response.status_code == 201, response.text
    return response.json()


def cash(client):
    return {k: Decimal(v) for k, v in client.get(API + '/ledger/payments', headers=OPS).json()['summary'].items()}


def statement(client, seeded):
    return client.get(API + f"/ledger/suppliers/{seeded['supplier']}/statement", headers=OPS).json()


def debt(client, id):
    return client.get(API + f'/ledger/debts/{id}', headers=OPS).json()


def allocation_on(client, debt_id):
    return next(p for p in debt(client, debt_id)['payments'] if not p['reversed'])


def test_every_supplier_payment_is_a_transfer(client, seeded, sessions):
    first, second = invoices(client, seeded, 30000, 20000)
    assert pay(client, first['id'], '10000', reference='CASH-SLIP-1').status_code == 201
    with_cost = sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '2', 'unit_price': '9000',
        'supplier_id': seeded['supplier'], 'unit_cost': '6000', 'cost_payment': {'paid_on': TODAY, 'method': 'cash'}}])
    paid_with_sale = next(d for d in with_cost['debts'] if d['direction'] == 'payable')
    assert Decimal(paid_with_sale['paid_amount']) == Decimal('12000')
    with sessions() as db:
        rows = db.scalars(select(m.SupplierPayment).order_by(m.SupplierPayment.created_at)).all()
        assert [(r.origin, r.amount) for r in rows] == [('single', Decimal('10000')), ('single', Decimal('12000'))]
        assert db.scalar(select(m.LedgerPayment.id).where(m.LedgerPayment.supplier_payment_id.is_(None))) is None
    # Payments to other parties (and buyers) are not supplier transfers.
    other = sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '1', 'unit_price': '9000',
        'supplier_name': 'Tegeta Sokoni', 'unit_cost': '6000'}], payment={'amount': '9000', 'paid_on': TODAY, 'method': 'cash'})
    payable = next(d for d in other['debts'] if d['direction'] == 'payable')
    assert pay(client, payable['id'], '6000').status_code == 201
    with sessions() as db:
        assert db.scalar(select(m.SupplierPayment.id).where(m.SupplierPayment.amount == 6000)) is None
    totals = cash(client)
    assert totals['money_out'] == Decimal('28000') and totals['money_in'] == Decimal('9000')
    assert second['status'] == 'open'


def test_reversal_moves_money_to_supplier_credit_and_cash_is_unchanged(client, seeded, sessions):
    first, second = invoices(client, seeded, 60000, 40000)
    sent = transfer(client, seeded, 100000)
    before = cash(client)
    assert before['money_out'] == Decimal('100000')
    allocation = allocation_on(client, second['id'])
    assert allocation['supplier_payment_id'] == sent['id']

    assert post(client, f"/ledger/payments/{allocation['id']}/reverse", {'reason': 'Wrong invoice'}, STAFF).status_code == 403
    moved = post(client, f"/ledger/payments/{allocation['id']}/reverse", {'reason': 'Wrong invoice'})
    assert moved.status_code == 200, moved.text
    assert moved.json()['status'] == 'open' and Decimal(moved.json()['balance']) == Decimal('40000')
    assert moved.json()['payments'][0]['moved_to_credit'] is True

    assert cash(client) == before  # the money left once and is still out
    rows = balanced(sessions)
    assert rows[sent['id']]['credit'] == Decimal('40000') and rows[sent['id']]['allocated'] == Decimal('60000')
    body = statement(client, seeded)
    assert Decimal(body['transferred']) == Decimal('100000') and Decimal(body['credit']) == Decimal('40000')
    assert Decimal(body['owed']) == Decimal('40000') and Decimal(body['unresolved']) == 0
    balances = client.get(API + '/ledger/supplier-balances', headers=OPS).json()
    assert Decimal(balances['items'][0]['credit']) == Decimal('40000') and Decimal(balances['summary']['credit']) == Decimal('40000')
    portal = client.get('/api/v1/supplier/invoices', headers={'Authorization': 'Bearer supplier'}).json()
    assert Decimal(portal['credit_total']) == Decimal('40000')
    book = client.get(API + '/ledger/payments?status=reversed', headers=OPS).json()
    assert book['total'] == 1 and book['items'][0]['moved_to_credit'] is True


def test_reallocating_credit_moves_no_money(client, seeded, sessions):
    first, second = invoices(client, seeded, 60000, 40000)
    sent = transfer(client, seeded, 60000, [first['id']])
    assert post(client, f"/ledger/payments/{allocation_on(client, first['id'])['id']}/reverse", {'reason': 'Paid the wrong order'}).status_code == 200
    before = cash(client)
    # Credit goes to an invoice of the same supplier only.
    too_much = post(client, f"/ledger/suppliers/{seeded['supplier']}/credit/apply", {'amount': '60001', 'debt_ids': [second['id'], first['id']]})
    assert too_much.status_code == 422
    applied = post(client, f"/ledger/suppliers/{seeded['supplier']}/credit/apply", {'amount': '40000', 'debt_ids': [second['id']]}, STAFF)
    assert applied.status_code == 201, applied.text
    assert Decimal(applied.json()['credit']) == Decimal('20000')
    assert debt(client, second['id'])['status'] == 'settled'
    assert cash(client) == before
    rows = balanced(sessions)
    assert rows[sent['id']]['amount'] == Decimal('60000')
    assert rows[sent['id']]['allocated'] == Decimal('40000') and rows[sent['id']]['credit'] == Decimal('20000')
    with sessions() as db:
        assert db.scalar(select(m.TransferEvent.kind).where(m.TransferEvent.kind == 'reallocation')) == 'reallocation'
        assert db.scalar(select(m.SupplierPayment.id).where(m.SupplierPayment.id != sent['id'])) is None


def test_credit_cannot_cross_suppliers(client, seeded, sessions):
    [mine] = invoices(client, seeded, 30000)
    transfer(client, seeded, 30000)
    assert post(client, f"/ledger/payments/{allocation_on(client, mine['id'])['id']}/reverse", {'reason': 'Wrong'}).status_code == 200
    with sessions.begin() as db:
        other = m.User(phone='+255712345699', roles=['supplier'], name='Other Farm')
        db.add(other); db.flush()
        db.add(m.SupplierProfile(user_id=other.id, legal_name='Other Farm', internal_pickup_address='x'))
        db.add(m.LedgerDebt(direction='payable', party_kind='supplier', supplier_id=other.id, party_name='Other Farm',
            amount=10000, incurred_on=date.fromisoformat(TODAY), source='manual'))
        other_id = other.id
        other_debt = db.scalar(select(m.LedgerDebt.id).where(m.LedgerDebt.supplier_id == other.id))
    # Their invoice is not one of this supplier's, and they hold no credit.
    assert post(client, f"/ledger/suppliers/{seeded['supplier']}/credit/apply", {'amount': '1000', 'debt_ids': [other_debt]}).status_code == 422
    assert post(client, f"/ledger/suppliers/{other_id}/credit/apply", {'amount': '1000'}).status_code == 422


def test_refund_is_a_separate_inflow_partial_allowed_never_more_than_credit(client, seeded, sessions):
    first, second = invoices(client, seeded, 60000, 40000)
    sent = transfer(client, seeded, 100000)
    assert post(client, f"/ledger/payments/{allocation_on(client, second['id'])['id']}/reverse", {'reason': 'Order cancelled'}).status_code == 200
    before = cash(client)
    refund = {'amount': '15000', 'received_on': TODAY, 'method': 'mpesa', 'reference': 'MP-REFUND-1'}
    assert post(client, f"/ledger/transfers/{sent['id']}/refunds", refund, STAFF).status_code == 403
    assert post(client, f"/ledger/transfers/{sent['id']}/refunds", {**refund, 'reference': ''}).status_code == 422
    assert post(client, f"/ledger/transfers/{sent['id']}/refunds", {**refund, 'amount': '100001'}).status_code == 422
    assert post(client, f"/ledger/transfers/{sent['id']}/refunds", {**refund, 'amount': '40001'}).status_code == 422
    early = (date.fromisoformat(TODAY) - timedelta(days=3)).isoformat()
    assert post(client, f"/ledger/transfers/{sent['id']}/refunds", {**refund, 'received_on': early}).status_code == 422
    done = post(client, f"/ledger/transfers/{sent['id']}/refunds", refund)
    assert done.status_code == 201, done.text
    assert Decimal(done.json()['refunded']) == Decimal('15000') and Decimal(done.json()['credit']) == Decimal('25000')
    assert Decimal(done.json()['amount']) == Decimal('100000')  # the transfer is never reduced (R3)
    after = cash(client)
    assert after['money_out'] == before['money_out'] == Decimal('100000')
    assert after['money_in'] == before['money_in'] + Decimal('15000')
    # A second partial refund, then nothing more than the credit left.
    assert post(client, f"/ledger/transfers/{sent['id']}/refunds", {**refund, 'amount': '25000', 'reference': 'MP-REFUND-2'}).status_code == 201
    assert post(client, f"/ledger/transfers/{sent['id']}/refunds", {**refund, 'amount': '1', 'reference': 'MP-REFUND-3'}).status_code == 422
    rows = balanced(sessions)
    assert rows[sent['id']]['refunded'] == Decimal('40000') and rows[sent['id']]['net_paid'] == Decimal('60000')
    book = client.get(API + '/ledger/payments?status=in', headers=OPS).json()
    assert {row['kind'] for row in book['items']} == {'refund'} and book['total'] == 2
    assert Decimal(statement(client, seeded)['refunded']) == Decimal('40000')


def test_entry_error_is_admin_only_and_reduces_money_out(client, seeded, sessions):
    [only] = invoices(client, seeded, 50000)
    sent = transfer(client, seeded, 50000)
    assert post(client, f"/ledger/payments/{allocation_on(client, only['id'])['id']}/reverse", {'reason': 'Typed 50,000; sent 45,000'}).status_code == 200
    body = {'amount': '5000', 'reason': 'Typed 50,000; sent 45,000', 'evidence': 'Bank statement line 3 Oct: 45,000'}
    assert post(client, f"/ledger/transfers/{sent['id']}/entry-error", body, STAFF).status_code == 403
    assert post(client, f"/ledger/transfers/{sent['id']}/entry-error", {**body, 'amount': '50001'}).status_code == 422
    assert post(client, f"/ledger/transfers/{sent['id']}/entry-error", body).status_code == 201
    assert cash(client)['money_out'] == Decimal('45000')
    assert post(client, f"/ledger/suppliers/{seeded['supplier']}/credit/apply", {'amount': '45000'}).status_code == 201
    rows = balanced(sessions)
    assert rows[sent['id']]['entry_error'] == Decimal('5000') and rows[sent['id']]['allocated'] == Decimal('45000')
    assert debt(client, only['id'])['balance'] == '5000.00'


def test_pay_supplier_uses_credit_first_and_only_new_money_is_a_transfer(client, seeded, sessions):
    first, second, third = invoices(client, seeded, 30000, 50000, 20000)
    sent = transfer(client, seeded, 30000, [first['id']])
    assert post(client, f"/ledger/payments/{allocation_on(client, first['id'])['id']}/reverse", {'reason': 'Birds returned'}).status_code == 200
    out_before = cash(client)['money_out']
    # 30,000 credit + 20,000 new money settle the 50,000 invoice.
    too_much = post(client, f"/ledger/suppliers/{seeded['supplier']}/payments", {
        'amount': '20000', 'paid_on': TODAY, 'method': 'mpesa', 'reference': 'MP-NEW-1', 'use_credit': '30001',
        'debt_ids': [second['id'], third['id']]})
    assert too_much.status_code == 422
    paid = transfer(client, seeded, 20000, [second['id']], use_credit='30000')
    assert Decimal(paid['credit_used']) == Decimal('30000') and Decimal(paid['amount']) == Decimal('20000')
    assert debt(client, second['id'])['status'] == 'settled'
    assert cash(client)['money_out'] == out_before + Decimal('20000')
    rows = balanced(sessions)
    assert rows[sent['id']]['credit'] == 0 and rows[sent['id']]['allocated'] == Decimal('30000')
    assert rows[paid['id']]['amount'] == Decimal('20000')
    with sessions() as db:
        assert db.scalar(select(func.count()).select_from(m.SupplierPayment)) == 2


def test_two_identical_pay_requests_and_a_retry_create_one_transfer(client, seeded, sessions):
    first, second = invoices(client, seeded, 30000, 30000)
    body = {'amount': '30000', 'paid_on': TODAY, 'method': 'mpesa', 'reference': 'MP-ONCE', 'debt_ids': [first['id'], second['id']]}
    idem = key()
    results = []

    def send():
        results.append(post(client, f"/ledger/suppliers/{seeded['supplier']}/payments", body, idem=idem))

    threads = [threading.Thread(target=send) for _ in range(2)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    assert [r.status_code for r in results] == [201, 201]
    assert results[0].json()['id'] == results[1].json()['id']
    # The answer was lost (a timeout): the same request is sent again later.
    retry = post(client, f"/ledger/suppliers/{seeded['supplier']}/payments", body, idem=idem)
    assert retry.status_code == 201 and retry.json()['id'] == results[0].json()['id']
    with sessions() as db:
        assert db.scalar(select(m.SupplierPayment.id).where(m.SupplierPayment.id != results[0].json()['id'])) is None
        assert sum(r.amount for r in db.scalars(select(m.LedgerPayment))) == Decimal('30000')
    assert cash(client)['money_out'] == Decimal('30000')
    # The same idempotency key with a different amount is refused, not a second transfer.
    assert post(client, f"/ledger/suppliers/{seeded['supplier']}/payments", {**body, 'amount': '1000'}, idem=idem).status_code == 409


def _legacy_reversal(sessions, seeded, amount=650000, reversed_amount=19500):
    """Production before M1.2: one transfer allocated over invoices, one
    allocation reversed with no transfer event (as Antonia's 27 Sep transfer)."""
    supplier = seeded['supplier']
    day = date.fromisoformat(TODAY) - timedelta(days=6)
    with sessions.begin() as db:
        kept = m.LedgerDebt(direction='payable', party_kind='supplier', supplier_id=supplier, party_name='Antonia',
            amount=amount - reversed_amount, paid_amount=amount - reversed_amount, status='settled', incurred_on=day,
            source='manual')
        freebies = m.LedgerDebt(direction='payable', party_kind='supplier', supplier_id=supplier, party_name='Antonia',
            amount=reversed_amount, incurred_on=day, source='manual', status='cancelled', cancel_reason='Sale edited')
        db.add_all([kept, freebies]); db.flush()
        sent = m.SupplierPayment(supplier_id=supplier, amount=amount, paid_on=day, method='bank_transfer', reference='BANK-27SEP')
        db.add(sent); db.flush()
        db.add(m.LedgerPayment(debt_id=kept.id, supplier_payment_id=sent.id, amount=amount - reversed_amount, paid_on=day,
            method='bank_transfer'))
        wrong = m.LedgerPayment(debt_id=freebies.id, supplier_payment_id=sent.id, amount=reversed_amount, paid_on=day,
            method='bank_transfer', reversed_at=m.now(), reverse_reason='Complimentary birds, no cost')
        db.add(wrong); db.flush()
        return sent.id, wrong.id


def test_historical_reversal_stays_unresolved_until_classified(client, seeded, sessions, engine, monkeypatch):
    from app import db as app_db
    # The Finance summary reads one snapshot through the app's engine.
    monkeypatch.setattr(app_db, 'engine', engine)
    owe = lambda: client.get(API + '/finance/summary', headers=OPS).json()['i_owe']
    transfer_id, allocation_id = _legacy_reversal(sessions, seeded, 100000, 40000)
    body = statement(client, seeded)
    assert Decimal(body['unresolved']) == Decimal('40000') and Decimal(body['credit']) == 0
    assert [r['ledger_payment_id'] for r in body['unresolved_items']] == [allocation_id]
    sections = {s['key']: s for s in fx.build_report(engine)['sections']}
    assert sections['unresolved_transfer_allocations']['amount'] == Decimal('40000.00')
    assert sections['transfer_invariant_breaks']['count'] == 0
    # Also on the Finance overview and Debts, beside I owe (M1 exit: unknowns are visible).
    assert Decimal(owe()['unresolved']) == Decimal('40000')
    # Unresolved money cannot be used or refunded until classified.
    assert post(client, f"/ledger/suppliers/{seeded['supplier']}/credit/apply", {'amount': '1'}).status_code == 422
    assert post(client, f'/ledger/transfers/{transfer_id}/refunds',
        {'amount': '1', 'received_on': TODAY, 'method': 'cash', 'reference': 'R'}).status_code == 422
    with sessions() as db:
        report = ct.dry_run(db)
    assert [(r['ledger_payment_id'], r['suggested']) for r in report['unresolved']] == [(allocation_id, 'credit')]
    # Part refunded (with its real date), the rest still held as credit.
    with sessions.begin() as db:
        with pytest.raises(ct.ClassifyError):
            ct.classify(db, allocation_id, 'credit', '', 'Maternus Joshua')
    with sessions.begin() as db:
        ct.classify(db, allocation_id, 'refund', 'M-Pesa SMS QX1 10,000 from supplier', 'Maternus Joshua',
            amount='10000', received_on=YESTERDAY, method='mpesa', reference='QX1')
    assert Decimal(statement(client, seeded)['unresolved']) == Decimal('30000')
    with sessions.begin() as db:
        ct.classify(db, allocation_id, 'credit', 'Supplier confirmed by phone she holds 30,000', 'Maternus Joshua')
        with pytest.raises(ct.ClassifyError):
            ct.classify(db, allocation_id, 'credit', 'again', 'Maternus Joshua')
    body = statement(client, seeded)
    assert Decimal(body['unresolved']) == 0 and Decimal(body['credit']) == Decimal('30000')
    assert Decimal(body['refunded']) == Decimal('10000')
    assert Decimal(owe()['unresolved']) == 0 and Decimal(owe()['credit']) == Decimal('30000')
    refunds = client.get(API + f'/ledger/payments?status=in&start={YESTERDAY}&end={YESTERDAY}', headers=OPS).json()
    assert Decimal(refunds['summary']['money_in']) == Decimal('10000')
    assert {s['key']: s for s in fx.build_report(engine)['sections']}['unresolved_transfer_allocations']['count'] == 0


def test_antonia_scenario_ends_with_reallocatable_credit(client, seeded, sessions, engine, capsys):
    transfer_id, allocation_id = _legacy_reversal(sessions, seeded)
    out_before = cash(client)['money_out']
    assert out_before == Decimal('650000')
    assert ct.main(['--dry-run'], bind=engine) == 0
    printed = capsys.readouterr().out
    assert allocation_id in printed and 'suggested: credit' in printed and 'TZS 19,500' in printed
    # Refused without confirming this very item.
    assert ct.main(['--apply', allocation_id, '--as', 'credit', '--evidence', 'Antonia confirmed she holds it',
        '--by', 'Maternus Joshua'], ask=lambda _prompt: 'yes', bind=engine) == 1
    assert Decimal(statement(client, seeded)['unresolved']) == Decimal('19500')
    assert ct.main(['--apply', allocation_id, '--as', 'credit', '--evidence', 'Antonia confirmed she holds it',
        '--by', 'Maternus Joshua', '--confirm', allocation_id], bind=engine) == 0
    body = statement(client, seeded)
    assert Decimal(body['credit']) == Decimal('19500') and Decimal(body['unresolved']) == 0
    assert Decimal(body['transferred']) == Decimal('650000')
    # Her next invoice takes the credit; no money moves.
    [next_invoice] = invoices(client, seeded, 26000)
    assert post(client, f"/ledger/suppliers/{seeded['supplier']}/credit/apply", {'amount': '19500', 'debt_ids': [next_invoice['id']]}).status_code == 201
    assert Decimal(debt(client, next_invoice['id'])['balance']) == Decimal('6500')
    assert cash(client)['money_out'] == out_before
    rows = balanced(sessions)
    assert rows[transfer_id] == rows[transfer_id] | {'allocated': Decimal('650000'), 'credit': 0, 'unresolved': 0}


def test_legacy_payments_are_wrapped_only_by_the_command(client, seeded, sessions, engine):
    supplier = seeded['supplier']
    day = date.fromisoformat(TODAY)
    with sessions.begin() as db:
        old = m.LedgerDebt(direction='payable', party_kind='supplier', supplier_id=supplier, party_name='Private Supplier',
            amount=30000, paid_amount=10000, incurred_on=day, source='manual')
        db.add(old); db.flush()
        active = m.LedgerPayment(debt_id=old.id, amount=10000, paid_on=day, method='cash')
        reversed_ = m.LedgerPayment(debt_id=old.id, amount=5000, paid_on=day, method='cash', reversed_at=m.now())
        db.add_all([active, reversed_]); db.flush()
        ids = (old.id, active.id, reversed_.id)
    assert cash(client)['money_out'] == Decimal('10000')
    sections = {s['key']: s for s in fx.build_report(engine)['sections']}
    assert sections['unwrapped_supplier_payments']['count'] == 2
    with sessions() as db:
        assert {r['ledger_payment_id'] for r in ct.dry_run(db)['unwrapped']} == {ids[1], ids[2]}
    assert ct.main(['--wrap', ids[1], '--evidence', 'Cash book page 12', '--by', 'Maternus Joshua', '--confirm', ids[1]], bind=engine) == 0
    assert ct.main(['--wrap', ids[2], '--evidence', 'Cash voucher 7 shows it was paid', '--by', 'Maternus Joshua'],
        ask=lambda _prompt: ids[2], bind=engine) == 0
    assert cash(client)['money_out'] == Decimal('15000')
    body = statement(client, seeded)
    assert Decimal(body['unresolved']) == Decimal('5000') and Decimal(body['without_transfer']) == 0
    with sessions() as db:
        assert {r.origin for r in db.scalars(select(m.SupplierPayment))} == {'legacy'}
    balanced(sessions)


def test_reversing_a_legacy_supplier_payment_keeps_the_money_as_credit(client, seeded, sessions):
    supplier = seeded['supplier']
    with sessions.begin() as db:
        old = m.LedgerDebt(direction='payable', party_kind='supplier', supplier_id=supplier, party_name='Private Supplier',
            amount=30000, paid_amount=10000, incurred_on=date.fromisoformat(TODAY), source='manual')
        db.add(old); db.flush()
        payment = m.LedgerPayment(debt_id=old.id, amount=10000, paid_on=date.fromisoformat(TODAY), method='cash')
        db.add(payment); db.flush()
        payment_id = payment.id
    assert post(client, f'/ledger/payments/{payment_id}/reverse', {'reason': 'Wrong invoice'}).status_code == 200
    assert cash(client)['money_out'] == Decimal('10000')
    assert Decimal(statement(client, seeded)['credit']) == Decimal('10000')
    balanced(sessions)


def test_a_payment_typed_with_the_sale_stays_with_its_supplier_when_corrected(client, seeded, sessions):
    """R1: even a payment typed in for this one invoice is not moved to the
    corrected supplier. The edit is refused; "Wrong supplier" moves the whole
    debt and leaves the payment with the supplier it was recorded to, here
    unresolved until the finance owner classifies it."""
    original = sale(client, items=[{'category': 'broilers', 'unit': 'bird', 'quantity': '3', 'unit_price': '7000',
        'supplier_id': seeded['supplier'], 'unit_cost': '6500'}])
    payable = next(d for d in original['debts'] if d['direction'] == 'payable')
    assert pay(client, payable['id'], '19500').status_code == 201
    with sessions.begin() as db:
        other = m.User(phone='+255712345688', roles=['supplier'], name='Corrected Supplier')
        db.add(other); db.flush()
        db.add(m.SupplierProfile(user_id=other.id, legal_name='Corrected Supplier', internal_pickup_address='x'))
        other_id = other.id
    changed = client.put(API + f"/sales/{original['id']}", headers=OPS, json={
        'buyer_profile_id': original['buyer_profile_id'], 'sold_on': TODAY,
        'items': [{'category': 'broilers', 'unit': 'bird', 'quantity': '3', 'unit_price': '7000',
                   'supplier_id': other_id, 'unit_cost': '6500'}]})
    assert changed.status_code == 422
    fixed = post(client, f"/ledger/debts/{payable['id']}/corrections", {'kind': 'wrong_supplier',
        'reason': 'Birds came from the other farm', 'supplier_id': other_id, 'payments': 'unresolved'})
    assert fixed.status_code == 200, fixed.text
    with sessions() as db:
        assert {r.supplier_id for r in db.scalars(select(m.SupplierPayment))} == {seeded['supplier']}
    assert Decimal(statement(client, seeded)['unresolved']) == Decimal('19500')
    assert cash(client)['money_out'] == Decimal('19500')
    balanced(sessions)


def test_migration_032_leaves_history_unresolved(tmp_path, monkeypatch):
    """Applied to a database holding a reversed allocation, 032 adds the
    tables and reclassifies nothing: the item stays unresolved (R6)."""
    import os
    import uuid
    from sqlalchemy import create_engine
    from app import migrations
    url = os.environ.get('OMOTERRA_TEST_DATABASE_URL')
    if not url:
        pytest.skip('Set OMOTERRA_TEST_DATABASE_URL to a disposable PostgreSQL database')
    schema = 'omoterra_m032_' + uuid.uuid4().hex
    admin = create_engine(url)
    with admin.begin() as db:
        db.execute(text(f'CREATE SCHEMA {schema}'))
    engine = create_engine(url, connect_args={'options': f'-csearch_path={schema}'})
    try:
        files = migrations.files()
        for path in files:
            if path.name < '032':
                shutil.copy(path, tmp_path / path.name)
        monkeypatch.setattr(migrations, 'DIRECTORY', tmp_path)
        migrations.apply(engine)
        with engine.begin() as db:
            db.execute(text("""INSERT INTO users (id, phone, name, region, language, roles, deleted, created_at)
                VALUES ('s1', '+255700000009', 'Antonia', '', 'en', '["supplier"]', false, now())"""))
            db.execute(text("""INSERT INTO ledger_debts (id, created_at, direction, party_kind, supplier_id, party_name,
                party_phone, description, amount, paid_amount, incurred_on, source, status, cancel_reason)
                VALUES ('d1', now(), 'payable', 'supplier', 's1', 'Antonia', '', 'Birds', 19500, 0, '2026-09-27',
                'manual', 'open', '')"""))
            db.execute(text("""INSERT INTO supplier_payments (id, created_at, supplier_id, amount, paid_on, method,
                reference, sms_text, note) VALUES ('t1', now(), 's1', 19500, '2026-09-27', 'bank_transfer', 'B1', '', '')"""))
            db.execute(text("""INSERT INTO ledger_payments (id, created_at, debt_id, supplier_payment_id, amount, paid_on,
                method, reference, note, reversed_at, reverse_reason) VALUES ('p1', now(), 'd1', 't1', 19500,
                '2026-09-27', 'bank_transfer', '', '', now(), 'Complimentary birds')"""))
        for path in files:
            shutil.copy(path, tmp_path / path.name)
        assert '032_transfers_and_supplier_credit.sql' in migrations.apply(engine)
        with Session(engine) as db:
            assert db.scalar(select(m.SupplierPayment.origin)) == 'pay_supplier'
            assert db.scalar(text('SELECT count(*) FROM transfer_events')) == 0
            [item] = tr.unresolved_items(db)
            assert item['ledger_payment_id'] == 'p1' and item['amount'] == Decimal('19500')
            row = tr.buckets(db)['t1']
            assert tr.balanced(row) and row['unresolved'] == Decimal('19500')
    finally:
        engine.dispose()
        with admin.begin() as db:
            db.execute(text(f'DROP SCHEMA {schema} CASCADE'))
        admin.dispose()
