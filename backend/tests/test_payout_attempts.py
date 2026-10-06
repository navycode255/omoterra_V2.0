"""Payout attempts and controlled resends (build plan M2.7, audit F12,
decision D9): each attempt is its own row; a debited one is a permanent
outflow on its debit day, a refund a separate inflow on its own day, an
initiated one is exposure but not money out, and a failed one records no
outflow. A resend, or a first payout over TZS 500,000, needs a second admin."""
from datetime import timedelta
from decimal import Decimal

import pytest
from sqlalchemy import select

from app import approvals, contracts as c, finance_exceptions as fx, models as m, payouts, reporting as rp
from test_commerce import headers
from test_reporting import app_order, settlement_of

API = '/api/v1/ops'
OPS = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin'}
DAY = c.business_today()
_keys = iter(range(10**6))


def key():
    return f'payout-attempt-{next(_keys):06d}'


def post(client, path, body, who=OPS):
    return client.post(API + path, json=body, headers={**who, 'Idempotency-Key': key()})


def make_second_admin(sessions):
    """Another admin signed in (session 'ops-admin-2'), for code that cannot
    take the `second_admin` fixture."""
    from app.auth import digest
    with sessions.begin() as db:
        if db.scalar(select(m.Operator).where(m.Operator.phone == '+255710000003')) is None:
            operator = m.Operator(phone='+255710000003', name='Second Admin', role='admin')
            db.add(operator); db.flush()
            db.add(m.OperatorSession(operator_id=operator.id, token_hash=digest('ops-admin-2'),
                expires_at=m.now() + timedelta(days=1)))
    return {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin-2'}


def more_stock(sessions, seeded, quantity=100):
    with sessions.begin() as db:
        db.get(m.Listing, seeded['listing']).quantity_total = quantity


def delivered_payout(sessions, seeded, birds, idem):
    """A delivered app order and its pending settlement (9,000 a bird)."""
    id = app_order(sessions, seeded, birds, idem, delivered_on=DAY - timedelta(days=10))
    return settlement_of(sessions, id).id


def attempt(client, settlement, amount, reference, **extra):
    return post(client, f'/settlements/{settlement}/attempts', {'amount': str(amount), 'payment_reference': reference,
        'method': 'mpesa', **extra})


def approve_resend(client, settlement, amount, approver, acknowledge=True):
    asked = post(client, f'/settlements/{settlement}/approvals', {'amount': str(amount),
        'reason': 'Supplier reports the money never arrived', 'acknowledge_two_outflows': acknowledge})
    assert asked.status_code == 201, asked.text
    done = client.post(f"{API}/approvals/{asked.json()['id']}/approve", json={}, headers=approver)
    assert done.status_code == 200, done.text
    return asked.json()['id']


def not_received(client, settlement):
    answer = client.post(f'/api/v1/supplier/payouts/{settlement}/confirm', headers=headers('supplier'),
        json={'received': False, 'note': 'Nothing arrived'})
    assert answer.status_code == 200, answer.text


def cash_rows(sessions, settlement):
    with sessions() as db:
        ids = select(m.SettlementTransfer.id).where(m.SettlementTransfer.settlement_id == settlement)
        refunds = select(m.SettlementRefund.id).where(m.SettlementRefund.settlement_id == settlement)
        rows = db.execute(select(rp.CASH).where(rp.COUNTED, (rp.CASH.c.id.in_(ids)) | (rp.CASH.c.id.in_(refunds)))).all()
        return sorted((row.paid_on, row.flow, row.amount, row.source_table) for row in rows)


def detail(client, settlement):
    response = client.get(f'{API}/settlements/{settlement}', headers=OPS)
    assert response.status_code == 200, response.text
    return response.json()


def test_two_debited_outflows_and_a_partial_refund_stay_on_their_dates(client, sessions, seeded, second_admin):
    settlement = delivered_payout(sessions, seeded, 3, 'payout-f12-two')  # 27,000
    first_day, second_day, refund_day = DAY - timedelta(days=6), DAY - timedelta(days=3), DAY - timedelta(days=1)
    first = attempt(client, settlement, 27000, 'QFIRST1', sent_on=first_day.isoformat(), debited=True,
        evidence='M-Pesa statement line')
    assert first.status_code == 201, first.text
    not_received(client, settlement)
    approval = approve_resend(client, settlement, 27000, second_admin)
    second = attempt(client, settlement, 27000, 'QSECOND2', sent_on=second_day.isoformat(), approval_id=approval)
    assert second.status_code == 201, second.text
    view = second.json()
    assert view['in_flight'] == '27000.00' and view['net_paid'] == '27000.00' and view['status'] == 'paid'
    second_id = view['attempts'][0]['id']
    # The resend is debited two days later: its outflow is on its debit day.
    debited = client.post(f'{API}/settlement-transfers/{second_id}/debited', headers=OPS,
        json={'debited_on': (second_day + timedelta(days=1)).isoformat(), 'evidence': 'Statement line 14'})
    assert debited.status_code == 200, debited.text
    first_id = view['attempts'][1]['id']
    refund = post(client, f'/settlement-transfers/{first_id}/refunds', {'amount': '10000',
        'refunded_on': refund_day.isoformat(), 'method': 'mpesa', 'reference': 'QBACK3', 'evidence': 'Reversal SMS'})
    assert refund.status_code == 201, refund.text
    body = refund.json()
    # Both outflows stay, each on its own date; the refund is a separate inflow.
    assert cash_rows(sessions, settlement) == [
        (first_day, 'out', Decimal('27000.00'), 'settlement_transfers'),
        (second_day + timedelta(days=1), 'out', Decimal('27000.00'), 'settlement_transfers'),
        (refund_day, 'in', Decimal('10000.00'), 'settlement_refunds')]
    assert Decimal(body['net_paid']) == 2 * Decimal('27000') - Decimal('10000')
    assert body['debited'] == '54000.00' and body['refunded'] == '10000.00' and body['status'] == 'paid'
    # Possibly paid twice: the 17,000 the first attempt kept, until refunded.
    assert body['exposure'] == '17000.00'
    with sessions() as db:
        totals = rp.settlement_totals(db)
        assert totals['paid'] == Decimal('44000.00') and totals['disputed'] == Decimal('17000.00')
        for day, flow, amount, _table in cash_rows(sessions, settlement):
            money_in, money_out = rp.moved(db, rp.CASH.c.paid_on == day, rp.CASH.c.supplier_id == seeded['supplier'])
            assert (money_in if flow == 'in' else money_out) == amount
    # The supplier's answer belongs to the first attempt.
    assert [(a['attempt_no'], a['supplier_confirmation']) for a in body['attempts']] == [(2, None), (1, 'not_received')]


def test_initiated_attempt_proven_failed_records_no_outflow_and_keeps_evidence(client, sessions, seeded):
    settlement = delivered_payout(sessions, seeded, 2, 'payout-f12-failed')  # 18,000
    sent = attempt(client, settlement, 18000, 'QFAIL01', sent_on=(DAY - timedelta(days=5)).isoformat())
    assert sent.status_code == 201, sent.text
    attempt_id = sent.json()['attempts'][0]['id']
    with sessions() as db:
        # In flight: exposure, but not money out and still owed.
        assert rp.payouts_in_flight(db) == {'amount': Decimal('18000.00'), 'count': 1}
        assert cash_rows(sessions, settlement) == []
        assert db.get(m.Settlement, settlement).status == 'pending'
        assert rp.payables(db)['marketplace'] == Decimal('18000.00')
    # Older than 3 days and unconfirmed: an exception.
    with sessions() as db:
        stale = fx.stale_payout_attempts(db)
    assert [r['attempt_id'] for r in stale['records']] == [attempt_id]
    failed = client.post(f'{API}/settlement-transfers/{attempt_id}/failed', headers=OPS,
        json={'failed_on': (DAY - timedelta(days=4)).isoformat(), 'evidence': 'Provider says the number was invalid'})
    assert failed.status_code == 200, failed.text
    body = failed.json()
    assert body['attempts'][0]['state'] == 'failed'
    assert body['attempts'][0]['failure_evidence'] == 'Provider says the number was invalid'
    assert body['net_paid'] == '0.00' and body['outstanding'] == '18000.00' and body['status'] == 'pending'
    assert cash_rows(sessions, settlement) == []
    with sessions() as db:
        assert rp.payouts_in_flight(db)['amount'] == 0
    # A failed attempt cannot be debited or failed again; a debited one cannot fail.
    assert client.post(f'{API}/settlement-transfers/{attempt_id}/debited', headers=OPS,
        json={'debited_on': DAY.isoformat(), 'evidence': 'oops'}).status_code == 409


def test_resend_needs_a_second_admin(client, sessions, seeded, second_admin):
    settlement = delivered_payout(sessions, seeded, 3, 'payout-f12-resend')
    assert attempt(client, settlement, 27000, 'QONE0001', debited=True, evidence='SMS').status_code == 201
    not_received(client, settlement)
    # Without approval: refused.
    refused = attempt(client, settlement, 27000, 'QTWO0002', debited=True, evidence='SMS')
    assert refused.status_code == 403 and 'second admin' in refused.json()['detail']
    # A request without the acknowledgement of two outflows: refused.
    assert post(client, f'/settlements/{settlement}/approvals', {'amount': '27000', 'reason': 'Never arrived'}).status_code == 422
    # Over the settlement amount: refused.
    assert post(client, f'/settlements/{settlement}/approvals', {'amount': '27001', 'reason': 'Never arrived',
        'acknowledge_two_outflows': True}).status_code == 422
    asked = post(client, f'/settlements/{settlement}/approvals', {'amount': '27000', 'reason': 'Never arrived',
        'acknowledge_two_outflows': True})
    assert asked.status_code == 201, asked.text
    approval = asked.json()['id']
    # Not yet approved: refused.
    assert attempt(client, settlement, 27000, 'QTWO0002', approval_id=approval).status_code == 409
    # The requester cannot approve their own request.
    own = client.post(f'{API}/approvals/{approval}/approve', json={}, headers=OPS)
    assert own.status_code == 403
    # A second admin can.
    assert client.post(f'{API}/approvals/{approval}/approve', json={}, headers=second_admin).status_code == 200
    sent = attempt(client, settlement, 27000, 'QTWO0002', approval_id=approval, debited=True, evidence='SMS')
    assert sent.status_code == 201, sent.text
    assert sent.json()['attempts'][0]['is_resend'] and sent.json()['attempts'][0]['approval_id'] == approval
    # An approval is used once.
    assert attempt(client, settlement, 27000, 'QTHREE03', approval_id=approval).status_code == 409
    with sessions() as db:
        row = db.get(m.ApprovalRequest, approval)
        assert row.decided_by == seeded['operator_admin_2'] and row.used_at is not None
    # The database itself refuses an approval by the requester.
    from sqlalchemy.exc import IntegrityError
    with pytest.raises(IntegrityError):
        with sessions.begin() as db:
            db.add(m.ApprovalRequest(subject_table='settlements', subject_id=settlement, kind='payout_resend',
                amount=1, requested_by=seeded['operator_admin'], status='approved', decided_by=seeded['operator_admin']))


def test_first_payout_over_the_threshold_needs_a_second_admin(client, sessions, seeded, second_admin):
    small = delivered_payout(sessions, seeded, 1, 'payout-f12-small')
    large = delivered_payout(sessions, seeded, 2, 'payout-f12-large')
    with sessions.begin() as db:
        # 500,000 exactly needs no approval; above it does.
        db.get(m.Settlement, small).total_payable = approvals.SECOND_ADMIN_THRESHOLD
        db.get(m.Settlement, large).total_payable = approvals.SECOND_ADMIN_THRESHOLD + 1
    # A request for a payout that needs none is refused.
    assert post(client, f'/settlements/{small}/approvals', {'amount': '500000', 'reason': 'Not needed'}).status_code == 409
    assert attempt(client, small, '500000', 'QSMALL01').status_code == 201
    refused = attempt(client, large, '500001', 'QLARGE01')
    assert refused.status_code == 403 and '500,000' in refused.json()['detail']
    # /pay is the same path: refused too.
    assert post(client, f'/settlements/{large}/pay', {'amount': '500001', 'payment_reference': 'QLARGE01'}).status_code == 403
    asked = post(client, f'/settlements/{large}/approvals', {'amount': '500001', 'reason': 'Large payout'})
    assert asked.status_code == 201 and asked.json()['kind'] == 'payout_over_threshold'
    assert client.post(f"{API}/approvals/{asked.json()['id']}/approve", json={}, headers=second_admin).status_code == 200
    assert attempt(client, large, '500001', 'QLARGE01', approval_id=asked.json()['id']).status_code == 201


def test_a_refund_larger_than_the_debited_outflows_is_refused(client, sessions, seeded):
    settlement = delivered_payout(sessions, seeded, 2, 'payout-f12-refund')  # 18,000
    sent = attempt(client, settlement, 18000, 'QREF0001')
    attempt_id = sent.json()['attempts'][0]['id']
    # Nothing debited yet: no refund.
    body = {'amount': '1000', 'refunded_on': DAY.isoformat(), 'evidence': 'Bank reversal'}
    assert post(client, f'/settlement-transfers/{attempt_id}/refunds', body).status_code == 409
    client.post(f'{API}/settlement-transfers/{attempt_id}/debited', headers=OPS,
        json={'debited_on': DAY.isoformat(), 'evidence': 'Statement'})
    too_much = post(client, f'/settlement-transfers/{attempt_id}/refunds', {**body, 'amount': '18001'})
    assert too_much.status_code == 422 and '18,000' in too_much.json()['detail']
    assert post(client, f'/settlement-transfers/{attempt_id}/refunds', {**body, 'amount': '18000'}).status_code == 201
    assert post(client, f'/settlement-transfers/{attempt_id}/refunds', {**body, 'amount': '1'}).status_code == 422
    # Refunded in full: owed again, and the debited outflow still stands.
    view = detail(client, settlement)
    assert view['status'] == 'pending' and view['outstanding'] == '18000.00' and view['debited'] == '18000.00'
    # A debited attempt never becomes failed (R3).
    assert client.post(f'{API}/settlement-transfers/{attempt_id}/failed', headers=OPS,
        json={'failed_on': DAY.isoformat(), 'evidence': 'Bounced'}).status_code == 409
    # Refunds are append-only.
    from sqlalchemy.exc import DBAPIError
    with pytest.raises(DBAPIError):
        with sessions.begin() as db:
            db.execute(m.SettlementRefund.__table__.update().values(amount=1))


def test_supplier_sees_a_sent_payout_and_answers_about_the_current_attempt(client, sessions, seeded, second_admin):
    """The supplier app and portal keep reading status 'paid' once money is
    sent (debit confirmed or not) and can answer; the answer attaches to the
    attempt."""
    settlement = delivered_payout(sessions, seeded, 3, 'payout-f12-supplier')
    payouts_ = lambda: {p['id']: p for p in client.get('/api/v1/supplier/payouts', headers=headers('supplier')).json()}
    assert payouts_()[settlement]['status'] == 'pending'
    attempt(client, settlement, 27000, 'QSUP0001')
    seen = payouts_()[settlement]
    assert seen['status'] == 'paid' and seen['payment_reference'] == 'QSUP0001' and seen['paid_at']
    not_received(client, settlement)
    approval = approve_resend(client, settlement, 27000, second_admin)
    attempt(client, settlement, 27000, 'QSUP0002', approval_id=approval, debited=True, evidence='SMS')
    seen = payouts_()[settlement]
    assert seen['payment_reference'] == 'QSUP0002' and seen['supplier_confirmation'] is None
    answer = client.post(f'/api/v1/supplier/payouts/{settlement}/confirm', headers=headers('supplier'), json={'received': True})
    assert answer.status_code == 200
    with sessions() as db:
        rows = db.scalars(select(m.PayoutConfirmation).order_by(m.PayoutConfirmation.created_at)).all()
        attempts_ = {a.id: a.attempt_no for a in db.scalars(select(m.SettlementTransfer))}
        assert [(r.outcome, attempts_[r.transfer_id], r.payment_reference) for r in rows] == [
            ('not_received', 1, 'QSUP0001'), ('received', 2, 'QSUP0002')]
    # The first attempt is still in flight and unresolved: exposure stays.
    view = detail(client, settlement)
    assert view['in_flight'] == '27000.00' and view['exposure'] == '27000.00'
    with sessions() as db:
        section = fx.payout_exposure(db)
    assert [r['settlement_id'] for r in section['records']] == [settlement]


def test_a_paid_payout_cannot_be_sent_again_without_a_dispute(client, sessions, seeded):
    settlement = delivered_payout(sessions, seeded, 1, 'payout-f12-closed')
    assert attempt(client, settlement, 9000, 'QCLOSED1', debited=True, evidence='SMS').status_code == 201
    # Paid, no dispute: nothing more to send.
    assert attempt(client, settlement, 9000, 'QCLOSED2').status_code == 409
    view = detail(client, settlement)
    assert view['next']['blocked'] == 'paid'


# ---- backfill (migration 045) ------------------------------------------------------------

@pytest.fixture
def fresh_engine():
    import os
    import uuid
    from sqlalchemy import create_engine, text
    url = os.environ.get('OMOTERRA_TEST_DATABASE_URL')
    if not url:
        pytest.skip('Set OMOTERRA_TEST_DATABASE_URL to a disposable PostgreSQL database')
    schema = 'omoterra_m045_' + uuid.uuid4().hex
    admin = create_engine(url)
    with admin.begin() as db:
        db.execute(text(f'CREATE SCHEMA {schema}'))
    engine = create_engine(url, connect_args={'options': f'-csearch_path={schema}'})
    yield engine
    engine.dispose()
    with admin.begin() as db:
        db.execute(text(f'DROP SCHEMA {schema} CASCADE'))
    admin.dispose()


def test_backfill_turns_each_paid_settlement_into_one_debited_attempt(fresh_engine, tmp_path, monkeypatch):
    import shutil
    from datetime import date, datetime, timezone
    from sqlalchemy import text
    from sqlalchemy.orm import Session
    from app import accounts, migrations
    files = migrations.files()
    for path in files:
        if path.name < '045':
            shutil.copy(path, tmp_path / path.name)
    monkeypatch.setattr(migrations, 'DIRECTORY', tmp_path)
    migrations.apply(fresh_engine)
    # 22:30 UTC on 20 September is 21 September in Dar es Salaam.
    paid_at = datetime(2026, 9, 20, 22, 30, tzinfo=timezone.utc)
    with Session(fresh_engine) as db, db.begin():
        buyer = m.User(phone='+255700000001', roles=['buyer'], name='Buyer')
        supplier = m.User(phone='+255700000002', roles=['supplier'], name='Supplier')
        db.add_all([buyer, supplier]); db.flush()
        listing = m.Listing(supplier_id=supplier.id, category='broilers', unit_type='bird', specs={}, region='Pwani',
            quantity_total=10, farmer_asking_price_per_unit=10000, supplier_payout_price_per_unit=9000,
            buyer_price_per_unit=12000, listing_status='live')
        account = m.MoneyAccount(name='M-Pesa', kind='mobile_wallet', cutoff_on=date(2026, 9, 1), opening_balance=0,
            opening_evidence='Statement', verified_by='Finance owner')
        db.add_all([listing, account]); db.flush()
        account_id = account.id
        ids = {}
        for n, (name, status, ref, answer) in enumerate([('plain', 'paid', 'QLEG0001', None),
                ('resent', 'paid', 'QLEG0003', 'received'), ('pending', 'pending', None, None),
                ('disputed', 'paid', 'QLEG0004', 'not_received')]):
            order = m.Order(buyer_id=buyer.id, delivery_snapshot={}, preferred_delivery_date='2026-09-15',
                payment_method='pay_on_delivery', internal_status='delivered', expected_quantity=3, total_amount=36000,
                idempotency_key=f'm045-{n}')
            db.add(order); db.flush()
            item = m.OrderItem(order_id=order.id, listing_id=listing.id, quantity=3, unit_price=12000, subtotal=36000,
                asking_snapshot=10000, payout_snapshot=9000)
            db.add(item); db.flush()
            row = m.Settlement(supplier_id=supplier.id, order_item_id=item.id, farmer_asking_price_per_unit=10000,
                supplier_payout_price_per_unit=9000, commission_amount_per_unit=1000, quantity=3, total_payable=27000,
                status=status, paid_at=paid_at if status == 'paid' else None, payment_reference=ref,
                supplier_confirmation=answer, supplier_confirmed_at=paid_at if answer else None)
            db.add(row); db.flush()
            ids[name] = row.id
        db.add(m.AccountAssignment(source_table='settlements', source_id=ids['plain'], account_id=account_id))
        db.add(m.MoneyReference(reference='QLEG0001', flow='out', source_table='settlements', source_id=ids['plain']))
        # Answers before attempts existed (no transfer_id column yet): the
        # resent payout's first reference survives only in its answers.
        for settlement, outcome, ref in [(ids['resent'], 'not_received', 'QLEG0002'), (ids['resent'], 'received', 'QLEG0003'),
                                         (ids['disputed'], 'not_received', 'QLEG0004')]:
            db.execute(text("""INSERT INTO payout_confirmations (id, created_at, settlement_id, supplier_id, outcome, note,
                amount, payment_reference) VALUES (:id, now(), :s, :u, :o, '', 27000, :r)"""),
                {'id': f'{settlement[:30]}-{outcome[:4]}', 's': settlement, 'u': supplier.id, 'o': outcome, 'r': ref})
    for path in files:
        if path.name >= '045':
            shutil.copy(path, tmp_path / path.name)
    migrations.apply(fresh_engine)
    with Session(fresh_engine) as db:
        attempts = {a.settlement_id: a for a in db.scalars(select(m.SettlementTransfer))}
        assert set(attempts) == {ids['plain'], ids['resent'], ids['disputed']}
        plain = attempts[ids['plain']]
        assert (plain.state, plain.amount, plain.sent_on, plain.debited_on, plain.reference, plain.legacy) == (
            'debited', Decimal('27000.00'), date(2026, 9, 21), date(2026, 9, 21), 'QLEG0001', True)
        assert plain.evidence == 'legacy: marked paid' and plain.money_account_id == account_id
        assert attempts[ids['disputed']].supplier_confirmation == 'not_received'
        # The account and the reference claim follow the attempt.
        assigned = db.scalar(select(m.AccountAssignment))
        assert (assigned.source_table, assigned.source_id) == ('settlement_transfers', plain.id)
        claim = db.scalar(select(m.MoneyReference))
        assert (claim.source_table, claim.source_id) == ('settlement_transfers', plain.id)
        # No money figure changes: three payouts of 27,000 out on 21 September.
        assert rp.cash_movements(db, date(2026, 9, 21), date(2026, 9, 21))['money_out'] == Decimal('81000.00')
        assert rp.settlement_totals(db)['paid'] == Decimal('81000.00')
        assert rp.settlement_totals(db)['pending'] == Decimal('27000.00')
        assert accounts.balance(db, db.get(m.MoneyAccount, account_id)) == Decimal('-27000.00')
        # Disputed stays disputed; the overwritten first transfer is listed, never invented.
        assert rp.disputed_out(db)['amount'] == Decimal('27000.00')
    report = {s['key']: s for s in fx.build_report(fresh_engine)['sections']}
    problems = {r['settlement_id']: r for r in report['settlement_payout_problems']['records']}
    assert set(problems) == {ids['resent'], ids['disputed']}
    assert problems[ids['resent']]['unrecorded_references'] == ['QLEG0002']
    assert any('resent before payout attempts' in reason for reason in problems[ids['resent']]['reasons'])
    assert [r['settlement_id'] for r in report['payout_exposure']['records']] == [ids['disputed']]
