"""Text messages through Sema (https://api.sema.co.tz, Web API v3.0).

Only the sign-in / verification code is sent by SMS. Omoterra generates and
checks the code itself (app/auth.py: expiry, resend wait, 5 attempts); Sema's
SendSMS only delivers it, with the account's message type (OMOTERRA_SEMA_SMS_TYPE).
"""
from __future__ import annotations

import logging

import httpx

from .config import settings

log = logging.getLogger(__name__)
TIMEOUT = httpx.Timeout(15.0, connect=5.0)


class SmsNotSent(Exception):
    """Sema refused or could not be reached. Never carries credentials."""


def sema_number(phone):
    """Sema wants the country code and number without '+': 255754123456."""
    return phone.removeprefix('+')


def send(phone, text, reference=''):
    cfg = settings()
    payload = {
        'api_id': cfg.sema_api_id, 'api_password': cfg.sema_api_password,
        'sms_type': cfg.sema_sms_type, 'encoding': 'T', 'sender_id': cfg.sema_sender_id,
        'phonenumber': sema_number(phone), 'textmessage': text,
        'ValidityPeriodInSeconds': cfg.otp_ttl_seconds,
    }
    if reference:
        payload['uid'] = reference
    try:
        response = httpx.post(cfg.sema_url, json=payload, timeout=TIMEOUT)
        answer = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        log.warning('Sema SendSMS unreachable: %s', type(exc).__name__)
        raise SmsNotSent('unreachable') from None
    # status: S = submitted, F = failed to submit (remarks says why).
    if not isinstance(answer, dict) or answer.get('status') != 'S':
        remarks = answer.get('remarks') if isinstance(answer, dict) else ''
        log.warning('Sema SendSMS refused (HTTP %s): %s', response.status_code, remarks)
        raise SmsNotSent(str(remarks or 'refused'))
    return answer.get('message_id')


def balance():
    """Sema CheckBalance: proves the API ID and password work, free of charge."""
    cfg = settings()
    url = cfg.sema_url.rsplit('/', 1)[0] + '/CheckBalance'
    response = httpx.post(url, json={'api_id': cfg.sema_api_id, 'api_password': cfg.sema_api_password}, timeout=TIMEOUT)
    return response.json()


def _check():
    """What this server will do with sign-in codes, without printing secrets."""
    import os
    from pathlib import Path
    cfg = settings()
    here = Path(__file__).resolve().parents[1]
    names = ('OMOTERRA_SMS_PROVIDER', 'SEMA_API_ID', 'SEMA_API_PASSWORD', 'OMOTERRA_SEMA_SENDER_ID', 'OMOTERRA_SEMA_SMS_TYPE')
    for path in (here / '.env', here.parent / '.env'):
        if not path.exists():
            print(f'{path}: missing')
            continue
        entries = [(number, *line.split('=', 1)) for number, line in enumerate(path.read_text().splitlines(), 1)
                   if '=' in line and line.split('=', 1)[0].strip().removeprefix('export ').strip() in names]
        entries = [(number, key.strip().removeprefix('export ').strip(), value) for number, key, value in entries]
        print(f'{path}: {", ".join(key for _, key, _ in entries) or "no SMS settings"}')
        for number, key, value in entries:
            if key == 'OMOTERRA_SMS_PROVIDER':
                # The provider name is not a secret; showing it makes a stray line obvious.
                print(f'  line {number}: OMOTERRA_SMS_PROVIDER={value.strip()}')
        for key in {key for _, key, _ in entries if [k for _, k, _ in entries].count(key) > 1}:
            print(f'  WARNING: {key} is set more than once in this file; the last line wins. Keep one.')
    if os.environ.get('OMOTERRA_SMS_PROVIDER'):
        print('OMOTERRA_SMS_PROVIDER is also set in the process environment')
    print(f'SMS provider in effect: {cfg.sms_provider}')
    if cfg.sms_provider != 'sema':
        print("Codes are shown on screen, not texted. Set OMOTERRA_SMS_PROVIDER=sema in the .env beside the app, then restart.")
        return
    print(f'Sender ID: {cfg.sema_sender_id or "MISSING"} | SMS type: {cfg.sema_sms_type} | '
          f'API ID: {"set" if cfg.sema_api_id else "MISSING"} | API password: {"set" if cfg.sema_api_password else "MISSING"}')
    try:
        answer = balance()
    except (httpx.HTTPError, ValueError) as exc:
        print(f'Sema not reachable: {type(exc).__name__}')
        return
    print(f'Sema balance check: {answer}')


def _test(phone):
    """Sends one real text to `phone` (costs one SMS) and shows Sema's answer."""
    cfg = settings()
    print(f'Sending from sender ID {cfg.sema_sender_id!r} as type {cfg.sema_sms_type!r} to {sema_number(phone)}')
    try:
        print(f'Submitted, Sema message_id {send(phone, "Omoterra test message: SMS delivery works.")}')
    except SmsNotSent as exc:
        print(f'Sema refused: {exc}')
        print('Common causes: sender ID not approved on the account, wrong SMS type (P/T) for that sender ID, '
              'wrong API ID or password, or no SMS balance. Run `python -m app.sms check` to test the login and balance.')


if __name__ == '__main__':
    import sys
    if sys.argv[1:2] == ['check']:
        _check()
    elif sys.argv[1:2] == ['test'] and len(sys.argv) == 3:
        _test(sys.argv[2])
    else:
        print('Usage: python -m app.sms check | python -m app.sms test +2557XXXXXXXX')
