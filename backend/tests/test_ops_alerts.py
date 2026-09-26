from datetime import timedelta
from sqlalchemy import select, func
from app import models as m
from test_commerce import headers, order

ADMIN = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin'}
STAFF = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-staff'}


def alerts(client, who=ADMIN):
    response = client.get('/api/v1/ops/alerts', headers=who)
    assert response.status_code == 200, response.text
    return response.json()


def test_new_work_shows_up_and_reading_clears_it_per_operator(client, sessions, seeded):
    id = order(sessions, seeded)
    with sessions.begin() as db:
        profile = db.get(m.SupplierProfile, seeded['supplier'])
        profile.status, profile.submitted_at = 'under_review', m.now()
    feed = alerts(client)
    kinds = {item['kind'] for item in feed['items']}
    assert {'order', 'supplier'} <= kinds and feed['unread'] >= 2
    assert any(item['link'] == f'/orders/{id}' for item in feed['items'])
    assert client.post('/api/v1/ops/alerts/seen', headers=ADMIN).json() == {'unread': 0}
    assert alerts(client)['unread'] == 0
    # Another operator's unread count is their own.
    assert alerts(client, STAFF)['unread'] >= 2


def test_reading_alerts_is_not_logged_as_work(client, sessions):
    client.post('/api/v1/ops/alerts/seen', headers=ADMIN)
    with sessions() as db:
        assert db.scalar(select(func.count()).select_from(m.OpsAuditEntry)) == 0


def test_old_items_fall_out_of_the_feed(client, sessions, seeded):
    id = order(sessions, seeded)
    with sessions.begin() as db:
        db.get(m.Order, id).created_at = m.now() - timedelta(days=8)
    assert all(item['link'] != f'/orders/{id}' for item in alerts(client)['items'])


def test_alerts_need_a_signed_in_operator(client):
    assert client.get('/api/v1/ops/alerts', headers={'X-Ops-Token': 'test-operator-secret'}).status_code == 401
