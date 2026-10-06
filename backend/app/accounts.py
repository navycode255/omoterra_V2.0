"""Money accounts and reconciliation (build plan M2.3, audit F05, decision D6).

Each account (cash box, bank, mobile wallet) starts from an opening balance
the finance owner verified at the end of its cutoff day. Its balance on any
later day is that opening balance plus the cash book rows assigned to it
dated after the cutoff, plus transfers between Omoterra's own accounts.

- Cutoff: a row dated on or before the cutoff is inside the opening balance.
  It stays visible as history and never counts again. One entered after the
  account was set up is a pre-cutoff adjustment: an exception until the
  finance owner says it was already inside the opening balance, or restates
  the opening balance with it (it then counts).
- New money entries name their account once any account exists. A
  historical row is assigned only with evidence the finance owner confirmed
  (rule R6); the payment method alone never decides it. Rows with no account
  are the "Unassigned (historical)" bucket: shown on the cash book, never in
  an account's balance, and an exception until assigned.
- A cash count or statement balance that differs from the recorded balance
  is an exception to explain. It never adjusts the balance: only entering
  the missing record does.
"""
from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Literal, Optional

from fastapi import APIRouter, Depends, Header, Query
from pydantic import Field, field_validator, model_validator
from sqlalchemy import and_, case, exists, func, select

from . import auth, contracts as c, models as m, services as s
from .db import database
from .i18n import fail

router = APIRouter(prefix='/api/v1')
ZERO = Decimal('0')
AA = m.AccountAssignment


def _result(value, status_code=200):
    from .main import result
    return result(value, status_code)


# ---- inputs -------------------------------------------------------------------

class AccountInput(c.Input):
    name: str = Field(min_length=2, max_length=80)
    kind: Literal['cash', 'bank', 'mobile_wallet']
    provider: str = Field(default='', max_length=80)
    number: str = Field(default='', max_length=80)
    cutoff_on: date
    opening_balance: Decimal = Field(max_digits=14, decimal_places=2)
    opening_evidence: str = Field(min_length=3, max_length=1000)
    verified_by: str = Field(min_length=2, max_length=120)

    @field_validator('cutoff_on')
    @classmethod
    def not_future(cls, value):
        return c._not_future(value)


class TransferInput(c.Input):
    from_account_id: str = Field(min_length=36, max_length=36)
    to_account_id: str = Field(min_length=36, max_length=36)
    amount: c.Money
    transferred_on: date
    fee: Decimal = Field(default=ZERO, ge=0, max_digits=14, decimal_places=2)
    reference: str = Field(default='', max_length=150)
    note: str = Field(default='', max_length=500)

    @field_validator('transferred_on')
    @classmethod
    def not_future(cls, value):
        return c._not_future(value)

    @model_validator(mode='after')
    def two_accounts(self):
        if self.from_account_id == self.to_account_id:
            raise ValueError('Choose two different accounts.')
        return self


class FeeInput(c.Input):
    amount: c.Money
    charged_on: date
    description: str = Field(min_length=3, max_length=300)
    reference: str = Field(default='', max_length=150)

    @field_validator('charged_on')
    @classmethod
    def not_future(cls, value):
        return c._not_future(value)


class CheckInput(c.Input):
    kind: Literal['count', 'statement']
    checked_on: date
    balance: Decimal = Field(max_digits=14, decimal_places=2)
    evidence: str = Field(min_length=3, max_length=1000)

    @field_validator('checked_on')
    @classmethod
    def not_future(cls, value):
        return c._not_future(value)


class AssignInput(c.Input):
    source_table: str = Field(min_length=3, max_length=32)
    source_id: str = Field(min_length=1, max_length=36)
    account_id: str = Field(min_length=36, max_length=36)
    evidence: str = Field(min_length=3, max_length=1000)


class PreCutoffInput(c.Input):
    resolution: Literal['inside_opening', 'restated']
    note: str = Field(min_length=3, max_length=1000)


# ---- naming the account of a new entry -----------------------------------------

def any_accounts(db):
    return db.scalar(select(m.MoneyAccount.id).where(m.MoneyAccount.active.is_(True)).limit(1)) is not None


def require_account(db, account_id):
    """The account a new money entry goes through. Once any account exists
    every new entry names one; before that, entries stay unassigned."""
    if account_id:
        row = db.get(m.MoneyAccount, account_id)
        if not row or not row.active:
            fail('err.money_account_not_found', 404)
        return row
    if any_accounts(db):
        fail('err.choose_money_account', 422)
    return None


def assign(db, source_table, source_id, account, operator=None, how='entered', evidence='', confirmed_by=''):
    """Record which account a cash book row went through (once)."""
    if account is None:
        return None
    if db.scalar(select(AA.id).where(AA.source_table == source_table, AA.source_id == source_id)):
        fail('err.movement_already_assigned', 409)
    row = AA(source_table=source_table, source_id=source_id, account_id=account.id, how=how, evidence=evidence,
        assigned_by=operator.id if operator else None, confirmed_by=confirmed_by)
    db.add(row)
    db.flush()
    return row


def follow(db, from_table, from_id, to_table, to_id):
    """A movement now counted from another record (an old supplier payment
    wrapped in its transfer): its account goes with it."""
    row = db.scalar(select(AA).where(AA.source_table == from_table, AA.source_id == from_id))
    if row:
        row.source_table, row.source_id = to_table, to_id


def copy(db, from_table, from_id, to_table, to_id):
    """Part of a movement now counted from another record (part of an order
    deposit applied to a sale, 7 October 2026): that part went through the
    same account, with the same standing (how, evidence, pre-cutoff)."""
    row = db.scalar(select(AA).where(AA.source_table == from_table, AA.source_id == from_id))
    if row and not db.scalar(select(AA.id).where(AA.source_table == to_table, AA.source_id == to_id)):
        db.add(AA(source_table=to_table, source_id=to_id, account_id=row.account_id, how=row.how, evidence=row.evidence,
            assigned_by=row.assigned_by, confirmed_by=row.confirmed_by, pre_cutoff=row.pre_cutoff,
            pre_cutoff_note=row.pre_cutoff_note, pre_cutoff_by=row.pre_cutoff_by))
        db.flush()


# ---- balances -------------------------------------------------------------------

def _cash():
    from .reporting import CASH, COUNTED
    return CASH, COUNTED


def _counts_in_balance(account):
    """Assigned rows that count in this account's balance: dated after the
    cutoff, or restated into the opening balance."""
    CASH, _ = _cash()
    return (CASH.c.paid_on > account.cutoff_on) | (AA.pre_cutoff == 'restated')


def _assigned(account):
    CASH, COUNTED = _cash()
    return and_(COUNTED, AA.source_table == CASH.c.source_table, AA.source_id == CASH.c.id, AA.account_id == account.id)


def balance(db, account, as_of=None):
    """The recorded balance at the end of `as_of` (today when None)."""
    CASH, _ = _cash()
    as_of = as_of or c.business_today()
    if as_of < account.cutoff_on:
        return None
    signed = func.coalesce(func.sum(CASH.c.amount * _sign(CASH.c.flow)), 0)
    moved = db.scalar(select(signed).select_from(CASH).join(AA, _assigned(account))
        .where(_counts_in_balance(account), (CASH.c.paid_on <= as_of) | (AA.pre_cutoff == 'restated'))) or ZERO
    transfers_in = db.scalar(select(func.coalesce(func.sum(m.AccountTransfer.amount), 0)).where(
        m.AccountTransfer.to_account_id == account.id, m.AccountTransfer.transferred_on > account.cutoff_on,
        m.AccountTransfer.transferred_on <= as_of)) or ZERO
    transfers_out = db.scalar(select(func.coalesce(func.sum(m.AccountTransfer.amount), 0)).where(
        m.AccountTransfer.from_account_id == account.id, m.AccountTransfer.transferred_on > account.cutoff_on,
        m.AccountTransfer.transferred_on <= as_of)) or ZERO
    return account.opening_balance + moved + transfers_in - transfers_out


def _sign(flow):
    return case((flow == 'in', 1), else_=-1)


def statement(db, account, start=None, end=None):
    """The account's movements after its cutoff with the running balance
    after each, oldest first: cash book rows and transfers."""
    rows = _assigned_rows(db, account)
    names = {a.id: a.name for a in db.scalars(select(m.MoneyAccount))}
    for t in db.scalars(select(m.AccountTransfer).where(
            (m.AccountTransfer.from_account_id == account.id) | (m.AccountTransfer.to_account_id == account.id),
            m.AccountTransfer.transferred_on > account.cutoff_on)):
        incoming = t.to_account_id == account.id
        rows.append({'source_table': 'account_transfers', 'id': t.id, 'kind': 'account_transfer', 'date': t.transferred_on,
            'flow': 'in' if incoming else 'out', 'amount': t.amount, 'method': '', 'reference': t.reference,
            'party_name': names.get(t.from_account_id if incoming else t.to_account_id, ''),
            'description': f"Transfer {'from' if incoming else 'to'} {names.get(t.from_account_id if incoming else t.to_account_id, '')}",
            'created_at': t.created_at, 'restated': False})
    rows.sort(key=lambda r: (r['date'], r['created_at']))
    running, out = account.opening_balance, []
    for row in rows:
        running += row['amount'] if row['flow'] == 'in' else -row['amount']
        if (start is None or row['date'] >= start) and (end is None or row['date'] <= end):
            out.append({**row, 'balance': running})
    return out


def _assigned_rows(db, account):
    CASH, _ = _cash()
    rows = []
    for cash in db.execute(select(CASH, AA.pre_cutoff.label('pre_cutoff')).join(AA, _assigned(account))
            .where(_counts_in_balance(account))).all():
        restated = cash.pre_cutoff == 'restated'
        rows.append({'source_table': cash.source_table, 'id': cash.id, 'kind': cash.kind,
            'date': account.cutoff_on if restated else cash.paid_on, 'paid_on': cash.paid_on, 'flow': cash.flow,
            'amount': cash.amount, 'method': cash.method, 'reference': cash.reference, 'party_name': cash.party_name,
            'description': cash.description, 'created_at': cash.created_at, 'restated': restated})
    return rows


def pre_cutoff(db, account=None, open_only=True):
    """Rows entered with an account but dated on or before its cutoff."""
    CASH, COUNTED = _cash()
    query = (select(CASH, AA, m.MoneyAccount).join(AA, and_(COUNTED, AA.source_table == CASH.c.source_table,
            AA.source_id == CASH.c.id)).join(m.MoneyAccount, m.MoneyAccount.id == AA.account_id)
        .where(AA.how == 'entered', CASH.c.paid_on <= m.MoneyAccount.cutoff_on))
    if account is not None:
        query = query.where(AA.account_id == account.id)
    if open_only:
        query = query.where(AA.pre_cutoff.is_(None))
    return [{'assignment_id': row.AccountAssignment.id, 'account_id': row.MoneyAccount.id, 'account': row.MoneyAccount.name,
        'source_table': row.source_table, 'id': row.id, 'date': row.paid_on, 'flow': row.flow, 'amount': row.amount,
        'description': row.description, 'party_name': row.party_name, 'resolution': row.AccountAssignment.pre_cutoff,
        'note': row.AccountAssignment.pre_cutoff_note} for row in db.execute(query.order_by(CASH.c.paid_on))]


def unassigned_filter():
    CASH, COUNTED = _cash()
    return and_(COUNTED, ~exists(select(AA.id).where(AA.source_table == CASH.c.source_table, AA.source_id == CASH.c.id)))


def account_filter(account_id):
    CASH, _ = _cash()
    return exists(select(AA.id).where(AA.source_table == CASH.c.source_table, AA.source_id == CASH.c.id,
        AA.account_id == account_id))


def unassigned_totals(db):
    CASH, _ = _cash()
    rows = db.execute(select(CASH.c.flow, func.count(), func.coalesce(func.sum(CASH.c.amount), 0))
        .where(unassigned_filter()).group_by(CASH.c.flow)).all()
    by = {flow: (count, amount) for flow, count, amount in rows}
    return {'count': sum(n for n, _ in by.values()), 'in': by.get('in', (0, ZERO))[1], 'out': by.get('out', (0, ZERO))[1]}


def open_differences(db, account=None):
    query = select(m.AccountCheck).where(m.AccountCheck.difference != 0, m.AccountCheck.resolved_at.is_(None))
    if account is not None:
        query = query.where(m.AccountCheck.account_id == account.id)
    return db.scalars(query.order_by(m.AccountCheck.checked_on)).all()


def account_view(db, account, as_of=None):
    checks = db.scalars(select(m.AccountCheck).where(m.AccountCheck.account_id == account.id)
        .order_by(m.AccountCheck.checked_on.desc(), m.AccountCheck.created_at.desc())).all()
    matched = [ch.checked_on for ch in checks if ch.difference == 0 or ch.resolved_at]
    return {**{k: getattr(account, k) for k in ('id', 'name', 'kind', 'provider', 'number', 'cutoff_on',
        'opening_balance', 'opening_evidence', 'verified_by', 'active', 'created_at')},
        'balance': balance(db, account, as_of), 'as_of': as_of or c.business_today(),
        'last_check': _check_view(checks[0]) if checks else None,
        'reconciled_through': max(matched) if matched else None,
        'open_differences': sum(1 for ch in checks if ch.difference != 0 and not ch.resolved_at),
        'pre_cutoff_open': len(pre_cutoff(db, account))}


def _check_view(row):
    return {k: getattr(row, k) for k in ('id', 'kind', 'checked_on', 'balance', 'expected', 'difference', 'evidence',
        'resolution', 'resolved_at', 'created_at')}


def _account(db, id, lock=False):
    query = select(m.MoneyAccount).where(m.MoneyAccount.id == id)
    row = db.scalar(query.with_for_update() if lock else query)
    if not row:
        fail('err.money_account_not_found', 404)
    return row


# ---- endpoints ------------------------------------------------------------------

@router.get('/ops/accounts')
def accounts(active: bool = False, operator=Depends(auth.ops), db=Depends(database)):
    """Every money account with its recorded balance today, last check and
    open exceptions; beside them, the unassigned (historical) bucket."""
    query = select(m.MoneyAccount).order_by(m.MoneyAccount.name)
    if active:
        query = query.where(m.MoneyAccount.active.is_(True))
    rows = [account_view(db, row) for row in db.scalars(query)]
    return _result({'items': rows, 'total': sum((r['balance'] or ZERO for r in rows), ZERO),
        'unassigned': unassigned_totals(db), 'pre_cutoff_open': len(pre_cutoff(db)),
        'open_differences': len(open_differences(db))})


@router.post('/ops/accounts', status_code=201)
def create_account(data: AccountInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                   db=Depends(database)):
    """Set up an account with the opening balance the finance owner verified
    at the end of the cutoff day, and the evidence for it (admin)."""
    key, fingerprint, prior = s.replay(db, operator.id, 'money-account', idempotency_key, data.model_dump())
    if not prior:
        if db.scalar(select(m.MoneyAccount.id).where(func.lower(m.MoneyAccount.name) == data.name.strip().lower())):
            fail('err.money_account_exists', 409)
        row = m.MoneyAccount(name=data.name.strip(), kind=data.kind, provider=data.provider.strip(), number=data.number.strip(),
            cutoff_on=data.cutoff_on, opening_balance=data.opening_balance, opening_evidence=data.opening_evidence.strip(),
            verified_by=data.verified_by.strip(), recorded_by=operator.id)
        db.add(row)
        db.flush()
        s.remember(db, key, fingerprint, row.id)
        prior = row.id
    return _result(account_view(db, db.get(m.MoneyAccount, prior)), 201)


@router.get('/ops/accounts/unassigned')
def unassigned(q: str = Query('', max_length=100), page: int = Query(1, ge=1), page_size: int = Query(10, ge=1, le=100),
               operator=Depends(auth.ops), db=Depends(database)):
    """Recorded money with no account: oldest first, 10 to a page."""
    CASH, _ = _cash()
    from . import paging
    where = [unassigned_filter()]
    if q.strip():
        where.append(paging.matches(q, CASH.c.reference, CASH.c.party_name, CASH.c.description, CASH.c.note))
    total = db.scalar(select(func.count()).select_from(CASH).where(*where))
    rows = db.execute(select(CASH).where(*where).order_by(CASH.c.paid_on, CASH.c.created_at)
        .offset((page - 1) * page_size).limit(page_size)).all()
    return _result({'items': [{k: getattr(r, k) for k in ('id', 'source_table', 'kind', 'flow', 'paid_on', 'amount',
        'method', 'reference', 'party_name', 'description', 'note')} for r in rows], 'total': total, 'page': page,
        'page_size': page_size, 'actionable': 0, 'summary': unassigned_totals(db)})


@router.post('/ops/accounts/assign', status_code=201)
def assign_historical(data: AssignInput, operator=Depends(auth.ops_admin), db=Depends(database)):
    """Assign a recorded movement to its account, with the evidence that
    shows which account it went through (admin; rule R6)."""
    CASH, COUNTED = _cash()
    row = db.execute(select(CASH).where(CASH.c.source_table == data.source_table, CASH.c.id == data.source_id, COUNTED)).first()
    if not row:
        fail('err.money_movement_not_found', 404)
    account = _account(db, data.account_id)
    done = assign(db, data.source_table, data.source_id, account, operator, how='historical',
        evidence=data.evidence.strip(), confirmed_by=operator.name)
    return _result({'id': done.id, 'account': account_view(db, account)}, 201)


@router.get('/ops/accounts/{id}')
def account_detail(id: str, start: Optional[date] = None, end: Optional[date] = None, page: int = Query(1, ge=1),
                   page_size: int = Query(10, ge=1, le=100), operator=Depends(auth.ops), db=Depends(database)):
    """One account: balance, its movements with the running balance (newest
    first, 10 to a page), checks and pre-cutoff adjustments."""
    account = _account(db, id)
    rows = list(reversed(statement(db, account, start, end)))
    first = (page - 1) * page_size
    checks = db.scalars(select(m.AccountCheck).where(m.AccountCheck.account_id == id)
        .order_by(m.AccountCheck.checked_on.desc(), m.AccountCheck.created_at.desc())).all()
    return _result({**account_view(db, account), 'movements': {'items': rows[first:first + page_size], 'total': len(rows),
        'page': page, 'page_size': page_size, 'actionable': 0},
        'checks': [_check_view(ch) for ch in checks], 'pre_cutoff': pre_cutoff(db, account, open_only=False)})


@router.post('/ops/accounts/transfers', status_code=201)
def transfer(data: TransferInput, idempotency_key: str = Header(), operator=Depends(auth.ops), db=Depends(database)):
    """Money moved between two Omoterra accounts. A fee charged on it is a
    separate charge on the sending account."""
    key, fingerprint, prior = s.replay(db, operator.id, 'account-transfer', idempotency_key, data.model_dump())
    if not prior:
        source, target = _account(db, data.from_account_id, True), _account(db, data.to_account_id, True)
        if not source.active or not target.active:
            fail('err.money_account_not_found', 404)
        if data.transferred_on <= max(source.cutoff_on, target.cutoff_on):
            fail('err.account_entry_before_cutoff', 422)
        row = m.AccountTransfer(from_account_id=source.id, to_account_id=target.id, amount=data.amount,
            transferred_on=data.transferred_on, reference=data.reference.strip(), note=data.note.strip(),
            recorded_by=operator.id)
        db.add(row)
        db.flush()
        if data.fee:
            _fee(db, source, data.fee, data.transferred_on, f'Transfer fee to {target.name}', data.reference, operator, row.id)
        s.remember(db, key, fingerprint, row.id)
        prior = row.id
    row = db.get(m.AccountTransfer, prior)
    return _result({'id': row.id, 'from': account_view(db, db.get(m.MoneyAccount, row.from_account_id)),
        'to': account_view(db, db.get(m.MoneyAccount, row.to_account_id))}, 201)


def _fee(db, account, amount, on, description, reference, operator, transfer_id=None):
    if on <= account.cutoff_on:
        fail('err.account_entry_before_cutoff', 422)
    row = m.AccountFee(account_id=account.id, amount=amount, charged_on=on, description=description.strip(),
        reference=(reference or '').strip(), transfer_id=transfer_id, recorded_by=operator.id)
    db.add(row)
    db.flush()
    assign(db, 'account_fees', row.id, account, operator)
    return row


@router.post('/ops/accounts/{id}/fees', status_code=201)
def record_fee(id: str, data: FeeInput, idempotency_key: str = Header(), operator=Depends(auth.ops), db=Depends(database)):
    """A bank or wallet charge: money out of the account and an expense."""
    key, fingerprint, prior = s.replay(db, operator.id, 'account-fee', idempotency_key, {'id': id, **data.model_dump()})
    account = _account(db, id, True)
    if not prior:
        row = _fee(db, account, data.amount, data.charged_on, data.description, data.reference, operator)
        s.remember(db, key, fingerprint, row.id)
    return _result(account_view(db, account), 201)


@router.post('/ops/accounts/{id}/checks', status_code=201)
def record_check(id: str, data: CheckInput, idempotency_key: str = Header(), operator=Depends(auth.ops),
                 db=Depends(database)):
    """A cash count or a statement balance at the end of a day. Any
    difference from the recorded balance is listed to explain; the
    balance itself never changes here."""
    key, fingerprint, prior = s.replay(db, operator.id, 'account-check', idempotency_key, {'id': id, **data.model_dump()})
    account = _account(db, id, True)
    if not prior:
        if data.checked_on < account.cutoff_on:
            fail('err.account_entry_before_cutoff', 422)
        expected = balance(db, account, data.checked_on)
        row = m.AccountCheck(account_id=account.id, kind=data.kind, checked_on=data.checked_on, balance=data.balance,
            expected=expected, difference=data.balance - expected, evidence=data.evidence.strip(), recorded_by=operator.id)
        db.add(row)
        db.flush()
        s.remember(db, key, fingerprint, row.id)
        prior = row.id
    return _result({**_check_view(db.get(m.AccountCheck, prior)), 'account': account_view(db, account)}, 201)


@router.post('/ops/account-checks/{id}/resolve')
def resolve_check(id: str, data: c.ReasonInput, operator=Depends(auth.ops_admin), db=Depends(database)):
    """Explain a difference found on a check (admin). The explanation is
    kept; the balance does not change."""
    row = db.scalar(select(m.AccountCheck).where(m.AccountCheck.id == id).with_for_update())
    if not row:
        fail('err.money_account_not_found', 404)
    if row.difference == 0 or row.resolved_at:
        fail('err.account_check_nothing_to_explain', 409)
    row.resolution, row.resolved_at, row.resolved_by = data.reason.strip(), m.now(), operator.id
    db.flush()
    return _result(_check_view(row))


@router.post('/ops/account-assignments/{id}/pre-cutoff')
def resolve_pre_cutoff(id: str, data: PreCutoffInput, operator=Depends(auth.ops_admin), db=Depends(database)):
    """A movement entered after setup but dated on or before the cutoff:
    either it was already inside the verified opening balance, or the
    opening balance is restated with it, with the evidence (admin)."""
    row = db.scalar(select(AA).where(AA.id == id).with_for_update())
    if not row:
        fail('err.money_movement_not_found', 404)
    if row.pre_cutoff:
        fail('err.pre_cutoff_already_resolved', 409)
    row.pre_cutoff, row.pre_cutoff_note, row.pre_cutoff_by = data.resolution, data.note.strip(), operator.id
    db.flush()
    return _result(account_view(db, db.get(m.MoneyAccount, row.account_id)))
