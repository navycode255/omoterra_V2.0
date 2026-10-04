"""M1.6 historical migration: `python -m app.link_batch_sales` links old
supplier sale lines to delivery notes, one confirmed line at a time."""
from decimal import Decimal

import pytest
from sqlalchemy import func, select

from app import link_batch_sales as link, models as m, transfers as tr
from test_batch_sales import batch, state
from test_finance import API, OPS, TODAY, sale


def supplier_line(seeded, quantity, cost='6500', **extra):
    return {'category': 'broilers', 'unit': 'bird', 'quantity': str(quantity), 'unit_price': '7000',
            'supplier_id': seeded['supplier'], 'unit_cost': cost, **extra}


PAID = {'paid_on': TODAY, 'method': 'cash'}


def counts(sessions):
    with sessions() as db:
        return {model.__tablename__: db.scalar(select(func.count()).select_from(model)) for model in (
            m.SupplierCollection, m.LedgerDebt, m.LedgerPayment, m.SupplierPayment, m.TransferEvent,
            m.FinancialAdjustment)} | {'batch_sold': db.scalar(select(func.sum(m.SupplierBatch.sold_quantity)))}


def report(sessions):
    with sessions() as db:
        return link.dry_run(db)


def statement(client, seeded):
    body = client.get(API + f"/ledger/suppliers/{seeded['supplier']}/statement", headers=OPS).json()
    return Decimal(body['bought']), Decimal(body['paid']), Decimal(body['owed']), Decimal(body['transferred'])


def test_dry_run_changes_nothing_and_apply_converts_exactly_one_line(client, sessions, seeded, engine, capsys):
    batch_id = batch(sessions, seeded, 300)
    first = sale(client, items=[supplier_line(seeded, 20, cost_payment=PAID)])
    second = sale(client, items=[supplier_line(seeded, 30)])
    before, money = counts(sessions), statement(client, seeded)

    assert link.main(['--dry-run'], bind=engine) == 0
    text = capsys.readouterr().out
    assert 'Proposed: 2 lines, TZS 325,000' in text and first['items'][0]['id'] in text
    proposals = report(sessions)['proposed']
    assert [p['batch']['id'] for p in proposals] == [batch_id, batch_id]
    assert [p['batch']['left'] for p in proposals] == [Decimal('300'), Decimal('280')]
    assert proposals[0]['debt']['receipt_paid'] == Decimal('130000') and proposals[0]['debt']['totals_match']
    assert counts(sessions) == before  # the dry run wrote nothing

    line_id = first['items'][0]['id']
    args = ['--apply', line_id, '--batch', batch_id, '--confirm-received-on', TODAY, '--by', 'Maternus Joshua']
    assert link.main(args + ['--confirm', 'something-else'], bind=engine) == 1
    assert counts(sessions) == before
    assert link.main(args + ['--confirm', line_id], bind=engine) == 0

    with sessions() as db:
        item = db.get(m.SaleItem, line_id)
        note = db.get(m.SupplierCollection, item.supplier_collection_id)
        assert (note.origin, note.accepted_quantity, note.unit_cost, note.confirmed_by_name, note.sale_id) == (
            'historical', Decimal('20'), Decimal('6500'), 'Maternus Joshua', first['id'])
        receipt = db.get(m.LedgerDebt, note.debt_id)
        assert (receipt.source, receipt.amount, receipt.paid_amount, receipt.status) == (
            'batch_receipt', Decimal('130000'), Decimal('130000'), 'settled')
        old = db.scalar(select(m.LedgerDebt).where(m.LedgerDebt.sale_id == first['id'], m.LedgerDebt.direction == 'payable'))
        assert old.status == 'cancelled' and old.paid_amount == 0
        assert all(tr.balanced(row) for row in tr.buckets(db).values())
        assert db.get(m.SaleItem, second['items'][0]['id']).supplier_collection_id is None  # untouched
        adjustment = db.scalar(select(m.FinancialAdjustment))
        assert adjustment.kind == 'historical_batch_link' and adjustment.entity_id == line_id
    assert state(sessions, batch_id)[0] == Decimal('20')
    # Same supplier totals: bought, paid, owed and money sent.
    assert statement(client, seeded) == money
    sale_view = client.get(API + f"/sales/{first['id']}", headers=OPS).json()
    assert Decimal(sale_view['cost_amount']) == Decimal('130000')
    left = report(sessions)
    assert [p['line_id'] for p in left['proposed']] == [second['items'][0]['id']]
    # Applying the same line again is refused.
    assert link.main(args + ['--confirm', line_id], bind=engine) == 2


def test_unresolved_lines_are_listed_with_their_reason(client, sessions, seeded):
    sale(client, items=[supplier_line(seeded, 5)])  # no batch at all
    assert report(sessions)['unresolved'][0]['problems'] == ['no open broilers batch for this supplier']
    batch(sessions, seeded, 10)
    sale(client, items=[supplier_line(seeded, 50)])
    rows = report(sessions)
    assert [r['quantity'] for r in rows['proposed']] == [Decimal('5')]
    assert 'no open batch has 50' in rows['unresolved'][0]['problems'][0]
    # Two lines on one partly paid debt: which line was paid is unknown.
    batch(sessions, seeded, 300)
    spread = sale(client, items=[supplier_line(seeded, 2), supplier_line(seeded, 3)])
    debt = next(d for d in spread['debts'] if d['direction'] == 'payable')
    paid = client.post(API + f"/ledger/debts/{debt['id']}/payments", headers={**OPS, 'Idempotency-Key': 'spread-payment-1'},
        json={'amount': '1000', 'paid_on': TODAY, 'method': 'cash'})
    assert paid.status_code == 201
    problems = [r['problems'] for r in report(sessions)['unresolved'] if r['sale_number'] == spread['sale_number']]
    assert len(problems) == 2 and all('partly paid' in p[0] for p in problems)


def test_a_fully_paid_debt_over_two_lines_splits_its_payments(client, sessions, seeded, engine):
    batch_id = batch(sessions, seeded, 300)
    body = sale(client, items=[supplier_line(seeded, 2, cost_payment=PAID), supplier_line(seeded, 3, cost_payment=PAID)])
    money = statement(client, seeded)
    with sessions.begin() as db:
        link.apply(db, body['items'][0]['id'], batch_id, TODAY, 'Maternus Joshua')
    with sessions() as db:
        old = db.scalar(select(m.LedgerDebt).where(m.LedgerDebt.sale_id == body['id'], m.LedgerDebt.direction == 'payable'))
        assert (old.amount, old.paid_amount, old.status) == (Decimal('19500'), Decimal('19500'), 'settled')
        note = db.get(m.SupplierCollection, db.get(m.SaleItem, body['items'][0]['id']).supplier_collection_id)
        receipt = db.get(m.LedgerDebt, note.debt_id)
        assert (receipt.amount, receipt.paid_amount) == (Decimal('13000'), Decimal('13000'))
    assert statement(client, seeded) == money


def test_a_legacy_batch_line_keeps_its_batch_count(client, sessions, seeded):
    batch_id = batch(sessions, seeded, 300)
    body = sale(client, items=[supplier_line(seeded, 20)])
    with sessions.begin() as db:
        db.get(m.SaleItem, body['items'][0]['id']).supplier_batch_id = batch_id
        db.get(m.SupplierBatch, batch_id).sold_quantity = 20
    proposal = report(sessions)['proposed'][0]
    assert proposal['kind'] == 'batch_line' and proposal['batch']['takes_birds'] is False
    with sessions.begin() as db:
        with pytest.raises(link.LinkError):
            link.apply(db, body['items'][0]['id'], batch_id, '2999-01-01', 'Maternus Joshua')
    with sessions.begin() as db:
        link.apply(db, body['items'][0]['id'], batch_id, TODAY, 'Maternus Joshua')
    assert state(sessions, batch_id)[0] == Decimal('20')  # not taken twice
    with sessions() as db:
        item = db.get(m.SaleItem, body['items'][0]['id'])
        assert item.supplier_batch_id is None and item.supplier_collection_id
    breakdown = client.post(API + f'/batches/{batch_id}/sold-elsewhere', headers={**OPS, 'Idempotency-Key': 'elsewhere-1'},
        json={'quantity': '1'})
    assert breakdown.status_code == 200, breakdown.text
    breakdown = breakdown.json()
    assert (Decimal(breakdown['received_on_notes']), Decimal(breakdown['sold_direct'])) == (Decimal('20'), 0)
