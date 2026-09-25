import hashlib
import hmac
import secrets
from datetime import timedelta
from fastapi import Depends, Header, HTTPException, Request
from sqlalchemy import select, text
from .db import database
from .config import settings
from . import models as m


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def otp_hash(challenge, code):
    return hmac.new(settings().otp_secret.encode(), f'{challenge}:{code}'.encode(), hashlib.sha256).hexdigest()


def current_user(authorization: str = Header(default=''), db=Depends(database)):
    token = authorization.removeprefix('Bearer ')
    session = db.scalar(select(m.AuthSession).where(m.AuthSession.token_hash == digest(token), m.AuthSession.expires_at > m.now()))
    if not session:
        raise HTTPException(401, 'Your session has expired. Sign in again.')
    return db.get(m.User, session.user_id)


def role(name):
    def require(user=Depends(current_user)):
        if name not in user.roles:
            raise HTTPException(403, f'Enable your {name} capability in Account first.')
        return user
    return require


OPERATOR_SESSION_HOURS = 12


def ops_service(x_ops_token: str = Header(default='')):
    """The dashboard server's own credential. Browsers never hold it, so
    ops endpoints can only be reached through the dashboard."""
    expected = settings().ops_token
    if not expected or not hmac.compare_digest(expected, x_ops_token):
        raise HTTPException(403, 'Operations authentication required.')


def ops(request: Request, x_operator_session: str = Header(default=''), _=Depends(ops_service), db=Depends(database)):
    """The signed-in operator. Every change they make is written to the
    audit trail inside the request's own transaction."""
    session = db.scalar(select(m.OperatorSession).where(
        m.OperatorSession.token_hash == digest(x_operator_session), m.OperatorSession.expires_at > m.now()))
    operator = db.get(m.Operator, session.operator_id) if session else None
    if not operator or not operator.active:
        raise HTTPException(401, 'Sign in to the operations dashboard again.')
    if request.method not in ('GET', 'HEAD', 'OPTIONS'):
        db.add(m.OpsAuditEntry(operator_id=operator.id, method=request.method, path=request.url.path))
    return operator


def ops_admin(operator=Depends(ops)):
    if operator.role != 'admin':
        raise HTTPException(403, 'Only an Omoterra admin can do this.')
    return operator


def operator_view(operator):
    return {k: getattr(operator, k) for k in ('id', 'phone', 'name', 'role', 'active', 'last_login_at', 'created_at')}


def user_view(user):
    return {k: getattr(user, k) for k in ['id', 'phone', 'name', 'region', 'language', 'roles', 'buyer_type']}


def start_otp(db, phone, purpose='app'):
    # Serialize per phone to prevent simultaneous resend-limit bypass.
    db.execute(text('SELECT pg_advisory_xact_lock(:key)'), {'key': int(digest(phone)[:15], 16)})
    prior = db.scalar(select(m.OtpChallenge).where(m.OtpChallenge.phone == phone).order_by(m.OtpChallenge.created_at.desc()))
    if prior and (m.now() - prior.created_at).total_seconds() < settings().otp_resend_seconds:
        raise HTTPException(429, 'Please wait before requesting another code.')
    for old in db.scalars(select(m.OtpChallenge).where(m.OtpChallenge.phone == phone, m.OtpChallenge.consumed.is_(False))):
        old.consumed = True
    code = ''.join(secrets.choice('0123456789') for _ in range(settings().otp_length))
    challenge = m.OtpChallenge(id=m.identifier(), phone=phone, code_hash='', purpose=purpose,
        expires_at=m.now() + timedelta(seconds=settings().otp_ttl_seconds))
    challenge.code_hash = otp_hash(challenge.id, code)
    db.add(challenge)
    # Commit before the challenge_id leaves this function. A flush alone
    # keeps the row invisible to other transactions until the request-scoped
    # transaction closes, which happens *after* the response is serialised —
    # so a client that verifies immediately (the app auto-submits on the last
    # digit) could present an id no other connection can see yet and be told
    # its brand-new code had expired.
    db.commit()
    response = {'challenge_id': challenge.id, 'otp_length': settings().otp_length, 'resend_after_seconds': settings().otp_resend_seconds}
    # The code is only ever put in the response while no real SMS provider is
    # wired up (see Settings.validate_runtime) — never on a real deployment
    # sending real texts, even one otherwise marked 'live'.
    if settings().sms_provider == 'development':
        response['development_code'] = code
    return response


def consume_otp(db, challenge_id, code, purpose):
    """Checks a code and returns the phone it was sent to."""
    challenge = db.scalar(select(m.OtpChallenge).where(m.OtpChallenge.id == challenge_id).with_for_update())
    if (not challenge or challenge.purpose != purpose or challenge.consumed
            or challenge.expires_at <= m.now() or challenge.attempts >= 5):
        raise HTTPException(400, 'This code has expired. Request a new code.')
    challenge.attempts += 1
    if not hmac.compare_digest(challenge.code_hash, otp_hash(challenge.id, code)):
        # Commit the failed attempt so a raised HTTP error cannot roll it back.
        db.commit()
        raise HTTPException(400, 'The code is incorrect. Check it and try again.')
    challenge.consumed = True
    return challenge.phone


def verify_otp(db, challenge_id, code):
    phone = consume_otp(db, challenge_id, code, 'app')
    user = db.scalar(select(m.User).where(m.User.phone == phone))
    if not user:
        user = m.User(phone=phone)
        db.add(user)
        db.flush()
    token = secrets.token_urlsafe(48)
    db.add(m.AuthSession(user_id=user.id, token_hash=digest(token), expires_at=m.now() + timedelta(days=settings().session_days)))
    db.flush()
    return {'access_token': token, 'user': user_view(user)}


def start_operator_session(db, challenge_id, code):
    phone = consume_otp(db, challenge_id, code, 'ops')
    operator = db.scalar(select(m.Operator).where(m.Operator.phone == phone))
    if not operator or not operator.active:
        raise HTTPException(403, 'This number is not an active Omoterra operator.')
    return issue_operator_session(db, operator)


def issue_operator_session(db, operator):
    token = secrets.token_urlsafe(48)
    db.add(m.OperatorSession(operator_id=operator.id, token_hash=digest(token),
        expires_at=m.now() + timedelta(hours=OPERATOR_SESSION_HOURS)))
    operator.last_login_at = m.now()
    db.flush()
    return {'session_token': token, 'expires_in': OPERATOR_SESSION_HOURS * 3600, 'operator': operator_view(operator)}
