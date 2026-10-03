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

Every payment to a registered supplier is part of a transfer
(`supplier_payments`, see transfers.py): the record that money left. Taking
a supplier payment off an invoice never brings the money back; it becomes
that supplier's credit on the same transfer, to use on another invoice or to
be refunded with evidence (build plan M1.2, rules R1, R3, R4).

A supplier debt opened by a sale is never simply cancelled: an admin corrects
it for a reason (wrong supplier, duplicate liability, free stock, cost never
existed), which keeps or changes the buying cost accordingly and writes a
`financial_adjustments` row with the state before and after (M1.4). Stock
from a delivery note or LPO is sold in the receipt's unit and category (M1.5).

The overview also counts the marketplace's own buyer payments and supplier
settlements, so the totals owed either way are complete.
"""
from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, File, Header, Query, UploadFile
from fastapi.concurrency import run_in_threadpool
from sqlalchemy import Date, Integer, String, Text, and_, case, cast, exists, func, literal, null, or_, select, union_all

from . import auth, contracts as c, models as m, notifications as notes, paging, services as s, supplier_payment_sms
from . import transfers as tr
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
    view = {k: getattr(row, k) for k in ('id', 'debt_id', 'supplier_payment_id', 'amount', 'paid_on', 'method',
        'reference', 'note', 'created_at', 'reversed_at', 'reverse_reason')}
    view['reversed'] = row.reversed_at is not None
    # A supplier payment taken off its invoice stayed with the supplier.
    view['moved_to_credit'] = view['reversed'] and row.supplier_payment_id is not None
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
            'subtotal', 'supplier_id', 'supplier_name', 'unit_cost', 'cost_total', 'lpo_line_id',
            'supplier_collection_id', 'supplier_batch_id')} for i in items]
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
    if supplier_payment_id is None and debt.direction == 'payable' and debt.supplier_id:
        # Money to a registered supplier is always a transfer (M1.2), even
        # when it pays one invoice: that record is what money out counts.
        supplier_payment_id = tr.new_transfer(db, debt.supplier_id, data.amount, data.paid_on, data.method,
            data.reference, data.note, operator.id, 'single').id
    row = m.LedgerPayment(debt_id=debt.id, supplier_payment_id=supplier_payment_id,
        recorded_by=operator.id, **data.model_dump())
    db.add(row)
    debt.paid_amount += data.amount
    debt.status = 'settled' if debt.paid_amount == debt.amount else 'open'
    db.flush()
    return row


def _party_key(row):
    """Who a payable or a costed sale line is owed to: a registered supplier,
    or a name typed for someone not registered."""
    if row.supplier_id:
        return 'supplier', row.supplier_id
    return 'other', (row.party_name if isinstance(row, m.LedgerDebt) else row.supplier_name).casefold()


def _whole(unit, quantity):
    if unit != 'kg' and quantity % 1:
        fail('err.birds_animals_require_whole_quantities', 422)


def _receipt_line(line, unit, category):
    """Received stock is sold in its receipt's unit and category (build plan
    M1.5): a line may leave them out and gets the receipt's; a line that
    sends a different one is refused, never silently replaced. Selling birds
    by weight needs a recorded conversion (M2.1)."""
    unit = unit or line.unit
    if not unit:
        fail('err.choose_unit_sold', 422)
    if line.unit and line.unit != unit:
        fail('err.unit_differs_from_receipt', 422, unit=unit, sent=line.unit)
    if line.category and category and line.category != category:
        fail('err.category_differs_from_receipt', 422, category=category.replace('_', ' '),
            sent=line.category.replace('_', ' '))
    _whole(unit, line.quantity)
    return unit, category or line.category or ''


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
        if line.supplier_collection_id:
            from .batch_stock import take_collection_stock
            collection, batch = take_collection_stock(db, line.supplier_collection_id, line.quantity,
                taken[line.supplier_collection_id])
            unit, category = _receipt_line(line, c.UNITS.get(batch.category), batch.category)
            taken[line.supplier_collection_id] += line.quantity
            items.append(m.SaleItem(sale_id=sale_id, position=position, category=category,
                description=line.description or batch.subtype or batch.category.replace('_', ' '), unit=unit,
                quantity=line.quantity, unit_price=line.unit_price, subtotal=subtotal, supplier_id=collection.supplier_id,
                unit_cost=collection.unit_cost, cost_total=s.money(line.quantity * collection.unit_cost),
                supplier_collection_id=collection.id))
            continue
        if line.lpo_line_id:
            # LPO stock: costed at the LPO price and already owed through the
            # LPO's receipts, so no payable here.
            from .purchasing import take_stock
            stock, lpo = take_stock(db, line.lpo_line_id, line.quantity, taken[line.lpo_line_id])
            unit, category = _receipt_line(line, stock.unit, stock.category)
            taken[line.lpo_line_id] += line.quantity
            items.append(m.SaleItem(sale_id=sale_id, position=position, category=category,
                description=line.description or stock.item, unit=unit, quantity=line.quantity,
                unit_price=line.unit_price, subtotal=subtotal, supplier_id=lpo.supplier_id,
                unit_cost=stock.unit_price, cost_total=s.money(line.quantity * stock.unit_price), lpo_line_id=stock.id))
            continue
        _whole(line.unit, line.quantity)
        if line.unit_cost == 0:
            fail('err.free_cost_only_by_correction', 422)
        cost_total = s.money(line.quantity * line.unit_cost) if line.unit_cost is not None else None
        if line.supplier_batch_id:
            from .batch_stock import take_from_batch
            take_from_batch(db, line.supplier_batch_id, line.supplier_id, line.quantity)
        items.append(m.SaleItem(sale_id=sale_id, position=position, category=line.category or '',
            description=line.description or '', unit=line.unit, quantity=line.quantity, unit_price=line.unit_price,
            subtotal=subtotal, supplier_id=line.supplier_id, supplier_name=line.supplier_name,
            unit_cost=line.unit_cost, cost_total=cost_total, supplier_batch_id=line.supplier_batch_id))
        if cost_total:  # free stock (0) is owed to no one
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
    old_collections = defaultdict(lambda: ZERO)
    # Birds the old version took from supplier batches go back first, so
    # the edited lines can take them again.
    from .batch_stock import return_to_batch
    for item in old_items:
        if item.supplier_batch_id:
            return_to_batch(db, item.supplier_batch_id, item.quantity)
    free = {_party_key(item) for item in old_items if item.unit_cost == 0}
    for item in old_items:
        if item.lpo_line_id:
            old_lpo[item.lpo_line_id] += item.quantity
        if item.supplier_collection_id:
            old_collections[item.supplier_collection_id] += item.quantity

    items, costs = [], defaultdict(lambda: {'amount': ZERO, 'lines': []})
    taken = defaultdict(lambda: ZERO)
    for position, line in enumerate(data.items, 1):
        subtotal = s.money(line.quantity * line.unit_price)
        if line.supplier_collection_id:
            from .batch_stock import take_collection_stock
            prior = taken[line.supplier_collection_id] - old_collections[line.supplier_collection_id]
            collection, batch = take_collection_stock(db, line.supplier_collection_id, line.quantity, prior)
            unit, category = _receipt_line(line, c.UNITS.get(batch.category), batch.category)
            taken[line.supplier_collection_id] += line.quantity
            items.append(m.SaleItem(sale_id=id, position=position, category=category,
                description=line.description or batch.subtype or batch.category.replace('_', ' '), unit=unit,
                quantity=line.quantity, unit_price=line.unit_price, subtotal=subtotal, supplier_id=collection.supplier_id,
                unit_cost=collection.unit_cost, cost_total=s.money(line.quantity * collection.unit_cost),
                supplier_collection_id=collection.id))
            continue
        if line.lpo_line_id:
            from .purchasing import take_stock
            prior = taken[line.lpo_line_id] - old_lpo[line.lpo_line_id]
            stock, lpo = take_stock(db, line.lpo_line_id, line.quantity, prior)
            unit, category = _receipt_line(line, stock.unit, stock.category)
            taken[line.lpo_line_id] += line.quantity
            items.append(m.SaleItem(sale_id=id, position=position, category=category,
                description=line.description or stock.item, unit=unit, quantity=line.quantity,
                unit_price=line.unit_price, subtotal=subtotal, supplier_id=lpo.supplier_id,
                unit_cost=stock.unit_price, cost_total=s.money(line.quantity * stock.unit_price), lpo_line_id=stock.id))
            continue
        _whole(line.unit, line.quantity)
        # A cost of 0 (free stock) is kept by an edit, never introduced by one.
        if line.unit_cost == 0 and (('supplier', line.supplier_id) if line.supplier_id
                else ('other', line.supplier_name.casefold())) not in free:
            fail('err.free_cost_only_by_correction', 422)
        cost_total = s.money(line.quantity * line.unit_cost) if line.unit_cost is not None else None
        if line.supplier_batch_id:
            from .batch_stock import take_from_batch
            take_from_batch(db, line.supplier_batch_id, line.supplier_id, line.quantity)
        items.append(m.SaleItem(sale_id=id, position=position, category=line.category or '',
            description=line.description or '', unit=line.unit, quantity=line.quantity, unit_price=line.unit_price,
            subtotal=subtotal, supplier_id=line.supplier_id, supplier_name=line.supplier_name,
            unit_cost=line.unit_cost, cost_total=cost_total, supplier_batch_id=line.supplier_batch_id))
        if cost_total:  # free stock (0) is owed to no one
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

    existing, covered = {}, set()
    duplicates = set(db.scalars(select(m.FinancialAdjustment.entity_id).where(m.FinancialAdjustment.sale_id == id,
        m.FinancialAdjustment.kind == 'duplicate_liability')))
    for debt in debts:
        if debt.direction != 'payable':
            continue
        key = _party_key(debt)
        if debt.status != 'cancelled':
            existing[key] = debt
        elif debt.id in duplicates:
            # Already owed on the debt it duplicated: an edit must not open it again.
            covered.add(key)
    # Changing who supplied the stock never moves money (rule R1). An unpaid
    # debt simply follows the corrected supplier (the wrong name picked).
    # Once a supplier has been paid on this sale, that payment belongs to
    # whoever received it: the change is made with "Wrong supplier" on the
    # debt, which moves the whole obligation and keeps the payment with them.
    for key, debt in existing.items():
        if key not in costs and debt.paid_amount > 0:
            fail('err.paid_supplier_correct_debt_instead', 422, supplier=debt.party_name)
    removed_keys = [key for key in existing if key not in costs]
    added_keys = [key for key in costs if key not in existing and key not in covered]
    if len(removed_keys) == 1 and len(added_keys) == 1:
        existing[added_keys[0]] = existing.pop(removed_keys[0])

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
        elif (kind, party) not in covered:
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
        from .batch_stock import return_to_batch
        for item in db.scalars(select(m.SaleItem).where(m.SaleItem.sale_id == id, m.SaleItem.supplier_batch_id.is_not(None))):
            return_to_batch(db, item.supplier_batch_id, item.quantity)
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


def _open_supplier_debts(db, supplier_id, debt_ids):
    """The supplier's open invoices, oldest due first, locked; only the ones
    picked when some are. Another supplier's invoice is never included."""
    query = select(m.LedgerDebt).where(m.LedgerDebt.supplier_id == supplier_id,
        m.LedgerDebt.direction == 'payable', m.LedgerDebt.status == 'open').order_by(
        m.LedgerDebt.due_on.asc().nulls_last(), m.LedgerDebt.incurred_on, m.LedgerDebt.created_at).with_for_update()
    if debt_ids:
        query = query.where(m.LedgerDebt.id.in_(debt_ids))
    debts = db.scalars(query).all()
    if debt_ids and {row.id for row in debts} != set(debt_ids):
        fail('err.supplier_invoice_unavailable', 422)
    return debts


def _lock_transfer(db, id):
    row = db.scalar(select(m.SupplierPayment).where(m.SupplierPayment.id == id).with_for_update())
    if not row:
        fail('err.transfer_not_found', 404)
    return row


def _apply_credit(db, supplier_id, amount, debts, operator, note='', transfer_id=None):
    """Put `amount` of the supplier's unapplied credit on their open invoices,
    oldest invoice first, oldest transfer's credit first. Each piece is a new
    allocation of the transfer that carried the money plus a re-allocation
    event: nothing new leaves the account (rule R4)."""
    transfers = db.scalars(select(m.SupplierPayment).where(m.SupplierPayment.supplier_id == supplier_id)
        .order_by(m.SupplierPayment.paid_on, m.SupplierPayment.created_at, m.SupplierPayment.id).with_for_update()).all()
    if transfer_id:
        transfers = [row for row in transfers if row.id == transfer_id]
        if not transfers:
            fail('err.transfer_not_found', 404)
    held = tr.buckets(db, [row.id for row in transfers])
    pool = [[row, held[row.id]['credit']] for row in transfers if held[row.id]['credit'] > 0]
    available = sum((credit for _row, credit in pool), ZERO)
    if amount > available:
        fail('err.more_than_supplier_credit', 422, credit=f'{available:,.2f}')
    owed = sum((row.balance for row in debts), ZERO)
    if not debts or amount > owed:
        fail('err.payment_more_than_balance', 422, balance=f'{owed:,.2f}')
    today = c.business_today()
    remaining = amount
    for debt in debts:
        for entry in pool:
            transfer, credit = entry
            take = min(remaining, debt.balance, credit)
            if take <= ZERO:
                continue
            text_ = note or f'From supplier credit (transfer of {transfer.paid_on:%d %b %Y})'
            allocation = record_payment(db, debt, c.LedgerPaymentInput(amount=take, paid_on=today,
                method=transfer.method, reference='', note=text_[:500]), operator, transfer.id)
            db.add(m.TransferEvent(supplier_payment_id=transfer.id, supplier_id=supplier_id, kind='reallocation',
                amount=take, allocation_id=allocation.id, occurred_on=today, reason=note, recorded_by=operator.id))
            entry[1] -= take
            remaining -= take
        if remaining <= ZERO:
            break
    db.flush()
    return amount


@router.post('/ledger/suppliers/{supplier_id}/payments', status_code=201)
def pay_supplier(supplier_id: str, data: c.SupplierPaymentInput, idempotency_key: str = Header(),
                 operator=Depends(auth.ops), db=Depends(database)):
    """One supplier transfer over selected invoices, oldest first. Credit the
    supplier already holds (`use_credit`) is applied first and moves no
    money; only `amount`, the new money, becomes the transfer."""
    _supplier_name, supplier_phone = _supplier_party(db, supplier_id)
    payload = {'supplier_id': supplier_id, **data.model_dump()}
    key, fingerprint, prior = s.replay(db, operator.id, 'supplier-payment', idempotency_key, payload)
    if prior:
        row = db.get(m.SupplierPayment, prior)
        return _result({'id': row.id, 'amount': row.amount, 'credit_used': data.use_credit,
            'receipt_sms_status': row.receipt_sms_status}, 201)
    if data.receipt_media_id:
        asset = db.get(m.MediaAsset, data.receipt_media_id)
        if not asset or asset.owner_id is not None or not asset.content_type.startswith('image/'):
            fail('err.photo_unavailable_upload_own', 422)
    debts = _open_supplier_debts(db, supplier_id, data.debt_ids)
    available = sum((row.balance for row in debts), ZERO)
    if not debts or data.amount + data.use_credit > available:
        fail('err.payment_more_than_balance', 422, balance=f'{available:,.2f}')
    if data.use_credit > 0:
        _apply_credit(db, supplier_id, data.use_credit, debts, operator, data.note.strip())
    group = tr.new_transfer(db, supplier_id, data.amount, data.paid_on, data.method, data.reference, data.note,
        operator.id, 'pay_supplier', data.sms_text, data.receipt_media_id)
    if data.send_receipt_sms:
        group.receipt_sms_language = data.receipt_language
        group.receipt_sms_phone = supplier_phone
        group.receipt_sms_message = supplier_payment_sms.message(data.amount, data.paid_on, data.method,
            data.reference, data.receipt_language, data.include_thank_you)
        supplier_payment_sms.queue(db, group)
        db.flush()
    remaining = data.amount
    for debt in debts:
        amount = min(remaining, debt.balance)
        if amount <= ZERO:
            continue
        allocation = c.LedgerPaymentInput(amount=amount, paid_on=data.paid_on, method=data.method,
            reference='', note=data.note)
        record_payment(db, debt, allocation, operator, group.id)
        remaining -= amount
        if remaining <= ZERO:
            break
    notes.notify(db, supplier_id, 'supplier', 'supplier_payment', M('notify.supplier_payment',
        amount=f'{data.amount:,.0f}'), '/account#payments')
    s.remember(db, key, fingerprint, group.id)
    return _result({'id': group.id, 'amount': group.amount, 'allocated': data.amount, 'credit_used': data.use_credit,
        'receipt_sms_status': group.receipt_sms_status}, 201)


@router.post('/ledger/suppliers/{supplier_id}/credit/apply', status_code=201)
def apply_supplier_credit(supplier_id: str, data: c.SupplierCreditInput, idempotency_key: str = Header(),
                          operator=Depends(auth.ops), db=Depends(database)):
    """Use credit a supplier already holds on their own open invoices. No
    money moves; their statement shows the credit going down."""
    _supplier_party(db, supplier_id)
    key, fingerprint, prior = s.replay(db, operator.id, 'supplier-credit', idempotency_key,
        {'supplier_id': supplier_id, **data.model_dump()})
    if not prior:
        debts = _open_supplier_debts(db, supplier_id, data.debt_ids)
        _apply_credit(db, supplier_id, data.amount, debts, operator, data.note.strip(), data.transfer_id)
        s.remember(db, key, fingerprint, supplier_id)
    return _result(_supplier_credit(db, supplier_id), 201)


@router.post('/ledger/payments/{id}/reverse')
def reverse_payment(id: str, data: c.ReasonInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                    db=Depends(database)):
    """Take a payment off its debt; the debt is owed again.

    A buyer payment, or a payment to someone who is not a registered
    supplier, was recorded in error and simply stops counting. Money paid to
    a registered supplier really left: it stays on its transfer as that
    supplier's credit (rules R1, R4, decision D5), so money out is unchanged
    and the supplier is never shown as owing it back."""
    key, fingerprint, prior = s.replay(db, operator.id, 'ledger-reverse', idempotency_key, {'id': id, **data.model_dump()})
    row = db.get(m.LedgerPayment, id)
    if not row:
        fail('err.payment_not_found', 404)
    debt = _lock_debt(db, row.debt_id)
    if not prior:
        if row.reversed_at is not None:
            fail('err.payment_already_reversed')
        _take_off_invoice(db, debt, row, data.reason, operator)
        debt.status = 'open'
        db.flush()
        s.remember(db, key, fingerprint, id)
    return _result(_debt_detail(db, debt))


def _take_off_invoice(db, debt, row, reason, operator, credit=True):
    """Take one payment off its debt. Money to a registered supplier stays on
    its transfer with the supplier who received it (R1): as their credit, or,
    when `credit` is False, as unresolved until the finance owner classifies
    it with evidence (R6). Returns the transfer, if any."""
    transfer = None
    if row.supplier_payment_id:
        transfer = _lock_transfer(db, row.supplier_payment_id)
    elif debt.direction == 'payable' and debt.supplier_id:
        # Recorded before every supplier payment was a transfer: record
        # the transfer now, so the money stays on the supplier's account.
        transfer = tr.new_transfer(db, debt.supplier_id, row.amount, row.paid_on, row.method, row.reference,
            row.note, row.recorded_by, 'legacy')
        row.supplier_payment_id = transfer.id
    row.reversed_at, row.reversed_by, row.reverse_reason = m.now(), operator.id, reason
    debt.paid_amount -= row.amount
    if transfer is not None and credit:
        db.add(m.TransferEvent(supplier_payment_id=transfer.id, supplier_id=transfer.supplier_id, kind='credit',
            amount=row.amount, source_payment_id=row.id, occurred_on=c.business_today(), reason=reason,
            recorded_by=operator.id))
    return transfer


def _evidence_media(db, media_id):
    if media_id:
        asset = db.get(m.MediaAsset, media_id)
        if not asset or asset.owner_id is not None or not asset.content_type.startswith('image/'):
            fail('err.photo_unavailable_upload_own', 422)


@router.post('/ledger/transfers/{id}/refunds', status_code=201)
def refund_transfer(id: str, data: c.TransferRefundInput, idempotency_key: str = Header(),
                    operator=Depends(auth.ops_admin), db=Depends(database)):
    """Money the supplier really sent back out of their credit: a new, dated
    inflow with evidence. The transfer itself is never reduced (rule R3)."""
    key, fingerprint, prior = s.replay(db, operator.id, 'transfer-refund', idempotency_key, {'id': id, **data.model_dump()})
    transfer = _lock_transfer(db, id)
    if not prior:
        _evidence_media(db, data.receipt_media_id)
        if data.received_on < transfer.paid_on:
            fail('err.refund_before_transfer', 422)
        credit = tr.buckets(db, [id])[id]['credit']
        if data.amount > credit:
            fail('err.more_than_supplier_credit', 422, credit=f'{credit:,.2f}')
        db.add(m.TransferEvent(supplier_payment_id=id, supplier_id=transfer.supplier_id, kind='refund',
            amount=data.amount, occurred_on=data.received_on, method=data.method, reference=data.reference,
            evidence=data.evidence, receipt_media_id=data.receipt_media_id, reason=data.note, recorded_by=operator.id))
        db.flush()
        s.remember(db, key, fingerprint, id)
    return _result(_transfer_detail(db, transfer), 201)


@router.post('/ledger/transfers/{id}/entry-error', status_code=201)
def correct_transfer(id: str, data: c.TransferEntryErrorInput, idempotency_key: str = Header(),
                     operator=Depends(auth.ops_admin), db=Depends(database)):
    """Part of the transfer never left the account (it was typed too high).
    Only credit can be corrected, so move it off its invoice first."""
    key, fingerprint, prior = s.replay(db, operator.id, 'transfer-entry-error', idempotency_key,
        {'id': id, **data.model_dump()})
    transfer = _lock_transfer(db, id)
    if not prior:
        credit = tr.buckets(db, [id])[id]['credit']
        if data.amount > credit:
            fail('err.more_than_supplier_credit', 422, credit=f'{credit:,.2f}')
        db.add(m.TransferEvent(supplier_payment_id=id, supplier_id=transfer.supplier_id, kind='entry_error',
            amount=data.amount, occurred_on=c.business_today(), evidence=data.evidence, reason=data.reason,
            recorded_by=operator.id))
        db.flush()
        s.remember(db, key, fingerprint, id)
    return _result(_transfer_detail(db, transfer), 201)


@router.post('/ledger/debts/{id}/cancel')
def cancel_debt(id: str, data: c.ReasonInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'debt-cancel', idempotency_key, {'id': id, **data.model_dump()})
    debt = _lock_debt(db, id)
    if not prior:
        if debt.source in ('lpo', 'batch_receipt'):
            fail('err.correct_the_receipt_instead')
        if debt.source == 'sale_cost':
            # A sale's supplier debt is corrected with its reason, which keeps
            # the buying cost unless the reason says otherwise (M1.4).
            fail('err.choose_debt_correction')
        if debt.source not in ('manual', 'expense'):
            fail('err.cancel_the_sale_instead')
        if debt.status == 'cancelled':
            fail('err.debt_already_cancelled')
        if debt.paid_amount > 0:
            fail('err.reverse_payments_before_cancelling')
        debt.status, debt.cancelled_at, debt.cancelled_by, debt.cancel_reason = 'cancelled', m.now(), operator.id, data.reason
        s.remember(db, key, fingerprint, id)
    return _result(_debt_detail(db, debt))


# ---- reasoned supplier-debt corrections (build plan M1.4) -------------------

def _plain(value):
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    return value


def _snapshot(row, fields):
    return {field: _plain(getattr(row, field)) for field in fields}


DEBT_FIELDS = ('id', 'supplier_id', 'party_kind', 'party_name', 'amount', 'paid_amount', 'status', 'cancel_reason')
ITEM_FIELDS = ('id', 'supplier_id', 'supplier_name', 'unit_cost', 'cost_total', 'quantity', 'unit')


def _state(debt, sale, lines):
    return {'debt': _snapshot(debt, DEBT_FIELDS), 'sale_cost_amount': _plain(sale.cost_amount),
        'items': [_snapshot(item, ITEM_FIELDS) for item in lines]}


def _debt_lines(db, debt, sale):
    """The sale lines this debt is owed for: costed, direct lines of the
    debt's supplier. Lines from a delivery note or LPO are never touched
    here; their cost and debt belong to the receipt."""
    items = db.scalars(select(m.SaleItem).where(m.SaleItem.sale_id == sale.id)
        .order_by(m.SaleItem.position).with_for_update()).all()
    lines = [item for item in items if item.cost_total is not None and _party_key(item) == _party_key(debt)
             and item.lpo_line_id is None and item.supplier_collection_id is None]
    if not lines:
        fail('err.sale_lines_from_receipt')
    return items, lines


def _release_payments(db, debt, how, reason, operator):
    """Take the money paid on a corrected debt off it. It stays with the
    supplier who received it (R1): their credit, or unresolved (R6). Cash out
    is unchanged and the money never reduces another debt."""
    active = [row for row in _payments(db, debt.id) if row.reversed_at is None]
    if not active:
        return [], []
    if not debt.supplier_id:
        fail('err.unregistered_supplier_paid')
    if how is None:
        fail('err.say_what_paid_money_is', 422)
    transfers = [_take_off_invoice(db, debt, row, reason, operator, credit=how == 'credit') for row in active]
    return [row.id for row in active], sorted({row.id for row in transfers})


@router.post('/ledger/debts/{id}/corrections')
def correct_debt(id: str, data: c.DebtCorrectionInput, idempotency_key: str = Header(),
                 operator=Depends(auth.ops_admin), db=Depends(database)):
    """Correct a supplier debt opened by a sale, for a stated reason. Admins
    only (decision D4 default); each correction writes a financial adjustment
    with the state before and after.

    - wrong_supplier: the whole obligation moves to the correct supplier; the
      buying cost is kept; money paid stays with whoever received it (R1).
    - duplicate_liability: cancelled as a copy of another open debt to the
      same supplier; the buying cost is kept.
    - free_stock: cancelled; the lines' cost becomes a known 0.
    - cost_never_existed: cancelled; the lines' cost becomes unknown, so the
      sale's margin is provisional (R5)."""
    key, fingerprint, prior = s.replay(db, operator.id, 'debt-correction', idempotency_key,
        {'id': id, **data.model_dump()})
    debt = _lock_debt(db, id)
    if not prior:
        if debt.source in ('lpo', 'batch_receipt'):
            fail('err.correct_the_receipt_instead')
        if debt.source != 'sale_cost' or debt.direction != 'payable':
            fail('err.only_sale_supplier_debts_corrected')
        if debt.status == 'cancelled':
            fail('err.debt_already_cancelled')
        sale = db.scalar(select(m.Sale).where(m.Sale.id == debt.sale_id).with_for_update())
        if not sale or sale.status != 'active':
            fail('err.cancel_the_sale_instead')
        items, lines = _debt_lines(db, debt, sale)
        reason = data.reason.strip()
        related, linked, target_before = None, {}, None
        if data.kind == 'wrong_supplier':
            related, target_before = _move_to_supplier(db, debt, sale, lines, data, operator)
            linked = {'new_debt_id': related.id, 'from_supplier_id': debt.supplier_id, 'to_supplier_id': data.supplier_id}
        elif data.kind == 'duplicate_liability':
            related = _lock_debt(db, data.duplicate_of)
            if (related.id == debt.id or related.direction != 'payable' or related.status == 'cancelled'
                    or _party_key(related) != _party_key(debt)):
                fail('err.duplicate_must_be_same_supplier', 422)
            linked = {'duplicate_of': related.id}
        elif debt.paid_amount > 0:
            # Free stock or no cost at all, yet money was paid for it.
            fail('err.paid_debt_cost_kept')
        before = _state(debt, sale, lines)
        payments, transfers = _release_payments(db, debt, data.payments, reason, operator)
        for item in lines:
            if data.kind == 'wrong_supplier':
                item.supplier_id, item.supplier_name = data.supplier_id, '' if data.supplier_id else data.supplier_name
            elif data.kind == 'free_stock':
                # A known zero. M1.3 marks these lines' cost_state 'free'.
                item.unit_cost = item.cost_total = Decimal('0.00')
            elif data.kind == 'cost_never_existed':
                # Unknown again, never zero (R5).
                item.supplier_id, item.supplier_name, item.unit_cost, item.cost_total = None, '', None, None
        sale.cost_amount = sum((item.cost_total or ZERO for item in items), ZERO)
        debt.status, debt.cancelled_at, debt.cancelled_by, debt.cancel_reason = 'cancelled', m.now(), operator.id, reason
        db.flush()
        after = _state(debt, sale, lines)
        if data.kind == 'wrong_supplier':
            before['target'], after['target'] = target_before, _snapshot(related, DEBT_FIELDS)
        db.add(m.FinancialAdjustment(kind=data.kind, entity_type='ledger_debt', entity_id=debt.id, sale_id=sale.id,
            related_debt_id=related.id if related else None, reason=reason, before=before, after=after,
            recorded_by=operator.id, linked_ids={**linked, 'sale_id': sale.id, 'item_ids': [item.id for item in lines],
                'payment_ids': payments, 'transfer_ids': transfers, 'payments_as': data.payments if payments else None}))
        db.flush()
        s.remember(db, key, fingerprint, id)
    return _result(_debt_detail(db, debt))


def _move_to_supplier(db, debt, sale, lines, data, operator):
    """Wrong supplier: the correct supplier is owed the whole debt, on this
    sale. Their open debt here grows, or a new one opens. Never paid by
    money the wrong supplier received (R1)."""
    if any(item.supplier_batch_id for item in lines):
        fail('err.batch_line_wrong_supplier')
    if data.supplier_id:
        name, phone = _supplier_party(db, data.supplier_id)
        party = ('supplier', data.supplier_id)
    else:
        name, phone = data.supplier_name, ''
        party = ('other', data.supplier_name.casefold())
    if party == _party_key(debt):
        fail('err.same_supplier_already', 422)
    target = next((row for row in db.scalars(select(m.LedgerDebt).where(m.LedgerDebt.sale_id == sale.id,
        m.LedgerDebt.direction == 'payable', m.LedgerDebt.status != 'cancelled').with_for_update())
        if _party_key(row) == party), None)
    before = None
    if target is not None:
        before = _snapshot(target, DEBT_FIELDS)
        target.amount += debt.amount
        target.status = 'open'
    else:
        target = m.LedgerDebt(direction='payable', party_kind=party[0], supplier_id=data.supplier_id,
            party_name=name, party_phone=phone, description=debt.description, amount=debt.amount,
            incurred_on=debt.incurred_on, due_on=debt.due_on, source='sale_cost', sale_id=sale.id,
            created_by=operator.id)
        db.add(target)
    db.flush()
    return target, before


# ---- reads ------------------------------------------------------------------

def adjustment_view(db, row):
    return {**{k: getattr(row, k) for k in ('id', 'kind', 'entity_type', 'entity_id', 'sale_id', 'related_debt_id',
        'reason', 'before', 'after', 'linked_ids', 'created_at')}, 'recorded_by': _operator_name(db, row.recorded_by)}


def _duplicate_candidates(db, debt):
    """Other open debts to the same supplier this one might duplicate."""
    query = select(m.LedgerDebt).where(m.LedgerDebt.id != debt.id, m.LedgerDebt.direction == 'payable',
        m.LedgerDebt.status != 'cancelled').order_by(m.LedgerDebt.incurred_on.desc(), m.LedgerDebt.created_at.desc())
    if debt.supplier_id:
        query = query.where(m.LedgerDebt.supplier_id == debt.supplier_id)
    else:
        query = query.where(m.LedgerDebt.supplier_id.is_(None),
            func.lower(m.LedgerDebt.party_name) == debt.party_name.casefold())
    return [{k: getattr(row, k) for k in ('id', 'description', 'amount', 'paid_amount', 'incurred_on', 'source',
        'status')} for row in db.scalars(query.limit(50))]


def _debt_detail(db, debt):
    sale = db.get(m.Sale, debt.sale_id) if debt.sale_id else None
    adjustments = db.scalars(select(m.FinancialAdjustment).where(or_(m.FinancialAdjustment.entity_id == debt.id,
        m.FinancialAdjustment.related_debt_id == debt.id)).order_by(m.FinancialAdjustment.created_at)).all()
    correctable = debt.source == 'sale_cost' and debt.direction == 'payable' and debt.status != 'cancelled'
    return {**debt_view(debt), 'created_by': _operator_name(db, debt.created_by),
        'sale_number': sale.sale_number if sale else None,
        'payments': [payment_view(db, p) for p in _payments(db, debt.id)],
        'adjustments': [adjustment_view(db, row) for row in adjustments],
        'duplicate_candidates': _duplicate_candidates(db, debt) if correctable else []}


def event_view(db, row):
    return {**{k: getattr(row, k) for k in ('id', 'supplier_payment_id', 'kind', 'amount', 'source_payment_id',
        'allocation_id', 'occurred_on', 'method', 'reference', 'evidence', 'reason', 'created_at')},
        'has_receipt': row.receipt_media_id is not None, 'recorded_by': _operator_name(db, row.recorded_by)}


def transfer_view(db, row, held=None):
    held = held or tr.buckets(db, [row.id])[row.id]
    return {**{k: getattr(row, k) for k in ('id', 'supplier_id', 'amount', 'paid_on', 'method', 'reference', 'note',
        'origin', 'created_at')}, **{k: held[k] for k in (*tr.BUCKETS, 'transferred', 'net_paid')},
        'has_receipt': row.receipt_media_id is not None, 'recorded_by': _operator_name(db, row.recorded_by)}


def _transfer_detail(db, row):
    allocations = db.scalars(select(m.LedgerPayment).where(m.LedgerPayment.supplier_payment_id == row.id)
        .order_by(m.LedgerPayment.created_at)).all()
    events = db.scalars(select(m.TransferEvent).where(m.TransferEvent.supplier_payment_id == row.id)
        .order_by(m.TransferEvent.created_at)).all()
    return {**transfer_view(db, row), 'sms_text': row.sms_text,
        'allocations': [payment_view(db, p, db.get(m.LedgerDebt, p.debt_id)) for p in allocations],
        'events': [event_view(db, e) for e in events],
        'unresolved_items': tr.unresolved_items(db, transfer_id=row.id)}


def _supplier_credit(db, supplier_id):
    held = tr.buckets(db, supplier_id=supplier_id)
    rows = db.scalars(select(m.SupplierPayment).where(m.SupplierPayment.id.in_(list(held)))
        .order_by(m.SupplierPayment.paid_on, m.SupplierPayment.created_at)).all() if held else []
    return {'supplier_id': supplier_id,
        'credit': sum((row['credit'] for row in held.values()), ZERO),
        'unresolved': sum((row['unresolved'] for row in held.values()), ZERO),
        'transfers': [transfer_view(db, row, held[row.id]) for row in rows
                      if held[row.id]['credit'] > 0 or held[row.id]['unresolved'] > 0]}


@router.get('/ledger/transfers/{id}')
def transfer(id: str, operator=Depends(auth.ops), db=Depends(database)):
    row = db.get(m.SupplierPayment, id)
    if not row:
        fail('err.transfer_not_found', 404)
    return _result(_transfer_detail(db, row))


@router.get('/ledger/suppliers/{supplier_id}/credit')
def supplier_credit(supplier_id: str, operator=Depends(auth.ops), db=Depends(database)):
    """Unapplied credit this supplier holds, and unresolved history, per transfer."""
    return _result(_supplier_credit(db, supplier_id))


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


def _sales_summary(db, where, q):
    """Totals for the sales a list shows (its dates, buyer and search; every
    status tab): what was sold, received, still owed by buyers and still owed
    to suppliers, with how many sales each covers. Cancelled sales count for
    nothing."""
    chosen = select(m.Sale.id).where(m.Sale.status == 'active', *where)
    if q:
        chosen = chosen.where(SALES.search(q))
    sold, count = db.execute(select(func.coalesce(func.sum(m.Sale.total_amount), 0), func.count())
        .where(m.Sale.id.in_(chosen))).one()
    def owed(direction):
        debts = select(m.LedgerDebt).where(m.LedgerDebt.sale_id.in_(chosen), m.LedgerDebt.direction == direction,
            m.LedgerDebt.status != 'cancelled').subquery()
        paid, balance, sales = db.execute(select(func.coalesce(func.sum(debts.c.paid_amount), 0),
            func.coalesce(func.sum(debts.c.amount - debts.c.paid_amount), 0),
            func.count(func.distinct(debts.c.sale_id)).filter(debts.c.amount > debts.c.paid_amount))).one()
        return paid, balance, sales
    received, buyer_owes, owing_sales = owed('receivable')
    _paid, supplier_owed, supplier_sales = owed('payable')
    return {'sales_total': sold, 'sales_count': count, 'received': received,
            'buyer_owes': buyer_owes, 'buyer_owes_count': owing_sales,
            'supplier_owed': supplier_owed, 'supplier_owed_count': supplier_sales}


@router.get('/sales')
def sales(params: Paging = Depends(), buyer_profile_id: Optional[str] = None, start: Optional[date] = None,
          end: Optional[date] = None, operator=Depends(auth.ops), db=Depends(database)):
    where = [m.Sale.buyer_profile_id == buyer_profile_id] if buyer_profile_id else []
    if start:
        where.append(m.Sale.sold_on >= start)
    if end:
        where.append(m.Sale.sold_on <= end)
    body = paging.page(db, SALES, params, lambda row: sale_view(db, row), where=where)
    body['summary'] = _sales_summary(db, where, params.q)
    return _result(body)


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
          'settled': m.LedgerDebt.status == 'settled', 'cancelled': m.LedgerDebt.status == 'cancelled',
          # Open and past its due date, by the business's own calendar day.
          'overdue': and_(OPEN_DEBT, m.LedgerDebt.due_on < cast(func.timezone('Africa/Dar_es_Salaam', func.now()), Date))},
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


DUE_SOON_DAYS = 7


def _supplier_state(earliest_due, today):
    """Where a supplier's oldest open invoice stands. No due date means it
    is payable on receipt, so it counts as due now."""
    if earliest_due is None or earliest_due == today:
        return 'due_now'
    if earliest_due < today:
        return 'overdue'
    return 'due_soon' if (earliest_due - today).days <= DUE_SOON_DAYS else 'on_track'


@router.get('/ledger/supplier-balances')
def supplier_balances(q: str = Query('', max_length=100), state: str = Query('', max_length=16),
                      page: int = Query(1, ge=1), page_size: int = Query(10, ge=1, le=100),
                      operator=Depends(auth.ops), db=Depends(database)):
    """Every registered supplier with an open balance (direct sales, LPOs,
    collections), most urgent first, with totals for the whole set:
    owed, due now (due today, overdue or without a due date), overdue."""
    today = c.business_today()
    rows = db.execute(select(m.LedgerDebt.supplier_id, func.count(), func.sum(m.LedgerDebt.amount - m.LedgerDebt.paid_amount),
            func.min(m.LedgerDebt.due_on), func.bool_or(m.LedgerDebt.due_on.is_(None)))
        .where(m.LedgerDebt.direction == 'payable', m.LedgerDebt.status == 'open', m.LedgerDebt.supplier_id.is_not(None))
        .group_by(m.LedgerDebt.supplier_id)).all()
    due = dict(db.execute(select(m.LedgerDebt.supplier_id, func.sum(m.LedgerDebt.amount - m.LedgerDebt.paid_amount))
        .where(m.LedgerDebt.direction == 'payable', m.LedgerDebt.status == 'open', m.LedgerDebt.supplier_id.is_not(None),
               or_(m.LedgerDebt.due_on.is_(None), m.LedgerDebt.due_on <= today)).group_by(m.LedgerDebt.supplier_id)).all())
    late = dict(db.execute(select(m.LedgerDebt.supplier_id, func.sum(m.LedgerDebt.amount - m.LedgerDebt.paid_amount))
        .where(m.LedgerDebt.direction == 'payable', m.LedgerDebt.status == 'open', m.LedgerDebt.supplier_id.is_not(None),
               m.LedgerDebt.due_on < today).group_by(m.LedgerDebt.supplier_id)).all())
    credit = tr.credit_by_supplier(db)
    suppliers = []
    for supplier_id, invoices, owed, earliest, undated in rows:
        profile = db.get(m.SupplierProfile, supplier_id)
        user = db.get(m.User, supplier_id)
        # The last money sent: a transfer, or a payment from before transfers.
        candidates = [db.execute(select(m.SupplierPayment.paid_on, m.SupplierPayment.amount, m.SupplierPayment.created_at)
            .where(m.SupplierPayment.supplier_id == supplier_id)
            .order_by(m.SupplierPayment.paid_on.desc(), m.SupplierPayment.created_at.desc()).limit(1)).first(),
            db.execute(select(m.LedgerPayment.paid_on, m.LedgerPayment.amount, m.LedgerPayment.created_at).join(
                m.LedgerDebt, m.LedgerDebt.id == m.LedgerPayment.debt_id)
            .where(m.LedgerDebt.supplier_id == supplier_id, m.LedgerDebt.direction == 'payable',
                   m.LedgerPayment.supplier_payment_id.is_(None), m.LedgerPayment.reversed_at.is_(None))
            .order_by(m.LedgerPayment.paid_on.desc(), m.LedgerPayment.created_at.desc()).limit(1)).first()]
        last = max((row for row in candidates if row), key=lambda row: (row[0], row[2]), default=None)
        # The earliest dated invoice; overdue money outranks an undated one.
        first_due = earliest
        place = ', '.join(part for part in ((profile.district if profile else ''), (profile.region if profile else user.region if user else '')) if part)
        suppliers.append({'supplier_id': supplier_id,
            'name': (profile.legal_name or profile.public_alias) if profile else (user.name if user else ''),
            'alias': profile.public_alias if profile else '', 'phone': user.phone if user else '', 'place': place,
            'open_invoices': invoices, 'owed': owed, 'due_now': due.get(supplier_id, ZERO), 'overdue': late.get(supplier_id, ZERO),
            'credit': credit.get(supplier_id, ZERO),
            'earliest_due': first_due,
            'state': 'overdue' if late.get(supplier_id, ZERO) > 0 else 'due_now' if undated else _supplier_state(first_due, today),
            'last_payment': {'paid_on': last[0], 'amount': last[1]} if last else None})
    rank = {'overdue': 0, 'due_now': 1, 'due_soon': 2, 'on_track': 3}
    suppliers.sort(key=lambda row: (rank[row['state']], row['earliest_due'] or today, -row['owed']))
    summary = {'total_owed': sum((row['owed'] for row in suppliers), ZERO), 'suppliers': len(suppliers),
        'due_now': sum((row['due_now'] for row in suppliers), ZERO), 'due_now_suppliers': sum(1 for row in suppliers if row['due_now'] > 0),
        'overdue': sum((row['overdue'] for row in suppliers), ZERO), 'overdue_suppliers': sum(1 for row in suppliers if row['overdue'] > 0),
        'total_suppliers': db.scalar(select(func.count()).select_from(m.SupplierProfile)) or 0,
        # Money suppliers hold from payments taken off invoices: shown beside
        # what is owed, never netted against it.
        'credit': sum(credit.values(), ZERO), 'credit_suppliers': len(credit)}
    if q.strip():
        needle = q.strip().casefold()
        suppliers = [row for row in suppliers if needle in ' '.join((row['name'], row['alias'], row['phone'], row['place'])).casefold()]
    if state in rank:
        suppliers = [row for row in suppliers if row['state'] == state]
    start = (page - 1) * page_size
    return _result({'items': suppliers[start:start + page_size], 'total': len(suppliers), 'page': page,
        'page_size': page_size, 'actionable': 0, 'summary': summary})


@router.get('/ledger/suppliers/{supplier_id}/statement')
def supplier_statement(supplier_id: str, operator=Depends(auth.ops), db=Depends(database)):
    """Everything bought from one supplier outside app orders (direct sales,
    LPO receipts, collections) and every transfer made to them, newest first.

    bought / paid / owed come from the invoices (cancelled ones left out):
    `paid` is what is allocated to their invoices. The money side comes from
    the transfers: transferred = allocated + credit + refunded + unresolved
    (entry errors are not money that moved). Payments from before every
    supplier payment was a transfer are listed as `single`."""
    debts = db.scalars(select(m.LedgerDebt).where(m.LedgerDebt.supplier_id == supplier_id,
        m.LedgerDebt.direction == 'payable', m.LedgerDebt.status != 'cancelled')
        .order_by(m.LedgerDebt.incurred_on.desc(), m.LedgerDebt.created_at.desc())).all()
    sale_numbers = dict(db.execute(select(m.Sale.id, m.Sale.sale_number)
        .where(m.Sale.id.in_([row.sale_id for row in debts if row.sale_id]))).all())
    held = tr.buckets(db, supplier_id=supplier_id)
    payments = []
    for row in db.scalars(select(m.SupplierPayment).where(m.SupplierPayment.supplier_id == supplier_id)):
        events = db.scalars(select(m.TransferEvent).where(m.TransferEvent.supplier_payment_id == row.id)
            .order_by(m.TransferEvent.created_at)).all()
        payments.append({**transfer_view(db, row, held[row.id]), 'kind': 'transfer', 'debt_id': None,
            'events': [event_view(db, e) for e in events]})
    legacy = db.scalars(select(m.LedgerPayment).where(m.LedgerPayment.debt_id.in_([row.id for row in debts]),
        m.LedgerPayment.supplier_payment_id.is_(None), m.LedgerPayment.reversed_at.is_(None))).all()
    for row in legacy:
        # Paid on one invoice before transfers: its own line in the history.
        payments.append({'id': row.id, 'kind': 'single', 'origin': 'legacy', 'amount': row.amount,
            'allocated': row.amount, 'credit': ZERO, 'refunded': ZERO, 'entry_error': ZERO, 'unresolved': ZERO,
            'transferred': row.amount, 'net_paid': row.amount, 'paid_on': row.paid_on, 'method': row.method,
            'reference': row.reference, 'note': row.note, 'debt_id': row.debt_id, 'created_at': row.created_at,
            'events': []})
    payments.sort(key=lambda row: (row['paid_on'], row['created_at']), reverse=True)
    money = {key: sum((row[key] for row in held.values()), ZERO) for key in (*tr.BUCKETS, 'transferred', 'net_paid')}
    unwrapped = sum((row.amount for row in legacy), ZERO)
    return _result({
        'bought': sum((row.amount for row in debts), ZERO),
        'paid': sum((row.paid_amount for row in debts), ZERO),
        'owed': sum((row.balance for row in debts), ZERO),
        'open_count': sum(1 for row in debts if row.status == 'open'),
        # Money sent: transfers (less entry errors) plus older single payments.
        'transferred': money['transferred'] + unwrapped,
        'allocated': money['allocated'] + unwrapped,
        'credit': money['credit'], 'refunded': money['refunded'], 'entry_error': money['entry_error'],
        'unresolved': money['unresolved'], 'net_paid': money['net_paid'] + unwrapped,
        'without_transfer': unwrapped,
        'unresolved_items': tr.unresolved_items(db, supplier_id=supplier_id),
        'debts': [{**debt_view(row), 'sale_number': sale_numbers.get(row.sale_id)} for row in debts],
        'payments': payments,
    })


def _cash_movements():
    """Every movement of money the ledger knows, one row each (rule R3):

    - payments in from buyers and others (receivable installments);
    - payments out with no transfer: to unregistered parties, expenses, and
      supplier payments from before transfers existed;
    - supplier transfers, once each at what really left (less entry errors),
      however many invoices they pay;
    - refunds from suppliers: separate dated inflows;
    - reversed installments, kept for the history. They count for nothing:
      a reversed supplier allocation moved to credit, so its money is still
      in its transfer's row (rule R4).

    `flow` is 'in' or 'out'; `kind` is payment, allocation (a reversed one),
    transfer or refund."""
    P, D, T, E, U, S = m.LedgerPayment, m.LedgerDebt, m.SupplierPayment, m.TransferEvent, m.User, m.SupplierProfile
    text_ = lambda value: cast(literal(value), Text)
    nothing = lambda kind: cast(null(), kind)
    supplier = func.coalesce(func.nullif(S.legal_name, ''), func.nullif(U.name, ''), U.phone)
    payments = (select(P.id.label('id'),
            case((P.supplier_payment_id.is_(None), text_('payment')), else_=text_('allocation')).label('kind'),
            case((D.direction == 'receivable', text_('in')), else_=text_('out')).label('flow'),
            P.paid_on.label('paid_on'), P.amount.label('amount'), P.method.label('method'),
            P.reference.label('reference'), P.note.label('note'), D.party_name.label('party_name'),
            D.description.label('description'), P.debt_id.label('debt_id'), D.sale_id.label('sale_id'),
            D.supplier_id.label('supplier_id'), P.supplier_payment_id.label('transfer_id'),
            cast(literal(1), Integer).label('invoices'), P.created_at.label('created_at'),
            P.recorded_by.label('recorded_by'), P.reversed_at.label('reversed_at'), P.reversed_by.label('reversed_by'),
            P.reverse_reason.label('reverse_reason'))
        .join(D, D.id == P.debt_id)
        .where(or_(P.supplier_payment_id.is_(None), P.reversed_at.is_not(None))))
    corrected = (select(func.coalesce(func.sum(E.amount), 0)).where(E.supplier_payment_id == T.id,
        E.kind == 'entry_error').correlate(T).scalar_subquery())
    def first(column):
        """From the first invoice the transfer paid: what it was for."""
        return (select(column).select_from(P).join(D, D.id == P.debt_id).where(P.supplier_payment_id == T.id)
            .order_by(P.created_at).limit(1).correlate(T).scalar_subquery())
    invoices = (select(func.count(func.distinct(P.debt_id))).where(P.supplier_payment_id == T.id,
        P.reversed_at.is_(None)).correlate(T).scalar_subquery())
    transfers = (select(T.id, text_('transfer'), text_('out'), T.paid_on, (T.amount - corrected), T.method,
            T.reference, T.note, supplier,
            first(D.description), first(D.id), first(D.sale_id),
            T.supplier_id, T.id, invoices, T.created_at, T.recorded_by,
            nothing(m.LedgerPayment.reversed_at.type), nothing(String(36)), text_(''))
        .join(U, U.id == T.supplier_id).outerjoin(S, S.user_id == T.supplier_id)
        .where(T.amount - corrected > 0))
    refunds = (select(E.id, text_('refund'), text_('in'), E.occurred_on, E.amount, E.method, E.reference,
            E.reason, supplier, text_('Refund from supplier'), nothing(String(36)), nothing(String(36)),
            E.supplier_id, E.supplier_payment_id, cast(literal(0), Integer), E.created_at, E.recorded_by,
            nothing(m.LedgerPayment.reversed_at.type), nothing(String(36)), text_(''))
        .join(U, U.id == E.supplier_id).outerjoin(S, S.user_id == E.supplier_id)
        .where(E.kind == 'refund'))
    return union_all(payments, transfers, refunds).subquery('cash_movements')


CASH = _cash_movements()
COUNTED = CASH.c.reversed_at.is_(None)
PAYMENTS = Spec(CASH, (CASH.c.paid_on.desc(), CASH.c.created_at.desc(), CASH.c.id.desc()),
    lambda q: paging.matches(q, CASH.c.party_name, CASH.c.reference, CASH.c.note, CASH.c.description),
    tabs={'in': and_(COUNTED, CASH.c.flow == 'in'), 'out': and_(COUNTED, CASH.c.flow == 'out'),
          'reversed': CASH.c.reversed_at.is_not(None)},
    rows=True)


def _moved(db, *conditions):
    """Money in and out over the counted movements matching the conditions."""
    rows = db.execute(select(CASH.c.flow, func.coalesce(func.sum(CASH.c.amount), 0))
        .where(COUNTED, *conditions).group_by(CASH.c.flow)).all()
    totals = {flow: amount for flow, amount in rows}
    return totals.get('in', ZERO), totals.get('out', ZERO)


def _cash_totals(db, where, q):
    """Money in and out for the movements a cash book view shows (its dates,
    method and search), and cash in hand: every cash movement in minus every
    cash movement out, all time. Supplier transfers count once each; a
    payment moved to supplier credit is still money out (rule R4)."""
    chosen = [*where, PAYMENTS.search(q)] if q else list(where)
    money_in, money_out = _moved(db, *chosen)
    cash_in, cash_out = _moved(db, CASH.c.method == 'cash')
    return {'money_in': money_in, 'money_out': money_out, 'net': money_in - money_out,
            'cash_in_hand': cash_in - cash_out}


def movement_view(db, row):
    view = dict(row._mapping)
    view['direction'] = 'receivable' if view['flow'] == 'in' else 'payable'
    view['reversed'] = view['reversed_at'] is not None
    view['moved_to_credit'] = view['reversed'] and view['kind'] == 'allocation'
    view['recorded_by'] = _operator_name(db, view['recorded_by'])
    view['reversed_by'] = _operator_name(db, view['reversed_by'])
    return view


@router.get('/ledger/payments')
def cash_book(params: Paging = Depends(), start: Optional[date] = None, end: Optional[date] = None,
              method: Optional[str] = None, operator=Depends(auth.ops), db=Depends(database)):
    """Every movement of money in and out, newest first: the cash book."""
    where = []
    if start:
        where.append(CASH.c.paid_on >= start)
    if end:
        where.append(CASH.c.paid_on <= end)
    if method:
        where.append(CASH.c.method == method)
    body = paging.page(db, PAYMENTS, params, lambda row: movement_view(db, row), where=where)
    body['summary'] = _cash_totals(db, where, params.q)
    return _result(body)


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


def _sold(db, *conditions):
    return db.scalar(select(func.coalesce(func.sum(m.Sale.total_amount), 0))
        .where(m.Sale.status == 'active', *conditions)) or ZERO


def _trends(db, today, days=30):
    """Daily figures for the last `days` days, oldest first, for the overview's
    small charts: what buyers owed and what Omoterra owed at the end of each
    day (from debts and their payment dates), and each day's revenue and net
    profit. Cancelled debts and reversed payments are left out."""
    start = today - timedelta(days=days - 1)
    def balances(direction):
        live = and_(m.LedgerDebt.direction == direction, m.LedgerDebt.status != 'cancelled')
        owed = dict(db.execute(select(m.LedgerDebt.incurred_on, func.sum(m.LedgerDebt.amount)).where(live)
            .group_by(m.LedgerDebt.incurred_on)).all())
        paid = dict(db.execute(select(m.LedgerPayment.paid_on, func.sum(m.LedgerPayment.amount))
            .join(m.LedgerDebt, m.LedgerDebt.id == m.LedgerPayment.debt_id)
            .where(live, m.LedgerPayment.reversed_at.is_(None)).group_by(m.LedgerPayment.paid_on)).all())
        balance = sum((v for d, v in owed.items() if d < start), ZERO) - sum((v for d, v in paid.items() if d < start), ZERO)
        series = []
        for n in range(days):
            d = start + timedelta(n)
            balance += owed.get(d, ZERO) - paid.get(d, ZERO)
            series.append(balance)
        return series
    profit = sorted(profit_between(db, start, today)['days'], key=lambda row: row['date'])
    return {'owed_to_me': balances('receivable'), 'i_owe': balances('payable'),
            'revenue': [row['revenue'] for row in profit], 'net_profit': [row['net_profit'] for row in profit]}


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
    for method, flow, amount in db.execute(select(CASH.c.method, CASH.c.flow, func.sum(CASH.c.amount))
            .where(COUNTED).group_by(CASH.c.method, CASH.c.flow)):
        by_method[method][flow] += amount
    def moved(*conditions):
        money_in, money_out = _moved(db, *conditions)
        return {'money_in': money_in, 'money_out': money_out}
    recent = db.scalars(select(m.LedgerPayment).order_by(m.LedgerPayment.created_at.desc()).limit(15)).all()
    return _result({
        'today': {'date': today, 'sales': _sold(db, m.Sale.sold_on == today),
                  'sales_count': db.scalar(select(func.count()).where(m.Sale.status == 'active', m.Sale.sold_on == today)),
                  **moved(CASH.c.paid_on == today)},
        'month': {'start': month, 'sales': _sold(db, m.Sale.sold_on >= month), **moved(CASH.c.paid_on >= month)},
        'all_time': {'sales': _sold(db), **moved()},
        'profit_today': {k: v for k, v in profit_between(db, today, today).items() if k != 'days'},
        'profit_month': {k: v for k, v in profit_between(db, month, today).items() if k != 'days'},
        'owed_to_me': {'ledger': owed_to_me, 'marketplace': market_owed, 'total': owed_to_me + market_owed,
                       'overdue': sum((p['overdue'] for p in debtors), ZERO)},
        'i_owe': {'ledger': i_owe, 'marketplace': market_payouts, 'total': i_owe + market_payouts,
                  'overdue': sum((p['overdue'] for p in creditors), ZERO)},
        'by_method': [{'method': k, **v, 'net': v['in'] - v['out']} for k, v in sorted(by_method.items())],
        'debtors': debtors[:100], 'creditors': creditors[:100],
        'recent_payments': [payment_view(db, p, db.get(m.LedgerDebt, p.debt_id)) for p in recent],
        'trends': _trends(db, today),
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
    # Money over every row the list pages through (same dates, category, sale,
    # search and status tab), not just this page. `total` stays the row count.
    # Cancelled expenses are listed but never count as money spent.
    matching = paging.filtered(DEBTS, params, where=where).where(m.LedgerDebt.status != 'cancelled')
    rows = db.execute(matching.with_only_columns(m.LedgerDebt.expense_category, func.sum(m.LedgerDebt.amount),
        func.sum(m.LedgerDebt.paid_amount)).group_by(m.LedgerDebt.expense_category)).all()
    body['by_category'] = sorted(({'category': k, 'amount': a, 'paid': p, 'owed': a - p} for k, a, p in rows),
        key=lambda r: -r['amount'])
    incurred, paid = (sum((r[key] for r in body['by_category']), ZERO) for key in ('amount', 'paid'))
    body['summary'] = {'incurred': incurred, 'paid': paid, 'outstanding': incurred - paid}
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


@router.get('/finance/reports')
def financial_report(start: date, end: date,
                     fixed: Optional[Decimal] = Query(None, ge=0, le=1000000000000),
                     variable_pct: Optional[Decimal] = Query(None, ge=0, le=100),
                     growth_pct: Decimal = Query(Decimal('0'), ge=-50, le=50),
                     investment: Optional[Decimal] = Query(None, ge=0, le=1000000000000),
                     reviewed: bool = False, operator=Depends(auth.ops)):
    """A single consistent read snapshot. Read-only; no forecast changes books."""
    from datetime import datetime, timezone
    from sqlalchemy import text
    from .db import Session, engine
    from .report_analysis import project
    today = c.business_today()
    if start > end or end > today or (end - start).days > 365:
        fail('err.choose_period_up_to_a_year', 422)
    with Session(bind=engine.execution_options(isolation_level='REPEATABLE READ')) as db, db.begin():
        db.execute(text('SET TRANSACTION READ ONLY'))
        actual = profit_between(db, start, end)
        previous_end = start - timedelta(days=1)
        days = (end - start).days + 1
        previous = profit_between(db, start - timedelta(days=days), previous_end)
        where = (m.Sale.status == 'active', m.Sale.sold_on >= start, m.Sale.sold_on <= end)
        rows = db.execute(select(m.SaleItem.category, func.sum(m.SaleItem.subtotal),
            func.sum(m.SaleItem.cost_total), func.count().filter(m.SaleItem.cost_total.is_(None)),
            func.count()).join(m.Sale, m.Sale.id == m.SaleItem.sale_id).where(*where)
            .group_by(m.SaleItem.category)).all()
        products = [{'category': category or 'other', 'revenue': revenue, 'known_cost': cost or ZERO,
                     'unknown_lines': unknown, 'lines': count,
                     'gross_margin': None if unknown else revenue - (cost or ZERO)}
                    for category, revenue, cost, unknown, count in rows]
        unknown = sum(r['unknown_lines'] for r in products)
        active_days = sum(d['revenue'] > 0 for d in actual['days'])
        issues = []
        if unknown:
            issues.append(f'{unknown} sale lines have no recorded buying cost. Complete their costs before forecasting.')
        if days < 60 or active_days < 10:
            issues.append('Use at least 60 calendar days with sales on at least 10 days. This is a minimum screening rule, not a confidence guarantee.')
        if actual['revenue'] <= 0:
            issues.append('No positive sales baseline is available for this period.')
        if actual['marketplace_sales'] > 0:
            issues.append('Marketplace revenue currently uses order creation dates after delivery. Forecasts are withheld until recognition dates are reconciled.')
        if (today - end).days > 31:
            issues.append('The report ends more than 31 days ago. Choose a recent period for a forward projection.')
        if fixed is None or variable_pct is None or not reviewed:
            issues.append('Enter monthly fixed costs and other variable costs, then confirm that you reviewed the assumptions and source records.')
        notes = [
            'Management report of recorded activity, not reconciled statutory accounts. Missing expenses, opening stock costs and historical corrections can change these results.',
            'Revenue covers active direct sales and delivered/completed marketplace orders. Marketplace activity is grouped by order creation date under the existing reporting policy.',
            'Expenses include recorded expense debts, whether paid or unpaid, plus recorded LPO stock losses. Collection losses, depreciation, tax and financing are not comprehensively captured.',
            'Product analysis covers direct sales only. Unknown costs are never shown as a final product margin.',
            'Forecasts are conditional operating scenarios, not cash forecasts. They assume constant selling prices, product mix and stock-cost ratios, with enough supply and delivery capacity.',
            'Investment recovery means future cumulative operating earnings reach the entered unrecovered amount; it is not a cash payback or guaranteed date.',
            'Lower/higher cases change sales by -20%/+20% at the same cost ratios and fixed overhead. These are sensitivity assumptions, not statistical confidence intervals.',
        ]
        forecast = None if issues else project(revenue=actual['revenue'],
            stock_cost=actual['stock_cost'] + actual['marketplace_cost'], losses=actual['stock_lost'],
            days=days, end=end, fixed=fixed, variable_pct=variable_pct,
            growth_pct=growth_pct, investment=investment)
        suggestions = []
        if unknown:
            suggestions.append({'title': 'Complete buying costs first', 'evidence': f'{unknown} direct-sale lines are uncosted.',
                'action': 'Match these sales to supplier receipts. Do not use their apparent margin to justify expansion.', 'priority': 'Data quality'})
        for row in sorted(products, key=lambda r: r['gross_margin'] if r['gross_margin'] is not None else ZERO)[:3]:
            if row['gross_margin'] is not None and row['gross_margin'] < 0:
                suggestions.append({'title': f'Review {row["category"].replace("_", " ")} pricing',
                    'evidence': f'Recorded gross loss: TZS {-row["gross_margin"]:,.2f}, before overhead.',
                    'action': 'Check buying price, selling price and unit quantities before purchasing more of this product.', 'priority': 'Protect margin'})
        if actual['expenses_by_category']:
            top = actual['expenses_by_category'][0]
            suggestions.append({'title': f'Review {top["category"].replace("_", " ")} spending',
                'evidence': f'Largest recorded expense category: TZS {top["amount"]:,.2f}.',
                'action': 'Compare supplier quotes and cost per fulfilled order. A large expense is not automatically waste.', 'priority': 'Cost review'})
        if actual['stock_lost'] > 0:
            suggestions.append({'title': 'Investigate stock losses', 'evidence': f'Recorded loss cost: TZS {actual["stock_lost"]:,.2f}.',
                'action': 'Identify causes before choosing handling, veterinary care or storage investment. Compare the proposed cost with avoidable losses.', 'priority': 'Protect stock'})
        candidates = [p for p in products if p['gross_margin'] is not None and p['gross_margin'] > 0 and p['lines'] >= 5]
        if candidates and not issues:
            best = max(candidates, key=lambda p: p['gross_margin'])
            suggestions.append({'title': f'Evaluate a small {best["category"].replace("_", " ")} growth trial',
                'evidence': f'TZS {best["gross_margin"]:,.2f} recorded gross contribution across {best["lines"]} sale lines; shared overhead is not allocated.',
                'action': 'Validate repeat demand, supplier capacity, collections and delivery costs. Set a capped trial budget only after cash reconciliation; gross contribution alone does not establish investment return.', 'priority': 'Growth candidate'})
        else:
            suggestions.append({'title': 'Validate growth before committing capital',
                'evidence': 'The current evidence does not support a reliable investment allocation.',
                'action': 'Complete costs and reconcile cash, then collect repeat-demand and capacity evidence. No investment amount is recommended from incomplete data.', 'priority': 'Growth readiness'})
        return _result({'generated_at': datetime.now(timezone.utc), 'model_version': 'operating-scenarios-v1',
            'actual': actual, 'previous': previous, 'products': products, 'unknown_cost_lines': unknown,
            'active_sales_days': active_days, 'history_days': days, 'limitations': notes,
            'forecast_blockers': issues, 'forecast': forecast, 'suggestions': suggestions,
            'assumptions': {'fixed': fixed, 'variable_pct': variable_pct, 'growth_pct': growth_pct,
                            'investment': investment, 'reviewed': reviewed},
            'methodology_url': 'https://www.sba.gov/counseling/plan-your-business/'})
