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
    resolved    = possibly-paid-twice money resolved (supplier credit or
                  write-off, see below)
    credit used = the supplier's payout credit set off against this payout
    settled     = net paid - resolved + credit used
    outstanding = settlement amount - settled (never below zero)
    status      = paid once settled reaches the settlement amount, else pending
    in flight   = initiated attempts (sent, debit not confirmed)
    disputed    = debited money (less its refunds) on attempts the supplier
                  says never arrived
    exposure    = money possibly paid twice: the larger of (disputed -
                  resolved) and (settled + in flight - settlement amount)

Resend controls (D9): every attempt after the first, and a first attempt over
approvals.SECOND_ADMIN_THRESHOLD, needs an approval request that a second
admin (not the requester) approved. While an earlier attempt is unresolved
(initiated, or debited and the supplier says not received) a resend also
needs the acknowledgement that two outflows may exist, and may be up to the
settlement amount; otherwise an attempt may be up to what is outstanding.
A retry after every earlier attempt was proven failed (with evidence: no
money left, so nothing can be paid twice) needs no second admin; it is
treated as a first attempt, so the over-threshold rule still applies
(finance owner, 7 October 2026).

Possibly paid twice, not returned (7 October 2026): an admin asks, a second
admin approves (approvals.py, used once), and the excess is resolved with
evidence, up to the current exposure, in parts if need be. Append-only
(`settlement_resolutions`):

- supplier credit: the supplier received the excess and keeps it. It is
  their payout credit; their next payout attempts use it first
  (`payout_credit_uses`), so the credited part needs no new outflow. Using
  credit moves no money (R4); the outflows stay on their dates (R3).
- write-off: the excess is lost (wrong number, fraud): an expense "Payout
  loss" on the resolution day (reporting.expenses). No money moves: it left
  on its debit day.

A refund after a resolution can never bring back more than the payout's net
paid less what was resolved.

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
# Resolving money possibly paid twice (approval kinds = 'payout_' + kind).
RESOLUTIONS = ('supplier_credit', 'write_off')
ST, SR = m.SettlementTransfer, m.SettlementRefund
RS, CU = m.SettlementResolution, m.PayoutCreditUse


# ---- figures ------------------------------------------------------------------------

def figures(total, debited=ZERO, refunded=ZERO, initiated=ZERO, disputed=ZERO, resolved=ZERO, credit_used=ZERO,
            credited=ZERO, written_off=ZERO):
    """A settlement's money from its attempt sums (see the module notes)."""
    net = debited - refunded
    settled = net - resolved + credit_used
    out = {'debited': debited, 'refunded': refunded, 'net_paid': net, 'in_flight': initiated,
        'resolved': resolved, 'credited': credited, 'written_off': written_off, 'credit_used': credit_used,
        'settled': settled, 'outstanding': max(ZERO, total - settled), 'disputed': disputed,
        'exposure': max(ZERO, disputed - resolved, settled + initiated - total)}
    return {k: s.money(v) for k, v in out.items()}


def _resolved(db, settlement_ids):
    """{settlement_id: {'supplier_credit': x, 'write_off': y}}."""
    out = {}
    query = select(RS.settlement_id, RS.kind, func.sum(RS.amount)).group_by(RS.settlement_id, RS.kind)
    if settlement_ids is not None:
        query = query.where(RS.settlement_id.in_(list(settlement_ids)))
    for settlement_id, kind, amount in db.execute(query):
        out.setdefault(settlement_id, {})[kind] = amount
    return out


def _credit_used(db, settlement_ids):
    query = select(CU.settlement_id, func.sum(CU.amount)).group_by(CU.settlement_id)
    if settlement_ids is not None:
        query = query.where(CU.settlement_id.in_(list(settlement_ids)))
    return dict(db.execute(query).all())


def _resolution_sums(resolved, used):
    credited, written = resolved.get('supplier_credit', ZERO), resolved.get('write_off', ZERO)
    return {'resolved': credited + written, 'credited': credited, 'written_off': written, 'credit_used': used or ZERO}


def state(db, settlement, lock=False):
    """Every attempt and refund of one settlement, with its figures, the
    current attempt and the unresolved ones."""
    query = select(ST).where(ST.settlement_id == settlement.id).order_by(ST.attempt_no)
    attempts = db.scalars(query.with_for_update() if lock else query).all()
    refunds = db.scalars(select(SR).where(SR.settlement_id == settlement.id).order_by(SR.refunded_on, SR.created_at)).all()
    resolutions = db.scalars(select(RS).where(RS.settlement_id == settlement.id).order_by(RS.created_at)).all()
    back = {}
    for refund in refunds:
        back[refund.transfer_id] = back.get(refund.transfer_id, ZERO) + refund.amount
    kept = lambda a: a.amount - back.get(a.id, ZERO)
    debited = sum((a.amount for a in attempts if a.state == 'debited'), ZERO)
    initiated = sum((a.amount for a in attempts if a.state == 'initiated'), ZERO)
    disputed = sum((kept(a) for a in attempts if a.state == 'debited' and a.supplier_confirmation == 'not_received'), ZERO)
    by_kind = {}
    for row in resolutions:
        by_kind[row.kind] = by_kind.get(row.kind, ZERO) + row.amount
    sums = _resolution_sums(by_kind, _credit_used(db, [settlement.id]).get(settlement.id))
    live = [a for a in attempts if a.state == 'initiated' or (a.state == 'debited' and kept(a) > 0)]
    # A disputed attempt stops being unresolved once its money is resolved
    # (supplier credit or write-off) with a second admin's approval.
    still_disputed = disputed - sums['resolved'] > 0
    unresolved = [a for a in live if a.state == 'initiated' or (a.supplier_confirmation == 'not_received' and still_disputed)]
    return {'attempts': attempts, 'refunds': refunds, 'resolutions': resolutions, 'refunded_by_attempt': back,
        'current': live[-1] if live else None, 'unresolved': unresolved,
        **figures(settlement.total_payable, debited, sum(back.values(), ZERO), initiated, disputed, **sums)}


def by_settlement(db, settlement_ids=None):
    """{settlement_id: {debited, refunded, initiated, disputed, resolved,
    credited, written_off, credit_used}} for many settlements at once
    (reporting)."""
    refunded_q = select(SR.transfer_id, func.sum(SR.amount).label('back')).group_by(SR.transfer_id).subquery()
    query = (select(ST.settlement_id, ST.state, ST.supplier_confirmation, func.sum(ST.amount),
            func.sum(func.coalesce(refunded_q.c.back, 0)))
        .outerjoin(refunded_q, refunded_q.c.transfer_id == ST.id).group_by(ST.settlement_id, ST.state, ST.supplier_confirmation))
    if settlement_ids is not None:
        query = query.where(ST.settlement_id.in_(list(settlement_ids)))
    blank = lambda: {'debited': ZERO, 'refunded': ZERO, 'initiated': ZERO, 'disputed': ZERO}
    out = {}
    for settlement_id, state_, answer, amount, back in db.execute(query):
        row = out.setdefault(settlement_id, blank())
        if state_ == 'debited':
            row['debited'] += amount
            row['refunded'] += back
            if answer == 'not_received':
                row['disputed'] += amount - back
        elif state_ == 'initiated':
            row['initiated'] += amount
    resolved, used = _resolved(db, settlement_ids), _credit_used(db, settlement_ids)
    for settlement_id in set(resolved) | set(used):
        out.setdefault(settlement_id, blank()).update(_resolution_sums(resolved.get(settlement_id, {}),
            used.get(settlement_id)))
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


# ---- supplier payout credit (7 October 2026) ---------------------------------------------

def credit_available(db, supplier_id):
    """A supplier's payout credit not yet used: supplier-credit resolutions
    less what their payouts used (a use on a payout cancelled with its
    order's delivery gives the credit back)."""
    granted = db.scalar(select(func.coalesce(func.sum(RS.amount), 0)).where(RS.supplier_id == supplier_id,
        RS.kind == 'supplier_credit')) or ZERO
    used = db.scalar(select(func.coalesce(func.sum(CU.amount), 0)).join(m.Settlement, m.Settlement.id == CU.settlement_id)
        .where(CU.supplier_id == supplier_id, m.Settlement.status != 'cancelled')) or ZERO
    return s.money(granted - used)


def credit_by_supplier(db, supplier_ids=None):
    """{supplier_id: payout credit available} for suppliers with any."""
    granted = select(RS.supplier_id, func.sum(RS.amount)).where(RS.kind == 'supplier_credit').group_by(RS.supplier_id)
    used = (select(CU.supplier_id, func.sum(CU.amount)).join(m.Settlement, m.Settlement.id == CU.settlement_id)
        .where(m.Settlement.status != 'cancelled').group_by(CU.supplier_id))
    if supplier_ids is not None:
        granted = granted.where(RS.supplier_id.in_(list(supplier_ids)))
        used = used.where(CU.supplier_id.in_(list(supplier_ids)))
    spent = dict(db.execute(used).all())
    out = {}
    for supplier_id, amount in db.execute(granted):
        left = s.money(amount - spent.get(supplier_id, ZERO))
        if left > 0:
            out[supplier_id] = left
    return out


def use_credit(db, settlement, amount, operator):
    if amount <= 0:
        return None
    row = CU(supplier_id=settlement.supplier_id, settlement_id=settlement.id, amount=amount,
        used_on=c.business_today(), recorded_by=operator.id if operator else None)
    db.add(row)
    db.flush()
    return row


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
        settlement.status = 'paid' if st['settled'] >= settlement.total_payable else 'pending'
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
    """Whether another attempt may be recorded, up to how much, which
    approval it needs, and how much of the supplier's payout credit it uses
    first. Never fails: `blocked` names the reason."""
    st = st or state(db, settlement)
    total = settlement.total_payable
    unresolved = bool(st['unresolved'])
    # A retry after every earlier attempt was proven failed is not a resend
    # (7 October 2026): no money left, so nothing can be paid twice.
    resend = any(a.state != 'failed' for a in st['attempts'])
    retry = bool(st['attempts']) and not resend
    base = {'resend': resend, 'retry_after_failure': retry, 'unresolved': unresolved, 'credit': ZERO}
    if settlement.status == 'cancelled':
        return {**base, 'blocked': 'cancelled', 'limit': ZERO}
    if unresolved:
        return {**base, 'blocked': None, 'limit': total, 'threshold': approvals.SECOND_ADMIN_THRESHOLD}
    owed = total - st['settled'] - st['in_flight']
    credit = min(credit_available(db, settlement.supplier_id), max(ZERO, owed))
    limit = owed - credit
    if limit <= 0:
        return {**base, 'credit': credit, 'blocked': 'covered_by_credit' if credit > 0 else 'paid', 'limit': ZERO}
    return {**base, 'credit': credit, 'blocked': None, 'limit': limit, 'threshold': approvals.SECOND_ADMIN_THRESHOLD}


def approval_kind(planned, amount):
    if planned['resend']:
        return RESEND
    return OVER_THRESHOLD if approvals.over_threshold(amount) else None


def _check_amount(settlement, planned, amount):
    if planned['blocked'] == 'cancelled':
        fail('err.payout_cancelled', 409)
    if planned['blocked'] == 'paid':
        fail('err.settlement_already_paid_amount_does')
    if planned['blocked'] == 'covered_by_credit':
        fail('err.payout_covered_by_credit', 409, credit=f"{planned['credit']:,.0f}")
    if amount > planned['limit']:
        if planned['credit'] > 0:
            fail('err.payout_attempt_over_limit_credit', 422, limit=f"{planned['limit']:,.0f}",
                credit=f"{planned['credit']:,.0f}")
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


class ResolutionRequestInput(c.Input):
    """Ask a second admin to approve resolving money possibly paid twice."""
    kind: Literal['supplier_credit', 'write_off']
    amount: c.Money
    evidence: str = Field(min_length=3, max_length=1000)


class ResolutionInput(c.Input):
    """Record an approved resolution. Its kind, amount and evidence are the
    approved request's; the day defaults to today."""
    approval_id: str = Field(max_length=36)
    resolved_on: Optional[date] = None

    @field_validator('resolved_on')
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
    # The supplier's payout credit is used first: no money moves for it.
    use_credit(db, settlement, planned['credit'], operator)
    number = max((a.attempt_no for a in st['attempts']), default=0) + 1
    row = ST(settlement_id=settlement.id, attempt_no=number, amount=data.amount, method=data.method,
        reference=data.payment_reference.strip(), money_account_id=account.id if account else None, sent_on=sent_on,
        evidence=(data.evidence or '').strip(), state='debited' if debited else 'initiated', initiated_by=operator.id,
        is_resend=planned['resend'], approval_id=approval.id if approval else None)
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
    # Money resolved as supplier credit or written off is no longer there to
    # come back on this payout (7 October 2026).
    unresolved = st['net_paid'] - st['resolved']
    if data.amount > available or data.amount > unresolved:
        fail('err.payout_refund_more_than_debited', 422, available=f'{max(ZERO, min(available, unresolved)):,.0f}')
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


def request_resolution(db, settlement, data, operator):
    """An admin asks to resolve money possibly paid twice (7 October 2026):
    up to the current exposure, with evidence; a second admin approves."""
    st = state(db, settlement, lock=True)
    if st['exposure'] <= 0:
        fail('err.payout_nothing_to_resolve', 409)
    if data.amount > st['exposure']:
        fail('err.payout_resolution_over_exposure', 422, exposure=f"{st['exposure']:,.0f}")
    return approvals.request(db, 'settlements', settlement.id, 'payout_' + data.kind, data.amount,
        data.evidence, False, operator)


def resolve(db, settlement, data, operator):
    """Record a resolution a second admin approved (used once). Supplier
    credit becomes the supplier's payout credit; a write-off is an expense
    "Payout loss" on the resolution day. No money moves either way."""
    st = state(db, settlement, lock=True)
    row = db.scalar(select(m.ApprovalRequest).where(m.ApprovalRequest.id == data.approval_id))
    kind = row.kind.removeprefix('payout_') if row is not None else ''
    if kind not in RESOLUTIONS:
        fail('err.approval_not_usable', 409)
    approval = approvals.usable(db, data.approval_id, 'settlements', settlement.id, row.kind, row.amount)
    if st['exposure'] <= 0:
        fail('err.payout_nothing_to_resolve', 409)
    if approval.amount > st['exposure']:
        fail('err.payout_resolution_over_exposure', 422, exposure=f"{st['exposure']:,.0f}")
    on = data.resolved_on or c.business_today()
    debited = [a.debited_on for a in st['attempts'] if a.state == 'debited']
    if debited and on < min(debited):
        fail('err.payout_resolution_before_debit', 422, day=min(debited).isoformat())
    resolution = RS(settlement_id=settlement.id, supplier_id=settlement.supplier_id, kind=kind, amount=approval.amount,
        resolved_on=on, evidence=approval.reason, approval_id=approval.id, recorded_by=operator.id)
    db.add(resolution)
    db.flush()
    approvals.use(approval, 'settlement_resolutions', resolution.id)
    refresh(db, settlement)
    return resolution


def settle_with_credit(db, settlement, operator):
    """The supplier's payout credit covers what is owed: set it off, no
    money moves (7 October 2026)."""
    st = state(db, settlement, lock=True)
    planned = plan(db, settlement, st)
    if planned['credit'] <= 0 or planned['unresolved'] or planned['blocked'] in ('cancelled', 'paid'):
        fail('err.payout_no_credit_to_use', 409)
    row = use_credit(db, settlement, planned['credit'], operator)
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

def payout_losses(db, start=None, end=None):
    """Write-offs of money possibly paid twice (7 October 2026): expenses
    "Payout loss" on their resolution day. [(resolution, order_id)]."""
    query = (select(RS, m.OrderItem.order_id).join(m.Settlement, m.Settlement.id == RS.settlement_id)
        .join(m.OrderItem, m.OrderItem.id == m.Settlement.order_item_id).where(RS.kind == 'write_off'))
    if start:
        query = query.where(RS.resolved_on >= start)
    if end:
        query = query.where(RS.resolved_on <= end)
    return db.execute(query.order_by(RS.resolved_on, RS.created_at)).all()


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
    resolver = _names(db, [r.recorded_by for r in st['resolutions']])
    return {**s.payout_view(settlement, True), 'supplier_id': settlement.supplier_id,
        'order_item_id': settlement.order_item_id, 'order_id': item.order_id if item else None,
        'supplier_alias': profile.public_alias if profile else '', 'supplier_legal_name': profile.legal_name if profile else '',
        **{k: st[k] for k in ('debited', 'refunded', 'net_paid', 'in_flight', 'outstanding', 'disputed', 'exposure',
            'resolved', 'credited', 'written_off', 'credit_used', 'settled')},
        'unresolved_count': len(st['unresolved']),
        'supplier_credit': credit_available(db, settlement.supplier_id),
        'resolutions': [{'id': r.id, 'kind': r.kind, 'amount': r.amount, 'resolved_on': r.resolved_on,
            'evidence': r.evidence, 'approval_id': r.approval_id, 'recorded_by': resolver.get(r.recorded_by, ''),
            'created_at': r.created_at} for r in st['resolutions']],
        'credit_uses': [{'id': u.id, 'amount': u.amount, 'used_on': u.used_on, 'created_at': u.created_at}
            for u in db.scalars(select(CU).where(CU.settlement_id == settlement.id).order_by(CU.created_at))],
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
    return {**{k: st[k] for k in ('net_paid', 'in_flight', 'outstanding', 'exposure', 'refunded', 'resolved',
        'credit_used')},
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


@router.post('/ops/settlements/{id}/resolutions/approvals')
def new_resolution_request(id: str, data: ResolutionRequestInput, idempotency_key: str = Header(),
                           operator=Depends(auth.ops_admin), db=Depends(database)):
    key, fingerprint, prior = _replayed(db, idempotency_key, 'settlement_resolution_request',
        {'id': id, **data.model_dump()}, m.ApprovalRequest)
    settlement = _settlement(db, id)
    if prior is None:
        prior = request_resolution(db, settlement, data, operator)
        s.remember(db, key, fingerprint, prior.id)
    return _result(approvals.view(db, prior), 201)


@router.post('/ops/settlements/{id}/resolutions')
def new_resolution(id: str, data: ResolutionInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                   db=Depends(database)):
    key, fingerprint, prior = _replayed(db, idempotency_key, 'settlement_resolution', {'id': id, **data.model_dump()}, RS)
    settlement = _settlement(db, id)
    if prior is None:
        prior = resolve(db, settlement, data, operator)
        s.remember(db, key, fingerprint, prior.id)
    return _result(detail(db, settlement), 201)


@router.post('/ops/settlements/{id}/use-credit')
def use_supplier_credit(id: str, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                        db=Depends(database)):
    key, fingerprint, prior = _replayed(db, idempotency_key, 'settlement_use_credit', {'id': id}, CU)
    settlement = _settlement(db, id)
    if prior is None:
        prior = settle_with_credit(db, settlement, operator)
        s.remember(db, key, fingerprint, prior.id)
    return _result(detail(db, settlement), 201)
