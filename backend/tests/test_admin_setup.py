import pytest
from sqlalchemy import select, delete
from app import models as m
from app.config import settings

SERVICE = {'X-Ops-Token': 'test-operator-secret'}
PASSPHRASE = 'correct horse battery staple'


@pytest.fixture
def setup_on(monkeypatch):
    monkeypatch.setattr(settings(), 'admin_setup_passphrase', PASSPHRASE)


@pytest.fixture
def no_admins(sessions, client):
    with sessions.begin() as db:
        db.execute(delete(m.OperatorSession))
        db.execute(delete(m.Operator))


def post(client, path, body):
    return client.post(f'/api/v1/ops/setup/{path}', headers=SERVICE, json=body)


def start(client, passphrase=PASSPHRASE):
    return post(client, 'start', {'passphrase': passphrase})


def code_for(client, path, body):
    response = post(client, path, body)
    assert response.status_code == 200, response.text
    return response.json()


def register(client, token, name, phone):
    challenge = code_for(client, 'admin/otp', {'setup_token': token, 'name': name, 'phone': phone})
    return post(client, 'admin/verify', {'setup_token': token, 'challenge_id': challenge['challenge_id'],
        'code': challenge['development_code']})


def test_first_admin_registers_with_passphrase_and_own_phone(client, sessions, setup_on, no_admins):
    started = start(client).json()
    assert started['needs_approval'] is False
    done = register(client, started['setup_token'], 'Asha Mwita', '+255710000050')
    assert done.status_code == 200, done.text
    assert done.json()['operator']['role'] == 'admin'
    me = client.get('/api/v1/ops/me', headers={**SERVICE, 'X-Operator-Session': done.json()['session_token']})
    assert me.json()['name'] == 'Asha Mwita'
    # The setup cannot be used a second time.
    again = post(client, 'admin/otp', {'setup_token': started['setup_token'], 'name': 'Someone Else', 'phone': '+255710000051'})
    assert again.status_code == 401


def test_with_an_admin_the_passphrase_alone_is_not_enough(client, setup_on):
    token = start(client).json()
    assert token['needs_approval'] is True
    blocked = post(client, 'admin/otp', {'setup_token': token['setup_token'], 'name': 'Intruder', 'phone': '+255710000060'})
    assert blocked.status_code == 403


def test_existing_admin_approves_with_their_code_then_new_admin_confirms(client, sessions, seeded, setup_on):
    token = start(client).json()['setup_token']
    # Only an active admin's number can approve; staff cannot.
    assert post(client, 'approve/otp', {'setup_token': token, 'phone': '+255710000002'}).status_code == 403
    challenge = code_for(client, 'approve/otp', {'setup_token': token, 'phone': '+255710000001'})
    wrong = post(client, 'approve/verify', {'setup_token': token, 'challenge_id': challenge['challenge_id'], 'code': '000000'})
    assert wrong.status_code == 400
    approved = post(client, 'approve/verify', {'setup_token': token, 'challenge_id': challenge['challenge_id'],
        'code': challenge['development_code']})
    assert approved.json() == {'approved_by': 'Test Admin'}
    done = register(client, token, 'Neema Admin', '+255710000061')
    assert done.status_code == 200, done.text
    with sessions() as db:
        created = db.scalar(select(m.Operator).where(m.Operator.phone == '+255710000061'))
        assert created.role == 'admin' and created.created_by == seeded['operator_admin']


def test_codes_cannot_be_swapped_between_steps(client, sessions, setup_on, no_admins):
    token = start(client).json()['setup_token']
    challenge = code_for(client, 'admin/otp', {'setup_token': token, 'name': 'Asha', 'phone': '+255710000050'})
    # A setup code is not an approval code, and not a dashboard sign-in code.
    assert post(client, 'approve/verify', {'setup_token': token, 'challenge_id': challenge['challenge_id'],
        'code': challenge['development_code']}).status_code == 400
    login = client.post('/api/v1/ops/auth/verify', headers=SERVICE,
        json={'challenge_id': challenge['challenge_id'], 'code': challenge['development_code']})
    assert login.status_code == 400


def test_wrong_passphrases_lock_setup(client, setup_on):
    for _ in range(5):
        assert start(client, 'wrong guess here').status_code == 403
    assert start(client).status_code == 429  # even the right one, until the window passes


def test_setup_is_off_without_a_passphrase(client):
    assert start(client, 'anything at all').status_code == 403


def test_existing_accounts_cannot_be_taken_over(client, setup_on):
    token = start(client).json()['setup_token']
    challenge = code_for(client, 'approve/otp', {'setup_token': token, 'phone': '+255710000001'})
    post(client, 'approve/verify', {'setup_token': token, 'challenge_id': challenge['challenge_id'],
        'code': challenge['development_code']})
    # The staff member's number cannot be re-registered as a new admin.
    taken = post(client, 'admin/otp', {'setup_token': token, 'name': 'Rename', 'phone': '+255710000002'})
    assert taken.status_code == 409


def test_short_passphrase_is_refused_at_startup():
    from app.config import Settings
    with pytest.raises(RuntimeError, match='at least 8'):
        Settings(database_url='postgresql://x', admin_setup_passphrase='short').validate_runtime()


def test_eight_character_passphrase_is_accepted():
    from app.config import Settings
    Settings(database_url='postgresql://x', admin_setup_passphrase='Husein23').validate_runtime()
    with pytest.raises(RuntimeError, match='at least 8'):
        Settings(database_url='postgresql://x', admin_setup_passphrase='Husein2').validate_runtime()
