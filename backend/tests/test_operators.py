from sqlalchemy import select, func
from app import models as m
from app.operators import add_operator
from test_commerce import headers

SERVICE = {'X-Ops-Token': 'test-operator-secret'}
ADMIN = {**SERVICE, 'X-Operator-Session': 'ops-admin'}
STAFF = {**SERVICE, 'X-Operator-Session': 'ops-staff'}


def sign_in(client, phone):
    challenge = client.post('/api/v1/ops/auth/otp', headers=SERVICE, json={'phone': phone})
    assert challenge.status_code == 200, challenge.text
    body = challenge.json()
    return client.post('/api/v1/ops/auth/verify', headers=SERVICE,
        json={'challenge_id': body['challenge_id'], 'code': body['development_code']})


def test_operator_signs_in_with_phone_code_and_gets_their_own_session(client):
    signed_in = sign_in(client, '+255710000002')
    assert signed_in.status_code == 200, signed_in.text
    token = signed_in.json()['session_token']
    me = client.get('/api/v1/ops/me', headers={**SERVICE, 'X-Operator-Session': token})
    assert me.json()['name'] == 'Test Staff' and me.json()['role'] == 'staff'


def test_unknown_number_cannot_request_an_ops_code(client):
    response = client.post('/api/v1/ops/auth/otp', headers=SERVICE, json={'phone': '+255719999999'})
    assert response.status_code == 403


def test_service_token_alone_no_longer_opens_ops(client):
    assert client.get('/api/v1/ops/summary', headers=SERVICE).status_code == 401
    assert client.get('/api/v1/ops/summary', headers={'X-Operator-Session': 'ops-admin'}).status_code == 403


def test_app_and_ops_codes_cannot_open_each_other(client):
    ops_code = client.post('/api/v1/ops/auth/otp', headers=SERVICE, json={'phone': '+255710000001'}).json()
    as_app = client.post('/api/v1/auth/verify', json={'challenge_id': ops_code['challenge_id'], 'code': ops_code['development_code']})
    assert as_app.status_code == 400
    app_code = client.post('/api/v1/auth/otp', json={'phone': '+255712345678'}).json()
    as_ops = client.post('/api/v1/ops/auth/verify', headers=SERVICE,
        json={'challenge_id': app_code['challenge_id'], 'code': app_code['development_code']})
    assert as_ops.status_code == 400


def test_changes_are_recorded_under_the_operator_who_made_them(client, sessions, seeded):
    moved = client.patch(f"/api/v1/ops/suppliers/{seeded['supplier']}/status", headers=STAFF, json={'status': 'suspended'})
    assert moved.status_code == 200, moved.text
    supplier = client.get(f"/api/v1/ops/suppliers/{seeded['supplier']}", headers=ADMIN).json()
    assert supplier['suspended_by_actor'] == 'Test Staff'
    audit = client.get('/api/v1/ops/audit', headers=ADMIN).json()
    assert audit[0]['operator_name'] == 'Test Staff'
    assert audit[0]['method'] == 'PATCH' and audit[0]['path'] == f"/ops/suppliers/{seeded['supplier']}/status"
    # Reading is not a change, and failed changes leave no trace.
    client.post('/api/v1/ops/settlements/missing/pay', headers={**ADMIN, 'Idempotency-Key': 'pay-missing-01'},
        json={'amount': '1', 'payment_reference': 'R'})
    with sessions() as db:
        assert db.scalar(select(func.count()).select_from(m.OpsAuditEntry)) == 1


def test_staff_cannot_record_payouts_or_manage_staff(client, seeded):
    assert client.post('/api/v1/ops/settlements/any/pay', headers={**STAFF, 'Idempotency-Key': 'staff-pay-01'},
        json={'amount': '1', 'payment_reference': 'R'}).status_code == 403
    assert client.post('/api/v1/ops/operators', headers=STAFF,
        json={'phone': '+255710000009', 'name': 'New Person'}).status_code == 403
    assert client.get('/api/v1/ops/audit', headers=STAFF).status_code == 403


def test_admin_adds_and_removes_staff(client, seeded):
    added = client.post('/api/v1/ops/operators', headers=ADMIN, json={'phone': '+255710000009', 'name': 'Neema Staff'})
    assert added.status_code == 201, added.text
    assert client.post('/api/v1/ops/operators', headers=ADMIN,
        json={'phone': '+255710000009', 'name': 'Twice'}).status_code == 409
    removed = client.patch(f"/api/v1/ops/operators/{seeded['operator_staff']}", headers=ADMIN, json={'active': False})
    assert removed.status_code == 200
    # Removal signs them out immediately.
    assert client.get('/api/v1/ops/me', headers=STAFF).status_code == 401
    assert client.post('/api/v1/ops/auth/otp', headers=SERVICE, json={'phone': '+255710000002'}).status_code == 403


def test_the_last_admin_cannot_be_removed_or_demoted(client, seeded):
    for change in ({'active': False}, {'role': 'staff'}):
        response = client.patch(f"/api/v1/ops/operators/{seeded['operator_admin']}", headers=ADMIN, json=change)
        assert response.status_code == 409, change
    client.patch(f"/api/v1/ops/operators/{seeded['operator_staff']}", headers=ADMIN, json={'role': 'admin'})
    assert client.patch(f"/api/v1/ops/operators/{seeded['operator_admin']}", headers=ADMIN, json={'role': 'staff'}).status_code == 200


def test_sign_out_ends_the_session(client):
    token = sign_in(client, '+255710000001').json()['session_token']
    session = {**SERVICE, 'X-Operator-Session': token}
    assert client.post('/api/v1/ops/auth/logout', headers=session).status_code == 204
    assert client.get('/api/v1/ops/me', headers=session).status_code == 401


def test_command_line_creates_the_first_admin(sessions):
    with sessions.begin() as db:
        row, created = add_operator(db, '+255710000077', 'First Admin', 'admin')
        assert created and row.role == 'admin'
        again, created = add_operator(db, '+255710000077', 'First Admin', 'admin')
        assert not created and again.id == row.id
