"""Read-only finance exception report (build plan M0.3).

    python -m app.finance_exceptions          # readable text report
    python -m app.finance_exceptions --json   # machine-readable

Connects with the normal settings database URL, opens one READ ONLY
transaction and always rolls it back: it can never change data. It lists the
records that make finance figures provisional (rule R5: unknown is not zero)
so the finance owner can classify them with evidence (R6).
"""
from __future__ import annotations

import argparse
import json
import sys
from contextlib import contextmanager
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

from sqlalchemy import and_, exists, func, or_, select, text
from sqlalchemy.orm import Session

from . import models as m, transfers

ZERO = Decimal('0')
STALE_BATCH_DAYS = 7


@contextmanager
def read_only_session(bind):
    """A session whose transaction PostgreSQL itself refuses to write in.
    Rolled back on exit; nothing is ever committed."""
    with bind.connect() as connection:
        transaction = connection.begin()
        try:
            connection.execute(text('SET TRANSACTION READ ONLY'))
            with Session(bind=connection, autoflush=False) as session:
                yield session
        finally:
            transaction.rollback()


def _money(value):
    return Decimal(value or 0).quantize(Decimal('0.01'))


def _supplier_names(db, ids):
    ids = {i for i in ids if i}
    if not ids:
        return {}
    rows = db.execute(select(m.User.id, m.User.name, m.User.phone).where(m.User.id.in_(ids))).all()
    return {row.id: row.name or row.phone for row in rows}


def _section(key, title, records, amount_label, amount, note='', **extra):
    return {'key': key, 'title': title, 'count': len(records), 'amount_label': amount_label,
            'amount': _money(amount), 'note': note, 'records': records, **extra}


def unknown_cost_lines(db):
    rows = db.execute(select(m.Sale.sale_number, m.Sale.sold_on, m.SaleItem.id, m.SaleItem.position,
            m.SaleItem.description, m.SaleItem.quantity, m.SaleItem.unit, m.SaleItem.subtotal)
        .join(m.Sale, m.Sale.id == m.SaleItem.sale_id)
        .where(m.Sale.status == 'active', or_(m.SaleItem.unit_cost.is_(None), m.SaleItem.cost_total.is_(None)))
        .order_by(m.Sale.sold_on, m.Sale.sale_number, m.SaleItem.position)).all()
    records = [{'sale_number': r.sale_number, 'sold_on': r.sold_on, 'sale_item_id': r.id, 'line': r.position,
                'description': r.description, 'quantity': r.quantity, 'unit': r.unit, 'revenue': _money(r.subtotal)}
               for r in rows]
    return _section('unknown_cost_lines', 'Active sale lines with no known cost (own stock)', records,
        'revenue affected', sum((r['revenue'] for r in records), ZERO),
        'Profit on these sales is provisional (R5).', sales=len({r['sale_number'] for r in records}))


def supplier_lines_without_source(db):
    rows = db.execute(select(m.Sale.sale_number, m.Sale.sold_on, m.SaleItem.id, m.SaleItem.position,
            m.SaleItem.description, m.SaleItem.supplier_id, m.SaleItem.subtotal, m.SaleItem.cost_total)
        .join(m.Sale, m.Sale.id == m.SaleItem.sale_id)
        .where(m.Sale.status == 'active', m.SaleItem.supplier_id.is_not(None),
               m.SaleItem.supplier_batch_id.is_(None), m.SaleItem.supplier_collection_id.is_(None),
               m.SaleItem.lpo_line_id.is_(None))
        .order_by(m.Sale.sold_on, m.Sale.sale_number, m.SaleItem.position)).all()
    names = _supplier_names(db, [r.supplier_id for r in rows])
    records = [{'sale_number': r.sale_number, 'sold_on': r.sold_on, 'sale_item_id': r.id, 'line': r.position,
                'description': r.description, 'supplier': names.get(r.supplier_id, r.supplier_id),
                'supplier_id': r.supplier_id, 'revenue': _money(r.subtotal), 'cost': _money(r.cost_total)}
               for r in rows]
    return _section('supplier_lines_without_source',
        'Registered-supplier sale lines with no batch, collection or LPO line', records,
        'supplier cost', sum((r['cost'] for r in records), ZERO),
        'No physical receipt backs these costs (R2).',
        revenue=_money(sum((r['revenue'] for r in records), ZERO)))


def unresolved_transfer_allocations(db):
    """Reversed allocations of transfers whose money has no decision yet
    (from before M1.2). The money left the account; the finance owner
    classifies each as credit, refund or entry error with evidence via
    `python -m app.classify_transfers` (R3, R4, R6)."""
    items = transfers.unresolved_items(db)
    held = transfers.buckets(db, {r['transfer_id'] for r in items})
    names = _supplier_names(db, [r['supplier_id'] for r in items])
    records = [{'ledger_payment_id': r['ledger_payment_id'], 'debt_id': r['debt_id'], 'amount': _money(r['amount']),
                'reversed_at': r['reversed_at'], 'reverse_reason': r['reverse_reason'], 'transfer_id': r['transfer_id'],
                'supplier': names.get(r['supplier_id'], r['supplier_id']), 'transfer_paid_on': r['transfer_paid_on'],
                'transfer_reference': r['transfer_reference'], 'transfer_amount': _money(r['transfer_amount']),
                'transfer_active_allocations': _money(held[r['transfer_id']]['allocated']),
                'suggested': 'credit'}
               for r in items]
    return _section('unresolved_transfer_allocations', 'Unresolved allocations of supplier transfers', records,
        'unresolved', sum((r['amount'] for r in records), ZERO),
        'The money left the account; classify each as credit (D5 default), refund or entry error with evidence: '
        'python -m app.classify_transfers --dry-run (R3, R4, R6).',
        transfers=len({r['transfer_id'] for r in records}))


def transfer_invariant_breaks(db):
    """Transfers whose money does not add up: allocated + credit + refunded +
    entry errors + unresolved must equal the transfer, every bucket >= 0."""
    rows = db.scalars(select(m.SupplierPayment).order_by(m.SupplierPayment.paid_on)).all()
    held = transfers.buckets(db, [r.id for r in rows])
    names = _supplier_names(db, [r.supplier_id for r in rows])
    records = []
    for row in rows:
        b = held[row.id]
        if not transfers.balanced(b):
            accounted = sum((b[k] for k in transfers.BUCKETS), ZERO)
            records.append({'transfer_id': row.id, 'supplier': names.get(row.supplier_id, row.supplier_id),
                'paid_on': row.paid_on, 'method': row.method, 'reference': row.reference,
                'transfer_amount': _money(row.amount), **{k: _money(b[k]) for k in transfers.BUCKETS},
                'difference': _money(row.amount - accounted)})
    return _section('transfer_invariant_breaks', 'Supplier transfers whose money does not add up', records,
        'difference', sum((abs(r['difference']) for r in records), ZERO),
        'allocated + credit + refunded + entry error + unresolved must equal the transfer amount.')


def unwrapped_supplier_payments(db):
    rows = transfers.unwrapped_supplier_payments(db)
    names = _supplier_names(db, [r['supplier_id'] for r in rows])
    records = [{**r, 'amount': _money(r['amount']), 'supplier': names.get(r['supplier_id'], r['supplier_id'])}
               for r in rows]
    return _section('unwrapped_supplier_payments', 'Supplier payments recorded before transfers (no transfer yet)',
        records, 'amount', sum((r['amount'] for r in records), ZERO),
        'Every outflow to a supplier must be a transfer (R3). Wrap with python -m app.classify_transfers --wrap.',
        reversed=sum(1 for r in records if r['reversed']))


def supplier_credit(db):
    rows = db.scalars(select(m.SupplierPayment).order_by(m.SupplierPayment.paid_on)).all()
    held = transfers.buckets(db, [r.id for r in rows])
    names = _supplier_names(db, [r.supplier_id for r in rows])
    records = [{'transfer_id': r.id, 'supplier': names.get(r.supplier_id, r.supplier_id), 'paid_on': r.paid_on,
                'reference': r.reference, 'transfer_amount': _money(r.amount), 'credit': _money(held[r.id]['credit'])}
               for r in rows if held[r.id]['credit'] > 0]
    return _section('supplier_credit', 'Unapplied supplier credit (context)', records,
        'credit held', sum((r['credit'] for r in records), ZERO),
        'Money suppliers hold from payments taken off invoices; it goes on their next invoice (D5). Not an exception.')


def settlement_payout_problems(db):
    history = {}
    for row in db.execute(select(m.PayoutConfirmation.settlement_id, m.PayoutConfirmation.outcome,
            m.PayoutConfirmation.payment_reference, m.PayoutConfirmation.created_at)
            .order_by(m.PayoutConfirmation.created_at)):
        history.setdefault(row.settlement_id, []).append(row)
    candidates = db.scalars(select(m.Settlement).where(or_(m.Settlement.supplier_confirmation == 'not_received',
        m.Settlement.id.in_(list(history) or ['']))).order_by(m.Settlement.created_at)).all()
    names = _supplier_names(db, [r.supplier_id for r in candidates])
    records = []
    for row in candidates:
        answers = history.get(row.id, [])
        references = []
        for ref in [a.payment_reference for a in answers] + ([row.payment_reference] if row.status == 'paid' else []):
            ref = (ref or '').strip()
            if ref and ref not in references:
                references.append(ref)
        reasons = []
        if row.supplier_confirmation == 'not_received':
            reasons.append('supplier says not received')
        if len(references) > 1:
            reasons.append(f'paid {len(references)} times')
        if reasons:
            records.append({'settlement_id': row.id, 'supplier': names.get(row.supplier_id, row.supplier_id),
                'status': row.status, 'total_payable': _money(row.total_payable),
                'supplier_confirmation': row.supplier_confirmation, 'payment_references': references,
                'answers': [a.outcome for a in answers], 'reasons': reasons,
                'possible_extra_paid': _money(row.total_payable) * max(len(references) - 1, 0)})
    return _section('settlement_payout_problems', 'Marketplace settlements not received or paid more than once',
        records, 'payable at issue', sum((r['total_payable'] for r in records), ZERO),
        'Each extra reference is a separate outflow until proven failed (R3).',
        possible_extra_paid=_money(sum((r['possible_extra_paid'] for r in records), ZERO)))


def expenses_without_category(db):
    rows = db.scalars(select(m.LedgerDebt).where(m.LedgerDebt.source == 'expense',
        m.LedgerDebt.expense_category.is_(None), m.LedgerDebt.status != 'cancelled')
        .order_by(m.LedgerDebt.incurred_on)).all()
    records = [{'debt_id': r.id, 'incurred_on': r.incurred_on, 'party': r.party_name, 'description': r.description,
                'amount': _money(r.amount), 'status': r.status} for r in rows]
    other = db.execute(select(func.count(), func.coalesce(func.sum(m.LedgerDebt.amount), 0))
        .where(m.LedgerDebt.source == 'expense', m.LedgerDebt.expense_category == 'other',
               m.LedgerDebt.status != 'cancelled')).one()
    return _section('expenses_without_category', 'Expenses with no category', records,
        'amount', sum((r['amount'] for r in records), ZERO),
        'Context: expenses filed under "other" are listed as a count only.',
        other_category_count=other[0], other_category_amount=_money(other[1]))


def batch_movement_problems(db, now=None):
    cutoff = (now or datetime.now(timezone.utc)) - timedelta(days=STALE_BATCH_DAYS)
    B = m.SupplierBatch
    stale = db.scalars(select(B).where(B.created_at < cutoff, B.sold_quantity == 0,
        B.externally_sold_quantity == 0,
        ~exists().where(m.SupplierCollection.batch_id == B.id, m.SupplierCollection.cancelled_at.is_(None)),
        ~exists().where(m.SaleItem.supplier_batch_id == B.id),
        ~exists().where(m.SupplierBatchMovement.batch_id == B.id)).order_by(B.created_at)).all()
    over = db.scalars(select(B).where(B.sold_quantity + B.externally_sold_quantity > B.current_quantity)
        .order_by(B.created_at)).all()
    names = _supplier_names(db, [r.supplier_id for r in stale + over])

    def view(row, problem):
        return {'batch_id': row.id, 'supplier': names.get(row.supplier_id, row.supplier_id),
                'category': row.category, 'status': row.status, 'created_at': row.created_at,
                'current_quantity': row.current_quantity, 'sold_quantity': row.sold_quantity,
                'externally_sold_quantity': row.externally_sold_quantity,
                'reserved_quantity': row.reserved_quantity, 'problem': problem,
                'excess': max(row.sold_quantity + row.externally_sold_quantity - row.current_quantity, ZERO)}
    records = [view(r, f'no movement for over {STALE_BATCH_DAYS} days') for r in stale]
    records += [view(r, 'sold + sold elsewhere exceeds current quantity') for r in over]
    return _section('batch_movement_problems', 'Supplier batches with no movement or oversold', records,
        'n/a', ZERO, 'Quantities, not money.', no_movement=len(stale), oversold=len(over))


def cancelled_sale_cost_debts(db):
    D, I = m.LedgerDebt, m.SaleItem
    costed_match = exists().where(I.sale_id == D.sale_id, I.unit_cost.is_not(None), or_(
        and_(D.supplier_id.is_not(None), I.supplier_id == D.supplier_id),
        and_(D.supplier_id.is_(None), I.supplier_id.is_(None), func.lower(I.supplier_name) == func.lower(D.party_name))))
    rows = db.execute(select(D, m.Sale.sale_number, m.Sale.status.label('sale_status'))
        .join(m.Sale, m.Sale.id == D.sale_id)
        .where(D.source == 'sale_cost', D.status == 'cancelled', D.cancel_reason != '',
               m.Sale.status == 'active', ~costed_match,
               # A reasoned correction (M1.4) records what changed and why.
               ~exists().where(m.FinancialAdjustment.entity_id == D.id))
        .order_by(D.cancelled_at)).all()
    records = [{'debt_id': r.LedgerDebt.id, 'sale_number': r.sale_number, 'supplier': r.LedgerDebt.party_name,
                'amount': _money(r.LedgerDebt.amount), 'cancelled_at': r.LedgerDebt.cancelled_at,
                'cancel_reason': r.LedgerDebt.cancel_reason,
                'via': 'sale edit' if r.LedgerDebt.cancel_reason.startswith('Sale edited') else 'reconciliation'}
               for r in rows]
    return _section('cancelled_sale_cost_debts', 'Supplier cost debts cancelled with the sale cost cleared', records,
        'cost removed', sum((r['amount'] for r in records), ZERO),
        'Removing a cost raises profit; confirm each was really an entry error (audit F06).')


def ledger_payment_methods(db):
    P, D = m.LedgerPayment, m.LedgerDebt
    rows = db.execute(select(P.method, D.direction, func.count(), func.sum(P.amount))
        .join(D, D.id == P.debt_id).where(P.reversed_at.is_(None))
        .group_by(P.method, D.direction).order_by(P.method, D.direction)).all()
    by_method = {}
    for method, direction, count, amount in rows:
        entry = by_method.setdefault(method, {'method': method, 'count': 0, 'received': ZERO, 'paid_out': ZERO})
        entry['count'] += count
        entry['received' if direction == 'receivable' else 'paid_out'] += _money(amount)
    records = list(by_method.values())
    reversed_row = db.execute(select(func.count(), func.coalesce(func.sum(P.amount), 0))
        .where(P.reversed_at.is_not(None))).one()
    return _section('ledger_payment_methods', 'Active ledger payments by method (context)', records,
        'total recorded', sum((r['received'] + r['paid_out'] for r in records), ZERO),
        'Context for mapping methods to real cash, bank and mobile-money accounts. Not an exception.',
        reversed_count=reversed_row[0], reversed_amount=_money(reversed_row[1]))


CHECKS = (unknown_cost_lines, supplier_lines_without_source, unresolved_transfer_allocations,
          transfer_invariant_breaks, settlement_payout_problems, expenses_without_category,
          batch_movement_problems, cancelled_sale_cost_debts, unwrapped_supplier_payments,
          supplier_credit, ledger_payment_methods)
# Sections that give context and are never counted as exceptions.
CONTEXT = {'supplier_credit', 'ledger_payment_methods'}


def collect(db):
    sections = [check(db) for check in CHECKS]
    return {'generated_at': datetime.now(timezone.utc), 'currency': 'TZS',
            'database': db.get_bind().engine.url.render_as_string(hide_password=True),
            'sections': sections}


def build_report(bind):
    with read_only_session(bind) as db:
        return collect(db)


# ---- output -----------------------------------------------------------------

def _plain(value):
    if isinstance(value, Decimal):
        return int(value) if value == value.to_integral_value() else float(value)
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    raise TypeError(f'not JSON serialisable: {type(value).__name__}')


def to_json(report):
    return json.dumps(report, default=_plain, indent=2)


def _tzs(value):
    return f'TZS {Decimal(value):,.0f}'


def _line(section, r):
    k = section['key']
    if k == 'unknown_cost_lines':
        return f"{r['sale_number']} line {r['line']} ({r['sold_on']}): {r['description']} {r['quantity']} {r['unit']}, revenue {_tzs(r['revenue'])}"
    if k == 'supplier_lines_without_source':
        return f"{r['sale_number']} line {r['line']}: {r['supplier']}, {r['description']}, cost {_tzs(r['cost'])}"
    if k == 'unresolved_transfer_allocations':
        return (f"{r['supplier']} transfer {r['transfer_id']} ({r['transfer_paid_on']}, ref {r['transfer_reference'] or '-'}) "
                f"{_tzs(r['transfer_amount'])}, active allocations {_tzs(r['transfer_active_allocations'])}; "
                f"unresolved {_tzs(r['amount'])} from allocation {r['ledger_payment_id']} on debt {r['debt_id']}: "
                f"{r['reverse_reason'] or '-'} (suggested: {r['suggested']})")
    if k == 'transfer_invariant_breaks':
        return (f"{r['supplier']} transfer {r['transfer_id']} ({r['paid_on']}, {r['method']}, ref {r['reference'] or '-'}): "
                f"{_tzs(r['transfer_amount'])} vs allocated {_tzs(r['allocated'])} + credit {_tzs(r['credit'])} + refunded "
                f"{_tzs(r['refunded'])} + entry error {_tzs(r['entry_error'])} + unresolved {_tzs(r['unresolved'])}")
    if k == 'unwrapped_supplier_payments':
        return (f"{r['supplier']} payment {r['ledger_payment_id']} ({r['paid_on']}, {r['method']}, ref {r['reference'] or '-'}) "
                f"{_tzs(r['amount'])} on {r['debt_description']}{' [reversed]' if r['reversed'] else ''}")
    if k == 'supplier_credit':
        return f"{r['supplier']} transfer {r['transfer_id']} ({r['paid_on']}) {_tzs(r['transfer_amount'])}: credit {_tzs(r['credit'])}"
    if k == 'settlement_payout_problems':
        return (f"{r['supplier']} settlement {r['settlement_id']}: {_tzs(r['total_payable'])}, "
                f"{'; '.join(r['reasons'])}, refs {', '.join(r['payment_references']) or '-'}")
    if k == 'expenses_without_category':
        return f"debt {r['debt_id']} ({r['incurred_on']}) {r['party']}: {r['description']} {_tzs(r['amount'])}"
    if k == 'batch_movement_problems':
        return (f"{r['supplier']} batch {r['batch_id']} {r['category']} ({r['status']}): {r['problem']}; "
                f"current {r['current_quantity']}, sold {r['sold_quantity']}, elsewhere {r['externally_sold_quantity']}")
    if k == 'cancelled_sale_cost_debts':
        return f"{r['sale_number']} debt {r['debt_id']} {r['supplier']} {_tzs(r['amount'])} [{r['via']}]: {r['cancel_reason']}"
    if k == 'ledger_payment_methods':
        return f"{r['method']}: {r['count']} payments, received {_tzs(r['received'])}, paid out {_tzs(r['paid_out'])}"
    return str(r)


def to_text(report, limit=None):
    out = ['Omoterra finance exception report (read-only)',
           f"Generated {report['generated_at']:%Y-%m-%d %H:%M} UTC from {report['database']}", '']
    for number, section in enumerate(report['sections'], 1):
        amount = '' if section['amount_label'] == 'n/a' else f", {section['amount_label']} {_tzs(section['amount'])}"
        out.append(f"{number}. {section['title']}: {section['count']}{amount}")
        extras = {k: v for k, v in section.items()
                  if k not in ('key', 'title', 'count', 'amount_label', 'amount', 'note', 'records')}
        if extras:
            out.append('   ' + ', '.join(f"{k.replace('_', ' ')} {_tzs(v) if isinstance(v, Decimal) else v}"
                                         for k, v in extras.items()))
        if section['note']:
            out.append('   ' + section['note'])
        shown = section['records'] if limit is None else section['records'][:limit]
        out.extend('   - ' + _line(section, r) for r in shown)
        if len(shown) < len(section['records']):
            out.append(f"   ... {len(section['records']) - len(shown)} more (use --json or --limit 0)")
        out.append('')
    flagged = [s for s in report['sections'] if s['key'] not in CONTEXT and s['count']]
    out.append(f"Sections with exceptions: {len(flagged)} of {len(report['sections']) - len(CONTEXT)}")
    return '\n'.join(out)


def main(argv=None):
    parser = argparse.ArgumentParser(description='Read-only finance exception report.')
    parser.add_argument('--json', action='store_true', help='print JSON instead of text')
    parser.add_argument('--limit', type=int, default=50, help='records per section in text output (0 = all)')
    args = parser.parse_args(argv)
    from .db import engine
    report = build_report(engine)
    print(to_json(report) if args.json else to_text(report, args.limit or None))
    return 0


if __name__ == '__main__':
    sys.exit(main())
