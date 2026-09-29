"""Sales staff record directly, operating expenses, one ledger of who owes
whom, and profit.

A sale (phone order, market, walk-in) is a money record only: it never moves
listing or batch stock. Recording it opens, in the same transaction:

- a receivable: the buyer owes Omoterra the sale total;
- one payable per supplier the stock came from: Omoterra owes the cost.

Debts that have nothing to do with a sale (a loan, feed on credit) are
entered by hand as the same kind of row, and so are operating expenses
(labour, transport...): an expense is a payable, paid there and then or still
owed. One set of balances and one cash book cover everything, and profit is
sales less the cost of the stock sold less expenses. Money moves as installments against a debt:

- `paid_amount` equals the sum of the debt's unreversed payments, updated
  under a row lock, and a CHECK keeps it within `amount`: no overpayment;
- nothing is deleted. A wrong payment is reversed (admins only, with a
  reason) and a sale or debt is cancelled only once nothing is paid on it.

The overview also counts the marketplace's own buyer payments and supplier
settlements, so the totals owed either way are complete.
"""
from __future__ import annotations

from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, File, Header, Query, UploadFile
from fastapi.concurrency import run_in_threadpool
from sqlalchemy import Date, Text, and_, cast, exists, func, or_, select

from . import auth, contracts as c, models as m, notifications as notes, paging, services as s
from .db import database
from .i18n import M, fail
from .media import save_photo
from .paging import Paging, Spec

router = APIRouter(prefix='/api/v1/ops')
ZERO = Decimal('0')


def _result(value, status_code=200):
    from .main import result
    return result(value, status_code)


# ---- views ------------------------------------------------------------------

def payment_view(db, row, debt=None):
    view = {k: getattr(row, k) for k in ('id', 'debt_id', 'amount', 'paid_on', 'method', 'reference', 'note',
        'created_at', 'reversed_at', 'reverse_reason')}
    view['reversed'] = row.reversed_at is not None
    view['recorded_by'] = _operator_name(db, row.recorded_by)
    view['reversed_by'] = _operator_name(db, row.reversed_by)
    if debt is not None:
        view.update(direction=debt.direction, party_name=debt.party_name, description=debt.description,
            sale_id=debt.sale_id)
    return view


def debt_view(row):
    today = c.business_today()
    return {**{k: getattr(row, k) for k in ('id', 'direction', 'party_kind', 'buyer_profile_id', 'supplier_id',
        'party_name', 'party_phone', 'description', 'amount', 'paid_amount', 'incurred_on', 'due_on', 'source',
        'expense_category', 'sale_id', 'lpo_id', 'status', 'created_at', 'cancelled_at', 'cancel_reason')},
        'balance': row.balance, 'overdue': row.status == 'open' and row.due_on is not None and row.due_on < today}


def _operator_name(db, id):
    """Who did it, by name. Operators are few; they are read once per request."""
    if not id:
        return None
    names = db.info.get('omoterra_operator_names')
    if names is None:
        names = db.info['omoterra_operator_names'] = dict(db.execute(select(m.Operator.id, m.Operator.name)).all())
    return names.get(id, id)


def _payments(db, debt_id):
    return db.scalars(select(m.LedgerPayment).where(m.LedgerPayment.debt_id == debt_id)
        .order_by(m.LedgerPayment.paid_on, m.LedgerPayment.created_at)).all()


def _sale_debts(db, sale_id):
    return db.scalars(select(m.LedgerDebt).where(m.LedgerDebt.sale_id == sale_id)
        .order_by(m.LedgerDebt.direction.desc(), m.LedgerDebt.created_at)).all()


def sale_view(db, sale, detail=False):
    debts = _sale_debts(db, sale.id)
    receivable = next((d for d in debts if d.direction == 'receivable'), None)
    payables = [d for d in debts if d.direction == 'payable']
    view = {**{k: getattr(sale, k) for k in ('id', 'sale_number', 'sold_on', 'buyer_profile_id', 'buyer_user_id',
        'buyer_name', 'buyer_phone', 'total_amount', 'cost_amount', 'notes', 'status', 'created_at',
        'cancelled_at', 'cancel_reason')},
        'created_by': _operator_name(db, sale.created_by),
        'received_amount': receivable.paid_amount if receivable else ZERO,
        'balance': receivable.balance if receivable and receivable.status != 'cancelled' else ZERO,
        'supplier_balance': sum((d.balance for d in payables if d.status != 'cancelled'), ZERO),
        'margin': sale.total_amount - sale.cost_amount,
        'receivable_id': receivable.id if receivable else None}
    if detail:
        items = db.scalars(select(m.SaleItem).where(m.SaleItem.sale_id == sale.id).order_by(m.SaleItem.position)).all()
        view['items'] = [{k: getattr(i, k) for k in ('id', 'category', 'description', 'unit', 'quantity', 'unit_price',
            'subtotal', 'supplier_id', 'supplier_name', 'unit_cost', 'cost_total', 'lpo_line_id')} for i in items]
        view['debts'] = [{**debt_view(d), 'payments': [payment_view(db, p) for p in _payments(db, d.id)]} for d in debts]
    return view


# ---- writes -----------------------------------------------------------------

def _supplier_party(db, supplier_id):
    user = db.get(m.User, supplier_id)
    if not user or 'supplier' not in (user.roles or []) or user.deleted:
        fail('err.choose_registered_supplier', 422)
    profile = db.get(m.SupplierProfile, supplier_id)
    return (profile.legal_name if profile and profile.legal_name else user.name) or user.phone, user.phone


def _buyer_profile_for(db, user):
    """The buyer record of an app account, created from the account if it has none."""
    profile = db.scalar(select(m.BuyerProfile).where(m.BuyerProfile.user_id == user.id).with_for_update())
    if profile is None:
        profile = m.BuyerProfile(user_id=user.id, business_name=user.name or user.phone, contact_person=user.name,
            phone=user.phone, region=user.region, buyer_type=user.buyer_type or 'personal')
        db.add(profile)
        db.flush()
    return profile


def _sale_buyer(db, data):
    if data.buyer_profile_id:
        profile = db.get(m.BuyerProfile, data.buyer_profile_id)
        if not profile:
            fail('err.buyer_crm_record_not_found', 404)
        return profile
    if data.buyer_user_id:
        user = db.get(m.User, data.buyer_user_id)
        if not user or user.deleted or 'buyer' not in (user.roles or []):
            fail('err.choose_existing_buyer_account', 422)
        return _buyer_profile_for(db, user)
    new = data.new_buyer
    if new.phone:
        # One record per phone: a buyer already known by this number is reused.
        known = db.scalar(select(m.BuyerProfile).where(m.BuyerProfile.phone == new.phone)
            .order_by(m.BuyerProfile.created_at))
        if known:
            return known
        user = db.scalar(select(m.User).where(m.User.phone == new.phone))
        if user and not user.deleted and 'buyer' in (user.roles or []):
            return _buyer_profile_for(db, user)
    profile = m.BuyerProfile(**new.model_dump())
    db.add(profile)
    db.flush()
    return profile


def _lock_debt(db, id):
    debt = db.scalar(select(m.LedgerDebt).where(m.LedgerDebt.id == id).with_for_update())
    if not debt:
        fail('err.debt_not_found', 404)
    return debt


def record_payment(db, debt, data, operator, supplier_payment_id=None):
    if debt.status == 'cancelled':
        fail('err.debt_cancelled_no_payments')
    if data.amount > debt.balance:
        fail('err.payment_more_than_balance', 422, balance=f'{debt.balance:,.2f}')
    if data.reference and db.scalar(select(m.LedgerPayment.id).where(m.LedgerPayment.debt_id == debt.id,
            m.LedgerPayment.method == data.method, m.LedgerPayment.reference == data.reference,
            m.LedgerPayment.reversed_at.is_(None))):
        fail('err.payment_reference_already_recorded')
    row = m.LedgerPayment(debt_id=debt.id, supplier_payment_id=supplier_payment_id,
        recorded_by=operator.id, **data.model_dump())
    db.add(row)
    debt.paid_amount += data.amount
    debt.status = 'settled' if debt.paid_amount == debt.amount else 'open'
    db.flush()
    return row


@router.post('/sales', status_code=201)
def create_sale(data: c.DirectSaleInput, idempotency_key: str = Header(), operator=Depends(auth.ops), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'sale', idempotency_key, data.model_dump())
    if prior:
        return _result(sale_view(db, db.get(m.Sale, prior), True), 201)
    profile = _sale_buyer(db, data)
    sale_id = m.identifier()
    number = 'SL-' + sale_id.replace('-', '')[:8].upper()
    items, costs = [], defaultdict(lambda: {'amount': ZERO, 'lines': []})
    taken = defaultdict(lambda: ZERO)
    for position, line in enumerate(data.items, 1):
        subtotal = s.money(line.quantity * line.unit_price)
        if line.unit not in ('kg',) and line.quantity % 1:
            fail('err.birds_animals_require_whole_quantities', 422)
        if line.lpo_line_id:
            # LPO stock: costed at the LPO price and already owed through the
            # LPO's receipts, so no payable here.
            from .purchasing import take_stock
            stock, lpo = take_stock(db, line.lpo_line_id, line.quantity, taken[line.lpo_line_id])
            taken[line.lpo_line_id] += line.quantity
            items.append(m.SaleItem(sale_id=sale_id, position=position, category=line.category or stock.category or '',
                description=line.description or stock.item, unit=line.unit, quantity=line.quantity,
                unit_price=line.unit_price, subtotal=subtotal, supplier_id=lpo.supplier_id,
                unit_cost=stock.unit_price, cost_total=s.money(line.quantity * stock.unit_price), lpo_line_id=stock.id))
            continue
        cost_total = s.money(line.quantity * line.unit_cost) if line.unit_cost is not None else None
        items.append(m.SaleItem(sale_id=sale_id, position=position, category=line.category or '',
            description=line.description or '', unit=line.unit, quantity=line.quantity, unit_price=line.unit_price,
            subtotal=subtotal, supplier_id=line.supplier_id, supplier_name=line.supplier_name,
            unit_cost=line.unit_cost, cost_total=cost_total))
        if cost_total is not None:
            if line.supplier_id:
                party = ('supplier', line.supplier_id)
                costs[party]['name'], costs[party]['phone'] = _supplier_party(db, line.supplier_id)
            else:
                party = ('other', line.supplier_name.casefold())
                costs[party]['name'], costs[party]['phone'] = line.supplier_name, ''
            costs[party]['amount'] += cost_total
            costs[party]['lines'].append(line.description or line.category.replace('_', ' '))
            if line.cost_payment:
                costs[party].setdefault('payments', []).append((cost_total, line.cost_payment))
    total = sum((i.subtotal for i in items), ZERO)
    cost = sum((i.cost_total or ZERO for i in items), ZERO)
    name = profile.business_name or profile.contact_person or profile.phone
    sale = m.Sale(id=sale_id, sale_number=number, sold_on=data.sold_on, buyer_profile_id=profile.id,
        buyer_user_id=profile.user_id, buyer_name=name, buyer_phone=profile.phone or '',
        total_amount=total, cost_amount=cost, notes=data.notes, created_by=operator.id)
    db.add(sale)
    db.flush()
    db.add_all(items)
    receivable = m.LedgerDebt(direction='receivable', party_kind='buyer', buyer_profile_id=profile.id,
        party_name=name, party_phone=profile.phone or '', description=f'Sale {number}', amount=total,
        incurred_on=data.sold_on, source='sale', sale_id=sale.id, created_by=operator.id)
    db.add(receivable)
    payables = []
    for (kind, party), owed in costs.items():
        debt = m.LedgerDebt(direction='payable', party_kind='supplier' if kind == 'supplier' else 'other',
            supplier_id=party if kind == 'supplier' else None, party_name=owed['name'], party_phone=owed['phone'],
            description=f"Stock for sale {number}: {', '.join(owed['lines'])}"[:500], amount=owed['amount'],
            incurred_on=data.sold_on, source='sale_cost', sale_id=sale.id, created_by=operator.id)
        db.add(debt)
        payables.append((debt, owed.get('payments', [])))
    db.flush()
    for debt, payments in payables:
        grouped = defaultdict(lambda: ZERO)
        details = {}
        for amount, payment in payments:
            payment_key = (payment.paid_on, payment.method, payment.reference, payment.note)
            grouped[payment_key] += amount
            details[payment_key] = payment
        for payment_key, amount in grouped.items():
            record_payment(db, debt, c.LedgerPaymentInput(amount=amount, **details[payment_key].model_dump()), operator)
    if data.payment:
        record_payment(db, receivable, data.payment, operator)
    s.remember(db, key, fingerprint, sale.id)
    return _result(sale_view(db, sale, True), 201)


@router.put('/sales/{id}')
def update_sale(id: str, data: c.DirectSaleInput, operator=Depends(auth.ops), db=Depends(database)):
    """Correct an active direct sale while preserving every money record.

    Totals may not be reduced below payments already made. Supplier payments
    stay attached to their supplier debt; payment changes are made from the
    sale/debt screen so an edit can never silently create or erase cash.
    """
    sale = db.scalar(select(m.Sale).where(m.Sale.id == id).with_for_update())
    if not sale:
        fail('err.sale_not_found', 404)
    if sale.status != 'active':
        fail('err.cancelled_sale_cannot_be_edited')
    if data.payment or any(line.cost_payment for line in data.items):
        fail('err.sale_edit_payments_separately', 422)

    profile = _sale_buyer(db, data)
    old_items = db.scalars(select(m.SaleItem).where(m.SaleItem.sale_id == id).order_by(m.SaleItem.position)).all()
    old_lpo = defaultdict(lambda: ZERO)
    for item in old_items:
        if item.lpo_line_id:
            old_lpo[item.lpo_line_id] += item.quantity

    items, costs = [], defaultdict(lambda: {'amount': ZERO, 'lines': []})
    taken = defaultdict(lambda: ZERO)
    for position, line in enumerate(data.items, 1):
        subtotal = s.money(line.quantity * line.unit_price)
        if line.unit not in ('kg',) and line.quantity % 1:
            fail('err.birds_animals_require_whole_quantities', 422)
        if line.lpo_line_id:
            from .purchasing import take_stock
            prior = taken[line.lpo_line_id] - old_lpo[line.lpo_line_id]
            stock, lpo = take_stock(db, line.lpo_line_id, line.quantity, prior)
            taken[line.lpo_line_id] += line.quantity
            items.append(m.SaleItem(sale_id=id, position=position, category=line.category or stock.category or '',
                description=line.description or stock.item, unit=line.unit, quantity=line.quantity,
                unit_price=line.unit_price, subtotal=subtotal, supplier_id=lpo.supplier_id,
                unit_cost=stock.unit_price, cost_total=s.money(line.quantity * stock.unit_price), lpo_line_id=stock.id))
            continue
        cost_total = s.money(line.quantity * line.unit_cost) if line.unit_cost is not None else None
        items.append(m.SaleItem(sale_id=id, position=position, category=line.category or '',
            description=line.description or '', unit=line.unit, quantity=line.quantity, unit_price=line.unit_price,
            subtotal=subtotal, supplier_id=line.supplier_id, supplier_name=line.supplier_name,
            unit_cost=line.unit_cost, cost_total=cost_total))
        if cost_total is not None:
            if line.supplier_id:
                party = ('supplier', line.supplier_id)
                costs[party]['name'], costs[party]['phone'] = _supplier_party(db, line.supplier_id)
            else:
                party = ('other', line.supplier_name.casefold())
                costs[party]['name'], costs[party]['phone'] = line.supplier_name, ''
            costs[party]['amount'] += cost_total
            costs[party]['lines'].append(line.description or line.category.replace('_', ' '))

    total = sum((item.subtotal for item in items), ZERO)
    cost = sum((item.cost_total or ZERO for item in items), ZERO)
    debts = db.scalars(select(m.LedgerDebt).where(m.LedgerDebt.sale_id == id).with_for_update()).all()
    receivable = next((row for row in debts if row.direction == 'receivable'), None)
    if not receivable or total < receivable.paid_amount:
        fail('err.sale_total_below_recorded_payments', 422)

    existing = {}
    for debt in debts:
        if debt.direction != 'payable' or debt.status == 'cancelled':
            continue
        key = ('supplier', debt.supplier_id) if debt.supplier_id else ('other', debt.party_name.casefold())
        existing[key] = debt
    # A supplier correction must keep the original debt and every payment on
    # it. When one supplier was replaced by one other supplier, re-key that
    # debt instead of treating the edit as deleting a paid debt and creating a
    # new unpaid one.
    removed_keys = [key for key in existing if key not in costs]
    added_keys = [key for key in costs if key not in existing]
    if len(removed_keys) == 1 and len(added_keys) == 1:
        debt = existing.pop(removed_keys[0])
        existing[added_keys[0]] = debt

    for key, debt in existing.items():
        desired = costs.get(key, {}).get('amount', ZERO)
        if desired < debt.paid_amount:
            fail('err.sale_cost_below_recorded_payments', 422, supplier=debt.party_name)

    name = profile.business_name or profile.contact_person or profile.phone
    sale.sold_on, sale.buyer_profile_id, sale.buyer_user_id = data.sold_on, profile.id, profile.user_id
    sale.buyer_name, sale.buyer_phone, sale.total_amount = name, profile.phone or '', total
    sale.cost_amount, sale.notes = cost, data.notes
    receivable.buyer_profile_id, receivable.party_name, receivable.party_phone = profile.id, name, profile.phone or ''
    receivable.amount, receivable.incurred_on = total, data.sold_on
    receivable.status = 'settled' if receivable.paid_amount == total else 'open'

    for item in old_items:
        db.delete(item)
    db.flush()
    db.add_all(items)

    for key, debt in existing.items():
        if key not in costs:
            payment_history = db.scalar(select(m.LedgerPayment.id).where(m.LedgerPayment.debt_id == debt.id).limit(1))
            if payment_history:
                debt.status, debt.cancelled_at = 'cancelled', m.now()
                debt.cancelled_by, debt.cancel_reason = operator.id, 'Sale edited; supplier cost removed'
            else:
                db.delete(debt)
    for (kind, party), owed in costs.items():
        debt = existing.get((kind, party))
        if debt:
            debt.party_kind = 'supplier' if kind == 'supplier' else 'other'
            debt.supplier_id = party if kind == 'supplier' else None
            debt.party_name, debt.party_phone = owed['name'], owed['phone']
            debt.amount, debt.incurred_on = owed['amount'], data.sold_on
            debt.description = f"Stock for sale {sale.sale_number}: {', '.join(owed['lines'])}"[:500]
            debt.status = 'settled' if debt.paid_amount == debt.amount else 'open'
        else:
            db.add(m.LedgerDebt(direction='payable', party_kind='supplier' if kind == 'supplier' else 'other',
                supplier_id=party if kind == 'supplier' else None, party_name=owed['name'], party_phone=owed['phone'],
                description=f"Stock for sale {sale.sale_number}: {', '.join(owed['lines'])}"[:500], amount=owed['amount'],
                incurred_on=data.sold_on, source='sale_cost', sale_id=id, created_by=operator.id))
    db.flush()
    return _result(sale_view(db, sale, True))


@router.post('/sales/{id}/cancel')
def cancel_sale(id: str, data: c.ReasonInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'sale-cancel', idempotency_key, {'id': id, **data.model_dump()})
    sale = db.scalar(select(m.Sale).where(m.Sale.id == id).with_for_update())
    if not sale:
        fail('err.sale_not_found', 404)
    if not prior:
        if sale.status == 'cancelled':
            fail('err.sale_already_cancelled')
        debts = db.scalars(select(m.LedgerDebt).where(m.LedgerDebt.sale_id == id).with_for_update()).all()
        if any(d.paid_amount > 0 for d in debts):
            fail('err.reverse_payments_before_cancelling')
        at = m.now()
        sale.status, sale.cancelled_at, sale.cancelled_by, sale.cancel_reason = 'cancelled', at, operator.id, data.reason
        for debt in debts:
            debt.status, debt.cancelled_at, debt.cancelled_by, debt.cancel_reason = 'cancelled', at, operator.id, data.reason
        s.remember(db, key, fingerprint, id)
    return _result(sale_view(db, sale, True))


@router.post('/ledger/debts', status_code=201)
def create_debt(data: c.LedgerDebtInput, idempotency_key: str = Header(), operator=Depends(auth.ops), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'debt', idempotency_key, data.model_dump())
    if prior:
        return _result(debt_view(db.get(m.LedgerDebt, prior)), 201)
    name, phone = data.party_name, data.party_phone
    if data.party_kind == 'buyer':
        profile = db.get(m.BuyerProfile, data.buyer_profile_id)
        if not profile:
            fail('err.buyer_crm_record_not_found', 404)
        name, phone = profile.business_name or profile.contact_person, phone or profile.phone
    elif data.party_kind == 'supplier':
        name, supplier_phone = _supplier_party(db, data.supplier_id)
        phone = phone or supplier_phone
    row = m.LedgerDebt(direction=data.direction, party_kind=data.party_kind, buyer_profile_id=data.buyer_profile_id,
        supplier_id=data.supplier_id, party_name=name, party_phone=phone or '', description=data.description,
        amount=data.amount, incurred_on=data.incurred_on, due_on=data.due_on, source='manual', created_by=operator.id)
    db.add(row)
    db.flush()
    s.remember(db, key, fingerprint, row.id)
    return _result(debt_view(row), 201)


@router.post('/ledger/debts/{id}/payments', status_code=201)
def add_payment(id: str, data: c.LedgerPaymentInput, idempotency_key: str = Header(), operator=Depends(auth.ops),
                db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'ledger-payment', idempotency_key, {'id': id, **data.model_dump()})
    debt = _lock_debt(db, id)
    if not prior:
        record_payment(db, debt, data, operator)
        s.remember(db, key, fingerprint, id)
    return _result(_debt_detail(db, debt), 201)


@router.post('/ledger/supplier-payment-receipts', status_code=201)
async def upload_supplier_payment_receipt(file: UploadFile = File(), operator=Depends(auth.ops), db=Depends(database)):
    """Store a cleaned receipt image before its payment record is submitted."""
    raw = await file.read(10 * 1024 * 1024 + 1)
    if len(raw) > 10 * 1024 * 1024:
        fail('err.choose_photo_under_10mb', 413)
    return _result(await run_in_threadpool(save_photo, db, None, raw), 201)


@router.post('/ledger/suppliers/{supplier_id}/payments', status_code=201)
def pay_supplier(supplier_id: str, data: c.SupplierPaymentInput, idempotency_key: str = Header(),
                 operator=Depends(auth.ops), db=Depends(database)):
    """Allocate one supplier transfer over selected invoices, oldest first."""
    _supplier_party(db, supplier_id)
    payload = {'supplier_id': supplier_id, **data.model_dump()}
    key, fingerprint, prior = s.replay(db, operator.id, 'supplier-payment', idempotency_key, payload)
    if prior:
        row = db.get(m.SupplierPayment, prior)
        return _result({'id': row.id, 'amount': row.amount}, 201)
    if data.receipt_media_id:
        asset = db.get(m.MediaAsset, data.receipt_media_id)
        if not asset or asset.owner_id is not None or not asset.content_type.startswith('image/'):
            fail('err.photo_unavailable_upload_own', 422)
    query = select(m.LedgerDebt).where(m.LedgerDebt.supplier_id == supplier_id,
        m.LedgerDebt.direction == 'payable', m.LedgerDebt.status == 'open').order_by(
        m.LedgerDebt.due_on.asc().nulls_last(), m.LedgerDebt.incurred_on, m.LedgerDebt.created_at).with_for_update()
    if data.debt_ids:
        query = query.where(m.LedgerDebt.id.in_(data.debt_ids))
    debts = db.scalars(query).all()
    if data.debt_ids and {row.id for row in debts} != set(data.debt_ids):
        fail('err.supplier_invoice_unavailable', 422)
    available = sum((row.balance for row in debts), ZERO)
    if not debts or data.amount > available:
        fail('err.payment_more_than_balance', 422, balance=f'{available:,.2f}')
    group = m.SupplierPayment(supplier_id=supplier_id, amount=data.amount, paid_on=data.paid_on,
        method=data.method, reference=data.reference.strip(), sms_text=data.sms_text.strip(),
        receipt_media_id=data.receipt_media_id, note=data.note.strip(), recorded_by=operator.id)
    db.add(group)
    db.flush()
    remaining = data.amount
    for debt in debts:
        amount = min(remaining, debt.balance)
        if amount <= ZERO:
            break
        allocation = c.LedgerPaymentInput(amount=amount, paid_on=data.paid_on, method=data.method,
            reference='', note=data.note)
        record_payment(db, debt, allocation, operator, group.id)
        remaining -= amount
    notes.notify(db, supplier_id, 'supplier', 'supplier_payment', M('notify.supplier_payment',
        amount=f'{data.amount:,.0f}'), '/account#payments')
    s.remember(db, key, fingerprint, group.id)
    return _result({'id': group.id, 'amount': group.amount, 'allocated': data.amount}, 201)


@router.post('/ledger/payments/{id}/reverse')
def reverse_payment(id: str, data: c.ReasonInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                    db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'ledger-reverse', idempotency_key, {'id': id, **data.model_dump()})
    row = db.get(m.LedgerPayment, id)
    if not row:
        fail('err.payment_not_found', 404)
    debt = _lock_debt(db, row.debt_id)
    if not prior:
        if row.reversed_at is not None:
            fail('err.payment_already_reversed')
        row.reversed_at, row.reversed_by, row.reverse_reason = m.now(), operator.id, data.reason
        debt.paid_amount -= row.amount
        debt.status = 'open'
        s.remember(db, key, fingerprint, id)
    return _result(_debt_detail(db, debt))


@router.post('/ledger/debts/{id}/cancel')
def cancel_debt(id: str, data: c.ReasonInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'debt-cancel', idempotency_key, {'id': id, **data.model_dump()})
    debt = _lock_debt(db, id)
    if not prior:
        if debt.source == 'lpo':
            fail('err.cancel_the_receipt_instead')
        if debt.source not in ('manual', 'expense'):
            fail('err.cancel_the_sale_instead')
        if debt.status == 'cancelled':
            fail('err.debt_already_cancelled')
        if debt.paid_amount > 0:
            fail('err.reverse_payments_before_cancelling')
        debt.status, debt.cancelled_at, debt.cancelled_by, debt.cancel_reason = 'cancelled', m.now(), operator.id, data.reason
        s.remember(db, key, fingerprint, id)
    return _result(_debt_detail(db, debt))


# ---- reads ------------------------------------------------------------------

def _debt_detail(db, debt):
    sale = db.get(m.Sale, debt.sale_id) if debt.sale_id else None
    return {**debt_view(debt), 'created_by': _operator_name(db, debt.created_by),
        'sale_number': sale.sale_number if sale else None,
        'payments': [payment_view(db, p) for p in _payments(db, debt.id)]}


def _receivable_state(state):
    debt = select(m.LedgerDebt.id).where(m.LedgerDebt.sale_id == m.Sale.id, m.LedgerDebt.direction == 'receivable',
        m.LedgerDebt.status == state)
    return exists(debt)


SALES = Spec(m.Sale, (m.Sale.sold_on.desc(), m.Sale.created_at.desc(), m.Sale.id.desc()),
    lambda q: or_(paging.matches(q, m.Sale.sale_number, m.Sale.buyer_name, m.Sale.buyer_phone),
                  m.Sale.id.in_(select(m.SaleItem.sale_id).where(
                      paging.matches(q, m.SaleItem.description, m.SaleItem.supplier_name)))),
    tabs={'unpaid': and_(m.Sale.status == 'active', _receivable_state('open')),
          'paid': and_(m.Sale.status == 'active', _receivable_state('settled')),
          'cancelled': m.Sale.status == 'cancelled'},
    column=m.Sale.status)


@router.get('/sales')
def sales(params: Paging = Depends(), buyer_profile_id: Optional[str] = None, operator=Depends(auth.ops),
          db=Depends(database)):
    where = [m.Sale.buyer_profile_id == buyer_profile_id] if buyer_profile_id else []
    return _result(paging.page(db, SALES, params, lambda row: sale_view(db, row), where=where))


@router.get('/sales/{id}')
def sale(id: str, operator=Depends(auth.ops), db=Depends(database)):
    row = db.get(m.Sale, id)
    if not row:
        fail('err.sale_not_found', 404)
    return _result(sale_view(db, row, True))


OPEN_DEBT = m.LedgerDebt.status == 'open'
DEBTS = Spec(m.LedgerDebt, (m.LedgerDebt.incurred_on.desc(), m.LedgerDebt.created_at.desc(), m.LedgerDebt.id.desc()),
    lambda q: paging.matches(q, m.LedgerDebt.party_name, m.LedgerDebt.party_phone, m.LedgerDebt.description),
    tabs={'owed_to_me': and_(OPEN_DEBT, m.LedgerDebt.direction == 'receivable'),
          'i_owe': and_(OPEN_DEBT, m.LedgerDebt.direction == 'payable'),
          'settled': m.LedgerDebt.status == 'settled', 'cancelled': m.LedgerDebt.status == 'cancelled'},
    column=m.LedgerDebt.status, urgent=OPEN_DEBT,
    urgent_order=(m.LedgerDebt.due_on.asc().nulls_last(), m.LedgerDebt.incurred_on, m.LedgerDebt.id))


@router.get('/ledger/debts')
def debts(params: Paging = Depends(), direction: Optional[str] = None, buyer_profile_id: Optional[str] = None,
          supplier_id: Optional[str] = None, operator=Depends(auth.ops), db=Depends(database)):
    where = []
    if direction in ('receivable', 'payable'):
        where.append(m.LedgerDebt.direction == direction)
    if buyer_profile_id:
        where.append(m.LedgerDebt.buyer_profile_id == buyer_profile_id)
    if supplier_id:
        where.append(m.LedgerDebt.supplier_id == supplier_id)
    return _result(paging.page(db, DEBTS, params, debt_view, where=where))


@router.get('/ledger/debts/{id}')
def debt(id: str, operator=Depends(auth.ops), db=Depends(database)):
    row = db.get(m.LedgerDebt, id)
    if not row:
        fail('err.debt_not_found', 404)
    return _result(_debt_detail(db, row))


PAYMENTS = Spec(m.LedgerPayment, (m.LedgerPayment.paid_on.desc(), m.LedgerPayment.created_at.desc(), m.LedgerPayment.id.desc()),
    lambda q: or_(paging.matches(q, m.LedgerPayment.reference, m.LedgerPayment.note),
                  m.LedgerPayment.debt_id.in_(select(m.LedgerDebt.id).where(
                      paging.matches(q, m.LedgerDebt.party_name, m.LedgerDebt.party_phone, m.LedgerDebt.description)))),
    tabs={'in': and_(m.LedgerPayment.reversed_at.is_(None), m.LedgerPayment.debt_id.in_(
              select(m.LedgerDebt.id).where(m.LedgerDebt.direction == 'receivable'))),
          'out': and_(m.LedgerPayment.reversed_at.is_(None), m.LedgerPayment.debt_id.in_(
              select(m.LedgerDebt.id).where(m.LedgerDebt.direction == 'payable'))),
          'reversed': m.LedgerPayment.reversed_at.is_not(None)})


@router.get('/ledger/payments')
def cash_book(params: Paging = Depends(), start: Optional[date] = None, end: Optional[date] = None,
              operator=Depends(auth.ops), db=Depends(database)):
    """Every installment in and out, newest first: the cash book."""
    where = []
    if start:
        where.append(m.LedgerPayment.paid_on >= start)
    if end:
        where.append(m.LedgerPayment.paid_on <= end)
    return _result(paging.page(db, PAYMENTS, params,
        lambda row: payment_view(db, row, db.get(m.LedgerDebt, row.debt_id)), where=where))


def _parties(db, direction):
    """Everyone with an open balance in one direction, largest first."""
    rows = db.scalars(select(m.LedgerDebt).where(m.LedgerDebt.direction == direction, OPEN_DEBT)).all()
    today = c.business_today()
    parties = {}
    for row in rows:
        key = row.buyer_profile_id or row.supplier_id or f'{row.party_kind}:{row.party_name.casefold()}'
        party = parties.setdefault(key, {'party_name': row.party_name, 'party_phone': row.party_phone,
            'party_kind': row.party_kind, 'buyer_profile_id': row.buyer_profile_id, 'supplier_id': row.supplier_id,
            'balance': ZERO, 'debts': 0, 'oldest': row.incurred_on, 'overdue': ZERO})
        party['balance'] += row.balance
        party['debts'] += 1
        party['oldest'] = min(party['oldest'], row.incurred_on)
        if row.due_on is not None and row.due_on < today:
            party['overdue'] += row.balance
    return sorted(parties.values(), key=lambda p: (-p['balance'], p['party_name']))


def _paid(db, direction, *conditions):
    return db.scalar(select(func.coalesce(func.sum(m.LedgerPayment.amount), 0))
        .join(m.LedgerDebt, m.LedgerDebt.id == m.LedgerPayment.debt_id)
        .where(m.LedgerDebt.direction == direction, m.LedgerPayment.reversed_at.is_(None), *conditions)) or ZERO


def _sold(db, *conditions):
    return db.scalar(select(func.coalesce(func.sum(m.Sale.total_amount), 0))
        .where(m.Sale.status == 'active', *conditions)) or ZERO


@router.get('/finance/summary')
def finance_summary(operator=Depends(auth.ops), db=Depends(database)):
    today = c.business_today()
    month = today.replace(day=1)
    debtors, creditors = _parties(db, 'receivable'), _parties(db, 'payable')
    owed_to_me = sum((p['balance'] for p in debtors), ZERO)
    i_owe = sum((p['balance'] for p in creditors), ZERO)
    # The marketplace keeps its own records; count them so nothing is missed.
    market_owed = db.scalar(select(func.coalesce(func.sum(m.Payment.amount - m.Payment.received_amount), 0))
        .join(m.Order, m.Order.id == m.Payment.order_id)
        .where(m.Payment.status.in_(('pending', 'partial')),
               m.Order.internal_status.not_in(('cancelled', 'payment_failed')))) or ZERO
    market_payouts = db.scalar(select(func.coalesce(func.sum(m.Settlement.total_payable), 0))
        .where(m.Settlement.status == 'pending')) or ZERO
    by_method = defaultdict(lambda: {'in': ZERO, 'out': ZERO})
    for method, direction, amount in db.execute(select(m.LedgerPayment.method, m.LedgerDebt.direction,
            func.sum(m.LedgerPayment.amount)).join(m.LedgerDebt, m.LedgerDebt.id == m.LedgerPayment.debt_id)
            .where(m.LedgerPayment.reversed_at.is_(None)).group_by(m.LedgerPayment.method, m.LedgerDebt.direction)):
        by_method[method]['in' if direction == 'receivable' else 'out'] += amount
    recent = db.scalars(select(m.LedgerPayment).order_by(m.LedgerPayment.created_at.desc()).limit(15)).all()
    return _result({
        'today': {'date': today, 'sales': _sold(db, m.Sale.sold_on == today),
                  'sales_count': db.scalar(select(func.count()).where(m.Sale.status == 'active', m.Sale.sold_on == today)),
                  'money_in': _paid(db, 'receivable', m.LedgerPayment.paid_on == today),
                  'money_out': _paid(db, 'payable', m.LedgerPayment.paid_on == today)},
        'month': {'start': month, 'sales': _sold(db, m.Sale.sold_on >= month),
                  'money_in': _paid(db, 'receivable', m.LedgerPayment.paid_on >= month),
                  'money_out': _paid(db, 'payable', m.LedgerPayment.paid_on >= month)},
        'all_time': {'sales': _sold(db), 'money_in': _paid(db, 'receivable'), 'money_out': _paid(db, 'payable')},
        'profit_today': {k: v for k, v in profit_between(db, today, today).items() if k != 'days'},
        'profit_month': {k: v for k, v in profit_between(db, month, today).items() if k != 'days'},
        'owed_to_me': {'ledger': owed_to_me, 'marketplace': market_owed, 'total': owed_to_me + market_owed,
                       'overdue': sum((p['overdue'] for p in debtors), ZERO)},
        'i_owe': {'ledger': i_owe, 'marketplace': market_payouts, 'total': i_owe + market_payouts,
                  'overdue': sum((p['overdue'] for p in creditors), ZERO)},
        'by_method': [{'method': k, **v, 'net': v['in'] - v['out']} for k, v in sorted(by_method.items())],
        'debtors': debtors[:100], 'creditors': creditors[:100],
        'recent_payments': [payment_view(db, p, db.get(m.LedgerDebt, p.debt_id)) for p in recent],
    })


@router.get('/finance/parties')
def finance_parties(q: str = Query('', max_length=100), operator=Depends(auth.ops), db=Depends(database)):
    """Buyers and suppliers to pick from when recording a sale or a debt."""
    q = q.strip()
    buyers = select(m.BuyerProfile).order_by(func.lower(m.BuyerProfile.business_name)).limit(500)
    suppliers = (select(m.User, m.SupplierProfile).join(m.SupplierProfile, m.SupplierProfile.user_id == m.User.id, isouter=True)
        .where(cast(m.User.roles, Text).like('%"supplier"%'), m.User.deleted.is_(False))
        .order_by(func.lower(m.User.name)).limit(500))
    app_buyers = (select(m.User).where(paging.is_buyer(), m.User.deleted.is_(False),
        m.User.id.not_in(select(m.BuyerProfile.user_id).where(m.BuyerProfile.user_id.is_not(None))))
        .order_by(func.lower(m.User.name)).limit(500))
    if q:
        buyers = buyers.where(paging.matches(q, m.BuyerProfile.business_name, m.BuyerProfile.contact_person, m.BuyerProfile.phone))
        suppliers = suppliers.where(paging.matches(q, m.User.name, m.User.phone, m.SupplierProfile.legal_name,
            m.SupplierProfile.public_alias))
        app_buyers = app_buyers.where(paging.matches(q, m.User.name, m.User.phone))
    return _result({
        'buyers': [{'kind': 'profile', 'id': b.id, 'name': b.business_name or b.contact_person, 'phone': b.phone,
                    'region': b.region} for b in db.scalars(buyers)]
                  + [{'kind': 'user', 'id': u.id, 'name': u.name or u.phone, 'phone': u.phone, 'region': u.region}
                     for u in db.scalars(app_buyers)],
        'suppliers': [{'id': u.id, 'name': (p.legal_name if p and p.legal_name else u.name) or u.phone,
                       'alias': p.public_alias if p else '', 'phone': u.phone} for u, p in db.execute(suppliers)],
    })


# ---- expenses and profit ----------------------------------------------------

@router.post('/expenses', status_code=201)
def create_expense(data: c.ExpenseInput, idempotency_key: str = Header(), operator=Depends(auth.ops), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'expense', idempotency_key, data.model_dump())
    if prior:
        return _result(_debt_detail(db, db.get(m.LedgerDebt, prior)), 201)
    if data.sale_id:
        sale = db.get(m.Sale, data.sale_id)
        if not sale:
            fail('err.sale_not_found', 404)
    row = m.LedgerDebt(direction='payable', party_kind='other', party_name=data.paid_to or 'Expense',
        party_phone=data.paid_to_phone, description=data.description, amount=data.amount, incurred_on=data.spent_on,
        due_on=data.due_on, source='expense', expense_category=data.category, sale_id=data.sale_id,
        created_by=operator.id)
    db.add(row)
    db.flush()
    if data.payment:
        record_payment(db, row, data.payment, operator)
    s.remember(db, key, fingerprint, row.id)
    return _result(_debt_detail(db, row), 201)


EXPENSE = and_(m.LedgerDebt.source == 'expense', m.LedgerDebt.status != 'cancelled')


@router.get('/expenses')
def expenses(params: Paging = Depends(), start: Optional[date] = None, end: Optional[date] = None,
             category: Optional[str] = None, sale_id: Optional[str] = None, operator=Depends(auth.ops),
             db=Depends(database)):
    where = [m.LedgerDebt.source == 'expense']
    if start:
        where.append(m.LedgerDebt.incurred_on >= start)
    if end:
        where.append(m.LedgerDebt.incurred_on <= end)
    if category:
        where.append(m.LedgerDebt.expense_category == category)
    if sale_id:
        where.append(m.LedgerDebt.sale_id == sale_id)
    body = paging.page(db, DEBTS, params, debt_view, where=where)
    rows = db.execute(select(m.LedgerDebt.expense_category, func.sum(m.LedgerDebt.amount), func.sum(m.LedgerDebt.paid_amount))
        .where(*where, m.LedgerDebt.status != 'cancelled').group_by(m.LedgerDebt.expense_category)).all()
    body['by_category'] = sorted(({'category': k, 'amount': a, 'paid': p, 'owed': a - p} for k, a, p in rows),
        key=lambda r: -r['amount'])
    body['total'] = sum((r['amount'] for r in body['by_category']), ZERO)
    return _result(body)


def _order_day():
    return cast(func.timezone('Africa/Dar_es_Salaam', m.Order.created_at), Date)


DELIVERED = m.Order.internal_status.in_(('delivered', 'completed'))


def profit_between(db, start, end):
    """Profit for the days start..end (inclusive), on Omoterra's calendar."""
    def by_day(query, day_column):
        return {day: value or ZERO for day, value in db.execute(query.where(day_column >= start, day_column <= end)
            .group_by(day_column)).all()}

    sales = db.execute(select(m.Sale.sold_on, func.sum(m.Sale.total_amount), func.sum(m.Sale.cost_amount))
        .where(m.Sale.status == 'active', m.Sale.sold_on >= start, m.Sale.sold_on <= end).group_by(m.Sale.sold_on)).all()
    day = _order_day()
    market_sales = by_day(select(day, func.sum(m.Order.total_amount)).where(DELIVERED), day)
    market_cost = by_day(select(day, func.sum(m.OrderItem.payout_snapshot * func.coalesce(m.OrderItem.actual_quantity,
        m.OrderItem.quantity))).join(m.Order, m.Order.id == m.OrderItem.order_id).where(DELIVERED), day)
    spent = by_day(select(m.LedgerDebt.incurred_on, func.sum(m.LedgerDebt.amount)).where(EXPENSE), m.LedgerDebt.incurred_on)
    # Received stock that died or was lost before it was sold, at cost.
    lost = by_day(select(m.StockLoss.lost_on, func.sum(m.StockLoss.quantity * m.StockLoss.unit_cost))
        .where(m.StockLoss.cancelled_at.is_(None)), m.StockLoss.lost_on)
    categories = db.execute(select(m.LedgerDebt.expense_category, func.sum(m.LedgerDebt.amount))
        .where(EXPENSE, m.LedgerDebt.incurred_on >= start, m.LedgerDebt.incurred_on <= end)
        .group_by(m.LedgerDebt.expense_category)).all()
    days = {}
    for d in (start + timedelta(n) for n in range((end - start).days + 1)):
        days[d] = {'date': d, 'sales': ZERO, 'stock_cost': ZERO, 'expenses': spent.get(d, ZERO),
                   'marketplace_sales': market_sales.get(d, ZERO), 'marketplace_cost': s.money(market_cost.get(d, ZERO)),
                   'stock_lost': s.money(lost.get(d, ZERO))}
    for d, total, cost in sales:
        days[d]['sales'], days[d]['stock_cost'] = total, cost
    for row in days.values():
        row['revenue'] = row['sales'] + row['marketplace_sales']
        row['gross_profit'] = row['revenue'] - row['stock_cost'] - row['marketplace_cost']
        row['net_profit'] = row['gross_profit'] - row['expenses'] - row['stock_lost']
    totals = {key: sum((row[key] for row in days.values()), ZERO) for key in
        ('sales', 'stock_cost', 'marketplace_sales', 'marketplace_cost', 'revenue', 'gross_profit', 'expenses',
         'stock_lost', 'net_profit')}
    return {'start': start, 'end': end, **totals,
        'expenses_by_category': sorted(({'category': k, 'amount': v} for k, v in categories), key=lambda r: -r['amount']),
        'days': sorted(days.values(), key=lambda r: r['date'], reverse=True)}


@router.get('/finance/profit')
def profit(start: Optional[date] = None, end: Optional[date] = None, operator=Depends(auth.ops), db=Depends(database)):
    today = c.business_today()
    end = min(end or today, today)
    start = start or end.replace(day=1)
    if start > end or (end - start).days > 366:
        fail('err.choose_period_up_to_a_year', 422)
    return _result(profit_between(db, start, end))
