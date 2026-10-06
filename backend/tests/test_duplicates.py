"""Duplicate transfer detection (build plan M2.6, audit F11).

A retry key protects one request; it does not stop the same real transaction
being typed in again with a new key. A transaction reference is claimed once
per (provider, account, reference), normalised (mobile money ignores the
account: its codes are unique network-wide); without a reference, a
possible duplicate (same party, amount, day and direction) needs an explicit
override with a reason, which is kept."""
import os
import shutil
import uuid
from decimal import Decimal

import pytest
from sqlalchemy import create_engine, func, select, text
from sqlalchemy.orm import Session

from app import duplicates as dup, finance_exceptions as fx, migrations, models as m
from test_accounts import account
from test_finance import OPS, TODAY, key, pay, post, receivable, sale
from test_transfers import invoices


def pay_supplier(client, seeded, debt_ids, reference, idem=None, **extra):
    body = {'amount': '30000', 'paid_on': TODAY, 'method': 'mpesa', 'reference': reference,
            'debt_ids': list(debt_ids), **extra}
    return post(client, f"/ledger/suppliers/{seeded['supplier']}/payments", body, idem=idem)


def test_the_same_mpesa_code_with_a_new_retry_key_is_blocked(client, seeded, sessions):
    first, second = invoices(client, seeded, 30000, 30000)
    idem = key()
    paid = pay_supplier(client, seeded, [first['id']], 'QAB12XYZ', idem=idem)
    assert paid.status_code == 201, paid.text
    # Typed again later, from a new form (a new retry key).
    again = pay_supplier(client, seeded, [second['id']], 'QAB12XYZ')
    assert again.status_code == 409
    detail = again.json()['detail']
    assert 'QAB12XYZ' in detail and 'supplier transfer' in detail and 'TZS 30,000' in detail
    # Spaces and case do not make it a new transaction.
    assert pay_supplier(client, seeded, [second['id']], ' qab12 xyz ').status_code == 409
    # The same code on another kind of record is the same transaction too.
    body = sale(client)
    assert pay(client, receivable(body)['id'], '1000', method='mpesa', reference='qab12xyz').status_code == 409
    # The original request retried with its own key still replays.
    retry = pay_supplier(client, seeded, [first['id']], 'QAB12XYZ', idem=idem)
    assert retry.status_code == 201 and retry.json()['id'] == paid.json()['id']
    with sessions() as db:
        assert db.scalar(select(func.count()).select_from(m.SupplierPayment)) == 1
        [claim] = db.scalars(select(m.MoneyReference)).all()
        assert (claim.provider, claim.account_key, claim.reference, claim.source_table) == (
            'mpesa', '', 'QAB12XYZ', 'supplier_payments')


def test_the_same_code_with_another_provider_or_bank_account_is_allowed(client, seeded, sessions):
    wallet = account(client, 'M-Pesa till', 'mobile_wallet').json()
    other = account(client, 'M-Pesa second till', 'mobile_wallet').json()
    bank = account(client, 'CRDB', 'bank').json()
    second_bank = account(client, 'NMB', 'bank').json()
    debts = invoices(client, seeded, 30000, 30000, 30000, 30000, 30000)
    ids = [d['id'] for d in debts]
    assert pay_supplier(client, seeded, ids[:1], 'REF-7', money_account_id=wallet['id']).status_code == 201
    # Mobile-money codes are unique network-wide: the same M-Pesa code on
    # another wallet is the same transaction (finance owner, 6 October).
    assert pay_supplier(client, seeded, ids[1:2], 'ref-7', money_account_id=other['id']).status_code == 409
    # Another provider: a bank reference that happens to read the same.
    assert pay_supplier(client, seeded, ids[1:2], 'REF-7', method='bank_transfer',
        money_account_id=bank['id']).status_code == 201
    # Bank references are only unique per account.
    assert pay_supplier(client, seeded, ids[2:3], 'ref-7', method='bank_transfer',
        money_account_id=second_bank['id']).status_code == 201
    # The same bank account again is refused.
    assert pay_supplier(client, seeded, ids[3:4], ' ref-7 ', method='bank_transfer',
        money_account_id=bank['id']).status_code == 409
    with sessions() as db:
        claims = db.scalars(select(m.MoneyReference)).all()
        assert sorted((c.provider, c.account_key) for c in claims) == sorted(
            [('mpesa', ''), ('bank_transfer', bank['id']), ('bank_transfer', second_bank['id'])])


def test_references_are_normalised():
    assert dup.normalise('  qab 12\txyz ') == 'QAB12XYZ'
    assert dup.normalise('') == '' and dup.normalise(None) == ''


def test_a_possible_duplicate_without_a_reference_needs_an_override_and_a_reason(client, seeded, sessions):
    first, second = sale(client), sale(client)
    assert first['buyer_profile_id'] == second['buyer_profile_id']
    paid = pay(client, receivable(first)['id'], '10000')
    assert paid.status_code == 201
    earlier = next(p for p in paid.json()['payments'])
    # Same buyer, amount, day and direction, no reference: refused, naming it.
    again = pay(client, receivable(second)['id'], '10000')
    assert again.status_code == 409 and again.json()['detail'].startswith('Possible duplicate')
    assert 'TZS 10,000' in again.json()['detail'] and 'Mama Asha Restaurant' in again.json()['detail']
    assert pay(client, receivable(second)['id'], '10000', duplicate_override=True).status_code == 422
    assert pay(client, receivable(second)['id'], '10000', duplicate_override=True,
        duplicate_reason='  ').status_code == 422
    ok = pay(client, receivable(second)['id'], '10000', duplicate_override=True,
        duplicate_reason='Two separate cash payments, one for each order')
    assert ok.status_code == 201, ok.text
    # A different amount, or a reference, is not a possible duplicate.
    assert pay(client, receivable(second)['id'], '9000').status_code == 201
    assert pay(client, receivable(first)['id'], '10000', method='mpesa', reference='QREF1').status_code == 201
    with sessions() as db:
        [row] = db.scalars(select(m.DuplicateOverride)).all()
        assert row.reason == 'Two separate cash payments, one for each order'
        assert row.overridden_by == seeded['operator_admin']
        assert (row.earlier_table, row.earlier_id, row.flow, row.amount) == (
            'ledger_payments', earlier['id'], 'in', Decimal('10000'))
    report = fx.duplicate_overrides
    with sessions() as db:
        section = report(db)
        assert section['count'] == 1 and section['records'][0]['by'] == 'Test Admin'


def test_possible_duplicates_on_supplier_and_customer_payments(client, seeded, sessions):
    debts = invoices(client, seeded, 30000, 30000)
    body = {'amount': '30000', 'paid_on': TODAY, 'method': 'cash', 'sms_text': 'Paid cash at the farm'}
    path = f"/ledger/suppliers/{seeded['supplier']}/payments"
    assert post(client, path, {**body, 'debt_ids': [debts[0]['id']]}).status_code == 201
    refused = post(client, path, {**body, 'debt_ids': [debts[1]['id']]})
    assert refused.status_code == 409 and 'supplier transfer' in refused.json()['detail']
    assert post(client, path, {**body, 'debt_ids': [debts[1]['id']], 'duplicate_override': True,
        'duplicate_reason': 'Second batch collected the same day'}).status_code == 201
    first = sale(client)
    buyer = first['buyer_profile_id']
    sale(client)
    customer = {'amount': '5000', 'paid_on': TODAY, 'method': 'cash'}
    assert post(client, f'/ledger/buyers/{buyer}/payments', customer).status_code == 201
    assert post(client, f'/ledger/buyers/{buyer}/payments', customer).status_code == 409
    with sessions() as db:
        assert {r.source_table for r in db.scalars(select(m.DuplicateOverride))} == {'supplier_payments'}


def test_a_payment_reversed_as_an_error_frees_its_reference(client, sessions):
    body = sale(client)
    debt_id = receivable(body)['id']
    paid = pay(client, debt_id, '5000', method='mpesa', reference='QREV1')
    assert paid.status_code == 201
    payment = paid.json()['payments'][0]
    assert post(client, f"/ledger/payments/{payment['id']}/reverse", {'reason': 'Typed on the wrong sale'}).status_code == 200
    other = sale(client, new_buyer={'business_name': 'Someone else', 'phone': '0754 999 888'})
    assert pay(client, receivable(other)['id'], '5000', method='mpesa', reference='QREV1').status_code == 201
    with sessions() as db:
        claims = db.scalars(select(m.MoneyReference).order_by(m.MoneyReference.created_at)).all()
        assert [c.released_at is not None for c in claims] == [True, False]


def test_the_database_refuses_a_second_live_claim(sessions):
    from sqlalchemy.exc import IntegrityError
    with pytest.raises(IntegrityError):
        with sessions.begin() as db:
            for n in range(2):
                db.add(m.MoneyReference(provider='mpesa', account_key='', reference='QDB1', flow='in',
                    source_table='ledger_payments', source_id=f'x{n}'))
                db.flush()


def test_migration_043_is_safe_with_existing_duplicates(tmp_path, monkeypatch):
    url = os.environ.get('OMOTERRA_TEST_DATABASE_URL')
    if not url:
        pytest.skip('Set OMOTERRA_TEST_DATABASE_URL to a disposable PostgreSQL database')
    schema = 'omoterra_m043_' + uuid.uuid4().hex
    admin = create_engine(url)
    with admin.begin() as db:
        db.execute(text(f'CREATE SCHEMA {schema}'))
    engine = create_engine(url, connect_args={'options': f'-csearch_path={schema}'})
    try:
        files = migrations.files()
        for path in files:
            if path.name < '043':
                shutil.copy(path, tmp_path / path.name)
        monkeypatch.setattr(migrations, 'DIRECTORY', tmp_path)
        migrations.apply(engine)
        with engine.begin() as db:
            db.execute(text("""INSERT INTO users (id, phone, name, region, language, roles, deleted, created_at)
                VALUES ('s1', '+255700000009', 'Antonia', '', 'en', '["supplier"]', false, now())"""))
            # The same M-Pesa code typed twice, the second time in lower case.
            for n, (ref, at) in enumerate((('QDUP1', "now() - interval '2 days'"), (' qdup1', 'now()'))):
                db.execute(text(f"""INSERT INTO supplier_payments (id, created_at, supplier_id, amount, paid_on, method,
                    reference, sms_text, note, origin) VALUES ('t{n}', {at}, 's1', 1000, '2026-09-27', 'mpesa', '{ref}',
                    '', '', 'single')"""))
            db.execute(text("""INSERT INTO supplier_payments (id, created_at, supplier_id, amount, paid_on, method,
                reference, sms_text, note, origin) VALUES ('t9', now(), 's1', 1000, '2026-09-27', 'mpesa', '', '', '', 'single')"""))
        for path in files:
            shutil.copy(path, tmp_path / path.name)
        assert '043_money_references.sql' in migrations.apply(engine)
        with Session(engine) as db:
            claims = db.execute(text('SELECT reference, source_id FROM money_references')).all()
            assert claims == [('QDUP1', 't0')]
            [group] = dup.historical_duplicates(db)
            assert group['reference'] == 'QDUP1' and [r['id'] for r in group['records']] == ['t0', 't1']
            section = fx.duplicate_references(db)
            assert section['count'] == 1 and section['amount'] == Decimal('1000.00')
    finally:
        engine.dispose()
        with admin.begin() as db:
            db.execute(text(f'DROP SCHEMA {schema} CASCADE'))
        admin.dispose()
