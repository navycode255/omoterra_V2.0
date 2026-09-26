from datetime import timedelta
import pytest
from sqlalchemy import select, func
from app import models as m, notifications as notes
from app.reminders import remind_stale_stock
from test_commerce import headers, order

OPS = {'X-Ops-Token': 'test-operator-secret', 'X-Operator-Session': 'ops-admin'}
TOKEN = 'phone-token-' + 'x' * 30


class Recorder:
    def __init__(self):
        self.sent, self.dead = [], set()

    def send(self, token, title, body, data):
        self.sent.append({'token': token, 'title': title, 'body': body, **data})
        return 'unregistered' if token in self.dead else 'sent'


@pytest.fixture
def pushes(monkeypatch):
    recorder = Recorder()
    monkeypatch.setattr(notes, '_sender', recorder)
    monkeypatch.setattr(notes, 'dispatch', lambda job: job())
    return recorder


def inbox(client, role):
    response = client.get('/api/v1/notifications', headers=headers(role))
    assert response.status_code == 200, response.text
    return response.json()


def register(client, role, token=TOKEN):
    assert client.post('/api/v1/devices', headers=headers(role), json={'token': token}).status_code == 204


def test_new_order_reaches_supplier_inbox_and_phone(client, sessions, seeded, pushes):
    register(client, 'supplier')
    order(sessions, seeded)
    items = inbox(client, 'supplier')
    assert items['unread'] == 1
    note = items['items'][0]
    assert note['kind'] == 'order_new' and note['role'] == 'supplier'
    assert note['link'].startswith('/supplier-orders/')
    assert [p['token'] for p in pushes.sent] == [TOKEN]
    assert pushes.sent[0]['link'] == note['link']
    # The buyer placed it themselves; nothing for them yet.
    assert inbox(client, 'buyer')['items'] == []


def test_order_updates_notify_buyer_and_supplier(client, sessions, seeded, pushes):
    id = order(sessions, seeded)
    moved = client.post(f'/api/v1/ops/orders/{id}/progress', headers={**OPS, 'Idempotency-Key': 'progress-note-01'},
        json={'internal_status': 'pickup_scheduled', 'expected_collection_date': '2027-01-05'})
    assert moved.status_code == 200, moved.text
    buyer = inbox(client, 'buyer')['items']
    assert buyer[0]['kind'] == 'order_pickup_scheduled' and buyer[0]['link'] == f'/order/{id}'
    supplier = [n for n in inbox(client, 'supplier')['items'] if n['kind'] == 'collection_scheduled']
    assert supplier and '2027-01-05' in supplier[0]['body']


def test_buyer_cancelling_their_own_order_only_tells_the_supplier(client, sessions, seeded, pushes):
    id = order(sessions, seeded)
    cancelled = client.post(f'/api/v1/orders/{id}/cancel', headers=headers('buyer', 'self-cancel-note'))
    assert cancelled.status_code == 200, cancelled.text
    assert inbox(client, 'buyer')['items'] == []
    assert any(n['kind'] == 'order_cancelled' for n in inbox(client, 'supplier')['items'])


def test_rejected_request_sends_no_push(client, sessions, seeded, pushes):
    register(client, 'supplier')
    # Paying out a settlement that doesn't exist fails; nothing may be pushed.
    response = client.post('/api/v1/ops/settlements/missing/pay', headers={**OPS, 'Idempotency-Key': 'pay-missing-01'},
        json={'amount': '1', 'payment_reference': 'REF-1'})
    assert response.status_code == 404
    assert pushes.sent == []


def test_listing_review_and_supplier_status_notify_supplier(client, sessions, seeded, pushes):
    paused = client.patch(f"/api/v1/ops/listings/{seeded['listing']}/status", headers={**OPS, 'Idempotency-Key': 'pause-note-01'},
        json={'status': 'paused'})
    assert paused.status_code == 200, paused.text
    suspended = client.patch(f"/api/v1/ops/suppliers/{seeded['supplier']}/status", headers=OPS, json={'status': 'suspended'})
    assert suspended.status_code == 200, suspended.text
    kinds = [n['kind'] for n in inbox(client, 'supplier')['items']]
    assert 'stock_paused' in kinds and 'supplier_suspended' in kinds


def test_marking_read_clears_the_badge(client, sessions, seeded, pushes):
    order(sessions, seeded)
    order(sessions, seeded, quantity=1, key='checkout-key-0002')
    first = inbox(client, 'supplier')['items'][0]['id']
    after_one = client.post('/api/v1/notifications/read', headers=headers('supplier'), json={'ids': [first]}).json()
    assert after_one['unread'] == 1
    after_all = client.post('/api/v1/notifications/read', headers=headers('supplier'), json={'all': True}).json()
    assert after_all['unread'] == 0
    # Someone else's ids are ignored.
    assert client.post('/api/v1/notifications/read', headers=headers('buyer'), json={'ids': [first]}).json()['unread'] == 0


def test_a_phone_follows_whoever_signed_in_last(client, sessions, seeded, pushes):
    register(client, 'supplier')
    register(client, 'buyer')
    order(sessions, seeded)
    assert pushes.sent == []  # the phone now belongs to the buyer, not the supplier
    with sessions() as db:
        assert db.scalar(select(m.DeviceToken.user_id).where(m.DeviceToken.token == TOKEN)) == seeded['buyer']


def test_dead_tokens_are_dropped(client, sessions, seeded, pushes):
    register(client, 'supplier')
    pushes.dead.add(TOKEN)
    order(sessions, seeded)
    with sessions() as db:
        assert db.scalar(select(func.count()).select_from(m.DeviceToken)) == 0


def test_unregister_on_sign_out_stops_pushes(client, sessions, seeded, pushes):
    register(client, 'supplier')
    assert client.post('/api/v1/devices/unregister', headers=headers('supplier'), json={'token': TOKEN}).status_code == 204
    order(sessions, seeded)
    assert pushes.sent == []
    assert inbox(client, 'supplier')['unread'] == 1  # still in the inbox


def test_stock_reminder_fires_once_per_confirmation_window(sessions, seeded, pushes):
    now = m.now()
    with sessions.begin() as db:
        listing = db.get(m.Listing, seeded['listing'])
        listing.last_confirmed_at = now - timedelta(hours=44)
        listing.confirmation_due_at = now + timedelta(hours=4)
    with sessions.begin() as db:
        assert remind_stale_stock(db, now) == 1
    with sessions.begin() as db:
        assert remind_stale_stock(db, now + timedelta(hours=1)) == 0
    with sessions.begin() as db:
        listing = db.get(m.Listing, seeded['listing'])
        listing.last_confirmed_at = now + timedelta(hours=2)
        listing.confirmation_due_at = now + timedelta(hours=50)
    with sessions.begin() as db:
        assert remind_stale_stock(db, now + timedelta(hours=46)) == 1
        notes_for = db.scalars(select(m.Notification).where(m.Notification.user_id == seeded['supplier'])).all()
        assert [n.kind for n in notes_for] == ['stock_confirm', 'stock_confirm']


def test_expired_stock_gets_a_hidden_notice(sessions, seeded, pushes):
    now = m.now()
    with sessions.begin() as db:
        listing = db.get(m.Listing, seeded['listing'])
        listing.last_confirmed_at = now - timedelta(hours=50)
        listing.confirmation_due_at = now - timedelta(hours=2)
    with sessions.begin() as db:
        remind_stale_stock(db, now)
        note = db.scalar(select(m.Notification).where(m.Notification.user_id == seeded['supplier']))
        assert note.title == 'Stock hidden from buyers'


def test_deleted_accounts_get_nothing(client, sessions, seeded, pushes):
    register(client, 'buyer')
    assert client.delete('/api/v1/me', headers=headers('buyer')).status_code == 204
    with sessions.begin() as db:
        assert notes.notify(db, seeded['buyer'], 'buyer', 'test', 'Hello') is None
        assert db.scalar(select(func.count()).select_from(m.DeviceToken)) == 0
    assert pushes.sent == []


def fake_service_account(tmp_path):
    import json
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()).decode()
    path = tmp_path / 'key.json'
    path.write_text(json.dumps({'type': 'service_account', 'project_id': 'omoterra-tz', 'private_key_id': 'k1',
        'private_key': pem, 'client_email': 'push@omoterra-tz.iam.gserviceaccount.com',
        'token_uri': 'https://oauth2.googleapis.com/token'}))
    return path


def test_fcm_sender_signs_in_once_and_sends_the_v1_message(tmp_path, monkeypatch):
    import httpx
    calls = []

    def post(url, **kwargs):
        calls.append((url, kwargs))
        if url.endswith('/token'):
            assert kwargs['data']['grant_type'] == 'urn:ietf:params:oauth:grant-type:jwt-bearer'
            return httpx.Response(200, json={'access_token': 'at-1', 'expires_in': 3600}, request=httpx.Request('POST', url))
        if kwargs['json']['message']['token'] == 'dead':
            return httpx.Response(404, json={'error': {'status': 'NOT_FOUND'}}, request=httpx.Request('POST', url))
        return httpx.Response(200, json={'name': 'm1'}, request=httpx.Request('POST', url))

    monkeypatch.setattr(httpx, 'post', post)
    sender = notes.FcmPushSender(fake_service_account(tmp_path))
    assert sender.send('good', 'Hi', 'Body', {'link': '/order/1', 'n': 3}) == 'sent'
    assert sender.send('dead', 'Hi', 'Body', {}) == 'unregistered'
    token_calls = [c for c in calls if c[0].endswith('/token')]
    assert len(token_calls) == 1  # access token reused
    url, sent = calls[1]
    assert url == 'https://fcm.googleapis.com/v1/projects/omoterra-tz/messages:send'
    assert sent['headers']['Authorization'] == 'Bearer at-1'
    assert sent['json']['message']['notification'] == {'title': 'Hi', 'body': 'Body'}
    assert sent['json']['message']['data'] == {'link': '/order/1', 'n': '3'}
    # Rings and vibrates in the app's alert channel.
    android = sent['json']['message']['android']['notification']
    assert android['channel_id'] == 'omoterra_alerts' and android['sound'] == 'default'


def test_push_settings_refuse_a_missing_or_wrong_key(tmp_path):
    from app.config import Settings
    base = {'database_url': 'postgresql://x', 'push_provider': 'fcm'}
    with pytest.raises(RuntimeError, match='service-account'):
        Settings(**base, fcm_credentials_file=str(tmp_path / 'missing.json')).validate_runtime()
    wrong = tmp_path / 'google-services.json'
    wrong.write_text('{"project_info": {}, "client": []}')
    with pytest.raises(RuntimeError, match='not a Firebase service-account key'):
        Settings(**base, fcm_credentials_file=str(wrong)).validate_runtime()
    Settings(**base, fcm_credentials_file=str(fake_service_account(tmp_path))).validate_runtime()


def buyer_requirement(client, key='demand-note-001', category='broilers', unit='bird'):
    from datetime import date
    response = client.post('/api/v1/requirements', headers={**headers(), 'Idempotency-Key': key}, json={
        'category': category, 'unit_type': unit, 'quantity': '200', 'needed_by_date': date.today().isoformat(),
        'delivery_area': 'Kinondoni', 'delivery_region': 'Dar es Salaam'})
    assert response.status_code == 200, response.text
    return response.json()['id']


def test_new_demand_alerts_suppliers_of_that_category_only(client, sessions, seeded, pushes):
    with sessions.begin() as db:
        other = m.User(phone='+255712340001', roles=['supplier'], name='Goat Farmer')
        db.add(other); db.flush()
        db.add(m.SupplierProfile(user_id=other.id, legal_name='G', internal_pickup_address='x',
            status='approved', categories=['goats']))
        pending = m.User(phone='+255712340002', roles=['supplier'], name='Pending Farmer')
        db.add(pending); db.flush()
        db.add(m.SupplierProfile(user_id=pending.id, legal_name='P', internal_pickup_address='x',
            status='under_review', categories=['broilers']))
        other_id, pending_id = other.id, pending.id
    id = buyer_requirement(client)
    supplier = inbox(client, 'supplier')['items']
    assert supplier[0]['kind'] == 'demand_new' and supplier[0]['link'] == f'/supplier-demand/{id}'
    assert 'Dar es Salaam' in supplier[0]['body'] and 'Buyer Test' not in supplier[0]['body']
    with sessions() as db:
        for user_id in (other_id, pending_id):
            assert db.scalar(select(func.count()).select_from(m.Notification).where(m.Notification.user_id == user_id)) == 0


def test_request_status_changes_reach_the_buyer(client, sessions, seeded, pushes):
    id = buyer_requirement(client, key='demand-note-002')
    moved = client.patch(f'/api/v1/ops/requirements/{id}/progress', headers=OPS, json={'status': 'cancelled'})
    assert moved.status_code == 200, moved.text
    buyer = inbox(client, 'buyer')['items']
    assert buyer[0]['kind'] == 'request_cancelled' and buyer[0]['link'] == f'/requests/{id}'
    # Saving the same status again doesn't repeat the notification.
    client.patch(f'/api/v1/ops/requirements/{id}/progress', headers=OPS, json={'status': 'cancelled'})
    assert [n['kind'] for n in inbox(client, 'buyer')['items']].count('request_cancelled') == 1
