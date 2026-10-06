"""App payout attempts, refunds and controlled resends (build plan M2.7,
audit F12, decision D9).

A settlement is what Omoterra owes a supplier for one delivered app order
item. Paying it is one or more *attempts* (`settlement_transfers`):

- initiated: sent, no debit confirmation yet. Pending exposure, not money out.
- debited: confirmed on a statement or by the provider. A permanent outflow
  (rule R3), dated its debit day. It never becomes failed: money that comes
  back is a refund.
- failed: evidence that no debit happened. No outflow; the evidence stays.

A refund (`settlement_refunds`) is a separate dated inflow linked to the
debited attempt it came back from, full or partial, with evidence. It never
changes or removes the outflow, and it can never exceed what that attempt
debited (less earlier refunds).

    net paid    = debited outflows - refunds
    outstanding = settlement amount - net paid (never below zero)
    status      = paid once net paid reaches the settlement amount, else pending
    in flight   = initiated attempts (sent, debit not confirmed)
    disputed    = debited money (less its refunds) on attempts the supplier
                  says never arrived
    exposure    = money possibly paid twice: the larger of the disputed money
                  and (net paid + in flight - settlement amount)

Resend controls (D9): every attempt after the first, and a first attempt over
approvals.SECOND_ADMIN_THRESHOLD, needs an approval request that a second
admin (not the requester) approved. While an earlier attempt is unresolved
(initiated, or debited and the supplier says not received) a resend also
needs the acknowledgement that two outflows may exist, and may be up to the
settlement amount; otherwise an attempt may be up to what is outstanding.

The supplier answers "received" / "not received" about the current attempt
(the latest one sent that has not failed or come back in full). The
settlement row keeps that attempt's reference, sent time and answer, so the
supplier app and portal read the same fields as before.
"""
from __future__ import annotations

from datetime import date, datetime, time, timedelta
from decimal import Decimal
from typing import Literal, Optional, Union
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Header
from pydantic import Field, field_validator
from sqlalchemy import func, select

from . import accounts, approvals, auth, contracts as c, duplicates, models as m, services as s
from .db import database
from .i18n import M, fail

router = APIRouter(prefix='/api/v1')
ZERO = Decimal('0')
EAT = ZoneInfo('Africa/Dar_es_Salaam')
# An initiated attempt still unconfirmed after this many days is an exception.
STALE_INITIATED_DAYS = 3
LIVE = ('initiated', 'debited')
RESEND, OVER_THRESHOLD = 'payout_resend', 'payout_over_threshold'
ST, SR = m.SettlementTransfer, m.SettlementRefund


# ---- figures ------------------------------------------------------------------------

def figures(total, debited=ZERO, refunded=ZERO, initiated=ZERO, disputed=ZERO):
    """A settlement's money from its attempt sums (see the module notes)."""
    net = debited - refunded
    out = {'debited': debited, 'refunded': refunded, 'net_paid': net, 'in_flight': initiated,
        'outstanding': max(ZERO, total - net), 'disputed': disputed,
        'exposure': max(disputed, max(ZERO, net + initiated - total))}
    return {k: s.money(v) for k, v in out.items()}


def state(db, settlement, lock=False):
    """Every attempt and refund of one settlement, with its figures, the
    current attempt and the unresolved ones."""
    query = select(ST).where(ST.settlement_id == settlement.id).order_by(ST.attempt_no)
    attempts = db.scalars(query.with_for_update() if lock else query).all()
    refunds = db.scalars(select(SR).where(SR.settlement_id == settlement.id).order_by(SR.refunded_on, SR.created_at)).all()
    back = {}
    for refund in refunds:
        back[refund.transfer_id] = back.get(refund.transfer_id, ZERO) + refund.amount
    kept = lambda a: a.amount - back.get(a.id, ZERO)
    debited = sum((a.amount for a in attempts if a.state == 'debited'), ZERO)
    initiated = sum((a.amount for a in attempts if a.state == 'initiated'), ZERO)
    disputed = sum((kept(a) for a in attempts if a.state == 'debited' and a.supplier_confirmation == 'not_received'), ZERO)
    live = [a for a in attempts if a.state == 'initiated' or (a.state == 'debited' and kept(a) > 0)]
    unresolved = [a for a in live if a.state == 'initiated' or a.supplier_confirmation == 'not_received']
    return {'attempts': attempts, 'refunds': refunds, 'refunded_by_attempt': back,
        'current': live[-1] if live else None, 'unresolved': unresolved,
        **figures(settlement.total_payable, debited, sum(back.values(), ZERO), initiated, disputed)}


def by_settlement(db, settlement_ids=None):
    """{settlement_id: {debited, refunded, initiated, disputed}} for many
    settlements at once (reporting)."""
    refunded_q = select(SR.transfer_id, func.sum(SR.amount).label('back')).group_by(SR.transfer_id).subquery()
    query = (select(ST.settlement_id, ST.state, ST.supplier_confirmation, func.sum(ST.amount),
            func.sum(func.coalesce(refunded_q.c.back, 0)))
        .outerjoin(refunded_q, refunded_q.c.transfer_id == ST.id).group_by(ST.settlement_id, ST.state, ST.supplier_confirmation))
    if settlement_ids is not None:
        query = query.where(ST.settlement_id.in_(list(settlement_ids)))
    out = {}
    for settlement_id, state_, answer, amount, back in db.execute(query):
        row = out.setdefault(settlement_id, {'debited': ZERO, 'refunded': ZERO, 'initiated': ZERO, 'disputed': ZERO})
        if state_ == 'debited':
            row['debited'] += amount
            row['refunded'] += back
            if answer == 'not_received':
                row['disputed'] += amount - back
        elif state_ == 'initiated':
            row['initiated'] += amount
    return out


def settlement_figures(db, settlements):
    """{settlement_id: figures} for settlement rows. A row marked paid with
    no attempt at all (only possible before migration 045 ran) counts as
    paid in full, as it always did."""
    sums = by_settlement(db, [row.id for row in settlements])
    def of(row):
        found = sums.get(row.id)
        if found is None and row.status == 'paid':
            found = {'debited': row.total_payable}
        return figures(row.total_payable, **(found or {}))
    return {row.id: of(row) for row in settlements}


def _sent_at(attempt):
    """When the supplier is told the money was sent: the moment it was
    recorded, or noon of a back-dated sending day."""
    created = attempt.created_at or m.now()
    if created.astimezone(EAT).date() == attempt.sent_on:
        return created
    return datetime.combine(attempt.sent_on, time(12), tzinfo=EAT)


def refresh(db, settlement, current=None):
    """Keep the settlement row in step with its attempts: status from net
    paid, and the current attempt's reference, sent time and answer."""
    db.flush()
    st = state(db, settlement)
    if settlement.status != 'cancelled':
        settlement.status = 'paid' if st['net_paid'] >= settlement.total_payable else 'pending'
    current = st['current']
    settlement.paid_at = _sent_at(current) if current else None
    settlement.payment_reference = current.reference if current else None
    settlement.supplier_confirmation = current.supplier_confirmation if current else None
    settlement.supplier_confirmed_at = current.supplier_confirmed_at if current else None
    db.flush()
    return st


def sent(settlement):
    """The supplier has been told money was sent (an attempt is live)."""
    return settlement.status != 'cancelled' and (settlement.status == 'paid' or settlement.paid_at is not None)


def current_attempt(db, settlement):
    return state(db, settlement)['current']


# ---- what may be sent next --------------------------------------------------------------

def plan(db, settlement, st=None):
    """Whether another attempt may be recorded, up to how much, and which
    approval it needs. Never fails: `blocked` names the reason."""
    st = st or state(db, settlement)
    total = settlement.total_payable
    unresolved = bool(st['unresolved'])
    resend = bool(st['attempts'])
    if settlement.status == 'cancelled':
        return {'blocked': 'cancelled', 'limit': ZERO, 'resend': resend, 'unresolved': unresolved}
    limit = total if unresolved else total - st['net_paid'] - st['in_flight']
    if limit <= 0:
        return {'blocked': 'paid', 'limit': ZERO, 'resend': resend, 'unresolved': unresolved}
    return {'blocked': None, 'limit': limit, 'resend': resend, 'unresolved': unresolved,
        'threshold': approvals.SECOND_ADMIN_THRESHOLD}


def approval_kind(planned, amount):
    if planned['resend']:
        return RESEND
    return OVER_THRESHOLD if approvals.over_threshold(amount) else None


def _check_amount(settlement, planned, amount):
    if planned['blocked'] == 'cancelled':
        fail('err.payout_cancelled', 409)
    if planned['blocked'] == 'paid':
        fail('err.settlement_already_paid_amount_does')
    if amount > planned['limit']:
        fail('err.payout_attempt_over_limit', 422, limit=f"{planned['limit']:,.0f}")


# ---- inputs -----------------------------------------------------------------------------

Method = Union[c.LedgerMethod, Literal['']]


def _past(value):
    return c._not_future(value)


class AttemptInput(c.Input):
    amount: c.Money
    method: Method = ''
    payment_reference: str = Field(min_length=3, max_length=150)
    money_account_id: Optional[str] = Field(default=None, max_length=36)
    sent_on: Optional[date] = None
    # True: the debit is already confirmed (statement line or provider SMS).
    debited: bool = False
    evidence: str = Field(default='', max_length=1000)
    approval_id: Optional[str] = Field(default=None, max_length=36)

    @field_validator('sent_on')
    @classmethod
    def not_future(cls, value):
        return _past(value)


class DebitedInput(c.Input):
    debited_on: date
    evidence: str = Field(min_length=3, max_length=1000)

    @field_validator('debited_on')
    @classmethod
    def not_future(cls, value):
        return _past(value)


class FailedInput(c.Input):
    failed_on: date
    evidence: str = Field(min_length=3, max_length=1000)

    @field_validator('failed_on')
    @classmethod
    def not_future(cls, value):
        return _past(value)


class RefundInput(c.Input):
    amount: c.Money
    refunded_on: date
    method: Method = ''
    reference: str = Field(default='', max_length=150)
    money_account_id: Optional[str] = Field(default=None, max_length=36)
    evidence: str = Field(min_length=3, max_length=1000)

    @field_validator('refunded_on')
    @classmethod
    def not_future(cls, value):
        return _past(value)


class ApprovalInput(c.Input):
    amount: c.Money
    reason: str = Field(min_length=3, max_length=1000)
    # "I understand two outflows may exist for this payout."
    acknowledge_two_outflows: bool = False


# ---- actions ------------------------------------------------------------------------------

def _settlement(db, id):
    row = db.scalar(select(m.Settlement).where(m.Settlement.id == id).with_for_update())
    if row is None:
        fail('err.settlement_not_found', 404)
    return row


def _attempt(db, id):
    row = db.scalar(select(ST).where(ST.id == id).with_for_update())
    if row is None:
        fail('err.payout_attempt_not_found', 404)
    return row


def request_approval(db, settlement, data, operator):
    st = state(db, settlement, lock=True)
    planned = plan(db, settlement, st)
    _check_amount(settlement, planned, data.amount)
    kind = approval_kind(planned, data.amount)
    if kind is None:
        fail('err.payout_approval_not_needed', 409)
    if planned['unresolved'] and not data.acknowledge_two_outflows:
        fail('err.resend_acknowledge_two_outflows', 422)
    return approvals.request(db, 'settlements', settlement.id, kind, data.amount, data.reason,
        data.acknowledge_two_outflows, operator)


def create_attempt(db, settlement, data, operator, debited, evidence=''):
    """Record one payout attempt (see the module notes)."""
    st = state(db, settlement, lock=True)
    planned = plan(db, settlement, st)
    _check_amount(settlement, planned, data.amount)
    kind = approval_kind(planned, data.amount)
    approval = None
    if kind is not None:
        if not data.approval_id:
            fail('err.payout_resend_needs_approval' if kind == RESEND else 'err.payout_over_threshold_needs_approval',
                403, threshold=f'{approvals.SECOND_ADMIN_THRESHOLD:,.0f}')
        approval = approvals.usable(db, data.approval_id, 'settlements', settlement.id, kind, data.amount)
        if planned['unresolved'] and not approval.acknowledged:
            fail('err.resend_acknowledge_two_outflows', 422)
    evidence = (evidence or data.evidence or '').strip()
    if debited and len(evidence) < 3:
        fail('err.payout_debit_evidence', 422)
    account = accounts.require_account(db, data.money_account_id)
    sent_on = data.sent_on or c.business_today()
    number = max((a.attempt_no for a in st['attempts']), default=0) + 1
    row = ST(settlement_id=settlement.id, attempt_no=number, amount=data.amount, method=data.method,
        reference=data.payment_reference.strip(), money_account_id=account.id if account else None, sent_on=sent_on,
        evidence=(data.evidence or '').strip(), state='debited' if debited else 'initiated', initiated_by=operator.id,
        is_resend=number > 1, approval_id=approval.id if approval else None)
    if debited:
        row.debited_on, row.debit_evidence = sent_on, evidence
        row.debit_confirmed_by, row.debit_confirmed_at = operator.id, m.now()
    db.add(row)
    db.flush()
    if account is not None:
        accounts.assign(db, 'settlement_transfers', row.id, account, operator)
    duplicates.claim(db, 'settlement_transfers', row.id, data.method, account, data.payment_reference, 'out', operator)
    if approval is not None:
        approvals.use(approval, 'settlement_transfers', row.id)
    refresh(db, settlement)
    from . import notifications as notes
    notes.notify(db, settlement.supplier_id, 'supplier', 'payout_paid', M('notify.payout_paid',
        amount=f'{row.amount:,.0f}', reference=row.reference), f'/payouts/{settlement.id}')
    return row


def mark_debited(db, attempt, data, operator):
    if attempt.state != 'initiated':
        fail('err.payout_attempt_not_initiated', 409)
    if data.debited_on < attempt.sent_on:
        fail('err.payout_debit_before_sent', 422, day=attempt.sent_on.isoformat())
    attempt.state, attempt.debited_on, attempt.debit_evidence = 'debited', data.debited_on, data.evidence.strip()
    attempt.debit_confirmed_by, attempt.debit_confirmed_at = operator.id, m.now()
    refresh(db, db.get(m.Settlement, attempt.settlement_id))
    return attempt


def mark_failed(db, attempt, data, operator):
    """Evidence that the money never left: no outflow is recorded. A debited
    attempt cannot fail (R3); money that came back is a refund."""
    if attempt.state == 'debited':
        fail('err.payout_debited_cannot_fail', 409)
    if attempt.state != 'initiated':
        fail('err.payout_attempt_not_initiated', 409)
    if data.failed_on < attempt.sent_on:
        fail('err.payout_failed_before_sent', 422, day=attempt.sent_on.isoformat())
    attempt.state, attempt.failed_on, attempt.failure_evidence = 'failed', data.failed_on, data.evidence.strip()
    attempt.failed_by, attempt.failed_at = operator.id, m.now()
    refresh(db, db.get(m.Settlement, attempt.settlement_id))
    return attempt


def record_refund(db, attempt, data, operator):
    """Money back from a debited attempt: a separate inflow on its own day."""
    if attempt.state != 'debited':
        fail('err.refund_needs_debited_attempt', 409)
    if data.refunded_on < attempt.debited_on:
        fail('err.payout_refund_before_debit', 422, day=attempt.debited_on.isoformat())
    settlement = db.scalar(select(m.Settlement).where(m.Settlement.id == attempt.settlement_id).with_for_update())
    st = state(db, settlement)
    available = attempt.amount - st['refunded_by_attempt'].get(attempt.id, ZERO)
    if data.amount > available or data.amount > st['net_paid']:
        fail('err.payout_refund_more_than_debited', 422, available=f'{max(ZERO, min(available, st["net_paid"])):,.0f}')
    account = accounts.require_account(db, data.money_account_id)
    row = SR(settlement_id=settlement.id, transfer_id=attempt.id, amount=data.amount, refunded_on=data.refunded_on,
        method=data.method, reference=data.reference.strip(), money_account_id=account.id if account else None,
        evidence=data.evidence.strip(), recorded_by=operator.id)
    db.add(row)
    db.flush()
    if account is not None:
        accounts.assign(db, 'settlement_refunds', row.id, account, operator)
    duplicates.claim(db, 'settlement_refunds', row.id, data.method, account, data.reference, 'in', operator)
    refresh(db, settlement)
    return row


def confirm(db, settlement, supplier_id, received, note):
    """The supplier's answer, attached to the current attempt."""
    attempt = current_attempt(db, settlement)
    if not sent(settlement) or (attempt is None and settlement.status != 'paid'):
        fail('err.payout_not_sent_yet', 409)
    if settlement.supplier_confirmation == 'received':
        fail('err.payout_already_confirmed', 409)
    outcome = 'received' if received else 'not_received'
    at = m.now()
    db.add(m.PayoutConfirmation(settlement_id=settlement.id, supplier_id=supplier_id, outcome=outcome, note=note.strip(),
        amount=attempt.amount if attempt else settlement.total_payable,
        payment_reference=attempt.reference if attempt else settlement.payment_reference,
        transfer_id=attempt.id if attempt else None))
    if attempt is not None:
        attempt.supplier_confirmation, attempt.supplier_confirmed_at = outcome, at
        refresh(db, settlement)
    else:
        settlement.supplier_confirmation, settlement.supplier_confirmed_at = outcome, at
    db.flush()
    return outcome


# ---- totals (reporting) ----------------------------------------------------------------------

def exposure_totals(db):
    """Payouts in flight (sent, debit not confirmed: not money out) and the
    disputed exposure (money possibly paid twice), with their counts."""
    rows = db.scalars(select(m.Settlement).where(m.Settlement.id.in_(select(ST.settlement_id)))).all()
    numbers = settlement_figures(db, rows)
    in_flight = [n['in_flight'] for n in numbers.values() if n['in_flight'] > 0]
    exposure = [n['exposure'] for n in numbers.values() if n['exposure'] > 0]
    return {'in_flight': sum(in_flight, ZERO), 'in_flight_count': len(in_flight),
        'exposure': sum(exposure, ZERO), 'exposure_count': len(exposure)}


def stale_initiated(db, today=None, days=STALE_INITIATED_DAYS):
    """Initiated attempts sent more than `days` days ago and still not
    confirmed or proven failed."""
    today = today or c.business_today()
    return db.scalars(select(ST).where(ST.state == 'initiated', ST.sent_on < today - timedelta(days=days))
        .order_by(ST.sent_on)).all()


# ---- views ------------------------------------------------------------------------------------

def _names(db, ids):
    ids = [i for i in set(ids) if i]
    return dict(db.execute(select(m.Operator.id, m.Operator.name).where(m.Operator.id.in_(ids))).all()) if ids else {}


def attempt_view(db, row, refunds=(), names=None, account_names=None, answers=()):
    names, account_names = names or {}, account_names or {}
    back = sum((r.amount for r in refunds), ZERO)
    return {'id': row.id, 'attempt_no': row.attempt_no, 'amount': row.amount, 'method': row.method,
        'reference': row.reference, 'money_account_id': row.money_account_id,
        'account_name': account_names.get(row.money_account_id), 'sent_on': row.sent_on, 'evidence': row.evidence,
        'state': row.state, 'initiated_by': names.get(row.initiated_by, ''), 'created_at': row.created_at,
        'is_resend': row.is_resend, 'approval_id': row.approval_id, 'legacy': row.legacy,
        'debited_on': row.debited_on, 'debit_evidence': row.debit_evidence,
        'debit_confirmed_by': names.get(row.debit_confirmed_by, ''), 'failed_on': row.failed_on,
        'failure_evidence': row.failure_evidence, 'failed_by': names.get(row.failed_by, ''),
        'supplier_confirmation': row.supplier_confirmation, 'supplier_confirmed_at': row.supplier_confirmed_at,
        'refunded': s.money(back), 'kept': s.money(row.amount - back if row.state == 'debited' else ZERO),
        'refunds': [{'id': r.id, 'amount': r.amount, 'refunded_on': r.refunded_on, 'method': r.method,
            'reference': r.reference, 'account_name': account_names.get(r.money_account_id), 'evidence': r.evidence,
            'recorded_by': names.get(r.recorded_by, ''), 'created_at': r.created_at} for r in refunds],
        'answers': [{'outcome': a.outcome, 'note': a.note, 'created_at': a.created_at} for a in answers]}


def detail(db, settlement):
    st = state(db, settlement)
    approvals_rows = db.scalars(select(m.ApprovalRequest).where(m.ApprovalRequest.subject_table == 'settlements',
        m.ApprovalRequest.subject_id == settlement.id).order_by(m.ApprovalRequest.created_at.desc())).all()
    answers = db.scalars(select(m.PayoutConfirmation).where(m.PayoutConfirmation.settlement_id == settlement.id)
        .order_by(m.PayoutConfirmation.created_at)).all()
    legacy = next((a.id for a in st['attempts'] if a.legacy), None)
    by_attempt = {}
    for answer in answers:
        by_attempt.setdefault(answer.transfer_id or legacy, []).append(answer)
    names = _names(db, [i for a in st['attempts'] for i in (a.initiated_by, a.debit_confirmed_by, a.failed_by)]
        + [r.recorded_by for r in st['refunds']])
    account_ids = {a.money_account_id for a in st['attempts']} | {r.money_account_id for r in st['refunds']}
    account_names = dict(db.execute(select(m.MoneyAccount.id, m.MoneyAccount.name)
        .where(m.MoneyAccount.id.in_([i for i in account_ids if i])))) if any(account_ids) else {}
    refunds = {}
    for refund in st['refunds']:
        refunds.setdefault(refund.transfer_id, []).append(refund)
    profile = db.get(m.SupplierProfile, settlement.supplier_id)
    item = db.get(m.OrderItem, settlement.order_item_id)
    planned = plan(db, settlement, st)
    return {**s.payout_view(settlement, True), 'supplier_id': settlement.supplier_id,
        'order_item_id': settlement.order_item_id, 'order_id': item.order_id if item else None,
        'supplier_alias': profile.public_alias if profile else '', 'supplier_legal_name': profile.legal_name if profile else '',
        **{k: st[k] for k in ('debited', 'refunded', 'net_paid', 'in_flight', 'outstanding', 'disputed', 'exposure')},
        'unresolved_count': len(st['unresolved']),
        'next': {**planned, 'approval_kind': approval_kind(planned, planned['limit']) if not planned['blocked'] else None},
        'threshold': approvals.SECOND_ADMIN_THRESHOLD,
        'attempts': [attempt_view(db, a, refunds.get(a.id, []), names, account_names, by_attempt.get(a.id, []))
            for a in reversed(st['attempts'])],
        'approvals': [approvals.view(db, row) for row in approvals_rows]}


def list_extras(db, settlement):
    """What the Settlements list shows beside each row."""
    st = state(db, settlement)
    waiting = db.scalar(select(func.count()).select_from(m.ApprovalRequest).where(
        m.ApprovalRequest.subject_table == 'settlements', m.ApprovalRequest.subject_id == settlement.id,
        m.ApprovalRequest.status == 'pending')) or 0
    current = st['current']
    return {**{k: st[k] for k in ('net_paid', 'in_flight', 'outstanding', 'exposure', 'refunded')},
        'attempt_count': len(st['attempts']), 'approvals_waiting': waiting,
        'current_state': current.state if current else None}


# ---- API ------------------------------------------------------------------------------------

def _result(value, status_code=200):
    from .main import result
    return result(value, status_code)


def _replayed(db, key, operation, payload, model):
    scoped, fingerprint, prior = s.replay(db, 'ops', operation, key, payload)
    return scoped, fingerprint, (db.get(model, prior) if prior else None)


@router.get('/ops/settlements/{id}')
def settlement_detail(id: str, operator=Depends(auth.ops), db=Depends(database)):
    row = db.get(m.Settlement, id)
    if row is None:
        fail('err.settlement_not_found', 404)
    return _result(detail(db, row))


@router.post('/ops/settlements/{id}/attempts')
def new_attempt(id: str, data: AttemptInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                db=Depends(database)):
    key, fingerprint, prior = _replayed(db, idempotency_key, 'settlement_attempt', {'id': id, **data.model_dump()}, ST)
    settlement = _settlement(db, id)
    if prior is None:
        prior = create_attempt(db, settlement, data, operator, data.debited)
        s.remember(db, key, fingerprint, prior.id)
    return _result(detail(db, settlement), 201)


@router.post('/ops/settlements/{id}/approvals')
def new_approval(id: str, data: ApprovalInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                 db=Depends(database)):
    key, fingerprint, prior = _replayed(db, idempotency_key, 'settlement_approval', {'id': id, **data.model_dump()},
        m.ApprovalRequest)
    settlement = _settlement(db, id)
    if prior is None:
        prior = request_approval(db, settlement, data, operator)
        s.remember(db, key, fingerprint, prior.id)
    return _result(approvals.view(db, prior), 201)


@router.post('/ops/settlement-transfers/{id}/debited')
def attempt_debited(id: str, data: DebitedInput, operator=Depends(auth.ops_admin), db=Depends(database)):
    s.commerce_lock(db)
    attempt = mark_debited(db, _attempt(db, id), data, operator)
    return _result(detail(db, db.get(m.Settlement, attempt.settlement_id)))


@router.post('/ops/settlement-transfers/{id}/failed')
def attempt_failed(id: str, data: FailedInput, operator=Depends(auth.ops_admin), db=Depends(database)):
    s.commerce_lock(db)
    attempt = mark_failed(db, _attempt(db, id), data, operator)
    return _result(detail(db, db.get(m.Settlement, attempt.settlement_id)))


@router.post('/ops/settlement-transfers/{id}/refunds')
def attempt_refund(id: str, data: RefundInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                   db=Depends(database)):
    key, fingerprint, prior = _replayed(db, idempotency_key, 'settlement_refund', {'id': id, **data.model_dump()}, SR)
    attempt = _attempt(db, id)
    if prior is None:
        prior = record_refund(db, attempt, data, operator)
        s.remember(db, key, fingerprint, prior.id)
    return _result(detail(db, db.get(m.Settlement, attempt.settlement_id)), 201)
