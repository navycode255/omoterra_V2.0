"""Orders staff take for a buyer by phone or in person (build plan M2.5,
decision D7, confirmed 6 October 2026).

The buyer does not use the app. Staff record who ordered, what (lines with
the agreed price), when it is expected and any notes.

- Until delivered the order is a **commitment** (reporting.commitments): it
  is not a sale, the buyer owes nothing (no receivable) and no stock is
  taken. It can be edited, or cancelled with a reason, while open.
- A **deposit** the buyer pays before delivery is money in on the day it was
  paid (the cash book counts it, with its account and reference claimed as
  any other money, M2.3 and M2.6). It is held for the buyer: shown as the
  order's deposit, never as revenue. It can be given back (a separate dated
  outflow) or, if entered in error, voided by an admin with a reason.
  An order holding a deposit cannot be cancelled until it is given back or
  voided.
- **Mark delivered** records a direct sale dated the delivery day through
  the normal sale path (finance.record_sale), so every sale rule applies:
  cost states (M1.3), delivery-note confirmation for batch stock (M1.6),
  stock never below zero on any day (R8) and late entries (M2.2). Each held
  deposit becomes a payment on the sale's receivable with its own date,
  method, reference and account, so the cash book still shows that money
  once, on the day it came in. The order and the sale link to each other.
"""
from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Literal, Optional

from fastapi import APIRouter, Depends, Header
from pydantic import Field, field_validator, model_validator
from sqlalchemy import func, or_, select

from . import accounts, auth, contracts as c, duplicates as dup, models as m, paging, reporting as rp, services as s
from .db import database
from .i18n import M, fail
from .paging import Paging, Spec

router = APIRouter(prefix='/api/v1/ops')
ZERO = Decimal('0')
BO, BOL, BOP = m.BuyerOrder, m.BuyerOrderLine, m.BuyerOrderPayment


def _result(value, status_code=200):
    from .main import result
    return result(value, status_code)


# ---- inputs -------------------------------------------------------------------

class BuyerOrderLineInput(c.Input):
    category: Optional[c.Category] = None
    description: str = Field(default='', max_length=200)
    unit: Literal['bird', 'animal', 'kg', 'tray', 'piece']
    quantity: c.Quantity
    unit_price: c.Money

    @model_validator(mode='after')
    def described(self):
        if not self.category and len(self.description) < 2:
            raise ValueError(M('err.describe_what_was_ordered'))
        if self.unit != 'kg' and self.quantity % 1:
            raise ValueError(M('err.birds_animals_require_whole_quantities'))
        return self


class BuyerOrderEdit(c.Input):
    # Exactly one: an existing buyer record, a buyer app account, or a new buyer.
    buyer_profile_id: Optional[str] = Field(default=None, max_length=36)
    buyer_user_id: Optional[str] = Field(default=None, max_length=36)
    new_buyer: Optional[c.NewSaleBuyer] = None
    ordered_on: date
    expected_on: Optional[date] = None
    items: list[BuyerOrderLineInput] = Field(min_length=1, max_length=50)
    notes: str = Field(default='', max_length=2000)

    @field_validator('ordered_on')
    @classmethod
    def not_future(cls, value):
        return c._not_future(value)

    @model_validator(mode='after')
    def consistent(self):
        if sum(x is not None for x in (self.buyer_profile_id, self.buyer_user_id, self.new_buyer)) != 1:
            raise ValueError(M('err.choose_one_buyer_for_order'))
        if self.expected_on is not None and self.expected_on < self.ordered_on:
            raise ValueError(M('err.expected_before_ordered'))
        return self


class BuyerOrderInput(BuyerOrderEdit):
    # A deposit the buyer paid when ordering, if any.
    deposit: Optional[c.LedgerPaymentInput] = None


class DepositRefundInput(c.DuplicateOverride):
    """Giving a whole deposit back: a dated outflow of its amount."""
    paid_on: date
    method: c.LedgerMethod
    reference: str = Field(default='', max_length=150)
    note: str = Field(default='', max_length=500)
    money_account_id: Optional[str] = Field(default=None, max_length=36)

    @field_validator('paid_on')
    @classmethod
    def not_future(cls, value):
        return c._not_future(value)


# ---- views --------------------------------------------------------------------

def _held_rows(db, order_id, lock=False):
    refunded = select(BOP.refund_of).where(BOP.kind == 'refund', BOP.refund_of.is_not(None))
    query = select(BOP).where(BOP.buyer_order_id == order_id, BOP.kind == 'deposit', BOP.voided_at.is_(None),
        BOP.applied_payment_id.is_(None), BOP.id.not_in(refunded)).order_by(BOP.paid_on, BOP.created_at)
    return db.scalars(query.with_for_update() if lock else query).all()


def _payment_view(db, row, refunds):
    from .finance import _operator_name
    state = ('voided' if row.voided_at else 'applied' if row.applied_payment_id else
             'given_back' if row.id in refunds else 'held') if row.kind == 'deposit' else 'given_back'
    assigned = db.execute(select(m.MoneyAccount.name).join(m.AccountAssignment,
        m.AccountAssignment.account_id == m.MoneyAccount.id).where(m.AccountAssignment.source_table.in_(
            ('buyer_order_payments', 'ledger_payments')),
        m.AccountAssignment.source_id.in_([row.id, row.applied_payment_id or row.id]))).scalar()
    return {**{k: getattr(row, k) for k in ('id', 'kind', 'refund_of', 'amount', 'paid_on', 'method', 'reference',
        'note', 'applied_payment_id', 'voided_at', 'void_reason', 'created_at')},
        'state': state, 'account_name': assigned, 'recorded_by': _operator_name(db, row.recorded_by)}


def order_view(db, order, detail=False):
    from .finance import _operator_name
    held = rp.held_deposits(db, [order.id]).get(order.id, ZERO)
    today = c.business_today()
    view = {**{k: getattr(order, k) for k in ('id', 'order_number', 'buyer_profile_id', 'buyer_name', 'buyer_phone',
        'ordered_on', 'expected_on', 'notes', 'total_amount', 'status', 'sale_id', 'delivered_on', 'created_at',
        'cancelled_at', 'cancel_reason')},
        'deposit_held': held, 'unpaid': order.total_amount - held if order.status == 'open' else ZERO,
        'overdue': order.status == 'open' and order.expected_on is not None and order.expected_on < today,
        'created_by': _operator_name(db, order.created_by)}
    sale = db.get(m.Sale, order.sale_id) if order.sale_id else None
    view['sale_number'] = sale.sale_number if sale else None
    view['sale_status'] = sale.status if sale else None
    lines = db.scalars(select(BOL).where(BOL.buyer_order_id == order.id).order_by(BOL.position)).all()
    view['summary'] = ', '.join(f"{format(line.quantity.normalize(), 'f')} {line.description or line.category.replace('_', ' ')}"
        for line in lines)[:200]
    if detail:
        view['items'] = [{k: getattr(line, k) for k in ('id', 'position', 'category', 'description', 'unit',
            'quantity', 'unit_price', 'subtotal')} for line in lines]
        payments = db.scalars(select(BOP).where(BOP.buyer_order_id == order.id).order_by(BOP.paid_on, BOP.created_at)).all()
        refunds = {p.refund_of for p in payments if p.kind == 'refund'}
        view['payments'] = [_payment_view(db, p, refunds) for p in payments]
        view['updated_by'] = _operator_name(db, order.updated_by)
        view['cancelled_by'] = _operator_name(db, order.cancelled_by)
    return view


# ---- helpers ------------------------------------------------------------------

def _order(db, id, lock=False):
    query = select(BO).where(BO.id == id)
    order = db.scalar(query.with_for_update() if lock else query)
    if not order:
        fail('err.buyer_order_not_found', 404)
    return order


def _open(order):
    if order.status != 'open':
        fail('err.buyer_order_not_open')


def _lines(db, order, items):
    db.query(BOL).filter(BOL.buyer_order_id == order.id).delete()
    total = ZERO
    for position, line in enumerate(items, 1):
        subtotal = s.money(line.quantity * line.unit_price)
        total += subtotal
        db.add(BOL(buyer_order_id=order.id, position=position, category=line.category or '',
            description=line.description, unit=line.unit, quantity=line.quantity, unit_price=line.unit_price,
            subtotal=subtotal))
    return total


def _set_buyer(db, order, data):
    from .finance import _sale_buyer
    profile = _sale_buyer(db, data)
    order.buyer_profile_id = profile.id
    order.buyer_name = profile.business_name or profile.contact_person or profile.phone
    order.buyer_phone = profile.phone or ''


def _deposit(db, order, data, operator):
    """Money in on an open order, held for the buyer (see module notes)."""
    if data.amount + rp.held_deposits(db, [order.id]).get(order.id, ZERO) > order.total_amount:
        fail('err.deposit_more_than_order', 422, total=f'{order.total_amount:,.0f}')
    earlier = dup.check_possible(db, data, 'in', data.amount, data.paid_on, party_name=order.buyer_name)
    account = accounts.require_account(db, data.money_account_id)
    row = BOP(buyer_order_id=order.id, kind='deposit', amount=data.amount, paid_on=data.paid_on, method=data.method,
        reference=data.reference, note=data.note, recorded_by=operator.id)
    db.add(row)
    db.flush()
    accounts.assign(db, 'buyer_order_payments', row.id, account, operator)
    dup.claim(db, 'buyer_order_payments', row.id, data.method, account, data.reference, 'in', operator)
    dup.record_override(db, earlier, 'buyer_order_payments', row.id, data, 'in', data.amount, data.paid_on, operator)
    return row


def _deposit_row(db, order, payment_id):
    row = db.scalar(select(BOP).where(BOP.id == payment_id, BOP.buyer_order_id == order.id, BOP.kind == 'deposit')
        .with_for_update())
    if not row:
        fail('err.deposit_not_found', 404)
    if row.id not in {held.id for held in _held_rows(db, order.id)}:
        fail('err.deposit_not_held')
    return row


# ---- list and detail ----------------------------------------------------------

OPEN = BO.status == 'open'
ORDERS = Spec(BO, (BO.ordered_on.desc(), BO.created_at.desc(), BO.id.desc()),
    lambda q: or_(paging.matches(q, BO.order_number, BO.buyer_name, BO.buyer_phone, BO.notes),
                  BO.id.in_(select(BOL.buyer_order_id).where(paging.matches(q, BOL.description, BOL.category)))),
    tabs={'open': OPEN, 'delivered': BO.status == 'delivered', 'cancelled': BO.status == 'cancelled'},
    column=BO.status, urgent=OPEN, urgent_order=(BO.expected_on.asc().nulls_last(), BO.ordered_on, BO.id))


@router.get('/buyer-orders')
def buyer_orders(params: Paging = Depends(), buyer_profile_id: Optional[str] = None, operator=Depends(auth.ops),
                 db=Depends(database)):
    """Orders staff took for buyers: open ones first (expected soonest),
    then the history, 10 a page. `summary` is the open orders' commitment."""
    where = [BO.buyer_profile_id == buyer_profile_id] if buyer_profile_id else []
    body = paging.page(db, ORDERS, params, lambda row: order_view(db, row), where=where)
    pending = rp.commitments(db)
    body['summary'] = {'total': pending['ledger'], 'count': pending['ledger_count'],
        'deposits': sum((r['paid'] for r in pending['rows'] if r['source'] == 'ledger'), ZERO),
        'overdue': db.scalar(select(func.count()).where(OPEN, BO.expected_on < c.business_today())) or 0}
    return _result(body)


@router.get('/buyer-orders/{id}')
def buyer_order(id: str, operator=Depends(auth.ops), db=Depends(database)):
    return _result(order_view(db, _order(db, id), True))


# ---- create, edit, cancel -------------------------------------------------------

@router.post('/buyer-orders', status_code=201)
def create_buyer_order(data: BuyerOrderInput, idempotency_key: str = Header(), operator=Depends(auth.ops),
                       db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'buyer-order', idempotency_key, data.model_dump())
    if prior:
        return _result(order_view(db, db.get(BO, prior), True), 201)
    id = m.identifier()
    order = BO(id=id, order_number='BO-' + id.replace('-', '')[:8].upper(), ordered_on=data.ordered_on,
        expected_on=data.expected_on, notes=data.notes, created_by=operator.id,
        total_amount=sum((s.money(line.quantity * line.unit_price) for line in data.items), ZERO))
    _set_buyer(db, order, data)
    db.add(order)
    db.flush()
    _lines(db, order, data.items)
    db.flush()
    if data.deposit:
        _deposit(db, order, data.deposit, operator)
    s.remember(db, key, fingerprint, order.id)
    return _result(order_view(db, order, True), 201)


@router.put('/buyer-orders/{id}')
def update_buyer_order(id: str, data: BuyerOrderEdit, operator=Depends(auth.ops), db=Depends(database)):
    """Change an open order: buyer, dates, lines, notes. Its deposits stay;
    the total may not fall below what is held."""
    order = _order(db, id, lock=True)
    _open(order)
    held = rp.held_deposits(db, [order.id]).get(order.id, ZERO)
    buyer = order.buyer_profile_id
    _set_buyer(db, order, data)
    if held and order.buyer_profile_id != buyer:
        # The deposit belongs to whoever paid it (rule R1).
        fail('err.order_buyer_has_deposit')
    order.ordered_on, order.expected_on, order.notes = data.ordered_on, data.expected_on, data.notes
    order.total_amount = _lines(db, order, data.items)
    if order.total_amount < held:
        fail('err.order_total_below_deposits', 422, held=f'{held:,.0f}')
    order.updated_at, order.updated_by = m.now(), operator.id
    db.flush()
    return _result(order_view(db, order, True))


@router.post('/buyer-orders/{id}/cancel')
def cancel_buyer_order(id: str, data: c.ReasonInput, idempotency_key: str = Header(), operator=Depends(auth.ops),
                       db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'buyer-order-cancel', idempotency_key, {'id': id, **data.model_dump()})
    order = _order(db, id, lock=True)
    if not prior:
        _open(order)
        held = rp.held_deposits(db, [order.id]).get(order.id, ZERO)
        if held:
            fail('err.cancel_order_with_deposit', held=f'{held:,.0f}')
        order.status, order.cancelled_at, order.cancelled_by, order.cancel_reason = 'cancelled', m.now(), operator.id, data.reason
        s.remember(db, key, fingerprint, order.id)
    return _result(order_view(db, order, True))


# ---- deposits -------------------------------------------------------------------

@router.post('/buyer-orders/{id}/deposits', status_code=201)
def record_deposit(id: str, data: c.LedgerPaymentInput, idempotency_key: str = Header(), operator=Depends(auth.ops),
                   db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'buyer-order-deposit', idempotency_key, {'id': id, **data.model_dump()})
    order = _order(db, id, lock=True)
    if not prior:
        _open(order)
        row = _deposit(db, order, data, operator)
        s.remember(db, key, fingerprint, row.id)
    return _result(order_view(db, order, True), 201)


@router.post('/buyer-orders/{id}/deposits/{payment_id}/refund', status_code=201)
def refund_deposit(id: str, payment_id: str, data: DepositRefundInput, idempotency_key: str = Header(),
                   operator=Depends(auth.ops), db=Depends(database)):
    """The whole deposit given back to the buyer: money out on its own day.
    The deposit stays as history (money in on its day)."""
    key, fingerprint, prior = s.replay(db, operator.id, 'buyer-order-refund', idempotency_key,
        {'id': id, 'payment_id': payment_id, **data.model_dump()})
    order = _order(db, id, lock=True)
    if not prior:
        _open(order)
        deposit = _deposit_row(db, order, payment_id)
        if data.paid_on < deposit.paid_on:
            fail('err.refund_before_deposit', 422, day=deposit.paid_on.isoformat())
        earlier = dup.check_possible(db, data, 'out', deposit.amount, data.paid_on, party_name=order.buyer_name)
        account = accounts.require_account(db, data.money_account_id)
        row = BOP(buyer_order_id=order.id, kind='refund', refund_of=deposit.id, amount=deposit.amount,
            paid_on=data.paid_on, method=data.method, reference=data.reference, note=data.note, recorded_by=operator.id)
        db.add(row)
        db.flush()
        accounts.assign(db, 'buyer_order_payments', row.id, account, operator)
        dup.claim(db, 'buyer_order_payments', row.id, data.method, account, data.reference, 'out', operator)
        dup.record_override(db, earlier, 'buyer_order_payments', row.id, data, 'out', row.amount, data.paid_on, operator)
        s.remember(db, key, fingerprint, row.id)
    return _result(order_view(db, order, True), 201)


@router.post('/buyer-orders/{id}/deposits/{payment_id}/void')
def void_deposit(id: str, payment_id: str, data: c.ReasonInput, operator=Depends(auth.ops_admin), db=Depends(database)):
    """A deposit entered by mistake (the money never came): admins only,
    with a reason. It stops counting and its reference is free again."""
    order = _order(db, id, lock=True)
    _open(order)
    row = _deposit_row(db, order, payment_id)
    row.voided_at, row.voided_by, row.void_reason = m.now(), operator.id, data.reason
    dup.release(db, 'buyer_order_payments', row.id, data.reason)
    return _result(order_view(db, order, True))


# ---- delivery ---------------------------------------------------------------------

def deliver(db, order, data, operator):
    """The order becomes a direct sale dated its delivery day (see module
    notes). `data` is the sale as the sale form sends it."""
    _open(order)
    if data.buyer_profile_id != order.buyer_profile_id:
        fail('err.buyer_order_buyer_differs', 422)
    if data.sold_on < order.ordered_on:
        fail('err.delivered_before_ordered', 422, day=order.ordered_on.isoformat())
    from .finance import record_sale
    held = _held_rows(db, order.id, lock=True)
    held_total = sum((row.amount for row in held), ZERO)
    sale = record_sale(db, data, operator)
    receivable = db.scalar(select(m.LedgerDebt).where(m.LedgerDebt.sale_id == sale.id,
        m.LedgerDebt.direction == 'receivable').with_for_update())
    if held_total > receivable.balance:
        fail('err.deposit_more_than_sale', 422, held=f'{held_total:,.0f}')
    for row in held:
        # Same money, same day, method, reference and account: from now on
        # the cash book counts it as this payment on the sale.
        payment = m.LedgerPayment(debt_id=receivable.id, amount=row.amount, paid_on=row.paid_on, method=row.method,
            reference=row.reference, note=row.note or f'Deposit on order {order.order_number}',
            recorded_by=row.recorded_by)
        db.add(payment)
        receivable.paid_amount += row.amount
        db.flush()
        accounts.follow(db, 'buyer_order_payments', row.id, 'ledger_payments', payment.id)
        dup.follow(db, 'buyer_order_payments', row.id, 'ledger_payments', payment.id)
        row.applied_payment_id = payment.id
    receivable.status = 'settled' if receivable.paid_amount == receivable.amount else 'open'
    order.status, order.sale_id, order.delivered_on = 'delivered', sale.id, data.sold_on
    order.updated_at, order.updated_by = m.now(), operator.id
    db.flush()
    return sale


@router.post('/buyer-orders/{id}/deliver', status_code=201)
def deliver_buyer_order(id: str, data: c.DirectSaleInput, idempotency_key: str = Header(), operator=Depends(auth.ops),
                        db=Depends(database)):
    from .finance import sale_view
    key, fingerprint, prior = s.replay(db, operator.id, 'buyer-order-deliver', idempotency_key,
        {'id': id, **data.model_dump()})
    if prior:
        return _result(sale_view(db, db.get(m.Sale, prior), True), 201)
    order = _order(db, id, lock=True)
    sale = deliver(db, order, data, operator)
    s.remember(db, key, fingerprint, sale.id)
    return _result(sale_view(db, sale, True), 201)
