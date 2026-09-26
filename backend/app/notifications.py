"""Notifications: an in-app inbox for every user, pushed to their phones when
Firebase Cloud Messaging is configured.

`notify()` is called inside the request's transaction. The inbox row commits
with the change that caused it; push delivery waits until that transaction
commits, so a rolled-back action never alerts anyone.
"""
from __future__ import annotations

import json
import logging
import threading
import time
from pathlib import Path
from typing import Protocol

import httpx
from sqlalchemy import delete, event, select
from sqlalchemy.orm import Session

from . import i18n, models as m
from .config import settings

log = logging.getLogger(__name__)
_PENDING = 'omoterra_pending_push'


def notify(db, user_id, role, kind, message, link='', extra=None):
    """Queue a notification for one user. Deleted accounts get nothing.

    `message` is an i18n.M whose key has `.title` and `.body` entries; both
    are written in the recipient's language, with `extra` (another M)
    appended to the body."""
    if not user_id:
        return None
    user = db.get(m.User, user_id)
    if not user or user.deleted:
        return None
    lang = user.language or 'en'
    title = i18n.t(f'{message.key}.title', lang, **message.values)
    body = i18n.t(f'{message.key}.body', lang, **message.values)
    if extra:
        body = f'{body} {i18n.render(extra, lang)}'
    row = m.Notification(user_id=user_id, role=role, kind=kind, title=title, body=body, link=link)
    db.add(row)
    db.flush()
    tokens = db.scalars(select(m.DeviceToken.token).where(m.DeviceToken.user_id == user_id)).all()
    if tokens:
        db.info.setdefault(_PENDING, []).append({
            'tokens': list(tokens), 'title': title, 'body': body,
            'data': {'notification_id': row.id, 'link': link, 'role': role, 'kind': kind}})
    return row


def view(row):
    return {'id': row.id, 'role': row.role, 'kind': row.kind, 'title': row.title, 'body': row.body,
            'link': row.link, 'read': row.read_at is not None, 'created_at': row.created_at}


@event.listens_for(Session, 'after_commit')
def _send_after_commit(session):
    pending = session.info.pop(_PENDING, None)
    if pending:
        bind = session.get_bind()
        dispatch(lambda: deliver(pending, bind))


@event.listens_for(Session, 'after_rollback')
def _drop_after_rollback(session):
    session.info.pop(_PENDING, None)


def dispatch(job):
    """Push runs off the request thread; tests replace this to run inline."""
    threading.Thread(target=job, daemon=True).start()


def deliver(messages, bind):
    sender = push_sender()
    stale = set()
    for message in messages:
        for token in message['tokens']:
            try:
                if sender.send(token, message['title'], message['body'], message['data']) == 'unregistered':
                    stale.add(token)
            except Exception:  # one bad send must not stop the rest
                log.exception('Push delivery failed')
    if stale:
        # Same database the notification was committed to.
        with Session(bind) as db, db.begin():
            db.execute(delete(m.DeviceToken).where(m.DeviceToken.token.in_(stale)))


class PushSender(Protocol):
    def send(self, token: str, title: str, body: str, data: dict) -> str:
        """Returns 'sent', or 'unregistered' when the token is dead."""
        ...


class DisabledPushSender:
    def send(self, token, title, body, data):
        return 'sent'


class FcmPushSender:
    """Firebase Cloud Messaging HTTP v1, authenticated as the service account."""
    scope = 'https://www.googleapis.com/auth/firebase.messaging'

    def __init__(self, key_file):
        self.key = json.loads(Path(key_file).read_text())
        self.url = f"https://fcm.googleapis.com/v1/projects/{self.key['project_id']}/messages:send"
        self._token, self._expires, self._lock = None, 0.0, threading.Lock()

    def _access_token(self):
        with self._lock:
            if self._token and time.time() < self._expires - 60:
                return self._token
            from google.auth import crypt, jwt
            now = int(time.time())
            assertion = jwt.encode(crypt.RSASigner.from_service_account_info(self.key), {
                'iss': self.key['client_email'], 'scope': self.scope,
                'aud': self.key['token_uri'], 'iat': now, 'exp': now + 3600})
            response = httpx.post(self.key['token_uri'], timeout=15, data={
                'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion': assertion.decode() if isinstance(assertion, bytes) else assertion})
            response.raise_for_status()
            body = response.json()
            self._token, self._expires = body['access_token'], time.time() + body.get('expires_in', 3600)
            return self._token

    def send(self, token, title, body, data):
        response = httpx.post(self.url, timeout=15, headers={'Authorization': f'Bearer {self._access_token()}'}, json={
            'message': {'token': token, 'notification': {'title': title, 'body': body},
                        'data': {k: str(v) for k, v in data.items()},
                        # The app's "Omoterra alerts" channel rings and vibrates.
                        'android': {'priority': 'high', 'notification': {
                            'channel_id': 'omoterra_alerts', 'sound': 'default',
                            'default_vibrate_timings': True,
                            'notification_priority': 'PRIORITY_HIGH'}}}})
        if response.status_code == 404 or (response.status_code == 400 and 'registration token' in response.text):
            return 'unregistered'
        response.raise_for_status()
        return 'sent'


_sender = None


def push_sender() -> PushSender:
    global _sender
    if _sender is None:
        _sender = FcmPushSender(settings().fcm_credentials_file) if settings().push_provider == 'fcm' else DisabledPushSender()
    return _sender
