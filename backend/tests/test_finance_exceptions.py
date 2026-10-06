"""M0.3: the read-only finance exception report finds each condition and writes nothing."""
from contextlib import contextmanager
from datetime import date, timedelta
from decimal import Decimal
import json

import pytest
from sqlalchemy import event, func, select, text
from sqlalchemy.exc import DBAPIError

from app import db as app_db, finance_exceptions as fx, models as m
from app.db import Base

TODAY = date(2026, 10, 1)


def by_key(report):
    return {s['key']: s for s in report['sections']}


@contextmanager
def without_constraint(engine, table, name, definition, cleanup):
    """Production predates some checks; drop one to seed legacy rows, then
    delete them and restore it so the rest of the session is unaffected."""
    with engine.begin() as c:
        c.execute(text(f'ALTER TABLE {table} DROP CONSTRAINT {name}'))
    try:
        yield
    finally:
        with engine.begin() as c:
            c.execute(text(cleanup))
            c.execute(text(f'ALTER TABLE {table} ADD CONSTRAINT {name} CHECK ({definition})'))


def _buyer(db):
    profile = m.BuyerProfile(business_name='Mama Asha', phone='+255754111222')
    db.add(profile); db.flush()
    return profile


def _sale(db, profile, number, items, status='active'):
    sale = m.Sale(sale_number=number, sold_on=TODAY, buyer_profile_id=profile.id, buyer_name='Mama Asha',
                  total_amount=sum(i['subtotal'] for i in items), status=status)
    db.add(sale); db.flush()
    rows = []
    for position, item in enumerate(items, 1):
        state = 'known' if item.get('unit_cost') else 'unknown'
        row = m.SaleItem(sale_id=sale.id, position=position, description='Broilers', unit='bird',
                         quantity=item['subtotal'] / 1000, unit_price=1000, cost_state=state, **item)
        db.add(row); rows.append(row)
    db.flush()
    return sale, rows


def _batch(db, supplier, **kw):
    values = dict(supplier_id=supplier, category='broilers', initial_quantity=100, current_quantity=100)
    values.update(kw)
    batch = m.SupplierBatch(**values)
    db.add(batch); db.flush()
    return batch


def _payable(db, supplier, amount, **kw):
    kw.setdefault('source', 'manual')
    debt = m.LedgerDebt(direction='payable', party_kind='supplier', supplier_id=supplier, party_name='Private Supplier',
                        amount=amount, incurred_on=TODAY, **kw)
    db.add(debt); db.flush()
    return debt


def _settlement(db, seeded, key, **kw):
    order = m.Order(buyer_id=seeded['buyer'], delivery_snapshot={}, preferred_delivery_date='2027-01-01',
        payment_method='pay_on_delivery', internal_status='completed', expected_quantity=1, total_amount=12000,
        idempotency_key=key)
    db.add(order); db.flush()
    item = m.OrderItem(order_id=order.id, listing_id=seeded['listing'], quantity=1, unit_price=12000, subtotal=12000,
                       asking_snapshot=10000, payout_snapshot=9000)
    db.add(item); db.flush()
    row = m.Settlement(supplier_id=seeded['supplier'], order_item_id=item.id, farmer_asking_price_per_unit=9000,
        supplier_payout_price_per_unit=9000, commission_amount_per_unit=3000, quantity=1, total_payable=9000, **kw)
    db.add(row); db.flush()
    return row


def test_empty_database_reports_nothing(sessions, engine):
    report = fx.build_report(engine)
    assert all(s['count'] == 0 for s in report['sections'])
    assert 'Sections with exceptions: 0 of 17' in fx.to_text(report)


def test_unknown_cost_and_unsourced_supplier_lines(sessions, seeded, engine):
    supplier = seeded['supplier']
    with sessions.begin() as db:
        profile = _buyer(db)
        batch = _batch(db, supplier)
        _sale(db, profile, 'SL-0001', [{'subtotal': Decimal('20000')},
            {'subtotal': Decimal('30000'), 'supplier_id': supplier, 'unit_cost': 800, 'cost_total': Decimal('24000')},
            {'subtotal': Decimal('5000'), 'supplier_id': supplier, 'unit_cost': 800, 'cost_total': Decimal('4000'),
             'supplier_batch_id': batch.id}])
        # Cancelled sales are not exceptions.
        _sale(db, profile, 'SL-0002', [{'subtotal': Decimal('99000')}], status='cancelled')
    sections = by_key(fx.build_report(engine))
    unknown = sections['unknown_cost_lines']
    assert unknown['count'] == 1 and unknown['amount'] == Decimal('20000.00') and unknown['sales'] == 1
    assert unknown['records'][0]['sale_number'] == 'SL-0001'
    unsourced = sections['supplier_lines_without_source']
    assert unsourced['count'] == 1 and unsourced['amount'] == Decimal('24000.00')
    assert unsourced['records'][0]['supplier'] == 'Private Supplier'
    assert unsourced['revenue'] == Decimal('30000.00')
    # Sold straight from the batch before M1.6: no delivery note yet.
    legacy = sections['batch_lines_without_receipt']
    assert legacy['count'] == 1 and legacy['amount'] == Decimal('4000.00')
    assert legacy['records'][0]['batch_id'] == batch.id


def test_reversed_allocations_and_unallocated_transfers(sessions, seeded, engine):
    supplier = seeded['supplier']
    with sessions.begin() as db:
        first, second = _payable(db, supplier, 60000), _payable(db, supplier, 40000)
        transfer = m.SupplierPayment(supplier_id=supplier, amount=100000, paid_on=TODAY, method='mpesa', reference='QA1')
        clean = m.SupplierPayment(supplier_id=supplier, amount=10000, paid_on=TODAY, method='cash', reference='CASH-1')
        db.add_all([transfer, clean]); db.flush()
        db.add_all([
            m.LedgerPayment(debt_id=first.id, supplier_payment_id=transfer.id, amount=60000, paid_on=TODAY, method='mpesa'),
            m.LedgerPayment(debt_id=second.id, supplier_payment_id=transfer.id, amount=40000, paid_on=TODAY, method='mpesa',
                            reversed_at=m.now(), reverse_reason='Wrong supplier'),
            m.LedgerPayment(debt_id=second.id, supplier_payment_id=clean.id, amount=10000, paid_on=TODAY, method='cash'),
            # A reversed standalone payment is not part of a transfer.
            m.LedgerPayment(debt_id=second.id, amount=5000, paid_on=TODAY, method='cash', reversed_at=m.now()),
        ])
        second.paid_amount = 10000
        first.paid_amount, first.status = 60000, 'settled'
        ids = {'transfer': transfer.id, 'second': second.id}
    sections = by_key(fx.build_report(engine))
    # Reversed before M1.2: no event, so the 40,000 is unresolved (R6).
    unresolved = sections['unresolved_transfer_allocations']
    assert unresolved['count'] == 1 and unresolved['amount'] == Decimal('40000.00')
    record = unresolved['records'][0]
    assert record['debt_id'] == ids['second'] and record['transfer_amount'] == Decimal('100000.00')
    assert record['transfer_active_allocations'] == Decimal('60000.00') and record['suggested'] == 'credit'
    # Every transfer still adds up: 60,000 allocated + 40,000 unresolved.
    assert sections['transfer_invariant_breaks']['count'] == 0
    # The standalone reversed supplier payment has no transfer yet.
    unwrapped = sections['unwrapped_supplier_payments']
    assert unwrapped['count'] == 1 and unwrapped['reversed'] == 1
    assert sections['supplier_credit']['count'] == 0
    # Classified as credit, the money is context, not an exception.
    with sessions.begin() as db:
        db.add(m.TransferEvent(supplier_payment_id=ids['transfer'], supplier_id=supplier, kind='credit', amount=40000,
            source_payment_id=record['ledger_payment_id'], occurred_on=TODAY, evidence='Supplier confirmed'))
    after = by_key(fx.build_report(engine))
    assert after['unresolved_transfer_allocations']['count'] == 0
    assert after['supplier_credit']['amount'] == Decimal('40000.00')
    # A transfer whose buckets do not add up is an exception.
    with sessions.begin() as db:
        db.add(m.SupplierPayment(supplier_id=supplier, amount=7000, paid_on=TODAY, method='cash', reference='LOST'))
    broken = by_key(fx.build_report(engine))['transfer_invariant_breaks']
    assert broken['count'] == 1 and broken['amount'] == Decimal('7000.00')
    methods = {r['method']: r for r in sections['ledger_payment_methods']['records']}
    assert methods['mpesa']['paid_out'] == Decimal('60000.00') and methods['cash']['paid_out'] == Decimal('10000.00')
    assert sections['ledger_payment_methods']['reversed_count'] == 2


def test_settlements_not_received_or_paid_twice(sessions, seeded, engine):
    with sessions.begin() as db:
        not_received = _settlement(db, seeded, 'fx-1', status='paid', payment_reference='REF-A',
                                   supplier_confirmation='not_received')
        db.add(m.PayoutConfirmation(settlement_id=not_received.id, supplier_id=seeded['supplier'],
                                    outcome='not_received', amount=9000, payment_reference='REF-A'))
        # Resent after a "not received" answer, then confirmed: two outflows.
        twice = _settlement(db, seeded, 'fx-2', status='paid', payment_reference='REF-C', supplier_confirmation='received')
        db.add_all([m.PayoutConfirmation(settlement_id=twice.id, supplier_id=seeded['supplier'], outcome='not_received',
                                         amount=9000, payment_reference='REF-B'),
                    m.PayoutConfirmation(settlement_id=twice.id, supplier_id=seeded['supplier'], outcome='received',
                                         amount=9000, payment_reference='REF-C')])
        fine = _settlement(db, seeded, 'fx-3', status='paid', payment_reference='REF-D', supplier_confirmation='received')
        db.add(m.PayoutConfirmation(settlement_id=fine.id, supplier_id=seeded['supplier'], outcome='received',
                                    amount=9000, payment_reference='REF-D'))
        ids = {'not_received': not_received.id, 'twice': twice.id}
    section = by_key(fx.build_report(engine))['settlement_payout_problems']
    found = {r['settlement_id']: r for r in section['records']}
    assert set(found) == set(ids.values())
    assert found[ids['twice']]['payment_references'] == ['REF-B', 'REF-C']
    assert found[ids['not_received']]['reasons'] == ['supplier says not received']
    assert section['possible_extra_paid'] == Decimal('9000.00')


def test_expenses_without_category(sessions, engine):
    with without_constraint(engine, 'ledger_debts', 'ledger_expense_category',
                            "(source = 'expense') = (expense_category IS NOT NULL)",
                            "DELETE FROM ledger_debts WHERE source = 'expense' AND expense_category IS NULL"):
        with sessions.begin() as db:
            legacy = m.LedgerDebt(direction='payable', party_kind='other', party_name='Fuel station', amount=15000,
                                  incurred_on=TODAY, source='expense', status='settled', paid_amount=15000)
            db.add(legacy)
            db.add(m.LedgerDebt(direction='payable', party_kind='other', party_name='Shop', amount=7000,
                                incurred_on=TODAY, source='expense', expense_category='other'))
            db.flush(); legacy_id = legacy.id
        section = by_key(fx.build_report(engine))['expenses_without_category']
    assert section['count'] == 1 and section['records'][0]['debt_id'] == legacy_id
    assert section['amount'] == Decimal('15000.00') and section['other_category_count'] == 1


def test_batches_without_movement_or_oversold(sessions, seeded, engine):
    supplier = seeded['supplier']
    old = m.now() - timedelta(days=10)
    with without_constraint(engine, 'supplier_batches', 'valid_batch_allocatable',
                            'reserved_quantity + sold_quantity + externally_sold_quantity <= current_quantity',
                            'DELETE FROM supplier_batches WHERE sold_quantity + externally_sold_quantity > current_quantity'):
        with sessions.begin() as db:
            idle = _batch(db, supplier, created_at=old)
            _batch(db, supplier)  # recent: not stale yet
            _batch(db, supplier, created_at=old, sold_quantity=5)
            collected = _batch(db, supplier, created_at=old)
            db.add(m.SupplierCollection(collection_number='COL-1', supplier_id=supplier, batch_id=collected.id,
                received_on=TODAY, delivered_quantity=5, accepted_quantity=5, rejected_quantity=0, unit_cost=800, amount=4000))
            oversold = _batch(db, supplier, current_quantity=10, sold_quantity=8, externally_sold_quantity=5)
            ids = {'idle': idle.id, 'oversold': oversold.id}
        section = by_key(fx.build_report(engine))['batch_movement_problems']
    found = {r['batch_id']: r for r in section['records']}
    assert set(found) == set(ids.values())
    assert section['no_movement'] == 1 and section['oversold'] == 1
    assert found[ids['oversold']]['excess'] == Decimal('3.000')


def test_cancelled_sale_cost_debts_with_cleared_cost(sessions, seeded, engine):
    supplier = seeded['supplier']
    with sessions.begin() as db:
        profile = _buyer(db)
        cleared, _ = _sale(db, profile, 'SL-0100', [{'subtotal': Decimal('20000')}])
        kept, _ = _sale(db, profile, 'SL-0101', [{'subtotal': Decimal('20000'), 'supplier_id': supplier,
                                                  'unit_cost': 800, 'cost_total': Decimal('16000')}])
        debt = _payable(db, supplier, 16000, sale_id=cleared.id, status='cancelled', cancel_reason='Entered on wrong sale',
                        source='sale_cost')
        # Still costed on the sale: not a cleared cost.
        other = _payable(db, supplier, 16000, sale_id=kept.id, status='cancelled', cancel_reason='Duplicate',
                         source='sale_cost')
        db.flush(); debt_id = debt.id
    section = by_key(fx.build_report(engine))['cancelled_sale_cost_debts']
    assert section['count'] == 1 and section['records'][0]['debt_id'] == debt_id
    assert section['records'][0]['sale_number'] == 'SL-0100' and section['records'][0]['via'] == 'reconciliation'
    assert section['amount'] == Decimal('16000.00')


def _row_counts(engine):
    with engine.connect() as c:
        return {t.name: c.execute(select(func.count()).select_from(t)).scalar() for t in Base.metadata.sorted_tables}


def test_command_writes_nothing(sessions, seeded, engine, monkeypatch, capsys):
    with sessions.begin() as db:
        _sale(db, _buyer(db), 'SL-0200', [{'subtotal': Decimal('20000')}])
    before = _row_counts(engine)
    statements = []

    def watch(conn, cursor, statement, params, context, executemany):
        statements.append(statement)
    event.listen(engine, 'before_cursor_execute', watch)
    monkeypatch.setattr(app_db, 'engine', engine)
    try:
        assert fx.main([]) == 0
        text_out = capsys.readouterr().out
        assert fx.main(['--json']) == 0
        json_out = json.loads(capsys.readouterr().out)
    finally:
        event.remove(engine, 'before_cursor_execute', watch)
    assert 'SL-0200' in text_out and '1. Active sale lines with an unknown buying cost: 1' in text_out
    assert json_out['sections'][0]['amount'] == 20000
    writes = [s for s in statements if s.lstrip().split()[0].upper() in ('INSERT', 'UPDATE', 'DELETE', 'CREATE', 'ALTER', 'DROP', 'TRUNCATE')]
    assert writes == []
    assert any('SET TRANSACTION READ ONLY' in s for s in statements)
    assert _row_counts(engine) == before


def test_read_only_session_refuses_writes(sessions, engine):
    with fx.read_only_session(engine) as db:
        with pytest.raises(DBAPIError, match='read-only transaction'):
            db.execute(text("INSERT INTO promotion_opt_outs (phone, created_at, note) VALUES ('+255700000000', now(), '')"))
    with engine.connect() as c:
        assert c.execute(text('SELECT count(*) FROM promotion_opt_outs')).scalar() == 0
