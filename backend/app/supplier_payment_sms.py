"""Durable, post-commit SMS receipts for supplier payments."""
from __future__ import annotations

import logging

from sqlalchemy import event, select
from sqlalchemy.orm import Session

from . import models as m, notifications as notes, sms
from .config import settings

log = logging.getLogger(__name__)
BATCH = 20
SMS_VALIDITY_SECONDS = 24 * 3600
_PENDING = 'omoterra_pending_supplier_receipt_sms'

METHODS = {
    'en': {
        'cash': 'cash', 'mpesa': 'M-Pesa', 'airtel_money': 'Airtel Money',
        'mixx_by_yas': 'Mixx by Yas', 'halopesa': 'HaloPesa',
        'bank_transfer': 'bank transfer', 'cheque': 'cheque', 'other': 'the agreed method',
    },
    'sw': {
        'cash': 'taslimu', 'mpesa': 'M-Pesa', 'airtel_money': 'Airtel Money',
        'mixx_by_yas': 'Mixx by Yas', 'halopesa': 'HaloPesa',
        'bank_transfer': 'uhamisho wa benki', 'cheque': 'hundi', 'other': 'njia tuliyokubaliana',
    },
}


def message(amount, paid_on, method, reference, language='en', include_thank_you=True):
    amount_text = f'TZS {amount:,.0f}'
    method_text = METHODS[language].get(method, method.replace('_', ' '))
    reference = reference.strip()
    if language == 'sw':
        text = f'Risiti ya malipo ya Omoterra: {amount_text} imelipwa kwenye akaunti yako tarehe {paid_on.isoformat()} kupitia {method_text}.'
        if reference:
            text += f' Kumbukumbu: {reference}.'
        if include_thank_you:
            text += ' Asante kwa kusambaza bidhaa kwa Omoterra.'
        return text
    text = f'Omoterra payment receipt: {amount_text} was paid to your account on {paid_on.isoformat()} via {method_text}.'
    if reference:
        text += f' Reference: {reference}.'
    if include_thank_you:
        text += ' Thank you for supplying Omoterra.'
    return text


def queue(db, payment):
    payment.receipt_sms_status = 'queued'
    db.info[_PENDING] = True


def send_queued(bind, limit=None):
    done = 0
    while limit is None or done < limit:
        with Session(bind) as db, db.begin():
            rows = db.scalars(select(m.SupplierPayment)
                .where(m.SupplierPayment.receipt_sms_status == 'queued')
                .order_by(m.SupplierPayment.created_at).limit(BATCH)
                .with_for_update(skip_locked=True)).all()
            if not rows:
                return done
            for row in rows:
                row.receipt_sms_attempts += 1
                if settings().sms_provider != 'sema':
                    row.receipt_sms_status = 'skipped'
                    row.receipt_sms_error = 'SMS is not set up on this server'
                    continue
                try:
                    sms.send(row.receipt_sms_phone, row.receipt_sms_message,
                        reference=row.id[:32], validity_seconds=SMS_VALIDITY_SECONDS)
                except sms.SmsNotSent as exc:
                    row.receipt_sms_status, row.receipt_sms_error = 'failed', str(exc)[:300]
                except Exception:
                    log.exception('Supplier payment receipt SMS failed')
                    row.receipt_sms_status, row.receipt_sms_error = 'failed', 'Unexpected error'
                else:
                    row.receipt_sms_status = 'sent'
                    row.receipt_sms_error = ''
                    row.receipt_sms_sent_at = m.now()
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
