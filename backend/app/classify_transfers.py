"""Classify historical supplier-transfer money, one item at a time (build plan
M1.2, rule R6: evidence before classification).

Migration 032 reclassifies nothing. Two kinds of history wait here:

1. Unresolved allocations: an allocation of a transfer reversed before
   M1.2. The money left the account, but nobody has said where it is now.
   The finance owner decides, with evidence, that it is
     credit       still with the supplier, usable on their next invoice
                  (decision D5: the suggested default);
     refund       sent back by the supplier, dated when actually received;
     entry_error  never sent: the transfer was recorded too high.
2. Unwrapped payments: payments on registered-supplier invoices recorded
   before every supplier payment became a transfer. Wrapping one records its
   transfer (the same amount, date, method and reference). A reversed one
   then becomes an unresolved allocation to classify as above.

    python -m app.classify_transfers --dry-run [--json]
    python -m app.classify_transfers --apply LEDGER_PAYMENT_ID --as credit \\
        --evidence "Supplier confirmed by phone 3 Oct she still holds it" --by "Maternus Joshua"
    python -m app.classify_transfers --apply ID --as refund --amount 10000 --received-on 2026-10-02 \\
        --method mpesa --reference QJK2... --evidence "M-Pesa SMS ..." --by "..."
    python -m app.classify_transfers --wrap LEDGER_PAYMENT_ID [...] --evidence "..." --by "..."

The dry run changes nothing. Every change asks you to confirm each item by
typing its id (or passing it with --confirm ID); nothing is ever applied by
default or in bulk without that.
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import date
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from . import contracts as c, models as m, services, transfers

CLASSES = ('credit', 'refund', 'entry_error')
DEFAULT_CLASS = 'credit'  # decision D5


class ClassifyError(ValueError):
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


def dry_run(db):
    """What is waiting, with the suggested class and the command for each.
    Reads only."""
    unresolved = transfers.unresolved_items(db)
    unwrapped = transfers.unwrapped_supplier_payments(db)
    names = _names(db, [r['supplier_id'] for r in unresolved + unwrapped])
    for row in unresolved:
        row['supplier'] = names.get(row['supplier_id'])
        row['suggested'] = DEFAULT_CLASS
        row['command'] = (f"python -m app.classify_transfers --apply {row['ledger_payment_id']} --as {DEFAULT_CLASS} "
                          f"--evidence \"...\" --by \"...\"")
    for row in unwrapped:
        row['supplier'] = names.get(row['supplier_id'])
        row['command'] = f"python -m app.classify_transfers --wrap {row['ledger_payment_id']} --evidence \"...\" --by \"...\""
    return {'unresolved': unresolved, 'unwrapped': unwrapped,
            'unresolved_total': sum((r['amount'] for r in unresolved), Decimal('0')),
            'unwrapped_total': sum((r['amount'] for r in unwrapped), Decimal('0'))}


def _item(db, ledger_payment_id):
    found = [row for row in transfers.unresolved_items(db) if row['ledger_payment_id'] == ledger_payment_id]
    if not found:
        raise ClassifyError(f'{ledger_payment_id} is not an unresolved allocation (see --dry-run).')
    return found[0]


def classify(db, ledger_payment_id, as_, evidence, by, amount=None, received_on=None, method=None,
             reference='', operator_id=None):
    """Record one decision on an unresolved allocation. `amount` defaults to
    all that is still unresolved on it; a smaller amount leaves the rest
    unresolved (for example part refunded, part still held as credit)."""
    if as_ not in CLASSES:
        raise ClassifyError(f'--as must be one of {", ".join(CLASSES)}.')
    evidence, by = (evidence or '').strip(), (by or '').strip()
    if len(evidence) < 3:
        raise ClassifyError('Evidence is required: what shows where this money is (R6).')
    if len(by) < 3:
        raise ClassifyError('Say who decided (--by), normally the finance owner.')
    services.commerce_lock(db)
    item = _item(db, ledger_payment_id)
    transfer = db.scalar(select(m.SupplierPayment).where(m.SupplierPayment.id == item['transfer_id']).with_for_update())
    item = _item(db, ledger_payment_id)  # again, under the lock
    amount = Decimal(str(amount)) if amount is not None else item['amount']
    if amount <= 0 or amount > item['amount']:
        raise ClassifyError(f"Amount must be above 0 and at most the unresolved TZS {item['amount']:,.2f}.")
    today = c.business_today()
    event = m.TransferEvent(supplier_payment_id=transfer.id, supplier_id=transfer.supplier_id, kind=as_,
        amount=amount, source_payment_id=ledger_payment_id, occurred_on=today, evidence=evidence,
        reason=f'Classified as {as_.replace("_", " ")} by {by}', recorded_by=operator_id)
    if as_ == 'refund':
        if received_on is None or method is None:
            raise ClassifyError('A refund needs --received-on (when the money came back) and --method.')
        if isinstance(received_on, str):
            received_on = date.fromisoformat(received_on)
        if received_on > today or received_on < transfer.paid_on:
            raise ClassifyError('The refund date must be between the transfer date and today.')
        if method not in m.LEDGER_METHODS:
            raise ClassifyError(f'--method must be one of {", ".join(m.LEDGER_METHODS)}.')
        event.occurred_on, event.method, event.reference = received_on, method, (reference or '').strip()
    db.add(event)
    db.flush()
    if not transfers.balanced(transfers.buckets(db, [transfer.id])[transfer.id]):
        raise ClassifyError('The transfer would no longer add up; nothing was changed.')
    return event


def wrap(db, ledger_payment_id, evidence, by, operator_id=None):
    """Record the transfer behind one payment made before transfers existed."""
    evidence, by = (evidence or '').strip(), (by or '').strip()
    if len(evidence) < 3 or len(by) < 3:
        raise ClassifyError('Evidence and --by are required.')
    services.commerce_lock(db)
    payment = db.scalar(select(m.LedgerPayment).where(m.LedgerPayment.id == ledger_payment_id).with_for_update())
    debt = db.get(m.LedgerDebt, payment.debt_id) if payment else None
    if (not payment or payment.supplier_payment_id or not debt or debt.direction != 'payable'
            or not debt.supplier_id):
        raise ClassifyError(f'{ledger_payment_id} is not a supplier payment without a transfer (see --dry-run).')
    note = f'Recorded before transfers; wrapped by {by}: {evidence}'[:2000]
    transfer = transfers.new_transfer(db, debt.supplier_id, payment.amount, payment.paid_on, payment.method,
        payment.reference, note, operator_id or payment.recorded_by, 'legacy')
    payment.supplier_payment_id = transfer.id
    db.flush()
    return transfer


# ---- command line -----------------------------------------------------------

def _plain(value):
    if isinstance(value, Decimal):
        return str(value)
    if hasattr(value, 'isoformat'):
        return value.isoformat()
    raise TypeError(type(value).__name__)


def _tzs(value):
    return f'TZS {Decimal(value):,.0f}'


def to_text(report):
    out = ['Supplier transfer classification: dry run (nothing changed)', '']
    out.append(f"Unresolved allocations: {len(report['unresolved'])}, {_tzs(report['unresolved_total'])}")
    for r in report['unresolved']:
        out.append(f"  - {r['ledger_payment_id']}: {r['supplier']}, {_tzs(r['amount'])} of transfer "
                   f"{r['transfer_id']} ({r['transfer_paid_on']}, {r['transfer_method']}, ref {r['transfer_reference'] or '-'}, "
                   f"{_tzs(r['transfer_amount'])}); taken off \"{r['debt_description']}\" on {r['reversed_at']:%Y-%m-%d}: "
                   f"{r['reverse_reason'] or '-'}")
        out.append(f"    suggested: {r['suggested']} (D5)  ->  {r['command']}")
    out.append('')
    out.append(f"Supplier payments without a transfer: {len(report['unwrapped'])}, {_tzs(report['unwrapped_total'])}")
    for r in report['unwrapped']:
        out.append(f"  - {r['ledger_payment_id']}: {r['supplier']}, {_tzs(r['amount'])} {r['paid_on']} {r['method']} "
                   f"ref {r['reference'] or '-'} on \"{r['debt_description']}\"{' [reversed]' if r['reversed'] else ''}")
        out.append(f"    ->  {r['command']}")
    return '\n'.join(out)


def _confirm(item_id, given, ask):
    if given is not None:
        return given == item_id
    answer = ask(f'Type the id {item_id} to confirm this change (anything else cancels): ')
    return answer.strip() == item_id


def main(argv=None, ask=input, bind=None):
    parser = argparse.ArgumentParser(description='Classify historical supplier-transfer money, item by item.')
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--dry-run', action='store_true', help='list what waits; change nothing')
    action.add_argument('--apply', metavar='LEDGER_PAYMENT_ID', help='classify one unresolved allocation')
    action.add_argument('--wrap', nargs='+', metavar='LEDGER_PAYMENT_ID', help='record the transfer behind old payments')
    parser.add_argument('--as', dest='as_', choices=CLASSES, help='what the money is (with --apply)')
    parser.add_argument('--amount', help='part of the unresolved amount (default: all of it)')
    parser.add_argument('--received-on', help='refund: the day the money came back (YYYY-MM-DD)')
    parser.add_argument('--method', help='refund: how it came back')
    parser.add_argument('--reference', default='', help='refund: its transaction reference')
    parser.add_argument('--evidence', help='what shows it (statement line, SMS, supplier confirmation)')
    parser.add_argument('--by', help='who decided, normally the finance owner')
    parser.add_argument('--confirm', help='the item id, to confirm without a prompt (one item only)')
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
        if args.apply:
            if not args.as_:
                raise ClassifyError('Say what the money is: --as credit|refund|entry_error.')
            with Session(bind) as db, db.begin():
                item = _item(db, args.apply)
                amount = args.amount or item['amount']
                print(f"{args.apply}: {_tzs(amount)} of transfer {item['transfer_id']} ({item['transfer_paid_on']}, "
                      f"{_tzs(item['transfer_amount'])}) -> {args.as_}. Evidence: {args.evidence}")
                if not _confirm(args.apply, args.confirm, ask):
                    print('Cancelled; nothing changed.')
                    db.rollback()
                    return 1
                classify(db, args.apply, args.as_, args.evidence, args.by, args.amount, args.received_on,
                         args.method, args.reference)
            print('Recorded.')
            return 0
        if args.confirm is not None and len(args.wrap) > 1:
            raise ClassifyError('--confirm confirms one item; wrap several interactively.')
        done = 0
        for payment_id in args.wrap:
            with Session(bind) as db, db.begin():
                payment = db.get(m.LedgerPayment, payment_id)
                if payment is None:
                    raise ClassifyError(f'{payment_id} not found.')
                print(f"{payment_id}: record a transfer of {_tzs(payment.amount)} on {payment.paid_on} ({payment.method}"
                      f"{', reversed: becomes unresolved' if payment.reversed_at else ''}).")
                if not _confirm(payment_id, args.confirm, ask):
                    print('Skipped.')
                    db.rollback()
                    continue
                wrap(db, payment_id, args.evidence, args.by)
                done += 1
        print(f'Wrapped {done} of {len(args.wrap)}.')
        return 0
    except ClassifyError as error:
        print(f'Refused: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
