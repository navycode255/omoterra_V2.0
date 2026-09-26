import pytest

from app import models as m
from app.config import settings

SERVICE = {'X-Ops-Token': 'test-operator-secret'}
PASS = 'staff-pass-123'
ADMIN_PHONE = '+255710000001'


@pytest.fixture(autouse=True)
def staff_passphrase():
    saved = settings().staff_passphrase, settings().admin_setup_passphrase
    settings().staff_passphrase, settings().admin_setup_passphrase = PASS, ''
    yield
    settings().staff_passphrase, settings().admin_setup_passphrase = saved


def status(client, phone=ADMIN_PHONE, passphrase=PASS):
    return client.post('/api/v1/ops/auth/pin/status', headers=SERVICE, json={'passphrase': passphrase, 'phone': phone})


def sign_in(client, pin, phone=ADMIN_PHONE, passphrase=PASS):
    return client.post('/api/v1/ops/auth/pin/sign-in', headers=SERVICE, json={'passphrase': passphrase, 'phone': phone, 'pin': pin})


def test_an_existing_admin_creates_a_pin_on_first_sign_in_without_sms(client, sessions):
    assert status(client).json() == {'has_pin': False}
    first = sign_in(client, '4071')
    assert first.status_code == 200, first.text
    token = first.json()['session_token']
    me = client.get('/api/v1/ops/me', headers={**SERVICE, 'X-Operator-Session': token})
    assert me.json()['role'] == 'admin' and me.json()['has_pin'] is True
    assert status(client).json() == {'has_pin': True}
    # From now on only that PIN signs in, and nothing was texted.
    assert sign_in(client, '5093').status_code == 400
    assert sign_in(client, '4071').status_code == 200
    with sessions() as db:
        assert db.query(m.OtpChallenge).count() == 0


def test_a_first_pin_must_not_be_guessable(client):
    assert sign_in(client, '1234').status_code == 422
    assert status(client).json() == {'has_pin': False}


def test_passphrase_is_required_and_rate_limited(client):
    assert sign_in(client, '4071', passphrase='wrong-pass').status_code == 403
    assert status(client, passphrase='wrong-pass').status_code == 403
    for _ in range(3):
        status(client, passphrase='wrong-pass')
    assert status(client).status_code == 429


def test_unknown_or_removed_numbers_are_refused(client, sessions):
    assert status(client, phone='+255719999999').status_code == 403
    assert sign_in(client, '4071', phone='+255719999999').status_code == 403
    with sessions.begin() as db:
        db.query(m.Operator).filter_by(phone=ADMIN_PHONE).one().active = False
    assert sign_in(client, '4071').status_code == 403


def test_signin_is_off_without_any_passphrase(client):
    settings().staff_passphrase = ''
    assert status(client).status_code == 403
    assert 'turned off' in status(client).json()['detail']


def test_falls_back_to_the_admin_setup_passphrase(client):
    settings().staff_passphrase, settings().admin_setup_passphrase = '', 'setup-pass-456'
    assert status(client, passphrase='setup-pass-456').status_code == 200


def test_signed_in_staff_can_change_their_pin(client):
    token = sign_in(client, '4071').json()['session_token']
    changed = client.put('/api/v1/ops/auth/pin', headers={**SERVICE, 'X-Operator-Session': token}, json={'pin': '8352'})
    assert changed.status_code == 200
    assert sign_in(client, '4071').status_code == 400
    assert sign_in(client, '8352').status_code == 200
