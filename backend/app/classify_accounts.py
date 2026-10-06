"""Assign historical money movements to their accounts, one at a time
(build plan M2.3, rule R6).

    python -m app.classify_accounts --dry-run
    python -m app.classify_accounts --apply <source_table>:<id> --account <account id> \\
        --evidence "M-Pesa statement line 14 Oct, QX12AB34CD" --by "Maternus Joshua"

The dry run changes nothing. It proposes an account only where evidence on
the record itself identifies one:

- the account's own number (wallet number, last digits of a bank account)
  appears in the movement's reference or note;
- an M-Pesa transaction code (10 capital letters and digits) on an M-Pesa
  movement, when exactly one account is an M-Pesa wallet.

The payment method alone never decides the account. Everything else stays
in the Unassigned (historical) bucket until the finance owner assigns it
with evidence, here or on Finance → Accounts.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from . import accounts, models as m
from .reporting import CASH

MPESA_CODE = re.compile(r'^[A-Z0-9]{10}$')


class ClassifyError(Exception):
    pass


def _proposal(row, wallets, numbered):
    text = f'{row.reference} {row.note}'
    for account in numbered:
        digits = account.number.replace(' ', '')
        if len(digits) >= 4 and digits in text.replace(' ', ''):
            return account, f'account number {account.number} appears on the record'
    if row.method == 'mpesa' and MPESA_CODE.match((row.reference or '').strip()) and len(wallets) == 1:
        return wallets[0], f'M-Pesa transaction code {row.reference.strip()} and one M-Pesa wallet'
    return None, ''


def dry_run(db):
    active = db.scalars(select(m.MoneyAccount).where(m.MoneyAccount.active.is_(True))).all()
    wallets = [a for a in active if a.kind == 'mobile_wallet' and 'pesa' in f'{a.provider} {a.name}'.lower()]
    numbered = [a for a in active if a.number.strip()]
    proposed, unresolved = [], []
    for row in db.execute(select(CASH).where(accounts.unassigned_filter()).order_by(CASH.c.paid_on, CASH.c.created_at)):
        item = {'item': f'{row.source_table}:{row.id}', 'paid_on': row.paid_on, 'flow': row.flow, 'amount': row.amount,
            'method': row.method, 'reference': row.reference, 'party': row.party_name, 'description': row.description}
        account, why = _proposal(row, wallets, numbered)
        if account:
            proposed.append({**item, 'account_id': account.id, 'account': account.name, 'why': why,
                'command': f"python -m app.classify_accounts --apply {item['item']} --account {account.id} "
                           f"--evidence \"{why}\" --by \"<finance owner>\""})
        else:
            unresolved.append(item)
    return {'accounts': [{'id': a.id, 'name': a.name, 'kind': a.kind, 'number': a.number} for a in active],
        'proposed': proposed, 'unresolved': unresolved}


def apply(db, item, account_id, evidence, by):
    evidence, by = (evidence or '').strip(), (by or '').strip()
    if len(evidence) < 3 or len(by) < 3:
        raise ClassifyError('Evidence and --by are required.')
    table, _, source_id = item.partition(':')
    row = db.execute(select(CASH).where(CASH.c.source_table == table, CASH.c.id == source_id,
        accounts.unassigned_filter())).first()
    if not row:
        raise ClassifyError(f'{item} is not an unassigned movement (see --dry-run).')
    account = db.get(m.MoneyAccount, account_id)
    if not account or not account.active:
        raise ClassifyError(f'{account_id} is not an active account.')
    return accounts.assign(db, table, source_id, account, how='historical', evidence=evidence, confirmed_by=by)


def _plain(value):
    if isinstance(value, Decimal):
        return str(value)
    if hasattr(value, 'isoformat'):
        return value.isoformat()
    raise TypeError(type(value).__name__)


def _tzs(value):
    return f'TZS {Decimal(value):,.0f}'


def to_text(report):
    out = ['Money account assignment: dry run (nothing changed)', '']
    out.append('Accounts: ' + (', '.join(f"{a['name']} ({a['id']})" for a in report['accounts']) or 'none yet (D6)'))
    out.append('')
    out.append(f"Proposed from evidence on the record: {len(report['proposed'])}")
    for r in report['proposed']:
        out.append(f"  - {r['item']} {r['paid_on']} {r['flow']} {_tzs(r['amount'])} {r['method']} ref {r['reference'] or '-'}"
                   f" {r['party']}: {r['account']} ({r['why']})")
        out.append(f"    ->  {r['command']}")
    out.append('')
    out.append(f"No evidence on the record (stay Unassigned until the finance owner assigns them): {len(report['unresolved'])}")
    for r in report['unresolved']:
        out.append(f"  - {r['item']} {r['paid_on']} {r['flow']} {_tzs(r['amount'])} {r['method']} ref {r['reference'] or '-'} {r['party']}")
    return '\n'.join(out)


def main(argv=None, ask=input, bind=None):
    parser = argparse.ArgumentParser(description='Assign historical money movements to their accounts, one at a time.')
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--dry-run', action='store_true', help='list what waits; change nothing')
    action.add_argument('--apply', metavar='TABLE:ID', help='assign one movement')
    parser.add_argument('--account', help='the account id (with --apply)')
    parser.add_argument('--evidence', help='what shows it (statement line, SMS, cash book page)')
    parser.add_argument('--by', help='who decided, normally the finance owner')
    parser.add_argument('--confirm', help='the item, to confirm without a prompt')
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
        if not args.account:
            raise ClassifyError('Say which account: --account <id>.')
        with Session(bind) as db, db.begin():
            print(f'{args.apply} -> account {args.account}. Evidence: {args.evidence}')
            given = args.confirm if args.confirm is not None else ask(
                f'Type {args.apply} to confirm (anything else cancels): ').strip()
            if given != args.apply:
                print('Cancelled; nothing changed.')
                db.rollback()
                return 1
            apply(db, args.apply, args.account, args.evidence, args.by)
        print('Recorded.')
        return 0
    except ClassifyError as error:
        print(f'Refused: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
