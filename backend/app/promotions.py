"""Promotion messages from staff to buyers, suppliers or both.

Recipients are fixed when a promotion is created: every buyer record and
buyer account with a Tanzanian mobile number (offline buyers included) and/or
every supplier account, one row per number, minus numbers that opted out.

- In-app: an inbox notification (pushed when push is set up) for each
  recipient with an app account, written with the promotion.
- SMS: each recipient row starts 'queued'. The queue is drained after the
  promotion commits, off the request thread, in small batches with row locks
  (SKIP LOCKED), so the hourly cron (app/reminders.py) can finish anything a
  restarted server left behind and no number is texted twice.
"""
from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, Header, Response
from sqlalchemy import Text, cast, event, func, select
from sqlalchemy.orm import Session

from . import auth, contracts as c, models as m, notifications as notes, paging, services as s, sms
from .config import settings
from .db import database
from .i18n import M, fail
from .paging import Paging, Spec

log = logging.getLogger(__name__)
router = APIRouter(prefix='/api/v1/ops')
BATCH = 20
# A promotion is still worth delivering a day late; a sign-in code is not.
SMS_VALIDITY_SECONDS = 24 * 3600
_PENDING = 'omoterra_pending_promotions'


def _result(value, status_code=200):
    from .main import result
    return result(value, status_code)


def _opted_out(db):
    return set(db.scalars(select(m.PromotionOptOut.phone)))


def audience(db, who):
    """{phone: recipient} for 'buyers', 'suppliers' or 'everyone'."""
    people = {}

    def add(phone, name, role, user_id=None, profile_id=None):
        phone = c.tanzanian_mobile(phone or '')
        if not phone or not phone.startswith('+255') or len(phone) != 13:
            return
        person = people.setdefault(phone, {'phone': phone, 'name': name or '', 'role': role,
                                           'user_id': None, 'buyer_profile_id': None})
        person['name'] = person['name'] or name or ''
        person['user_id'] = person['user_id'] or user_id
        person['buyer_profile_id'] = person['buyer_profile_id'] or profile_id

    live = [m.User.deleted.is_(False)]
    if who in ('buyers', 'everyone'):
        for user in db.scalars(select(m.User).where(paging.is_buyer(), *live)):
            add(user.phone, user.name, 'buyer', user.id)
        for profile in db.scalars(select(m.BuyerProfile)):
            user = db.get(m.User, profile.user_id) if profile.user_id else None
            if user is not None and user.deleted:
                continue
            add(profile.phone, profile.contact_person or profile.business_name, 'buyer',
                profile.user_id, profile.id)
    if who in ('suppliers', 'everyone'):
        for user in db.scalars(select(m.User).where(cast(m.User.roles, Text).like('%"supplier"%'), *live)):
            add(user.phone, user.name, 'supplier', user.id)
    for phone in _opted_out(db) & people.keys():
        del people[phone]
    # A number that belongs to an account reaches its inbox too.
    for person in people.values():
        if not person['user_id']:
            user = db.scalar(select(m.User).where(m.User.phone == person['phone'], *live))
            person['user_id'] = user.id if user else None
    return people


def _counts(db, promotion_id):
    rows = dict(db.execute(select(m.PromotionRecipient.sms_status, func.count())
        .where(m.PromotionRecipient.promotion_id == promotion_id).group_by(m.PromotionRecipient.sms_status)).all())
    return {status: rows.get(status, 0) for status in ('queued', 'sent', 'failed', 'skipped')}


def view(db, row):
    return {**{k: getattr(row, k) for k in ('id', 'created_at', 'audience', 'title', 'message', 'send_sms',
        'send_in_app', 'recipient_count', 'in_app_count')}, 'sms': _counts(db, row.id),
        'created_by': (db.get(m.Operator, row.created_by).name if row.created_by and db.get(m.Operator, row.created_by) else None)}


@router.get('/promotions/audience')
def audience_size(who: str = 'buyers', operator=Depends(auth.ops), db=Depends(database)):
    if who not in ('buyers', 'suppliers', 'everyone'):
        fail('err.choose_promotion_audience', 422)
    people = audience(db, who)
    return _result({'audience': who, 'numbers': len(people),
        'with_app': sum(1 for p in people.values() if p['user_id']), 'opted_out': len(_opted_out(db)),
        'sms_ready': settings().sms_provider == 'sema'})


@router.post('/promotions', status_code=201)
def create_promotion(data: c.PromotionInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                     db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'promotion', idempotency_key, data.model_dump())
    if prior:
        return _result(view(db, db.get(m.Promotion, prior)), 201)
    people = audience(db, data.audience)
    if not people:
        fail('err.no_one_to_send_promotion', 422)
    row = m.Promotion(created_by=operator.id, recipient_count=len(people), **data.model_dump())
    db.add(row)
    db.flush()
    in_app = 0
    for person in people.values():
        db.add(m.PromotionRecipient(promotion_id=row.id, phone=person['phone'], name=person['name'],
            user_id=person['user_id'], buyer_profile_id=person['buyer_profile_id'],
            sms_status='queued' if data.send_sms else 'skipped'))
        if data.send_in_app and person['user_id']:
            if notes.notify(db, person['user_id'], person['role'], 'promotion',
                    M('notify.promotion', title=data.title, body=data.message)):
                in_app += 1
    row.in_app_count = in_app
    db.flush()
    if data.send_sms:
        db.info.setdefault(_PENDING, True)
    s.remember(db, key, fingerprint, row.id)
    return _result(view(db, row), 201)


@router.post('/promotions/{id}/retry')
def retry_failed(id: str, operator=Depends(auth.ops_admin), db=Depends(database)):
    row = db.get(m.Promotion, id)
    if not row:
        fail('err.promotion_not_found', 404)
    for recipient in db.scalars(select(m.PromotionRecipient).where(m.PromotionRecipient.promotion_id == id,
            m.PromotionRecipient.sms_status == 'failed').with_for_update(skip_locked=True)):
        recipient.sms_status, recipient.sms_error = 'queued', ''
    db.flush()
    db.info.setdefault(_PENDING, True)
    return _result(view(db, row))


PROMOTIONS = Spec(m.Promotion, (m.Promotion.created_at.desc(), m.Promotion.id.desc()),
    lambda q: paging.matches(q, m.Promotion.title, m.Promotion.message))


@router.get('/promotions')
def promotions(params: Paging = Depends(), operator=Depends(auth.ops), db=Depends(database)):
    return _result(paging.page(db, PROMOTIONS, params, lambda row: view(db, row)))


@router.get('/promotions/opt-outs')
def opt_outs(operator=Depends(auth.ops), db=Depends(database)):
    return _result([{'phone': r.phone, 'note': r.note, 'created_at': r.created_at}
        for r in db.scalars(select(m.PromotionOptOut).order_by(m.PromotionOptOut.created_at.desc()))])


@router.post('/promotions/opt-outs', status_code=201)
def add_opt_out(data: c.OptOutInput, operator=Depends(auth.ops), db=Depends(database)):
    row = db.get(m.PromotionOptOut, data.phone)
    if row is None:
        row = m.PromotionOptOut(phone=data.phone, note=data.note)
        db.add(row)
    # Nothing still waiting in a queue goes to this number.
    for recipient in db.scalars(select(m.PromotionRecipient).where(m.PromotionRecipient.phone == data.phone,
            m.PromotionRecipient.sms_status == 'queued').with_for_update()):
        recipient.sms_status, recipient.sms_error = 'skipped', 'Opted out'
    db.flush()
    return _result({'phone': row.phone, 'note': row.note, 'created_at': row.created_at}, 201)


@router.delete('/promotions/opt-outs/{phone}', status_code=204)
def remove_opt_out(phone: str, operator=Depends(auth.ops_admin), db=Depends(database)):
    row = db.get(m.PromotionOptOut, c.tanzanian_mobile(phone))
    if row:
        db.delete(row)
    return Response(status_code=204)


@router.get('/promotions/{id}')
def promotion(id: str, status: Optional[str] = None, operator=Depends(auth.ops), db=Depends(database)):
    row = db.get(m.Promotion, id)
    if not row:
        fail('err.promotion_not_found', 404)
    query = select(m.PromotionRecipient).where(m.PromotionRecipient.promotion_id == id)
    if status:
        query = query.where(m.PromotionRecipient.sms_status == status)
    recipients = db.scalars(query.order_by(m.PromotionRecipient.sms_status, m.PromotionRecipient.name).limit(1000)).all()
    return _result({**view(db, row), 'recipients': [{k: getattr(r, k) for k in ('id', 'phone', 'name', 'user_id',
        'buyer_profile_id', 'sms_status', 'sms_error', 'sms_attempts', 'sent_at')} for r in recipients]})


# ---- the SMS queue ------------------------------------------------------------

def send_queued(bind, limit=None):
    """Text every queued recipient, BATCH at a time, each batch its own
    transaction. Returns how many were attempted."""
    done = 0
    while limit is None or done < limit:
        with Session(bind) as db, db.begin():
            rows = db.scalars(select(m.PromotionRecipient).where(m.PromotionRecipient.sms_status == 'queued')
                .order_by(m.PromotionRecipient.created_at).limit(BATCH).with_for_update(skip_locked=True)).all()
            if not rows:
                return done
            messages = {p.id: p.message for p in db.scalars(select(m.Promotion)
                .where(m.Promotion.id.in_({r.promotion_id for r in rows})))}
            for row in rows:
                row.sms_attempts += 1
                if settings().sms_provider != 'sema':
                    row.sms_status, row.sms_error = 'skipped', 'SMS is not set up on this server'
                    continue
                try:
                    sms.send(row.phone, messages[row.promotion_id], reference=row.id[:32],
                             validity_seconds=SMS_VALIDITY_SECONDS)
                except sms.SmsNotSent as exc:
                    row.sms_status, row.sms_error = 'failed', str(exc)[:300]
                except Exception:  # one bad number must not stop the rest
                    log.exception('Promotion SMS failed')
                    row.sms_status, row.sms_error = 'failed', 'Unexpected error'
                else:
                    row.sms_status, row.sent_at = 'sent', m.now()
            done += len(rows)
    return done


@event.listens_for(Session, 'after_commit')
def _send_after_commit(session):
    if session.info.pop(_PENDING, None):
        bind = session.get_bind()
        notes.dispatch(lambda: send_queued(bind))


@event.listens_for(Session, 'after_rollback')
def _drop_after_rollback(session):
    session.info.pop(_PENDING, None)
