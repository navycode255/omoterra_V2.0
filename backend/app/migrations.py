"""Applies backend/migrations/*.sql in order, once each, at server start.

Every applied file is recorded in `schema_migrations`. A file runs inside one
transaction together with its record, so it is either fully applied and
recorded or not applied at all. A PostgreSQL advisory lock makes concurrent
starts (several Passenger or uvicorn workers) wait for one another instead of
applying the same file twice. If a file fails, startup stops with the reason
rather than serving an API whose code and schema disagree.

Adopting the runner on a database that was migrated by hand: the first run
finds no `schema_migrations` table, checks which migrations are already in
effect (DETECT below) and records those as 'detected' without running them.
Only migrations whose effects are missing are applied. Detection matters just
that once; afterwards the table is the record.

    .venv/bin/python -m app.migrations status   # what is applied / pending
    .venv/bin/python -m app.migrations apply    # apply now, without a restart

Adding a migration: add the next numbered .sql file. Nothing else is needed.
"""
from __future__ import annotations

import logging
import re
from pathlib import Path

from sqlalchemy import text

log = logging.getLogger(__name__)
DIRECTORY = Path(__file__).resolve().parents[1] / 'migrations'
LOCK_KEY = 804_310_227  # arbitrary, fixed: "omoterra schema migrations"

# Migrations that must never run automatically. 003a is a manual repair that
# replaces 003 on one specific half-migrated database state.
MANUAL = {'003a_repair_partial_managed_demand.sql'}


def _table(name):
    return f"SELECT to_regclass('{name}') IS NOT NULL"


def _column(table, column):
    return ("SELECT EXISTS (SELECT 1 FROM information_schema.columns "
            f"WHERE table_schema = current_schema() AND table_name = '{table}' AND column_name = '{column}')")


# How to tell, on a hand-migrated database, that a migration is in effect.
DETECT = {
    '001_initial.sql': _table('users'),
    '002_inventory_history.sql': _table('stock_movements'),
    '003_managed_demand.sql': _table('buyer_requirements'),
    '004_supplier_onboarding.sql': _column('supplier_profiles', 'district'),
    '005_supplier_media.sql': _table('supplier_photos'),
    '006_farm_location_stock_video.sql': _column('listings', 'video'),
    '007_account_deletion.sql': _column('users', 'deleted'),
    '008_notifications.sql': _table('notifications'),
    '009_operator_accounts.sql': _table('operators'),
    '010_admin_setup.sql': _table('admin_setups'),
    '011_order_ratings.sql': _table('order_ratings'),
    '012_ops_alerts.sql': _column('operators', 'alerts_seen_at'),
    '013_referrals.sql': _table('referrals'),
    '014_listing_changes.sql': _column('listings', 'review_note'),
    '015_default_address.sql': _column('addresses', 'is_default'),
    '016_media_uploads.sql': _table('media_uploads'),
}

_TRANSACTION_LINE = re.compile(r'^\s*(BEGIN|COMMIT)\s*;\s*$', re.I | re.M)


class MigrationError(RuntimeError):
    pass


def run_sql(connection, sql):
    """Run a whole migration file on this transaction's connection. Sent to
    the driver without parameters, so '%' in the SQL is just a character and
    functions with $$ bodies and several statements work as written."""
    with connection.connection.cursor() as cursor:
        cursor.execute(sql)


def files():
    return sorted(path for path in DIRECTORY.glob('*.sql') if path.name not in MANUAL)


def _recorded(connection):
    return {row[0]: row[1] for row in connection.execute(text('SELECT name, how FROM schema_migrations'))}


def _adopt(connection):
    """First run: record what a hand-migrated database already has."""
    if not connection.execute(text(_table('users'))).scalar():
        return  # a fresh database: everything will be applied
    for path in files():
        probe = DETECT.get(path.name)
        if probe and connection.execute(text(probe)).scalar():
            connection.execute(text("INSERT INTO schema_migrations (name, how) VALUES (:n, 'detected')"), {'n': path.name})
            log.info('Migration %s already in effect; recorded without running it.', path.name)


def status(engine):
    with engine.connect() as connection:
        exists = connection.execute(text(_table('schema_migrations'))).scalar()
        recorded = _recorded(connection) if exists else {}
    return [(path.name, recorded.get(path.name, 'pending')) for path in files()]


def apply(engine):
    """Apply every pending migration. Returns the names applied."""
    applied = []
    with engine.connect() as lock:
        lock.execute(text('SELECT pg_advisory_lock(:k)'), {'k': LOCK_KEY})
        try:
            with engine.begin() as connection:
                fresh = not connection.execute(text(_table('schema_migrations'))).scalar()
                connection.execute(text(
                    'CREATE TABLE IF NOT EXISTS schema_migrations ('
                    'name VARCHAR PRIMARY KEY, how VARCHAR NOT NULL, '
                    'applied_at TIMESTAMPTZ NOT NULL DEFAULT now())'))
                if fresh:
                    _adopt(connection)
            with engine.connect() as connection:
                done = _recorded(connection)
            for path in files():
                if path.name in done:
                    continue
                sql = _TRANSACTION_LINE.sub('', path.read_text())
                try:
                    with engine.begin() as connection:
                        run_sql(connection, sql)
                        connection.execute(text("INSERT INTO schema_migrations (name, how) VALUES (:n, 'applied')"),
                                           {'n': path.name})
                except Exception as exc:
                    raise MigrationError(f'Migration {path.name} failed and was rolled back: {exc}') from exc
                log.warning('Applied migration %s', path.name)
                applied.append(path.name)
        finally:
            lock.execute(text('SELECT pg_advisory_unlock(:k)'), {'k': LOCK_KEY})
            lock.commit()
    return applied


def apply_on_startup():
    """Called from both server entry points (uvicorn lifespan and Passenger)."""
    from .config import settings
    from .db import engine
    if not settings().auto_migrate:
        return []
    applied = apply(engine)
    if applied:
        print(f"Omoterra: applied migrations {', '.join(applied)}", flush=True)
    return applied


if __name__ == '__main__':
    import sys
    from .config import settings
    from .db import engine
    settings().validate_runtime()
    command = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if command == 'apply':
        names = apply(engine)
        print('Applied: ' + (', '.join(names) if names else 'nothing, already up to date'))
    elif command == 'status':
        for name, how in status(engine):
            print(f'{how:<10} {name}')
    else:
        raise SystemExit('Usage: python -m app.migrations [status|apply]')
