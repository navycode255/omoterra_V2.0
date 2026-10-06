"""Recognition date of app orders (build plan M2.5, audit F07, decision D7):
an app order counts as a sale, revenue and cost together, on the day it was
delivered (`orders.recognized_on`); a reopen or a return reverses it in the
period it happens and never rewrites an earlier one; history is backfilled
only where it is unambiguous."""
import os
import shutil
import uuid
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal

import pytest
from sqlalchemy import create_engine, select, text
from sqlalchemy.orm import Session

from app import contracts as c, migrations, models as m, recognition, reporting as rp, services as s
from test_finance import API, OPS, STAFF, key
from test_reporting import STEPS, app_order, drill, get, reconcile, settlement_of

DAY = c.business_today()
THIS_MONTH = DAY.replace(day=1)
LAST_MONTH = (THIS_MONTH - timedelta(days=1)).replace(day=1)
EAT = timezone(timedelta(hours=3))


def profit(client, start, end):
    body = get(client, '/finance/profit', start=start.isoformat(), end=end.isoformat())
    return Decimal(body['marketplace_sales']), Decimal(body['marketplace_cost'])


def reverse(client, order_id, kind, on=DAY, headers=OPS, reason='Buyer was not at home; birds came back'):
    return client.post(API + f'/orders/{order_id}/reverse-delivery', json={'kind': kind, 'reversed_on': on.isoformat(),
        'reason': reason}, headers={**headers, 'Idempotency-Key': key()})


def deliver_again(sessions, order_id):
    with sessions.begin() as db:
        s.advance(db, db.get(m.Order, order_id), c.Progress(internal_status='delivered'))


def test_an_order_made_last_month_and_delivered_this_month_counts_this_month(client, sessions, seeded):
    ordered = LAST_MONTH + timedelta(days=3)
    id = app_order(sessions, seeded, 4, 'f07-cross-month', accepted=3, created_on=ordered)
    with sessions() as db:
        order = db.get(m.Order, id)
        # Marked delivered today: stored as today's business day.
        assert order.recognized_on == DAY and order.recognition_note == 'Marked delivered'
    assert profit(client, LAST_MONTH, THIS_MONTH - timedelta(days=1)) == (0, 0)
    assert profit(client, THIS_MONTH, DAY) == (Decimal('36000'), Decimal('27000'))
    # The stored day decides, not the activity log: editing the log moves nothing.
    with sessions.begin() as db:
        row = db.get(m.Order, id)
        row.activity = [{**e, 'at': datetime.combine(ordered, time(9), tzinfo=EAT).isoformat()}
                        if e['label'] == 'Delivered' else e for e in row.activity]
    assert profit(client, THIS_MONTH, DAY) == (Decimal('36000'), Decimal('27000'))
    rows, amount = drill(client, 'revenue', start=THIS_MONTH.isoformat(), end=DAY.isoformat())
    assert amount == Decimal('36000') and [r['source_id'] for r in rows] == [id]


def _delivered_last_month(sessions, seeded, idem):
    """Delivered (and recognised) on a day last month."""
    delivered = LAST_MONTH + timedelta(days=10)
    id = app_order(sessions, seeded, 4, idem, accepted=3, created_on=LAST_MONTH + timedelta(days=2),
        delivered_on=delivered)
    return id, delivered


def test_a_reopen_reverses_in_the_period_it_happens(client, sessions, seeded):
    id, delivered = _delivered_last_month(sessions, seeded, 'f07-reopen')
    before = profit(client, LAST_MONTH, THIS_MONTH - timedelta(days=1))
    assert before == (Decimal('36000'), Decimal('27000'))
    assert reverse(client, id, 'reopen', headers=STAFF).status_code == 403  # admins only
    assert reverse(client, id, 'reopen', on=delivered - timedelta(days=1)).status_code == 422
    done = reverse(client, id, 'reopen')
    assert done.status_code == 200, done.text
    assert done.json()['recognized_on'] == delivered.isoformat()
    # Last month is unchanged; this month takes it out, revenue and cost.
    assert profit(client, LAST_MONTH, THIS_MONTH - timedelta(days=1)) == before
    assert profit(client, THIS_MONTH, DAY) == (Decimal('-36000'), Decimal('-27000'))
    with sessions() as db:
        order = db.get(m.Order, id)
        assert order.internal_status == 'in_transit' and order.recognized_on is None
        assert settlement_of(sessions, id).status == 'cancelled'
        # Back on its way: a commitment again, nothing owed either way.
        assert [r['source_id'] for r in rp.commitments(db)['rows']] == [id]
        assert rp.receivables(db)['marketplace'] == 0 and rp.payables(db)['marketplace'] == 0
        listing = db.get(m.Listing, seeded['listing'])
        assert listing.quantity_sold == 0 and listing.quantity_reserved == 4
    # Headline = drilldown for the period with the reversal in it.
    rows, amount = drill(client, 'revenue', start=THIS_MONTH.isoformat(), end=DAY.isoformat())
    assert amount == Decimal('-36000') and rows[0]['source_table'] == 'order_recognition_reversals'
    _rows, cost = drill(client, 'cost_of_goods', start=THIS_MONTH.isoformat(), end=DAY.isoformat())
    assert cost == Decimal('-27000')
    # Delivered again today: recognised again today, the payout pending again.
    deliver_again(sessions, id)
    assert profit(client, THIS_MONTH, DAY) == (0, 0)
    assert profit(client, LAST_MONTH, THIS_MONTH - timedelta(days=1)) == before
    with sessions() as db:
        assert db.get(m.Order, id).recognized_on == DAY
        assert settlement_of(sessions, id).status == 'pending'
        assert rp.payables(db)['marketplace'] == Decimal('27000')
        assert db.get(m.Listing, seeded['listing']).quantity_sold == 3
    sold = get(client, '/sales', start=THIS_MONTH.isoformat(), end=DAY.isoformat())['summary']
    assert Decimal(sold['marketplace_total']) == 0 and sold['marketplace_count'] == 1


def test_a_return_reverses_in_the_period_it_happens(client, sessions, seeded):
    id, delivered = _delivered_last_month(sessions, seeded, 'f07-return')
    before = profit(client, LAST_MONTH, THIS_MONTH - timedelta(days=1))
    # Money the buyer paid has no refund path on app orders yet: refused.
    reconcile(client, id, '10000', 'RT-1')
    assert reverse(client, id, 'return').status_code == 409
    with sessions.begin() as db:
        payment = db.scalar(select(m.Payment).where(m.Payment.order_id == id))
        db.execute(text('DELETE FROM money_references'))
        db.execute(text('DELETE FROM payment_receipts'))
        payment.received_amount, payment.status = 0, 'pending'
        db.get(m.Order, id).payment_status = 'pending'
    done = reverse(client, id, 'return', reason='Buyer returned 3 birds, 1 lame; back to the farm')
    assert done.status_code == 200, done.text
    assert profit(client, LAST_MONTH, THIS_MONTH - timedelta(days=1)) == before
    assert profit(client, THIS_MONTH, DAY) == (Decimal('-36000'), Decimal('-27000'))
    with sessions() as db:
        order = db.get(m.Order, id)
        assert order.internal_status == 'cancelled' and order.activity[-1]['label'] == 'Returned by buyer'
        assert rp.commitments(db)['count'] == 0 and rp.receivables(db)['marketplace'] == 0
        # The goods are back on the supplier's listing.
        assert db.get(m.Listing, seeded['listing']).quantity_sold == 0
    # A second reversal of the same delivery is refused.
    assert reverse(client, id, 'return').status_code == 409


def test_a_paid_payout_blocks_a_reversal(client, sessions, seeded):
    id, _delivered = _delivered_last_month(sessions, seeded, 'f07-paid')
    with sessions.begin() as db:
        row = db.get(m.Settlement, settlement_of(sessions, id).id)
        row.status, row.paid_at = 'paid', m.now()
    response = reverse(client, id, 'reopen')
    assert response.status_code == 409 and 'payout' in response.json()['detail']


# ---- backfill (migration 044) ---------------------------------------------------------

@pytest.fixture
def fresh_engine():
    url = os.environ.get('OMOTERRA_TEST_DATABASE_URL')
    if not url:
        pytest.skip('Set OMOTERRA_TEST_DATABASE_URL to a disposable PostgreSQL database')
    schema = 'omoterra_m044_' + uuid.uuid4().hex
    admin = create_engine(url)
    with admin.begin() as db:
        db.execute(text(f'CREATE SCHEMA {schema}'))
    engine = create_engine(url, connect_args={'options': f'-csearch_path={schema}'})
    yield engine
    engine.dispose()
    with admin.begin() as db:
        db.execute(text(f'DROP SCHEMA {schema} CASCADE'))
    admin.dispose()


def _at(day, hour=12):
    return datetime.combine(day, time(hour), tzinfo=EAT).isoformat()


HISTORY = {
    # Unambiguous: one Delivered entry; 01:30 in Dar es Salaam is the day before in UTC.
    'one': ('delivered', [{'label': 'Order confirmed', 'at': _at(date(2026, 9, 10))},
                          {'label': 'Delivered', 'at': datetime(2026, 9, 14, 22, 30, tzinfo=timezone.utc).isoformat()}]),
    # Two entries on the same day: still one day.
    'same_day': ('completed', [{'label': 'Delivered', 'at': _at(date(2026, 9, 20), 9)},
                               {'label': 'Delivered', 'at': _at(date(2026, 9, 20), 17)}]),
    # Ambiguous: conflicting days, no entry, an unreadable time, before the order existed.
    'conflict': ('delivered', [{'label': 'Delivered', 'at': _at(date(2026, 9, 20))},
                               {'label': 'Delivered', 'at': _at(date(2026, 9, 25))}]),
    'none': ('delivered', [{'label': 'Order confirmed', 'at': _at(date(2026, 9, 1))}]),
    'unreadable': ('completed', [{'label': 'Delivered', 'at': 'yesterday'}]),
    'early': ('delivered', [{'label': 'Delivered', 'at': _at(date(2026, 8, 1))}]),
    # Not delivered: never recognised, whatever its log says.
    'open': ('in_transit', [{'label': 'Order dispatched', 'at': _at(date(2026, 9, 3))}]),
}


def test_backfill_dates_unambiguous_history_and_leaves_the_rest_unresolved(fresh_engine, tmp_path, monkeypatch, capsys):
    files = migrations.files()
    for path in files:
        if path.name < '044':
            shutil.copy(path, tmp_path / path.name)
    monkeypatch.setattr(migrations, 'DIRECTORY', tmp_path)
    migrations.apply(fresh_engine)
    import json
    with fresh_engine.begin() as db:
        for n, (name, (status, activity)) in enumerate(HISTORY.items()):
            db.execute(text("""INSERT INTO orders (id, created_at, delivery_snapshot, preferred_delivery_date,
                payment_method, payment_status, internal_status, expected_quantity, total_amount, idempotency_key,
                activity, collection_photos, collection_notes)
                VALUES (:id, :created, '{}', '2026-09-01', 'pay_on_delivery', 'pending', :status, 1, :amount, :key,
                CAST(:activity AS json), '[]', '')"""), {'id': name, 'created': datetime(2026, 9, 1, 8, tzinfo=EAT),
                'status': status, 'amount': 1000 * (n + 1), 'key': f'k-{name}', 'activity': json.dumps(activity)})
    for path in files:
        if path.name >= '044':
            shutil.copy(path, tmp_path / path.name)
    migrations.apply(fresh_engine)
    with Session(fresh_engine) as db:
        stored = dict(db.execute(select(m.Order.id, m.Order.recognized_on)).all())
        assert stored == {'one': date(2026, 9, 15), 'same_day': date(2026, 9, 20), 'conflict': None, 'none': None,
                          'unreadable': None, 'early': None, 'open': None}
        # The Python rule (dry run, exception report) agrees with the migration.
        for order in db.scalars(select(m.Order).where(m.Order.internal_status.in_(recognition.RECOGNISED))):
            assert recognition.classify(order)[0] == stored[order.id], order.id
        # Unresolved orders are listed with their reason and kept out of revenue.
        waiting = {r['order_id']: r['reason'] for r in recognition.unresolved(db)}
        assert set(waiting) == {'conflict', 'none', 'unreadable', 'early'}
        assert 'conflicting' in waiting['conflict'] and 'no dated' in waiting['none']
        sold = rp.revenue(db, date(2026, 8, 1), date(2026, 9, 30))
        assert sold['marketplace'] == Decimal('3000') and sold['unresolved']['count'] == 4
    from app import finance_exceptions as fx
    report = fx.build_report(fresh_engine)
    [section] = [s for s in report['sections'] if s['key'] == 'unrecognised_orders']
    assert section['count'] == 4 and section['amount'] == Decimal('3000') + 4000 + 5000 + 6000
    # The dry run changes nothing; --apply dates one with evidence after confirmation.
    assert recognition.main(['--dry-run'], bind=fresh_engine) == 0
    assert 'Unresolved (kept out of every period): 4' in capsys.readouterr().out
    assert recognition.main(['--apply', 'none', '--on', '2026-09-05', '--evidence', 'Signed delivery note',
        '--by', 'Maternus Joshua'], ask=lambda _: 'no', bind=fresh_engine) == 1
    assert recognition.main(['--apply', 'none', '--on', '2026-09-05', '--by', 'Maternus Joshua', '--confirm', 'none'],
        bind=fresh_engine) == 2  # no evidence
    assert recognition.main(['--apply', 'none', '--on', '2026-09-05', '--evidence', 'Signed delivery note',
        '--by', 'Maternus Joshua', '--confirm', 'none'], bind=fresh_engine) == 0
    with Session(fresh_engine) as db:
        order = db.get(m.Order, 'none')
        assert order.recognized_on == date(2026, 9, 5) and 'Signed delivery note' in order.recognition_note
        assert len(recognition.unresolved(db)) == 3
    # A dated order is never dated again.
    assert recognition.main(['--apply', 'one', '--on', '2026-09-05', '--evidence', 'x' * 5, '--by', 'MJ',
        '--confirm', 'one'], bind=fresh_engine) == 2
