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
