"""Backend side of the Playwright suite (ops/e2e).

    python harness.py serve          fresh database, schema from the models, uvicorn
    python harness.py seed operator  empty every table, sign in one admin operator
    python harness.py seed debts     the same, plus 66 debts (18 open)
    python harness.py member <id>    a portal session for an existing user

`seed` and `member` print JSON for the tests. Everything here works on the
database named by OMOTERRA_E2E_DATABASE_URL, which must be a local, disposable
database whose name contains "e2e": `serve` drops and recreates it.
"""
from __future__ import annotations

import json
import os
import secrets
import sys
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))

DEFAULT_URL = 'postgresql+psycopg://omoterra:omoterra@localhost:55432/omoterra_e2e'
URL = os.environ.get('OMOTERRA_E2E_DATABASE_URL', DEFAULT_URL)
PORT = int(os.environ.get('OMOTERRA_E2E_API_PORT', '18765'))
OPS_TOKEN = os.environ.get('OMOTERRA_E2E_OPS_TOKEN', 'e2e-operations-token')
LOCAL_HOSTS = {'localhost', '127.0.0.1', '::1', 'postgres'}


def _check_target():
    parts = urlsplit(URL)
    name = parts.path.lstrip('/')
    if parts.hostname not in LOCAL_HOSTS or 'e2e' not in name:
        sys.exit(f'Refusing to use {parts.hostname}/{name}: the e2e database must be local and named *e2e*.')
    return parts, name


# The backend reads its settings once, at import: pin every one that could
# reach a real service before anything from app/ is imported.
os.environ.update({
    'OMOTERRA_DATABASE_URL': URL,
    'OMOTERRA_OPS_TOKEN': OPS_TOKEN,
    'OMOTERRA_AUTO_MIGRATE': 'false',
    'OMOTERRA_ENVIRONMENT': 'development',
    'OMOTERRA_SMS_PROVIDER': 'development',
    'OMOTERRA_PUSH_PROVIDER': 'disabled',
    'OMOTERRA_PAYMENT_PROVIDER': 'disabled',
    'OMOTERRA_VIDEO_PROVIDER': 'disabled',
    'OMOTERRA_MEDIA_STORAGE': 'local',
    'OMOTERRA_R2_ACCOUNT_ID': '',
    'OMOTERRA_MEDIA_DIRECTORY': os.environ.get('OMOTERRA_E2E_MEDIA', str(ROOT / 'ops' / 'test-results' / 'e2e-media')),
})


def recreate_database():
    from sqlalchemy import create_engine, text
    parts, name = _check_target()
    admin = create_engine(parts._replace(path='/postgres').geturl(), isolation_level='AUTOCOMMIT')
    with admin.connect() as db:
        db.execute(text(f'DROP DATABASE IF EXISTS "{name}" WITH (FORCE)'))
        db.execute(text(f'CREATE DATABASE "{name}"'))
    admin.dispose()
    from app.db import Base, engine
    from app import models  # noqa: F401  (registers every table)
    from app.migrate_inventory import install_history_guards
    Base.metadata.create_all(engine)
    install_history_guards(engine)


def serve():
    recreate_database()
    import uvicorn
    uvicorn.run('app.main:app', host='127.0.0.1', port=PORT, log_level='warning')


def _reset(db):
    from sqlalchemy import text
    from app.db import Base
    tables = ', '.join(f'"{t.name}"' for t in Base.metadata.sorted_tables)
    db.execute(text(f'TRUNCATE {tables} CASCADE'))


def _operator(db, m, digest):
    token = secrets.token_urlsafe(24)
    operator = m.Operator(phone='+255710000001', name='E2E Admin', role='admin',
        # Any value: the dashboard only checks that a PIN exists, so it does
        # not send this operator to the "create a PIN" step.
        pin_hash='e2e-pin-not-checked')
    db.add(operator)
    db.flush()
    db.add(m.OperatorSession(operator_id=operator.id, token_hash=digest(token),
        expires_at=m.now() + timedelta(days=1)))
    return {'operator_id': operator.id, 'operator_token': token}


def _debts(db, m):
    """66 manual debts: 18 open (they need action), 24 settled, 24 cancelled."""
    rows = []
    start = date.today() - timedelta(days=90)
    for index in range(66):
        status = 'open' if index < 18 else 'settled' if index < 42 else 'cancelled'
        amount = Decimal(10000 + index * 100)
        name = f'E2E Party {index + 1:02d}'
        db.add(m.LedgerDebt(direction='receivable' if index % 2 else 'payable', party_kind='other',
            party_name=name, description=f'E2E debt {index + 1:02d}', amount=amount,
            paid_amount=amount if status == 'settled' else Decimal(0),
            incurred_on=start + timedelta(days=index), due_on=start + timedelta(days=index + 30),
            source='manual', status=status, cancelled_at=m.now() if status == 'cancelled' else None,
            cancel_reason='E2E' if status == 'cancelled' else ''))
        rows.append({'name': name, 'status': status})
    return rows


def seed(scenario):
    _check_target()
    from app.auth import digest
    from app.db import Session
    from app import models as m
    with Session() as db, db.begin():
        _reset(db)
        out = _operator(db, m, digest)
        if scenario == 'debts':
            out['debts'] = _debts(db, m)
        elif scenario != 'operator':
            sys.exit(f'Unknown scenario {scenario}')
    out['ops_token'] = OPS_TOKEN
    print(json.dumps(out))


def member(user_id):
    """A signed-in portal session for `user_id` (the omoterra_member cookie)."""
    _check_target()
    from app.auth import digest
    from app.db import Session
    from app import models as m
    token = secrets.token_urlsafe(24)
    with Session() as db, db.begin():
        user = db.get(m.User, user_id)
        if not user:
            sys.exit(f'No user {user_id}')
        user.pin_hash = user.pin_hash or 'e2e-pin-not-checked'
        db.add(m.AuthSession(user_id=user_id, token_hash=digest(token), expires_at=m.now() + timedelta(days=1)))
    print(json.dumps({'member_token': token}))


if __name__ == '__main__':
    command = sys.argv[1] if len(sys.argv) > 1 else ''
    if command == 'serve':
        serve()
    elif command == 'seed' and len(sys.argv) == 3:
        seed(sys.argv[2])
    elif command == 'member' and len(sys.argv) == 3:
        member(sys.argv[2])
    else:
        sys.exit(__doc__)
