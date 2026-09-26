import re

import pytest

from app import models as m
from app import sms
from app.config import settings

BUYER = {'Authorization': 'Bearer buyer'}


class FakeSema:
    def __init__(self, status='S'):
        self.status, self.sent = status, []

    def __call__(self, url, json, timeout):
        self.sent.append((url, json))
        status = self.status

        class Answer:
            status_code = 200
            def json(self):
                return {'message_id': 41, 'status': status, 'remarks': 'Message Submitted Successfully' if status == 'S' else 'Invalid api_password'}
        return Answer()


@pytest.fixture
def sema(monkeypatch):
    cfg = settings()
    saved = {k: getattr(cfg, k) for k in ('sms_provider', 'sema_api_id', 'sema_api_password', 'sema_sender_id', 'sema_sms_type')}
    cfg.sms_provider, cfg.sema_api_id, cfg.sema_api_password, cfg.sema_sender_id, cfg.sema_sms_type = 'sema', 'API123', 'secret', 'OMOTERRA', 'P'
    fake = FakeSema()
    monkeypatch.setattr(sms.httpx, 'post', fake)
    yield fake
    for key, value in saved.items():
        setattr(cfg, key, value)


def test_sema_texts_the_code_and_never_returns_it(client, sema):
    start = client.post('/api/v1/auth/otp', json={'phone': '+255754123456'})
    assert start.status_code == 200
    assert 'development_code' not in start.json()
    url, payload = sema.sent[0]
    assert url == 'https://api.sema.co.tz/api/SendSMS'
    assert payload['phonenumber'] == '255754123456'
    assert payload['sms_type'] == 'P' and payload['encoding'] == 'T'
    assert payload['sender_id'] == 'OMOTERRA' and payload['api_id'] == 'API123'
    assert payload['uid'] == start.json()['challenge_id']
    code = re.search(r'\b(\d{6})\b', payload['textmessage']).group(1)
    verified = client.post('/api/v1/auth/verify', json={'challenge_id': start.json()['challenge_id'], 'code': code})
    assert verified.status_code == 200


def test_sms_type_comes_from_settings(client, sema):
    settings().sema_sms_type = 'T'
    client.post('/api/v1/auth/otp', json={'phone': '+255754123457'})
    assert sema.sent[0][1]['sms_type'] == 'T'


def test_a_refused_text_can_be_retried_straight_away(client, sema):
    sema.status = 'F'
    failed = client.post('/api/v1/auth/otp', json={'phone': '+255754123458'})
    assert failed.status_code == 503
    assert 'secret' not in failed.text
    sema.status = 'S'
    # No resend wait: the refused code was never delivered.
    assert client.post('/api/v1/auth/otp', json={'phone': '+255754123458'}).status_code == 200


def test_sema_settings_are_required():
    from app.config import Settings
    with pytest.raises(RuntimeError, match='SEMA_API_ID'):
        Settings(sms_provider='sema').validate_runtime()
    with pytest.raises(RuntimeError, match='SEMA_SMS_TYPE'):
        Settings(sms_provider='sema', sema_api_id='a', sema_api_password='b', sema_sender_id='c', sema_sms_type='X').validate_runtime()


def sign_in(client, pin, phone='+255712345678'):
    return client.post('/api/v1/auth/pin/sign-in', json={'phone': phone, 'pin': pin})


def test_pin_sign_in_needs_no_sms(client):
    assert client.get('/api/v1/me', headers=BUYER).json()['has_pin'] is False
    assert client.put('/api/v1/auth/pin', json={'pin': '4071'}).status_code == 401
    saved = client.put('/api/v1/auth/pin', json={'pin': '4071'}, headers=BUYER)
    assert saved.status_code == 200 and saved.json()['has_pin'] is True
    session = sign_in(client, '4071')
    assert session.status_code == 200
    token = session.json()['access_token']
    me = client.get('/api/v1/me', headers={'Authorization': f'Bearer {token}'})
    assert me.json()['phone'] == '+255712345678'


@pytest.mark.parametrize('pin', ['0000', '1234', '987654', '12a4', '123'])
def test_guessable_or_malformed_pins_are_refused(client, pin):
    assert client.put('/api/v1/auth/pin', json={'pin': pin}, headers=BUYER).status_code == 422


def test_wrong_pin_and_unknown_phone_look_the_same(client):
    client.put('/api/v1/auth/pin', json={'pin': '4071'}, headers=BUYER)
    wrong = sign_in(client, '4072')
    unknown = sign_in(client, '4071', phone='+255799999999')
    no_pin = sign_in(client, '4071', phone='+255712345679')
    assert wrong.status_code == unknown.status_code == no_pin.status_code == 400
    assert wrong.json() == unknown.json() == no_pin.json()


def test_five_wrong_pins_pause_and_ten_block_until_reset(client, sessions):
    client.put('/api/v1/auth/pin', json={'pin': '4071'}, headers=BUYER)
    for _ in range(4):
        assert sign_in(client, '5555').status_code == 400
    assert sign_in(client, '5555').status_code == 400
    # Paused: even the right PIN waits.
    assert sign_in(client, '4071').status_code == 429
    with sessions.begin() as db:
        user = db.query(m.User).filter_by(phone='+255712345678').one()
        user.pin_locked_until = None
    for _ in range(5):
        sign_in(client, '5555')
    with sessions.begin() as db:
        db.query(m.User).filter_by(phone='+255712345678').one().pin_locked_until = None
    blocked = sign_in(client, '4071')
    assert blocked.status_code == 429 and 'Reset' in blocked.json()['detail']
    # A texted code gives a session; resetting the PIN from it unblocks.
    assert client.put('/api/v1/auth/pin', json={'pin': '8352'}, headers=BUYER).status_code == 200
    assert sign_in(client, '8352').status_code == 200


def test_a_correct_pin_clears_earlier_wrong_tries(client, sessions):
    client.put('/api/v1/auth/pin', json={'pin': '4071'}, headers=BUYER)
    for _ in range(3):
        sign_in(client, '5555')
    assert sign_in(client, '4071').status_code == 200
    with sessions.begin() as db:
        assert db.query(m.User).filter_by(phone='+255712345678').one().pin_failed_attempts == 0


def test_sema_credentials_use_the_shared_unprefixed_names(monkeypatch):
    from app.config import Settings
    monkeypatch.setenv('SEMA_API_ID', 'API999')
    monkeypatch.setenv('SEMA_API_PASSWORD', 'shared-secret')
    monkeypatch.setenv('OMOTERRA_SEMA_SENDER_ID', 'OMOTERRA')
    cfg = Settings(_env_file=None)
    assert (cfg.sema_api_id, cfg.sema_api_password, cfg.sema_sender_id) == ('API999', 'shared-secret', 'OMOTERRA')
    # The prefixed names are not read for these two.
    monkeypatch.delenv('SEMA_API_ID')
    monkeypatch.setenv('OMOTERRA_SEMA_API_ID', 'API111')
    assert Settings(_env_file=None).sema_api_id == ''
