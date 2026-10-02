"""Supplier transfers, their allocations and supplier credit (build plan M1.2).

A transfer (`supplier_payments`) is the only record that money left an
account to a supplier. Its allocations (`ledger_payments` carrying its id)
spread it over that supplier's invoices. When an allocation is taken off an
invoice the money does not come back: it stays on the same transfer, with the
supplier who received it (rule R1), and `transfer_events` say what it became:

- credit: unapplied supplier credit, usable on their next invoice (D5);
- reallocation: credit applied to another invoice (a new allocation);
- refund: money the supplier actually sent back, a separate dated inflow;
- entry_error: the transfer was recorded too high; no money moved.

A reversed allocation with no such event is *unresolved* (R6): the history
from before this model, waiting for the finance owner to classify it.

For every transfer, always:

    allocated + credit + refunded + entry_error + unresolved = amount

`amount` itself never changes (R3). This module only reads; the writes live
in finance.py (API) and classify_transfers.py (historical classification).
"""
from __future__ import annotations

from collections import defaultdict
from decimal import Decimal

from sqlalchemy import func, select

from . import models as m

ZERO = Decimal('0')
BUCKETS = ('allocated', 'credit', 'refunded', 'entry_error', 'unresolved')


def buckets(db, transfer_ids=None, supplier_id=None):
    """Where each transfer's money is now: {transfer id: {amount, allocated,
    credit, refunded, entry_error, unresolved, transferred, net_paid}}.

    transferred = amount less entry errors: what really left the account.
    net_paid = transferred less refunds: what the supplier kept."""
    T, P, E = m.SupplierPayment, m.LedgerPayment, m.TransferEvent
    query = select(T.id, T.amount)
    if transfer_ids is not None:
        transfer_ids = list(transfer_ids)
        if not transfer_ids:
            return {}
        query = query.where(T.id.in_(transfer_ids))
    if supplier_id is not None:
        query = query.where(T.supplier_id == supplier_id)
    amounts = dict(db.execute(query).all())
    if not amounts:
        return {}
    ids = list(amounts)
    allocations = {row[0]: (row[1], row[2]) for row in db.execute(select(P.supplier_payment_id,
            func.coalesce(func.sum(P.amount).filter(P.reversed_at.is_(None)), 0),
            func.coalesce(func.sum(P.amount).filter(P.reversed_at.is_not(None)), 0))
        .where(P.supplier_payment_id.in_(ids)).group_by(P.supplier_payment_id))}
    sourced = E.source_payment_id.is_not(None)
    events = defaultdict(lambda: ZERO)
    for transfer_id, kind, from_allocation, total in db.execute(select(E.supplier_payment_id, E.kind, sourced,
            func.sum(E.amount)).where(E.supplier_payment_id.in_(ids)).group_by(E.supplier_payment_id, E.kind, sourced)):
        events[(transfer_id, kind, bool(from_allocation))] += total
    out = {}
    for transfer_id, amount in amounts.items():
        active, reversed_ = allocations.get(transfer_id, (ZERO, ZERO))
        def event(kind, from_allocation):
            return events.get((transfer_id, kind, from_allocation), ZERO)
        # Reversed allocations already decided: credit, or straight to a
        # refund or entry error. The rest is unresolved.
        classified = event('credit', True) + event('refund', True) + event('entry_error', True)
        credit = (event('credit', True) - event('reallocation', False)
                  - event('refund', False) - event('entry_error', False))
        refunded = event('refund', True) + event('refund', False)
        entry_error = event('entry_error', True) + event('entry_error', False)
        out[transfer_id] = {'amount': amount, 'allocated': active, 'credit': credit, 'refunded': refunded,
            'entry_error': entry_error, 'unresolved': reversed_ - classified,
            'transferred': amount - entry_error, 'net_paid': amount - entry_error - refunded}
    return out


def balanced(row):
    """The invariant: every shilling of the transfer is in exactly one bucket."""
    return sum((row[key] for key in BUCKETS), ZERO) == row['amount'] and all(row[key] >= 0 for key in BUCKETS)


def by_supplier(db, supplier_ids=None):
    """Per supplier: the sum of their transfers' buckets."""
    T = m.SupplierPayment
    query = select(T.id, T.supplier_id)
    if supplier_ids is not None:
        supplier_ids = list(supplier_ids)
        if not supplier_ids:
            return {}
        query = query.where(T.supplier_id.in_(supplier_ids))
    owners = dict(db.execute(query).all())
    totals = {}
    for transfer_id, row in buckets(db, owners).items():
        entry = totals.setdefault(owners[transfer_id], {key: ZERO for key in
            ('amount', 'transferred', 'net_paid', *BUCKETS)} | {'transfers': 0})
        entry['transfers'] += 1
        for key, value in row.items():
            entry[key] += value
    return totals


def credit_by_supplier(db, supplier_ids=None):
    """Unapplied credit each supplier holds (only suppliers with some)."""
    return {supplier: row['credit'] for supplier, row in by_supplier(db, supplier_ids).items() if row['credit'] > 0}


def unresolved_items(db, supplier_id=None, transfer_id=None):
    """Reversed allocations of transfers whose money is not yet classified
    (or only partly): each still needs a decision with evidence (R6)."""
    P, T, E, D = m.LedgerPayment, m.SupplierPayment, m.TransferEvent, m.LedgerDebt
    query = (select(P, T, D).join(T, T.id == P.supplier_payment_id).join(D, D.id == P.debt_id)
        .where(P.reversed_at.is_not(None)).order_by(T.paid_on, P.reversed_at))
    if supplier_id is not None:
        query = query.where(T.supplier_id == supplier_id)
    if transfer_id is not None:
        query = query.where(T.id == transfer_id)
    rows = db.execute(query).all()
    if not rows:
        return []
    decided = dict(db.execute(select(E.source_payment_id, func.sum(E.amount))
        .where(E.source_payment_id.in_([row[0].id for row in rows])).group_by(E.source_payment_id)).all())
    items = []
    for allocation, transfer, debt in rows:
        left = allocation.amount - decided.get(allocation.id, ZERO)
        if left > 0:
            items.append({'ledger_payment_id': allocation.id, 'amount': left, 'allocation_amount': allocation.amount,
                'reversed_at': allocation.reversed_at, 'reverse_reason': allocation.reverse_reason,
                'debt_id': debt.id, 'debt_description': debt.description, 'debt_party': debt.party_name,
                'transfer_id': transfer.id, 'supplier_id': transfer.supplier_id, 'transfer_amount': transfer.amount,
                'transfer_paid_on': transfer.paid_on, 'transfer_method': transfer.method,
                'transfer_reference': transfer.reference})
    return items


def unwrapped_supplier_payments(db, supplier_id=None):
    """Payments on registered-supplier invoices recorded before every outflow
    became a transfer: they have no transfer yet (rule R3). Active ones are
    still counted as money out by themselves; reversed ones are listed so the
    finance owner can say whether money really left."""
    P, D = m.LedgerPayment, m.LedgerDebt
    query = (select(P, D).join(D, D.id == P.debt_id)
        .where(P.supplier_payment_id.is_(None), D.direction == 'payable', D.supplier_id.is_not(None))
        .order_by(P.paid_on, P.created_at))
    if supplier_id is not None:
        query = query.where(D.supplier_id == supplier_id)
    return [{'ledger_payment_id': payment.id, 'amount': payment.amount, 'paid_on': payment.paid_on,
             'method': payment.method, 'reference': payment.reference, 'note': payment.note,
             'reversed': payment.reversed_at is not None, 'reverse_reason': payment.reverse_reason,
             'debt_id': debt.id, 'debt_description': debt.description, 'supplier_id': debt.supplier_id}
            for payment, debt in db.execute(query).all()]


def new_transfer(db, supplier_id, amount, paid_on, method, reference='', note='', recorded_by=None,
                 origin='single', sms_text='', receipt_media_id=None):
    row = m.SupplierPayment(supplier_id=supplier_id, amount=amount, paid_on=paid_on, method=method,
        reference=(reference or '').strip(), note=(note or '').strip(), recorded_by=recorded_by, origin=origin,
        sms_text=(sms_text or '').strip(), receipt_media_id=receipt_media_id)
    db.add(row)
    db.flush()
    return row
