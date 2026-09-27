"""Local purchase orders (LPOs): what Omoterra commits to buy from a supplier.

    draft ──(admin issues: number, signature, stamp)──> issued ──(supplier
    signs)──> accepted ──> closed          (draft / unused LPO ──> cancelled)

- Staff draft LPOs, usually from the most urgent buyer demand (`/lpos/demand`
  ranks open requirements by date needed and shortfall, and suggests
  suppliers). A draft has a placeholder number; the LPO number is given at
  issue, so issued numbers run without gaps.
- Only an admin issues. Issuing freezes the content and the supplier details
  as printed, and records which stamp and which signature (the issuing
  admin's) were put on it. Replacing the stamp later never changes an issued
  LPO.
- Each batch received is a receipt: delivered, accepted and rejected per
  line. Its accepted value opens a supplier payable in the ledger (source
  'lpo'), due `payment_terms_days` after receipt; payment then goes through
  the ledger like any other debt.
- Accepted birds are stock. Sales take from it (sale_items.lpo_line_id) and
  losses are recorded against it: accepted = sold + lost + on hand.
"""
from __future__ import annotations

import re
from datetime import date, timedelta
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, File, Header, Query, UploadFile
from fastapi.concurrency import run_in_threadpool
from sqlalchemy import Text, cast, func, or_, select

from . import auth, contracts as c, finance, models as m, notifications as notes, paging, services as s
from .config import settings
from .db import database
from .i18n import M, fail
from .media import save_photo, signed_link
from .paging import Paging, Spec

router = APIRouter(prefix='/api/v1/ops')
ZERO = Decimal('0')
ACTIVE = ('issued', 'accepted')
DEMAND_DONE = ('completed', 'cancelled', 'converted')

DEFAULT_DELIVERY_NOTES = [
    'Supply to be made in batches during {window} as scheduled by Omoterra.',
    'Collection or handover point: {collection_point}, unless otherwise agreed.',
    'Each batch is subject to verification of count, live condition, and target weight compliance.',
]
DEFAULT_TERMS = [
    'This LPO is issued on a call off basis and does not guarantee a minimum purchase quantity.',
    'Omoterra may accept or reject any batch or part of a batch that does not meet agreed quality, health, or weight requirements.',
    'Final payment shall be based only on quantities accepted after inspection.',
    'Unit price applies only to birds meeting the agreed target weight range and condition.',
    'Delivery dates and batch sizes may be adjusted by mutual agreement based on operational needs.',
    'This LPO does not create exclusivity and applies only to the specified delivery window unless extended in writing.',
    'Any quantity not delivered and accepted by {delivery_end} shall be deemed void and shall not carry forward, unless both '
    'parties agree in writing to an extension. The Buyer may cancel any unfulfilled portion of this LPO by written notice if '
    'the Supplier fails to deliver a scheduled batch, without penalty or compensation owed to the Supplier for undelivered quantities.',
    'Neither party shall be liable for delay or failure to perform due to circumstances beyond its reasonable control, including '
    'but not limited to disease outbreak, transport disruption, or natural disaster (force majeure). The affected party must '
    'notify the other party promptly.',
]


def _result(value, status_code=200):
    from .main import result
    return result(value, status_code)


def _long_date(value):
    return f'{value.day} {value:%B %Y}'


def _window(start, end):
    return _long_date(start) if start == end else (
        f'{start.day} to {_long_date(end)}' if (start.year, start.month) == (end.year, end.month)
        else f'{_long_date(start)} to {_long_date(end)}')


# ---- suppliers, marks, numbering --------------------------------------------

def supplier_snapshot(db, supplier_id):
    user = db.get(m.User, supplier_id)
    profile = db.get(m.SupplierProfile, supplier_id)
    if not user or user.deleted or 'supplier' not in (user.roles or []) or not profile:
        fail('err.choose_registered_supplier', 422)
    farm = ', '.join(part for part in (profile.general_area, profile.district, profile.region) if part)
    return {'name': profile.legal_name or user.name, 'alias': profile.public_alias if profile.alias_approved else (user.name or ''),
        'phone': user.phone, 'district': profile.district, 'region': profile.region or user.region,
        'farm_address': profile.internal_pickup_address or farm,
        'category': profile.primary_category or ((profile.categories or [''])[0]),
        'status': profile.status}


def live_mark(db, kind, operator_id=None):
    query = select(m.DocumentMark).where(m.DocumentMark.kind == kind, m.DocumentMark.retired_at.is_(None))
    if kind == 'signature':
        query = query.where(m.DocumentMark.operator_id == operator_id)
    return db.scalar(query)


def next_number(db, year):
    prefix = f'LPO-OMO-{year}-'
    used = db.scalars(select(m.Lpo.lpo_number).where(m.Lpo.lpo_number.like(prefix + '%'))).all()
    numbers = [int(n[len(prefix):]) for n in used if re.fullmatch(r'\d+', n[len(prefix):])]
    return f'{prefix}{(max(numbers) + 1) if numbers else 1:04d}'


# ---- stock ------------------------------------------------------------------

def line_stock(db, line_id):
    accepted = db.scalar(select(func.coalesce(func.sum(m.LpoReceiptLine.accepted_quantity), 0))
        .join(m.LpoReceipt, m.LpoReceipt.id == m.LpoReceiptLine.receipt_id)
        .where(m.LpoReceiptLine.lpo_line_id == line_id, m.LpoReceipt.cancelled_at.is_(None))) or ZERO
    rejected = db.scalar(select(func.coalesce(func.sum(m.LpoReceiptLine.rejected_quantity), 0))
        .join(m.LpoReceipt, m.LpoReceipt.id == m.LpoReceiptLine.receipt_id)
        .where(m.LpoReceiptLine.lpo_line_id == line_id, m.LpoReceipt.cancelled_at.is_(None))) or ZERO
    sold = db.scalar(select(func.coalesce(func.sum(m.SaleItem.quantity), 0))
        .join(m.Sale, m.Sale.id == m.SaleItem.sale_id)
        .where(m.SaleItem.lpo_line_id == line_id, m.Sale.status == 'active')) or ZERO
    lost = db.scalar(select(func.coalesce(func.sum(m.StockLoss.quantity), 0))
        .where(m.StockLoss.lpo_line_id == line_id, m.StockLoss.cancelled_at.is_(None))) or ZERO
    return {'accepted': accepted, 'rejected': rejected, 'sold': sold, 'lost': lost, 'on_hand': accepted - sold - lost}


def take_stock(db, line_id, quantity, taken=ZERO):
    """For a sale line: the LPO line, locked, after checking enough is on hand."""
    line = db.scalar(select(m.LpoLine).where(m.LpoLine.id == line_id).with_for_update())
    if not line:
        fail('err.lpo_stock_not_found', 404)
    lpo = db.get(m.Lpo, line.lpo_id)
    if lpo.status not in (*ACTIVE, 'closed'):
        fail('err.lpo_stock_not_found', 404)
    on_hand = line_stock(db, line.id)['on_hand'] - taken
    if quantity > on_hand:
        fail('err.not_enough_lpo_stock', 422, available=s.quantity(on_hand))
    return line, lpo


# ---- views ------------------------------------------------------------------

def display_status(lpo):
    if lpo.status in ACTIVE and lpo.delivery_end < c.business_today():
        return 'expired'
    return lpo.status


def lpo_view(db, lpo, detail=False):
    lines = db.scalars(select(m.LpoLine).where(m.LpoLine.lpo_id == lpo.id).order_by(m.LpoLine.position)).all()
    debts = db.scalars(select(m.LedgerDebt).where(m.LedgerDebt.lpo_id == lpo.id, m.LedgerDebt.status != 'cancelled')).all()
    view = {**{k: getattr(lpo, k) for k in ('id', 'lpo_number', 'supplier_id', 'supplier_snapshot', 'demand_id', 'lpo_date',
        'delivery_start', 'delivery_end', 'payment_terms_days', 'supply_basis', 'collection_point', 'delivery_notes',
        'terms', 'status', 'created_at', 'issued_at', 'issuer_name', 'issuer_position', 'supplier_accepted_at',
        'supplier_accepted_name', 'supplier_accepted_position', 'signed_copy_media_id', 'closed_at', 'close_reason')},
        'display_status': display_status(lpo),
        'created_by': finance._operator_name(db, lpo.created_by),
        'stamped': lpo.stamp_mark_id is not None and lpo.status not in ('draft', 'cancelled'),
        'received_value': sum((d.amount for d in debts), ZERO),
        'paid_value': sum((d.paid_amount for d in debts), ZERO),
        'owed_value': sum((d.balance for d in debts), ZERO),
        'lines': []}
    for line in lines:
        row = {k: getattr(line, k) for k in ('id', 'position', 'category', 'item', 'specification', 'unit', 'unit_price',
            'quantity', 'min_weight_kg', 'max_weight_kg')}
        if lpo.status != 'draft':
            row['stock'] = line_stock(db, line.id)
            row['outstanding'] = max(ZERO, line.quantity - row['stock']['accepted']) if line.quantity else None
        view['lines'].append(row)
    if detail:
        view['internal_notes'] = lpo.internal_notes
        view['demand'] = None
        if lpo.demand_id:
            demand = db.get(m.SourcingRequest, lpo.demand_id)
            view['demand'] = {'id': demand.id, 'requirement_number': demand.requirement_number, 'category': demand.category,
                'quantity': demand.quantity, 'unit_type': demand.unit_type, 'needed_by_date': demand.needed_by_date,
                'delivery_region': demand.delivery_region, 'status': demand.status}
        receipts = db.scalars(select(m.LpoReceipt).where(m.LpoReceipt.lpo_id == lpo.id)
            .order_by(m.LpoReceipt.received_on.desc(), m.LpoReceipt.created_at.desc())).all()
        by_line = {line.id: line for line in lines}
        view['receipts'] = []
        for receipt in receipts:
            debt = db.get(m.LedgerDebt, receipt.debt_id) if receipt.debt_id else None
            view['receipts'].append({**{k: getattr(receipt, k) for k in ('id', 'received_on', 'notes', 'amount', 'debt_id',
                'created_at', 'cancelled_at', 'cancel_reason')},
                'recorded_by': finance._operator_name(db, receipt.recorded_by),
                'debt': finance.debt_view(debt) if debt else None,
                'lines': [{**{k: getattr(r, k) for k in ('lpo_line_id', 'delivered_quantity', 'accepted_quantity',
                    'rejected_quantity', 'average_weight_kg', 'unit_price', 'amount')}, 'item': by_line[r.lpo_line_id].item}
                    for r in db.scalars(select(m.LpoReceiptLine).where(m.LpoReceiptLine.receipt_id == receipt.id))]})
        view['losses'] = [{**{k: getattr(row, k) for k in ('id', 'lpo_line_id', 'lost_on', 'quantity', 'reason', 'note',
            'unit_cost', 'created_at', 'cancelled_at')}, 'item': by_line[row.lpo_line_id].item,
            'recorded_by': finance._operator_name(db, row.recorded_by)}
            for row in db.scalars(select(m.StockLoss).where(m.StockLoss.lpo_line_id.in_(by_line))
                .order_by(m.StockLoss.lost_on.desc()))] if by_line else []
        view['sales'] = [{'sale_id': sale.id, 'sale_number': sale.sale_number, 'sold_on': sale.sold_on,
            'buyer_name': sale.buyer_name, 'lpo_line_id': item.lpo_line_id, 'quantity': item.quantity,
            'unit_price': item.unit_price, 'status': sale.status}
            for item, sale in db.execute(select(m.SaleItem, m.Sale).join(m.Sale, m.Sale.id == m.SaleItem.sale_id)
                .where(m.SaleItem.lpo_line_id.in_(by_line)).order_by(m.Sale.sold_on.desc()))] if by_line else []
    return view


# ---- drafting -----------------------------------------------------------------

def _load(db, id, lock=True):
    query = select(m.Lpo).where(m.Lpo.id == id)
    lpo = db.scalar(query.with_for_update() if lock else query)
    if not lpo:
        fail('err.lpo_not_found', 404)
    return lpo


def _apply(db, lpo, data):
    lpo.supplier_snapshot = supplier_snapshot(db, data.supplier_id)
    if data.demand_id and not db.get(m.SourcingRequest, data.demand_id):
        fail('err.requirement_not_found', 404)
    values = data.model_dump(exclude={'lines'})
    window = _window(data.delivery_start, data.delivery_end)
    point = data.collection_point or lpo.supplier_snapshot['farm_address'] or 'the supplier farm'
    values['delivery_notes'] = data.delivery_notes or [n.format(window=window, collection_point=point) for n in DEFAULT_DELIVERY_NOTES]
    values['terms'] = data.terms or [t.format(delivery_end=_long_date(data.delivery_end)) for t in DEFAULT_TERMS]
    values['collection_point'] = point
    for key, value in values.items():
        setattr(lpo, key, value)
    db.flush()
    for old in db.scalars(select(m.LpoLine).where(m.LpoLine.lpo_id == lpo.id)):
        db.delete(old)
    db.flush()
    for position, line in enumerate(data.lines, 1):
        db.add(m.LpoLine(lpo_id=lpo.id, position=position, **line.model_dump()))
    db.flush()


@router.get('/lpos/defaults')
def lpo_defaults(operator=Depends(auth.ops)):
    return _result({'delivery_notes': DEFAULT_DELIVERY_NOTES, 'terms': DEFAULT_TERMS, 'payment_terms_days': 2,
        'supply_basis': 'call_off'})


@router.post('/lpos', status_code=201)
def create_lpo(data: c.LpoInput, idempotency_key: str = Header(), operator=Depends(auth.ops), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'lpo', idempotency_key, data.model_dump())
    if prior:
        return _result(lpo_view(db, db.get(m.Lpo, prior), True), 201)
    id = m.identifier()
    lpo = m.Lpo(id=id, lpo_number='DRAFT-' + id.replace('-', '')[:8].upper(), status='draft', created_by=operator.id,
        supplier_id=data.supplier_id, supplier_snapshot={}, lpo_date=data.lpo_date, delivery_start=data.delivery_start,
        delivery_end=data.delivery_end, payment_terms_days=data.payment_terms_days, supply_basis=data.supply_basis)
    db.add(lpo)
    db.flush()
    _apply(db, lpo, data)
    s.remember(db, key, fingerprint, lpo.id)
    return _result(lpo_view(db, lpo, True), 201)


@router.put('/lpos/{id}')
def update_lpo(id: str, data: c.LpoInput, operator=Depends(auth.ops), db=Depends(database)):
    s.commerce_lock(db)
    lpo = _load(db, id)
    if lpo.status != 'draft':
        fail('err.only_draft_lpo_can_change')
    _apply(db, lpo, data)
    return _result(lpo_view(db, lpo, True))


# ---- issuing and the supplier's acceptance ------------------------------------

@router.post('/lpos/{id}/issue')
def issue_lpo(id: str, data: c.LpoIssueInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
              db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'lpo-issue', idempotency_key, {'id': id, **data.model_dump()})
    lpo = _load(db, id)
    if prior:
        return _result(lpo_view(db, lpo, True))
    if lpo.status != 'draft':
        fail('err.only_draft_lpo_can_change')
    stamp = live_mark(db, 'stamp')
    signature = live_mark(db, 'signature', operator.id)
    if not stamp:
        fail('err.upload_company_stamp_first', 422)
    if not signature:
        fail('err.upload_your_signature_first', 422)
    number = data.lpo_number or next_number(db, lpo.lpo_date.year)
    if db.scalar(select(m.Lpo.id).where(m.Lpo.lpo_number == number)):
        fail('err.lpo_number_taken')
    snapshot = supplier_snapshot(db, lpo.supplier_id)
    if snapshot['status'] != 'approved':
        fail('err.approve_supplier_before_lpo', 422)
    lpo.supplier_snapshot = snapshot
    lpo.lpo_number, lpo.status, lpo.issued_at, lpo.issued_by = number, 'issued', m.now(), operator.id
    lpo.issuer_name, lpo.issuer_position = operator.name, data.issuer_position
    lpo.stamp_mark_id, lpo.signature_mark_id = stamp.id, signature.id
    notes.notify(db, lpo.supplier_id, 'supplier', 'lpo_issued', M('notify.lpo_issued', number=number,
        window=_window(lpo.delivery_start, lpo.delivery_end)))
    s.remember(db, key, fingerprint, id)
    return _result(lpo_view(db, lpo, True))


@router.post('/lpos/{id}/acceptance')
def record_acceptance(id: str, data: c.LpoAcceptanceInput, operator=Depends(auth.ops), db=Depends(database)):
    s.commerce_lock(db)
    lpo = _load(db, id)
    if lpo.status not in ACTIVE:
        fail('err.lpo_not_active')
    lpo.status = 'accepted'
    lpo.supplier_accepted_at, lpo.supplier_accepted_name, lpo.supplier_accepted_position = data.accepted_on, data.name, data.position
    return _result(lpo_view(db, lpo, True))


@router.post('/lpos/{id}/signed-copy')
async def signed_copy(id: str, file: UploadFile = File(), operator=Depends(auth.ops), db=Depends(database)):
    raw = await file.read(settings().upload_max_bytes + 1)
    if len(raw) > settings().upload_max_bytes:
        fail('err.choose_photo_smaller_than_8', 413)
    lpo = _load(db, id)
    if lpo.status in ('draft', 'cancelled'):
        fail('err.lpo_not_active')
    saved = await run_in_threadpool(save_photo, db, None, raw)
    lpo.signed_copy_media_id = saved['id']
    db.flush()
    return _result(lpo_view(db, lpo, True))


@router.post('/lpos/{id}/extend')
def extend_lpo(id: str, data: c.LpoExtendInput, operator=Depends(auth.ops_admin), db=Depends(database)):
    s.commerce_lock(db)
    lpo = _load(db, id)
    if lpo.status not in ACTIVE:
        fail('err.lpo_not_active')
    if data.delivery_end <= lpo.delivery_end:
        fail('err.extension_must_be_later', 422)
    note = f'{c.business_today().isoformat()}: delivery window extended from {lpo.delivery_end.isoformat()} to ' \
        f'{data.delivery_end.isoformat()} by {operator.name}: {data.reason}'
    lpo.internal_notes = (lpo.internal_notes + '\n' + note).strip()
    lpo.delivery_end = data.delivery_end
    return _result(lpo_view(db, lpo, True))


@router.post('/lpos/{id}/close')
def close_lpo(id: str, data: c.ReasonInput, operator=Depends(auth.ops_admin), db=Depends(database)):
    s.commerce_lock(db)
    lpo = _load(db, id)
    if lpo.status not in ACTIVE:
        fail('err.lpo_not_active')
    lpo.status, lpo.closed_at, lpo.closed_by, lpo.close_reason = 'closed', m.now(), operator.id, data.reason
    return _result(lpo_view(db, lpo, True))


@router.post('/lpos/{id}/cancel')
def cancel_lpo(id: str, data: c.ReasonInput, operator=Depends(auth.ops_admin), db=Depends(database)):
    s.commerce_lock(db)
    lpo = _load(db, id)
    if lpo.status in ('closed', 'cancelled'):
        fail('err.lpo_not_active')
    if db.scalar(select(m.LpoReceipt.id).where(m.LpoReceipt.lpo_id == id, m.LpoReceipt.cancelled_at.is_(None))):
        fail('err.lpo_has_receipts_close_instead')
    lpo.status, lpo.closed_at, lpo.closed_by, lpo.close_reason = 'cancelled', m.now(), operator.id, data.reason
    return _result(lpo_view(db, lpo, True))


# ---- batches received, and losses ---------------------------------------------

@router.post('/lpos/{id}/receipts', status_code=201)
def receive_batch(id: str, data: c.LpoReceiptInput, idempotency_key: str = Header(), operator=Depends(auth.ops),
                  db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'lpo-receipt', idempotency_key, {'id': id, **data.model_dump()})
    lpo = _load(db, id)
    if prior:
        return _result(lpo_view(db, lpo, True), 201)
    if lpo.status not in ACTIVE:
        fail('err.lpo_not_active')
    if not lpo.delivery_start <= data.received_on <= lpo.delivery_end:
        fail('err.receipt_outside_delivery_window', 422)
    lines = {line.id: line for line in db.scalars(select(m.LpoLine).where(m.LpoLine.lpo_id == id))}
    if len({row.lpo_line_id for row in data.lines}) != len(data.lines) or any(r.lpo_line_id not in lines for r in data.lines):
        fail('err.receipt_lines_must_match_lpo', 422)
    receipt = m.LpoReceipt(lpo_id=id, received_on=data.received_on, notes=data.notes, amount=ZERO, recorded_by=operator.id)
    db.add(receipt)
    db.flush()
    total, counted = ZERO, []
    for row in data.lines:
        line = lines[row.lpo_line_id]
        if line.unit != 'kg' and (row.delivered_quantity % 1 or row.accepted_quantity % 1):
            fail('err.birds_animals_require_whole_quantities', 422)
        if line.quantity is not None:
            already = line_stock(db, line.id)['accepted']
            if already + row.accepted_quantity > line.quantity:
                fail('err.accepted_more_than_lpo_quantity', 422, item=line.item, remaining=s.quantity(line.quantity - already))
        amount = s.money(row.accepted_quantity * line.unit_price)
        db.add(m.LpoReceiptLine(receipt_id=receipt.id, lpo_line_id=line.id, delivered_quantity=row.delivered_quantity,
            accepted_quantity=row.accepted_quantity, rejected_quantity=row.delivered_quantity - row.accepted_quantity,
            average_weight_kg=row.average_weight_kg, unit_price=line.unit_price, amount=amount))
        total += amount
        if row.accepted_quantity:
            counted.append(f'{s.quantity(row.accepted_quantity)} {line.item}')
    receipt.amount = total
    if total > 0:
        snapshot = lpo.supplier_snapshot
        debt = m.LedgerDebt(direction='payable', party_kind='supplier', supplier_id=lpo.supplier_id,
            party_name=snapshot.get('name') or 'Supplier', party_phone=snapshot.get('phone') or '',
            description=f"{lpo.lpo_number} batch {data.received_on.isoformat()}: {', '.join(counted)}"[:500],
            amount=total, incurred_on=data.received_on, due_on=data.received_on + timedelta(days=lpo.payment_terms_days),
            source='lpo', lpo_id=lpo.id, created_by=operator.id)
        db.add(debt)
        db.flush()
        receipt.debt_id = debt.id
    db.flush()
    s.remember(db, key, fingerprint, id)
    return _result(lpo_view(db, lpo, True), 201)


@router.post('/lpos/receipts/{id}/cancel')
def cancel_receipt(id: str, data: c.ReasonInput, operator=Depends(auth.ops_admin), db=Depends(database)):
    s.commerce_lock(db)
    receipt = db.scalar(select(m.LpoReceipt).where(m.LpoReceipt.id == id).with_for_update())
    if not receipt:
        fail('err.receipt_not_found', 404)
    if receipt.cancelled_at:
        fail('err.receipt_already_cancelled')
    debt = db.scalar(select(m.LedgerDebt).where(m.LedgerDebt.id == receipt.debt_id).with_for_update()) if receipt.debt_id else None
    if debt and debt.paid_amount > 0:
        fail('err.reverse_payments_before_cancelling')
    for row in db.scalars(select(m.LpoReceiptLine).where(m.LpoReceiptLine.receipt_id == id)):
        if line_stock(db, row.lpo_line_id)['on_hand'] < row.accepted_quantity:
            fail('err.receipt_stock_already_sold')
    at = m.now()
    receipt.cancelled_at, receipt.cancelled_by, receipt.cancel_reason = at, operator.id, data.reason
    if debt:
        debt.status, debt.cancelled_at, debt.cancelled_by, debt.cancel_reason = 'cancelled', at, operator.id, data.reason
    return _result(lpo_view(db, _load(db, receipt.lpo_id), True))


@router.post('/lpos/losses', status_code=201)
def record_loss(data: c.StockLossInput, idempotency_key: str = Header(), operator=Depends(auth.ops), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'stock-loss', idempotency_key, data.model_dump())
    line = db.scalar(select(m.LpoLine).where(m.LpoLine.id == data.lpo_line_id).with_for_update())
    if not line:
        fail('err.lpo_stock_not_found', 404)
    if not prior:
        on_hand = line_stock(db, line.id)['on_hand']
        if data.quantity > on_hand:
            fail('err.not_enough_lpo_stock', 422, available=s.quantity(on_hand))
        db.add(m.StockLoss(recorded_by=operator.id, unit_cost=line.unit_price, **data.model_dump()))
        db.flush()
        s.remember(db, key, fingerprint, line.id)
    return _result(lpo_view(db, db.get(m.Lpo, line.lpo_id), True), 201)


@router.post('/lpos/losses/{id}/cancel')
def cancel_loss(id: str, operator=Depends(auth.ops_admin), db=Depends(database)):
    s.commerce_lock(db)
    row = db.scalar(select(m.StockLoss).where(m.StockLoss.id == id).with_for_update())
    if not row or row.cancelled_at:
        fail('err.record_unavailable', 404)
    row.cancelled_at, row.cancelled_by = m.now(), operator.id
    return _result(lpo_view(db, db.get(m.Lpo, db.get(m.LpoLine, row.lpo_line_id).lpo_id), True))


# ---- reads ------------------------------------------------------------------

LPOS = Spec(m.Lpo, (m.Lpo.created_at.desc(), m.Lpo.id.desc()),
    lambda q: paging.matches(q, m.Lpo.lpo_number, cast(m.Lpo.supplier_snapshot, Text)),
    tabs={'draft': m.Lpo.status == 'draft', 'active': m.Lpo.status.in_(ACTIVE),
          'closed': m.Lpo.status == 'closed', 'cancelled': m.Lpo.status == 'cancelled'},
    column=m.Lpo.status, urgent=m.Lpo.status.in_(('draft', *ACTIVE)),
    urgent_order=(m.Lpo.delivery_end, m.Lpo.id))


@router.get('/lpos')
def lpos(params: Paging = Depends(), supplier_id: Optional[str] = None, operator=Depends(auth.ops), db=Depends(database)):
    where = [m.Lpo.supplier_id == supplier_id] if supplier_id else []
    return _result(paging.page(db, LPOS, params, lambda row: lpo_view(db, row), where=where))


@router.get('/lpos/stock')
def lpo_stock(operator=Depends(auth.ops), db=Depends(database)):
    """LPO stock on hand, for sale lines and loss records."""
    rows = []
    for line, lpo in db.execute(select(m.LpoLine, m.Lpo).join(m.Lpo, m.Lpo.id == m.LpoLine.lpo_id)
            .where(m.Lpo.status.in_((*ACTIVE, 'closed'))).order_by(m.Lpo.delivery_start.desc(), m.LpoLine.position)):
        stock = line_stock(db, line.id)
        if stock['on_hand'] > 0:
            rows.append({'lpo_line_id': line.id, 'lpo_id': lpo.id, 'lpo_number': lpo.lpo_number, 'item': line.item,
                'category': line.category, 'unit': line.unit, 'unit_price': line.unit_price,
                'supplier_name': lpo.supplier_snapshot.get('name'), **stock})
    return _result(rows)


def _covered(db, demand):
    """How much of a requirement open LPOs already cover: what was accepted,
    plus what fixed-quantity LPOs still have to deliver."""
    covered = ZERO
    for lpo in db.scalars(select(m.Lpo).where(m.Lpo.demand_id == demand.id, m.Lpo.status.in_(('draft', *ACTIVE, 'closed')))):
        for line in db.scalars(select(m.LpoLine).where(m.LpoLine.lpo_id == lpo.id)):
            if line.category and line.category != demand.category:
                continue
            accepted = line_stock(db, line.id)['accepted'] if lpo.status != 'draft' else ZERO
            still = max(ZERO, line.quantity - accepted) if line.quantity and lpo.status in ('draft', *ACTIVE) else ZERO
            covered += accepted + still
    return covered


def suggest_suppliers(db, category, region, needed_by, limit=5):
    """Approved suppliers for a category, best first, with the reasons."""
    profiles = db.scalars(select(m.SupplierProfile).where(m.SupplierProfile.status == 'approved')).all()
    today = c.business_today()
    ranked = []
    for profile in profiles:
        batches = db.scalars(select(m.SupplierBatch).where(m.SupplierBatch.supplier_id == profile.user_id,
            m.SupplierBatch.category == category, m.SupplierBatch.status.not_in(('sold', 'closed', 'cancelled')))).all()
        if category not in (profile.categories or []) and profile.primary_category != category and not batches:
            continue
        ready = [b for b in batches if b.available_to_commit > 0 and (not b.expected_ready_date or not needed_by
            or b.expected_ready_date <= needed_by)]
        available = sum((b.available_to_commit for b in ready), ZERO)
        history = db.execute(select(func.coalesce(func.sum(m.LpoReceiptLine.accepted_quantity), 0),
            func.coalesce(func.sum(m.LpoReceiptLine.rejected_quantity), 0))
            .join(m.LpoReceipt, m.LpoReceipt.id == m.LpoReceiptLine.receipt_id)
            .join(m.Lpo, m.Lpo.id == m.LpoReceipt.lpo_id)
            .where(m.Lpo.supplier_id == profile.user_id, m.LpoReceipt.cancelled_at.is_(None))).one()
        accepted, rejected = history
        last_price = db.scalar(select(m.LpoLine.unit_price).join(m.Lpo, m.Lpo.id == m.LpoLine.lpo_id)
            .where(m.Lpo.supplier_id == profile.user_id, m.LpoLine.category == category,
                   m.Lpo.status.not_in(('draft', 'cancelled'))).order_by(m.Lpo.issued_at.desc()).limit(1))
        user = db.get(m.User, profile.user_id)
        home = profile.region or user.region
        reasons, score = [], 0
        if region and home and home.casefold() == region.casefold():
            score += 3
            reasons.append(f'In {home}')
        if available > 0:
            score += 4
            reasons.append(f'{s.quantity(available)} ready in recorded batches')
        if accepted:
            rate = accepted / (accepted + rejected)
            score += 2 if rate >= Decimal('0.9') else 0
            reasons.append(f'{s.quantity(accepted)} accepted before ({rate:.0%} pass rate)')
        ranked.append({'supplier_id': profile.user_id, 'name': profile.legal_name or user.name, 'alias': profile.public_alias,
            'phone': user.phone, 'region': home, 'district': profile.district, 'score': score,
            'available': available, 'last_price': last_price, 'reasons': reasons or ['Supplies this product']})
    ranked.sort(key=lambda r: (-r['score'], -r['available'], r['name']))
    return ranked[:limit]


@router.get('/lpos/demand')
def demand_board(operator=Depends(auth.ops), db=Depends(database)):
    """Open buyer demand still short of supply, most urgent first."""
    from . import demand as dm
    today = c.business_today()
    rows = []
    for demand in db.scalars(select(m.SourcingRequest).where(m.SourcingRequest.status.not_in(DEMAND_DONE))):
        secured = dm.secured(db, demand.id)
        covered = _covered(db, demand)
        short = Decimal(demand.quantity) - secured - covered
        if short <= 0:
            continue
        try:
            needed_by = date.fromisoformat(demand.needed_by_date)
        except (TypeError, ValueError):
            needed_by = None
        days = (needed_by - today).days if needed_by else None
        profile = db.get(m.BuyerProfile, demand.buyer_profile_id) if demand.buyer_profile_id else None
        buyer = db.get(m.User, demand.buyer_id) if demand.buyer_id else None
        rows.append({'id': demand.id, 'requirement_number': demand.requirement_number, 'category': demand.category,
            'product_subtype': demand.product_subtype, 'unit_type': demand.unit_type, 'quantity': demand.quantity,
            'secured': secured, 'on_lpo': covered, 'short': short, 'needed_by_date': demand.needed_by_date,
            'days_left': days, 'urgency': 'overdue' if days is not None and days < 0 else 'urgent' if days is not None and days <= 3
                else 'soon' if days is not None and days <= 7 else 'planned',
            'delivery_region': demand.delivery_region, 'delivery_area': demand.delivery_area,
            'minimum_weight_kg': demand.minimum_weight_kg, 'maximum_weight_kg': demand.maximum_weight_kg,
            'buyer_name': (profile.business_name if profile else '') or (buyer.name if buyer else ''),
            'suppliers': suggest_suppliers(db, demand.category, demand.delivery_region, demand.needed_by_date)})
    rows.sort(key=lambda r: (r['days_left'] if r['days_left'] is not None else 10**6, -r['short']))
    return _result(rows)


@router.get('/lpos/suppliers')
def lpo_suppliers(category: Optional[str] = None, region: Optional[str] = None, needed_by: Optional[str] = None,
                  operator=Depends(auth.ops), db=Depends(database)):
    """Every approved supplier (for the LPO form), suggested ones first for a category."""
    suggested = suggest_suppliers(db, category, region, needed_by, limit=50) if category else []
    first = {row['supplier_id'] for row in suggested}
    others = []
    for profile, user in db.execute(select(m.SupplierProfile, m.User).join(m.User, m.User.id == m.SupplierProfile.user_id)
            .where(m.SupplierProfile.status == 'approved', m.User.deleted.is_(False))
            .order_by(func.lower(m.SupplierProfile.legal_name))):
        if profile.user_id not in first:
            others.append({'supplier_id': user.id, 'name': profile.legal_name or user.name, 'alias': profile.public_alias,
                'phone': user.phone, 'region': profile.region, 'district': profile.district, 'score': 0,
                'available': ZERO, 'last_price': None, 'reasons': []})
    return _result({'suggested': suggested, 'others': others})


@router.get('/lpos/{id}')
def lpo(id: str, operator=Depends(auth.ops), db=Depends(database)):
    return _result(lpo_view(db, _load(db, id, lock=False), True))


# ---- the stamp and signatures ---------------------------------------------------

def _mark_view(db, mark):
    return {'id': mark.id, 'created_at': mark.created_at, 'uploaded_by': finance._operator_name(db, mark.uploaded_by)} if mark else None


@router.get('/marks')
def marks(operator=Depends(auth.ops), db=Depends(database)):
    return _result({'stamp': _mark_view(db, live_mark(db, 'stamp')),
        'my_signature': _mark_view(db, live_mark(db, 'signature', operator.id)), 'admin': operator.role == 'admin'})


@router.post('/marks/{kind}', status_code=201)
async def upload_mark(kind: str, file: UploadFile = File(), operator=Depends(auth.ops_admin), db=Depends(database)):
    """Only admins: the company stamp, or their own signature."""
    if kind not in ('stamp', 'signature'):
        fail('err.record_unavailable', 404)
    raw = await file.read(settings().upload_max_bytes + 1)
    if len(raw) > settings().upload_max_bytes:
        fail('err.choose_photo_smaller_than_8', 413)
    s.commerce_lock(db)
    saved = await run_in_threadpool(save_photo, db, None, raw)
    old = live_mark(db, kind, operator.id)
    if old:
        old.retired_at = m.now()
        db.flush()
    mark = m.DocumentMark(kind=kind, operator_id=operator.id if kind == 'signature' else None, media_id=saved['id'],
        uploaded_by=operator.id)
    db.add(mark)
    db.flush()
    return _result(_mark_view(db, mark), 201)


@router.get('/marks/{kind}/preview')
def preview_mark(kind: str, operator=Depends(auth.ops_admin), db=Depends(database)):
    mark = live_mark(db, kind, operator.id) if kind in ('stamp', 'signature') else None
    if not mark:
        fail('err.record_unavailable', 404)
    return signed_link(db.get(m.MediaAsset, mark.media_id))


@router.get('/lpos/{id}/marks/{kind}')
def lpo_mark(id: str, kind: str, operator=Depends(auth.ops), db=Depends(database)):
    """The stamp or signature printed on an issued LPO, and nowhere else."""
    lpo = _load(db, id, lock=False)
    mark_id = {'stamp': lpo.stamp_mark_id, 'signature': lpo.signature_mark_id}.get(kind)
    if lpo.status in ('draft', 'cancelled') or not mark_id:
        fail('err.record_unavailable', 404)
    return signed_link(db.get(m.MediaAsset, db.get(m.DocumentMark, mark_id).media_id))


def is_mark(db, media_id):
    return db.scalar(select(m.DocumentMark.id).where(m.DocumentMark.media_id == media_id)) is not None
