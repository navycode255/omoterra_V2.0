"""Second-admin approvals (decision D9, 6 October 2026).

Any payout resend, or any payment over SECOND_ADMIN_THRESHOLD, needs approval
from a second admin who is not the requester. Build plan M2.7 applies it to
app payout attempts (payouts.py): every attempt after the first, and a first
attempt over the threshold. M5 (configurable approvals for other payment
types) reuses this table, this threshold and these rules.

A request names what it is about (`subject_table`, `subject_id`), its kind,
the amount, a reason and, for a resend while an earlier attempt is
unresolved, the acknowledgement that two outflows may exist. Another admin
approves or rejects it; the database refuses an approval by the requester.
An approved request is used once, by the record it allowed.
"""
from __future__ import annotations

from decimal import Decimal

from fastapi import APIRouter, Depends, Query
from pydantic import Field
from sqlalchemy import select

from . import auth, contracts as c, models as m
from .db import database
from .i18n import fail

router = APIRouter(prefix='/api/v1')

# Decision D9: a payment above this (TZS) needs a second admin. One place,
# so M5's configurable thresholds start from it.
SECOND_ADMIN_THRESHOLD = Decimal('500000')

AR = m.ApprovalRequest


def over_threshold(amount):
    return Decimal(amount) > SECOND_ADMIN_THRESHOLD


def request(db, subject_table, subject_id, kind, amount, reason, acknowledged, operator):
    row = AR(subject_table=subject_table, subject_id=subject_id, kind=kind, amount=amount, reason=reason.strip(),
        acknowledged=bool(acknowledged), requested_by=operator.id)
    db.add(row)
    db.flush()
    return row


def decide(db, row, operator, approve, note=''):
    """Approve or reject a pending request. Only a second admin approves;
    anyone, the requester included, may reject (withdraw) it."""
    if row.status != 'pending':
        fail('err.approval_already_decided', 409)
    if approve and operator.id == row.requested_by:
        fail('err.approval_needs_second_admin', 403)
    row.status = 'approved' if approve else 'rejected'
    row.decided_by, row.decided_at, row.decision_note = operator.id, m.now(), (note or '').strip()
    db.flush()
    return row


def usable(db, approval_id, subject_table, subject_id, kind, amount):
    """The approved, unused request that allows this record, or a refusal."""
    if not approval_id:
        return None
    row = db.scalar(select(AR).where(AR.id == approval_id).with_for_update())
    if (row is None or row.subject_table != subject_table or row.subject_id != subject_id or row.kind != kind
            or row.status != 'approved' or row.used_at is not None):
        fail('err.approval_not_usable', 409)
    if Decimal(amount) > row.amount:
        fail('err.approval_amount_exceeded', 422, approved=f'{row.amount:,.0f}')
    return row


def use(row, table, id):
    row.used_by_table, row.used_by_id, row.used_at = table, id, m.now()


def view(db, row):
    names = dict(db.execute(select(m.Operator.id, m.Operator.name).where(
        m.Operator.id.in_([i for i in (row.requested_by, row.decided_by) if i]))).all())
    return {'id': row.id, 'created_at': row.created_at, 'subject_table': row.subject_table, 'subject_id': row.subject_id,
        'kind': row.kind, 'amount': row.amount, 'reason': row.reason, 'acknowledged': row.acknowledged,
        'requested_by': row.requested_by, 'requested_by_name': names.get(row.requested_by, ''),
        'status': row.status, 'decided_by': row.decided_by, 'decided_by_name': names.get(row.decided_by, ''),
        'decided_at': row.decided_at, 'decision_note': row.decision_note, 'used': row.used_at is not None,
        'used_by_id': row.used_by_id, 'used_at': row.used_at}


def _result(value, status_code=200):
    from .main import result
    return result(value, status_code)


class DecisionInput(c.Input):
    note: str = Field(default='', max_length=500)


def _row(db, id):
    row = db.scalar(select(AR).where(AR.id == id).with_for_update())
    if row is None:
        fail('err.approval_not_found', 404)
    return row


@router.get('/ops/approvals')
def approvals(status: str = Query('pending', pattern='^(pending|approved|rejected)$'),
              operator=Depends(auth.ops), db=Depends(database)):
    rows = db.scalars(select(AR).where(AR.status == status).order_by(AR.created_at.desc()).limit(100)).all()
    return _result({'items': [view(db, row) for row in rows], 'threshold': SECOND_ADMIN_THRESHOLD})


@router.post('/ops/approvals/{id}/approve')
def approve(id: str, data: DecisionInput, operator=Depends(auth.ops_admin), db=Depends(database)):
    return _result(view(db, decide(db, _row(db, id), operator, True, data.note)))


@router.post('/ops/approvals/{id}/reject')
def reject(id: str, data: DecisionInput, operator=Depends(auth.ops_admin), db=Depends(database)):
    return _result(view(db, decide(db, _row(db, id), operator, False, data.note)))
