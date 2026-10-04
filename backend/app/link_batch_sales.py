"""Link historical supplier sale lines to delivery notes, one line at a time
(build plan M1.6, rules R1, R2, R6).

Before M1.6 a sale line could name a registered supplier and its cost with
no physical receipt behind it, and its cost was owed through a `sale_cost`
debt on the sale. Two kinds of active line are listed:

1. unlinked: supplier and cost, but no batch, delivery note or LPO line
   (mostly sold before batch linking existed);
2. batch_line: sold straight from a batch (migration 031) without a note.

Converting a line records, with the confirmation of who saw the goods
received and when, a delivery note (origin 'historical') for exactly that
line from the supplier's batch, with its own batch_receipt payable. The line
then sells from that note, and the sale-cost debt is reduced by the line's
cost (cancelled when it covered only this line). Payments on the sale-cost
debt stay with the supplier who received them (R1): they are taken off it
and re-allocated from the same transfers onto the receipt debt (and back
onto what remains of the sale-cost debt) through the M1.2 transfer model.
Nothing moves cash. Totals owed and paid to the supplier must be the same
before and after, or nothing is changed.

    python -m app.link_batch_sales --dry-run [--json]
    python -m app.link_batch_sales --apply LINE_ID --batch BATCH_ID \\
        --confirm-received-on 2026-09-20 --by "Maternus Joshua" [--confirm LINE_ID]

The dry run changes nothing: it proposes the supplier's oldest open batch of
the same product with enough left, and shows the resulting receipt and how
the debt and its payments map onto it. Ambiguous lines (no batch, not enough
left, a different unit, payments spread over several lines) are listed as
unresolved, with the reason. Every change converts one line, after you type
its id (or pass it with --confirm); there is no bulk or automatic mode.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from datetime import date
from decimal import Decimal
from types import SimpleNamespace

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from . import contracts as c, models as m, services, transfers

ZERO = Decimal('0')


class LinkError(ValueError):
    pass


def _names(db, ids):
    ids = {i for i in ids if i}
    if not ids:
        return {}
    profiles = dict(db.execute(select(m.SupplierProfile.user_id, m.SupplierProfile.legal_name)
        .where(m.SupplierProfile.user_id.in_(ids))).all())
    users = {row.id: row.name or row.phone for row in db.execute(select(m.User.id, m.User.name, m.User.phone)
        .where(m.User.id.in_(ids)))}
    return {i: profiles.get(i) or users.get(i, i) for i in ids}


def _lines(db, line_id=None):
    """Active registered-supplier lines with a cost and no delivery note or
    LPO line, oldest sale first."""
    query = (select(m.SaleItem, m.Sale).join(m.Sale, m.Sale.id == m.SaleItem.sale_id)
        .where(m.Sale.status == 'active', m.SaleItem.supplier_id.is_not(None),
               m.SaleItem.supplier_collection_id.is_(None), m.SaleItem.lpo_line_id.is_(None))
        .order_by(m.Sale.sold_on, m.Sale.created_at, m.Sale.sale_number, m.SaleItem.position))
    if line_id:
        query = query.where(m.SaleItem.id == line_id)
    return db.execute(query).all()


def _debt_for(db, item, sale):
    """The sale-cost debt this line is owed through, and every direct costed
    line of the same supplier on the sale it covers."""
    debt = db.scalar(select(m.LedgerDebt).where(m.LedgerDebt.sale_id == sale.id, m.LedgerDebt.direction == 'payable',
        m.LedgerDebt.source == 'sale_cost', m.LedgerDebt.supplier_id == item.supplier_id,
        m.LedgerDebt.status != 'cancelled').order_by(m.LedgerDebt.created_at))
    lines = db.scalars(select(m.SaleItem).where(m.SaleItem.sale_id == sale.id,
        m.SaleItem.supplier_id == item.supplier_id, m.SaleItem.cost_total.is_not(None),
        m.SaleItem.supplier_collection_id.is_(None), m.SaleItem.lpo_line_id.is_(None))).all()
    return debt, lines


def _batches(db, supplier_id, category):
    return db.scalars(select(m.SupplierBatch).where(m.SupplierBatch.supplier_id == supplier_id,
        m.SupplierBatch.category == category, m.SupplierBatch.status != 'sold')
        .order_by(m.SupplierBatch.created_at, m.SupplierBatch.id)).all()


def _plan(db, item, sale, remaining, batch_id=None):
    """What converting this line would do, or why it cannot be done yet.
    `remaining` is each batch's quantity still free, shared across the dry
    run so two proposals never count the same birds."""
    kind = 'batch_line' if item.supplier_batch_id else 'unlinked'
    view = {'line_id': item.id, 'kind': kind, 'sale_id': sale.id, 'sale_number': sale.sale_number,
            'sold_on': sale.sold_on, 'line': item.position, 'supplier_id': item.supplier_id,
            'category': item.category, 'description': item.description, 'unit': item.unit,
            'quantity': item.quantity, 'unit_cost': item.unit_cost, 'cost': item.cost_total,
            'problems': []}
    problems = view['problems']
    if not item.unit_cost:
        problems.append('no buying cost (or free stock): nothing to put on a receipt')
    expected = c.UNITS.get(item.category)
    if not expected:
        problems.append('the line has no product category to match a batch')
    elif item.unit != expected:
        problems.append(f'sold by {item.unit}, but {item.category.replace("_", " ")} batches count by {expected} '
                        '(needs a documented conversion, M2.1)')
    elif expected != 'kg' and item.quantity % 1:
        problems.append('a fraction of a bird or animal')
    batch = None
    if item.supplier_batch_id:
        batch = db.get(m.SupplierBatch, item.supplier_batch_id)
        if batch_id and batch_id != item.supplier_batch_id:
            problems.append(f'this line already took its birds from batch {item.supplier_batch_id}; use that batch')
        elif batch is None or batch.supplier_id != item.supplier_id or batch.category != item.category:
            problems.append("the line's batch is another supplier's or another product")
    elif expected and not problems:
        if batch_id:
            batch = db.get(m.SupplierBatch, batch_id)
            if batch is None or batch.supplier_id != item.supplier_id or batch.category != item.category:
                problems.append("that batch is not this supplier's batch of this product")
            elif remaining.get(batch.id, batch.available_to_commit) < item.quantity:
                problems.append(f'batch {batch.id} has only {remaining.get(batch.id, batch.available_to_commit)} left')
        else:
            open_ = _batches(db, item.supplier_id, item.category)
            batch = next((row for row in open_ if remaining.get(row.id, row.available_to_commit) >= item.quantity), None)
            if not open_:
                problems.append(f'no open {item.category.replace("_", " ")} batch for this supplier')
            elif batch is None:
                most = max(remaining.get(row.id, row.available_to_commit) for row in open_)
                problems.append(f'no open batch has {item.quantity} left (the most is {most})')
    debt, lines = _debt_for(db, item, sale)
    mapping = None
    if debt is None:
        problems.append('no open supplier-cost debt on the sale for this supplier')
    else:
        owed_lines = sum((line.cost_total for line in lines), ZERO)
        others = owed_lines - (item.cost_total or ZERO)
        paid = debt.paid_amount
        if debt.amount != owed_lines:
            problems.append(f'the debt ({debt.amount}) differs from its lines ({owed_lines}); correct it first')
        elif len(lines) > 1 and ZERO < paid < debt.amount:
            problems.append(f'partly paid ({paid} of {debt.amount}) over {len(lines)} lines: which line was paid is '
                            'not known')
        else:
            moved = paid if len(lines) == 1 else (item.cost_total if paid == debt.amount else ZERO)
            mapping = {'debt_id': debt.id, 'debt_amount': debt.amount, 'debt_paid': paid, 'debt_lines': len(lines),
                'debt_after': None if len(lines) == 1 else others, 'debt_paid_after': paid - moved,
                'receipt_amount': item.cost_total, 'receipt_paid': moved,
                'payments': [{'id': row.id, 'amount': row.amount, 'paid_on': row.paid_on, 'method': row.method,
                    'transfer_id': row.supplier_payment_id} for row in db.scalars(select(m.LedgerPayment).where(
                        m.LedgerPayment.debt_id == debt.id, m.LedgerPayment.reversed_at.is_(None))
                        .order_by(m.LedgerPayment.paid_on, m.LedgerPayment.created_at))],
                'totals_match': (debt.amount == (others if len(lines) > 1 else ZERO) + item.cost_total
                                 and paid == (paid - moved) + moved)}
    view['debt'] = mapping
    if batch is not None:
        view['batch'] = {'id': batch.id, 'category': batch.category, 'subtype': batch.subtype,
            'registered': batch.current_quantity, 'left': remaining.get(batch.id, batch.available_to_commit),
            'created_at': batch.created_at, 'takes_birds': kind == 'unlinked'}
        view['receipt'] = {'received_on': sale.sold_on, 'quantity': item.quantity, 'unit_cost': item.unit_cost,
                           'amount': item.cost_total}
    view['resolved'] = not problems and batch is not None and mapping is not None
    if view['resolved']:
        if kind == 'unlinked':
            remaining[batch.id] = remaining.get(batch.id, batch.available_to_commit) - item.quantity
        view['command'] = (f'python -m app.link_batch_sales --apply {item.id} --batch {batch.id} '
                           f'--confirm-received-on {sale.sold_on} --by "..."')
    return view, batch, debt, lines


def dry_run(db):
    """Every line waiting, with a proposal or the reason it is unresolved."""
    remaining, proposed, unresolved = {}, [], []
    rows = _lines(db)
    names = _names(db, [item.supplier_id for item, _sale in rows])
    for item, sale in rows:
        if item.cost_total is None:
            continue
        view, *_ = _plan(db, item, sale, remaining)
        view['supplier'] = names.get(item.supplier_id)
        (proposed if view['resolved'] else unresolved).append(view)
    return {'proposed': proposed, 'unresolved': unresolved,
            'proposed_cost': sum((row['cost'] for row in proposed), ZERO),
            'unresolved_cost': sum((row['cost'] or ZERO for row in unresolved), ZERO)}


def _supplier_totals(db, supplier_id):
    owed, paid = db.execute(select(func.coalesce(func.sum(m.LedgerDebt.amount), 0),
        func.coalesce(func.sum(m.LedgerDebt.paid_amount), 0)).where(m.LedgerDebt.supplier_id == supplier_id,
        m.LedgerDebt.direction == 'payable', m.LedgerDebt.status != 'cancelled')).one()
    held = transfers.by_supplier(db, [supplier_id]).get(supplier_id, {})
    # Money sent: transfers, plus active payments from before every supplier
    # payment was a transfer (moving one wraps it into a legacy transfer).
    unwrapped = sum((row['amount'] for row in transfers.unwrapped_supplier_payments(db, supplier_id)
                     if not row['reversed']), ZERO)
    return {'owed': Decimal(owed), 'paid': Decimal(paid), 'money_out': held.get('transferred', ZERO) + unwrapped,
            'credit': held.get('credit', ZERO), 'unresolved': held.get('unresolved', ZERO)}


def apply(db, line_id, batch_id, received_on, by, operator_id=None):
    """Convert one line. Raises LinkError (and changes nothing, once the
    caller rolls back) when the line is not resolvable or totals differ."""
    from .batch_stock import record_note, refresh_batch_status
    from .finance import DEBT_FIELDS, ITEM_FIELDS, _apply_credit, _payments, _snapshot, _take_off_invoice, record_adjustment
    by = (by or '').strip()
    if len(by) < 3:
        raise LinkError('Say who confirmed the goods were received (--by), normally the finance owner.')
    if isinstance(received_on, str):
        received_on = date.fromisoformat(received_on)
    services.commerce_lock(db)
    found = _lines(db, line_id)
    if not found:
        raise LinkError(f'{line_id} is not an active supplier line without a delivery note (see --dry-run).')
    item, sale = found[0]
    if received_on > sale.sold_on or received_on > c.business_today():
        raise LinkError(f'The goods must have been received on or before the sale date ({sale.sold_on}).')
    item = db.scalar(select(m.SaleItem).where(m.SaleItem.id == item.id).with_for_update())
    db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == batch_id).with_for_update())
    view, batch, debt, lines = _plan(db, item, sale, {}, batch_id)
    if not view['resolved']:
        raise LinkError('Unresolved: ' + '; '.join(view['problems'] or ['no batch']))
    debt = db.scalar(select(m.LedgerDebt).where(m.LedgerDebt.id == debt.id).with_for_update())
    before_totals = _supplier_totals(db, item.supplier_id)
    mapping = view['debt']
    before = {'item': _snapshot(item, (*ITEM_FIELDS, 'supplier_batch_id', 'supplier_collection_id')),
              'debt': _snapshot(debt, DEBT_FIELDS), 'batch': _snapshot(batch, ('id', 'sold_quantity', 'status')),
              'supplier': {k: str(v) for k, v in before_totals.items()}}
    operator = SimpleNamespace(id=operator_id)
    reason = f'Linked to a delivery note, confirmed received {received_on} by {by}'

    if view['kind'] == 'unlinked':
        batch.sold_quantity += item.quantity
        refresh_batch_status(batch)
    user = db.get(m.User, item.supplier_id)
    note = record_note(db, batch, user, received_on=received_on, delivered=item.quantity, accepted=item.quantity,
        unit_cost=item.unit_cost, recorded_by=operator_id, origin='historical', confirmed_by=operator_id,
        confirmed_by_name=by, sale_id=sale.id, sale_number=sale.sale_number, notify=False,
        notes=f'Linked from sale {sale.sale_number} line {item.position} (sold {sale.sold_on}); '
              f'receipt confirmed by {by}.')
    receipt = db.scalar(select(m.LedgerDebt).where(m.LedgerDebt.id == note.debt_id).with_for_update())
    receipt.due_on = max(debt.due_on or received_on, received_on)

    # Payments stay with the supplier who received them (R1): taken off the
    # sale-cost debt to their credit, then re-allocated from the same
    # transfers, the receipt first. No money moves (R4).
    taken = []
    if debt.paid_amount > 0:
        for row in [row for row in _payments(db, debt.id) if row.reversed_at is None]:
            transfer = _take_off_invoice(db, debt, row, reason, operator, credit=True)
            taken.append((transfer.id, row.amount))
    if mapping['debt_after'] is None:
        debt.status, debt.cancelled_at, debt.cancel_reason = 'cancelled', m.now(), \
            f'Converted to delivery note {note.collection_number} ({by})'
    else:
        debt.amount, debt.status = mapping['debt_after'], 'open'
        debt.description = (debt.description + f' (less {note.collection_number})')[:500]
    db.flush()
    to_receipt = mapping['receipt_paid']
    for transfer_id, amount in taken:
        first = min(amount, to_receipt)
        if first > 0:
            _apply_credit(db, item.supplier_id, first, [receipt], operator, f'Moved to {note.collection_number}', transfer_id)
            to_receipt -= first
        rest = amount - first
        if rest > 0 and debt.status != 'cancelled':
            _apply_credit(db, item.supplier_id, rest, [debt], operator, 'Kept on the sale cost debt', transfer_id)
    if debt.status != 'cancelled':
        debt.status = 'settled' if debt.paid_amount == debt.amount else 'open'
    item.supplier_collection_id, item.supplier_batch_id = note.id, None
    db.flush()

    after_totals = _supplier_totals(db, item.supplier_id)
    if after_totals != before_totals:
        raise LinkError(f'Totals would change ({before_totals} -> {after_totals}); nothing was changed.')
    if receipt.amount != item.cost_total or receipt.paid_amount != mapping['receipt_paid']:
        raise LinkError('The receipt debt does not match the line; nothing was changed.')
    if not all(transfers.balanced(row) for row in transfers.buckets(db, supplier_id=item.supplier_id).values()):
        raise LinkError('A transfer would no longer add up; nothing was changed.')
    after = {'item': _snapshot(item, (*ITEM_FIELDS, 'supplier_batch_id', 'supplier_collection_id')),
             'debt': _snapshot(debt, DEBT_FIELDS), 'receipt_debt': _snapshot(receipt, DEBT_FIELDS),
             'batch': _snapshot(batch, ('id', 'sold_quantity', 'status')),
             'supplier': {k: str(v) for k, v in after_totals.items()}}
    record_adjustment(db, 'historical_batch_link', note, debt, reason, before, after,
        {'collection_id': note.id, 'receipt_debt_id': receipt.id, 'batch_id': batch.id, 'confirmed_by': by,
         'payments_moved': [{'transfer_id': t, 'amount': str(a)} for t, a in taken]},
        operator if operator_id else None, sale_id=sale.id, entity_type='sale_item', entity_id=item.id)
    return note


# ---- command line -----------------------------------------------------------

def _plain(value):
    if isinstance(value, Decimal):
        return str(value)
    if hasattr(value, 'isoformat'):
        return value.isoformat()
    raise TypeError(type(value).__name__)


def _tzs(value):
    return f'TZS {Decimal(value or 0):,.0f}'


def _q(value):
    value = Decimal(value or 0)
    return f'{value.normalize():f}' if value == value.to_integral_value() else str(value)


def to_text(report):
    out = ['Link supplier sale lines to delivery notes: dry run (nothing changed)', '']
    out.append(f"Proposed: {len(report['proposed'])} lines, {_tzs(report['proposed_cost'])}")
    for r in report['proposed']:
        d, b = r['debt'], r['batch']
        out.append(f"  - {r['line_id']}: {r['sale_number']} line {r['line']} ({r['sold_on']}), {r['supplier']}, "
                   f"{_q(r['quantity'])} {r['unit']} {r['category'].replace('_', ' ')} at {_tzs(r['unit_cost'])} = "
                   f"{_tzs(r['cost'])} [{r['kind']}]")
        out.append(f"    batch {b['id']} ({b['category'].replace('_', ' ')}{', ' + b['subtype'] if b['subtype'] else ''}, "
                   f"registered {_q(b['registered'])}, {_q(b['left'])} left, from {b['created_at']:%Y-%m-%d})"
                   f"{'' if b['takes_birds'] else ', birds already taken from it'}")
        out.append(f"    receipt: {_q(r['quantity'])} received on {r['receipt']['received_on']} (confirm the real date), "
                   f"payable {_tzs(d['receipt_amount'])}, paid {_tzs(d['receipt_paid'])}")
        after = 'cancelled' if d['debt_after'] is None else f"{_tzs(d['debt_after'])}, paid {_tzs(d['debt_paid_after'])}"
        out.append(f"    sale-cost debt {d['debt_id']}: {_tzs(d['debt_amount'])}, paid {_tzs(d['debt_paid'])}, "
                   f"{d['debt_lines']} line(s) -> {after}; totals match: {'yes' if d['totals_match'] else 'NO'}")
        for p in d['payments']:
            out.append(f"      payment {p['id']} {_tzs(p['amount'])} {p['paid_on']} {p['method']} "
                       f"(transfer {p['transfer_id'] or 'none yet: recorded as a legacy transfer'}) stays with the supplier")
        out.append(f"    ->  {r['command']}")
    out.append('')
    out.append(f"Unresolved: {len(report['unresolved'])} lines, {_tzs(report['unresolved_cost'])}")
    for r in report['unresolved']:
        out.append(f"  - {r['line_id']}: {r['sale_number']} line {r['line']} ({r['sold_on']}), {r['supplier']}, "
                   f"{_q(r['quantity'])} {r['unit']} {(r['category'] or '?').replace('_', ' ')}, cost {_tzs(r['cost'])}: "
                   + '; '.join(r['problems']))
    return '\n'.join(out)


def _confirm(item_id, given, ask):
    if given is not None:
        return given == item_id
    answer = ask(f'Type the line id {item_id} to confirm this change (anything else cancels): ')
    return answer.strip() == item_id


def main(argv=None, ask=input, bind=None):
    parser = argparse.ArgumentParser(description='Link historical supplier sale lines to delivery notes, one at a time.')
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--dry-run', action='store_true', help='list lines and proposals; change nothing')
    action.add_argument('--apply', metavar='LINE_ID', help='convert one sale line')
    parser.add_argument('--batch', help='the batch the goods came from (with --apply)')
    parser.add_argument('--confirm-received-on', help='the day the goods were physically received (YYYY-MM-DD)')
    parser.add_argument('--by', help='who confirms the goods were received')
    parser.add_argument('--confirm', help='the line id, to confirm without a prompt')
    parser.add_argument('--json', action='store_true', help='dry run as JSON')
    args = parser.parse_args(argv)
    if bind is None:
        from .db import engine as bind

    if args.dry_run:
        with bind.connect() as connection, connection.begin() as transaction:
            with Session(bind=connection) as db:
                report = dry_run(db)
            transaction.rollback()
        print(json.dumps(report, default=_plain, indent=2) if args.json else to_text(report))
        return 0

    try:
        if not args.batch or not args.confirm_received_on:
            raise LinkError('--apply needs --batch and --confirm-received-on (and --by).')
        try:
            received_on = date.fromisoformat(args.confirm_received_on)
        except ValueError:
            raise LinkError('--confirm-received-on must be a date, YYYY-MM-DD.') from None
        with Session(bind) as db, db.begin():
            found = _lines(db, args.apply)
            if not found:
                raise LinkError(f'{args.apply} is not an active supplier line without a delivery note (see --dry-run).')
            item, sale = found[0]
            view, *_ = _plan(db, item, sale, {}, args.batch)
            if not view['resolved']:
                raise LinkError('Unresolved: ' + '; '.join(view['problems'] or ['no batch']))
            d = view['debt']
            print(f"{args.apply}: {sale.sale_number} line {item.position}, {_q(item.quantity)} {item.unit} at "
                  f"{_tzs(item.unit_cost)} -> delivery note from batch {args.batch}, received {received_on}, "
                  f"confirmed by {args.by}. Receipt payable {_tzs(d['receipt_amount'])} (paid {_tzs(d['receipt_paid'])}); "
                  f"sale-cost debt {_tzs(d['debt_amount'])} -> "
                  f"{'cancelled' if d['debt_after'] is None else _tzs(d['debt_after'])}.")
            if not _confirm(args.apply, args.confirm, ask):
                print('Cancelled; nothing changed.')
                db.rollback()
                return 1
            note = apply(db, args.apply, args.batch, received_on, args.by)
            number = note.collection_number
        print(f'Recorded delivery note {number}.')
        return 0
    except LinkError as error:
        print(f'Refused: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
