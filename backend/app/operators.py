"""Operator accounts from the server's command line. Needed once, to create
the first admin; after that admins add staff from the dashboard.

    .venv/bin/python -m app.operators add +255712345678 "Asha Mwita" --admin
    .venv/bin/python -m app.operators list
"""
import argparse
import re

from sqlalchemy import select

from . import models as m


def add_operator(db, phone, name, role):
    if not re.fullmatch(r'\+255[67]\d{8}', phone):
        raise SystemExit('Use a Tanzanian mobile number like +255712345678.')
    existing = db.scalar(select(m.Operator).where(m.Operator.phone == phone))
    if existing:
        existing.name, existing.role, existing.active = name, role, True
        return existing, False
    row = m.Operator(phone=phone, name=name, role=role)
    db.add(row)
    db.flush()
    return row, True


def main(argv=None):
    parser = argparse.ArgumentParser(prog='python -m app.operators')
    commands = parser.add_subparsers(dest='command', required=True)
    add = commands.add_parser('add', help='add or reactivate an operator')
    add.add_argument('phone')
    add.add_argument('name')
    add.add_argument('--admin', action='store_true')
    commands.add_parser('list', help='list operators')
    args = parser.parse_args(argv)

    from .config import settings
    from .db import Session
    settings().validate_runtime()
    with Session.begin() as db:
        if args.command == 'add':
            row, created = add_operator(db, args.phone, args.name, 'admin' if args.admin else 'staff')
            print(f"{'Added' if created else 'Updated'} {row.role} {row.name} ({row.phone}).")
        else:
            for row in db.scalars(select(m.Operator).order_by(m.Operator.name)):
                print(f"{row.name:<30} {row.phone:<15} {row.role:<6} {'active' if row.active else 'removed'}")


if __name__ == '__main__':
    main()
