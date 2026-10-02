"""Supplier production batches, physical collection notes, and received stock."""
from __future__ import annotations

from collections import defaultdict
from datetime import timedelta
from decimal import Decimal

from fastapi import APIRouter, Depends, Header
from sqlalchemy import func, select

from . import auth, contracts as c, models as m, notifications as notes, services as s
from .db import database
from .i18n import M, fail

router = APIRouter(prefix='/api/v1')
supplier_member = auth.role('supplier')
ZERO = Decimal('0')


def _result(value, status_code=200):
    from .main import result
    return result(value, status_code)


def refresh_batch_status(batch):
    """A batch with nothing left to take is finished; one with stock is
    open again (a cancelled sale can return birds)."""
    left = batch.current_quantity - batch.sold_quantity - batch.externally_sold_quantity
    if left <= 0:
        batch.status = 'sold'
    elif batch.status == 'sold':
        batch.status = 'ready'


def take_from_batch(db, batch_id, supplier_id, quantity):
    """A direct sale line from this supplier's batch: count the birds as taken
    by Omoterra (sold_quantity). Fails if the batch has fewer left."""
    batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == batch_id).with_for_update())
    if not batch:
        fail('err.supplier_batch_not_found', 404)
    if batch.supplier_id != supplier_id:
        fail('err.batch_not_this_suppliers', 422)
    if quantity > batch.available_to_commit:
        fail('err.not_enough_left_in_batch', 422, available=s.quantity(max(batch.available_to_commit, ZERO)))
    batch.sold_quantity += quantity
    refresh_batch_status(batch)
    return batch


def return_to_batch(db, batch_id, quantity):
    """Undo take_from_batch (a sale edited or cancelled)."""
    batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == batch_id).with_for_update())
    if batch:
        batch.sold_quantity = max(ZERO, batch.sold_quantity - quantity)
        refresh_batch_status(batch)


def batch_breakdown(db, batch):
    """Registered, taken by Omoterra (received on delivery notes and sold
    straight from the batch), sold elsewhere by the supplier, and left."""
    received = db.scalar(select(func.coalesce(func.sum(m.SupplierCollection.accepted_quantity), 0)).where(
        m.SupplierCollection.batch_id == batch.id, m.SupplierCollection.cancelled_at.is_(None))) or ZERO
    sold_direct = db.scalar(select(func.coalesce(func.sum(m.SaleItem.quantity), 0)).join(m.Sale, m.Sale.id == m.SaleItem.sale_id)
        .where(m.SaleItem.supplier_batch_id == batch.id, m.Sale.status == 'active')) or ZERO
    movements = db.scalars(select(m.SupplierBatchMovement).where(m.SupplierBatchMovement.batch_id == batch.id)
        .order_by(m.SupplierBatchMovement.created_at.desc())).all()
    return {'registered': batch.current_quantity, 'taken_by_omoterra': batch.sold_quantity,
        'received_on_notes': received, 'sold_direct': sold_direct,
        'sold_elsewhere': batch.externally_sold_quantity, 'reserved': batch.reserved_quantity,
        'remaining': max(ZERO, batch.available_to_commit),
        'elsewhere_history': [{'quantity': row.quantity, 'note': row.note, 'at': row.created_at,
            'by_staff': row.recorded_by is not None} for row in movements if row.kind == 'external_sale']}


def collection_stock(db, collection_id):
    sold = db.scalar(select(func.coalesce(func.sum(m.SaleItem.quantity), 0))
        .join(m.Sale, m.Sale.id == m.SaleItem.sale_id)
        .where(m.SaleItem.supplier_collection_id == collection_id, m.Sale.status == 'active')) or ZERO
    row = db.get(m.SupplierCollection, collection_id)
    accepted = row.accepted_quantity if row and row.cancelled_at is None else ZERO
    return {'sold': sold, 'on_hand': accepted - sold}


def take_collection_stock(db, collection_id, quantity, taken=ZERO):
    row = db.scalar(select(m.SupplierCollection).where(
        m.SupplierCollection.id == collection_id, m.SupplierCollection.cancelled_at.is_(None)).with_for_update())
    if not row:
        fail('err.supplier_collection_stock_not_found', 404)
    on_hand = collection_stock(db, row.id)['on_hand'] - taken
    if quantity > on_hand:
        fail('err.not_enough_received_batch_stock', 422, available=s.quantity(on_hand))
    return row, db.get(m.SupplierBatch, row.batch_id)


def collection_view(db, row):
    batch = db.get(m.SupplierBatch, row.batch_id)
    supplier = db.get(m.User, row.supplier_id)
    stock = collection_stock(db, row.id)
    return {**{key: getattr(row, key) for key in (
        'id', 'collection_number', 'supplier_id', 'batch_id', 'received_on', 'delivered_quantity',
        'accepted_quantity', 'rejected_quantity', 'average_weight_kg', 'unit_cost', 'amount',
        'notes', 'debt_id', 'created_at', 'cancelled_at', 'cancel_reason')},
        'supplier_name': supplier.name if supplier else 'Supplier',
        'supplier_phone': supplier.phone if supplier else '',
        'category': batch.category if batch else '',
        'subtype': batch.subtype if batch else '',
        'unit': c.UNITS.get(batch.category, 'unit') if batch else 'unit',
        **stock}


def collections_for_batches(db, batches):
    grouped = defaultdict(list)
    ids = [row.id for row in batches]
    if not ids:
        return grouped
    rows = db.scalars(select(m.SupplierCollection).where(m.SupplierCollection.batch_id.in_(ids))
        .order_by(m.SupplierCollection.received_on.desc(), m.SupplierCollection.created_at.desc())).all()
    for row in rows:
        grouped[row.batch_id].append(collection_view(db, row))
    return grouped


@router.post('/ops/suppliers/{supplier_id}/batches', status_code=201)
def create_ops_batch(supplier_id: str, data: c.SupplierBatchInput, idempotency_key: str = Header(),
                     operator=Depends(auth.ops), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'ops-supplier-batch', idempotency_key,
        {'supplier_id': supplier_id, **data.model_dump()})
    if prior:
        from .demand import batch_view
        return _result(batch_view(db.get(m.SupplierBatch, prior), private=True), 201)
    profile = db.get(m.SupplierProfile, supplier_id)
    user = db.get(m.User, supplier_id)
    if not profile or not user or user.deleted or 'supplier' not in (user.roles or []):
        fail('err.supplier_not_found', 404)
    ready = data.expected_ready_date.isoformat()
    row = m.SupplierBatch(supplier_id=supplier_id, category=data.category, subtype=data.subtype,
        initial_quantity=data.initial_quantity, current_quantity=data.initial_quantity,
        current_age=data.current_age, age_unit=data.age_unit, expected_ready_date=ready,
        expected_min_weight_kg=data.expected_min_weight_kg, expected_max_weight_kg=data.expected_max_weight_kg,
        form=data.form, asking_price_per_unit=data.asking_price_per_unit,
        supplier_payout_price_per_unit=data.asking_price_per_unit,
        region=data.region or profile.region, private_pickup_location=data.private_pickup_location or profile.internal_pickup_address,
        photos=[], status='ready' if ready <= c.business_today().isoformat() else 'growing', approved_at=m.now())
    db.add(row)
    db.flush()
    s.remember(db, key, fingerprint, row.id)
    from .demand import batch_view
    return _result(batch_view(row, private=True), 201)


def _sold_elsewhere(db, batch, quantity, note, key, operator):
    batch.externally_sold_quantity += quantity
    refresh_batch_status(batch)
    db.add(m.SupplierBatchMovement(batch_id=batch.id, supplier_id=batch.supplier_id, kind='external_sale',
        quantity=quantity, note=note, idempotency_key=key, recorded_by=operator.id))


@router.post('/ops/batches/{batch_id}/sold-elsewhere')
def record_sold_elsewhere(batch_id: str, data: c.BatchExternalSaleInput, idempotency_key: str = Header(),
                          operator=Depends(auth.ops), db=Depends(database)):
    """Birds the supplier sold to someone else: they leave the batch."""
    key, fingerprint, prior = s.replay(db, operator.id, 'ops-batch-elsewhere', idempotency_key, {'id': batch_id, **data.model_dump()})
    batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == batch_id).with_for_update())
    if not batch:
        fail('err.supplier_batch_not_found', 404)
    if not prior:
        if data.quantity > batch.available_to_commit:
            fail('err.not_enough_left_in_batch', 422, available=s.quantity(max(batch.available_to_commit, ZERO)))
        _sold_elsewhere(db, batch, data.quantity, data.notes, key, operator)
        s.remember(db, key, fingerprint, batch.id)
    from .demand import batch_view
    return _result({**batch_view(batch, private=True), **batch_breakdown(db, batch)})


@router.post('/ops/batches/{batch_id}/close')
def close_batch(batch_id: str, data: c.BatchCloseInput, idempotency_key: str = Header(),
                operator=Depends(auth.ops), db=Depends(database)):
    """The supplier sold everything still left elsewhere: finish the batch."""
    key, fingerprint, prior = s.replay(db, operator.id, 'ops-batch-close', idempotency_key, {'id': batch_id, **data.model_dump()})
    batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == batch_id).with_for_update())
    if not batch:
        fail('err.supplier_batch_not_found', 404)
    if not prior:
        left = batch.available_to_commit
        if left <= 0:
            fail('err.batch_already_finished', 409)
        _sold_elsewhere(db, batch, left, data.notes or 'Rest of the batch sold elsewhere', key, operator)
        s.remember(db, key, fingerprint, batch.id)
    from .demand import batch_view
    return _result({**batch_view(batch, private=True), **batch_breakdown(db, batch)})


@router.post('/ops/suppliers/{supplier_id}/collections', status_code=201)
def receive_supplier_stock(supplier_id: str, data: c.SupplierCollectionInput, idempotency_key: str = Header(),
                           operator=Depends(auth.ops), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'supplier-collection', idempotency_key,
        {'supplier_id': supplier_id, **data.model_dump()})
    if prior:
        return _result(collection_view(db, db.get(m.SupplierCollection, prior)), 201)
    batch = db.scalar(select(m.SupplierBatch).where(
        m.SupplierBatch.id == data.batch_id, m.SupplierBatch.supplier_id == supplier_id).with_for_update())
    user = db.get(m.User, supplier_id)
    if not batch or not user:
        fail('err.supplier_batch_not_found', 404)
    if c.UNITS[batch.category] != 'kg' and (
            data.delivered_quantity % 1 or data.accepted_quantity % 1):
        fail('err.birds_animals_require_whole_quantities', 422)
    remaining = batch.current_quantity - batch.sold_quantity - batch.externally_sold_quantity
    if data.accepted_quantity > remaining:
        fail('err.collection_exceeds_supplier_batch', 422, available=s.quantity(remaining))
    amount = s.money(data.accepted_quantity * data.unit_cost)
    collection_id = m.identifier()
    row = m.SupplierCollection(id=collection_id,
        collection_number=f'DN-{data.received_on:%Y%m%d}-{collection_id.replace("-", "")[:6].upper()}',
        supplier_id=supplier_id, batch_id=batch.id,
        received_on=data.received_on, delivered_quantity=data.delivered_quantity,
        accepted_quantity=data.accepted_quantity, rejected_quantity=data.delivered_quantity - data.accepted_quantity,
        average_weight_kg=data.average_weight_kg, unit_cost=data.unit_cost, amount=amount,
        notes=data.notes, recorded_by=operator.id)
    db.add(row)
    db.flush()
    if data.accepted_quantity:
        reserved_used = min(batch.reserved_quantity, data.accepted_quantity)
        batch.reserved_quantity -= reserved_used
        batch.sold_quantity += data.accepted_quantity
        if batch.current_quantity - batch.sold_quantity - batch.externally_sold_quantity <= 0:
            batch.status = 'sold'
        elif batch.available_to_commit <= 0:
            batch.status = 'fully_reserved'
        elif batch.reserved_quantity:
            batch.status = 'partially_reserved'
        debt = m.LedgerDebt(direction='payable', party_kind='supplier', supplier_id=supplier_id,
            party_name=user.name or 'Supplier', party_phone=user.phone,
            description=f'{row.collection_number}: {s.quantity(data.accepted_quantity)} {batch.category.replace("_", " ")} accepted',
            amount=amount, incurred_on=data.received_on,
            due_on=data.received_on + timedelta(days=data.payment_terms_days),
            source='batch_receipt', created_by=operator.id)
        db.add(debt)
        db.flush()
        row.debt_id = debt.id
    notes.notify(db, supplier_id, 'supplier', 'batch_collected',
        M('notify.batch_collected', quantity=s.quantity(data.accepted_quantity),
          product=batch.category.replace('_', ' '), date=data.received_on.isoformat()),
        '/account?view=stock')
    db.flush()
    s.remember(db, key, fingerprint, row.id)
    return _result(collection_view(db, row), 201)


@router.get('/ops/supplier-batches/open')
def open_batches(operator=Depends(auth.ops), db=Depends(database)):
    """Batches that still have birds to take, for choosing on a sale line."""
    rows = db.scalars(select(m.SupplierBatch).where(m.SupplierBatch.status != 'sold')
        .order_by(m.SupplierBatch.created_at)).all()
    return _result([{'id': row.id, 'supplier_id': row.supplier_id, 'category': row.category, 'subtype': row.subtype,
        'registered': row.current_quantity, 'remaining': row.available_to_commit, 'created_at': row.created_at,
        'asking_price_per_unit': row.asking_price_per_unit} for row in rows if row.available_to_commit > 0])


@router.get('/ops/supplier-collections/stock')
def ops_collection_stock(operator=Depends(auth.ops), db=Depends(database)):
    rows = []
    for row in db.scalars(select(m.SupplierCollection).where(m.SupplierCollection.cancelled_at.is_(None))
            .order_by(m.SupplierCollection.received_on, m.SupplierCollection.created_at)):
        view = collection_view(db, row)
        if view['on_hand'] > 0:
            rows.append(view)
    return _result(rows)


@router.get('/ops/supplier-collections/{id}')
def ops_collection(id: str, operator=Depends(auth.ops), db=Depends(database)):
    row = db.get(m.SupplierCollection, id)
    if not row:
        fail('err.supplier_collection_not_found', 404)
    return _result(collection_view(db, row))


@router.get('/supplier/collections')
def supplier_collections(user=Depends(supplier_member), db=Depends(database)):
    rows = db.scalars(select(m.SupplierCollection).where(m.SupplierCollection.supplier_id == user.id)
        .order_by(m.SupplierCollection.received_on.desc(), m.SupplierCollection.created_at.desc())).all()
    return _result([collection_view(db, row) for row in rows])
