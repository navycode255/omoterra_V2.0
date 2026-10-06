"""Supplier production batches, physical collection notes, and received stock.

A delivery note (`SupplierCollection`) is the record that goods were
physically received from a supplier batch, with who confirmed it and when;
its `batch_receipt` debt is what Omoterra owes for them. Since build plan
M1.6, a direct sale from a batch goes through one too: staff confirm the
collection and a same-day note (origin 'sale') is recorded and sold from.

After receipt, stock moves only with a physical event (rule R2), recorded in
`collection_movements`: goods not recovered from a cancelled sale, goods
returned to the supplier (payable unchanged until an agreed supplier credit
note), or a receipt correction (the supplier never delivered them: the note
and its payable are reduced). On hand never goes below zero (R8, current
state; dated checks arrive with M2.2)."""
from __future__ import annotations

from collections import defaultdict
from datetime import timedelta
from decimal import Decimal

from fastapi import APIRouter, Depends, Header
from sqlalchemy import func, select

from . import auth, contracts as c, models as m, notifications as notes_module, services as s
from .db import database
from .i18n import M, fail
from .lots import StockGuard, late_entry, log_late

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
    return {'flow': batch_flows(db, [batch])[batch.id], 'commitments': commitments(db, batch.id),
        'registered': batch.current_quantity, 'taken_by_omoterra': batch.sold_quantity,
        'received_on_notes': received, 'sold_direct': sold_direct,
        'sold_elsewhere': batch.externally_sold_quantity, 'reserved': batch.reserved_quantity,
        'remaining': max(ZERO, batch.available_to_commit),
        'elsewhere_history': [{'quantity': row.quantity, 'note': row.note, 'at': row.created_at,
            'by_staff': row.recorded_by is not None} for row in movements if row.kind == 'external_sale']}


# ---- reservations a delivery fills (M2.1) ----------------------------------------

def fulfilled(db, kind, commitment_id):
    return db.scalar(select(func.coalesce(func.sum(m.CommitmentFulfilment.quantity), 0)).where(
        m.CommitmentFulfilment.commitment_kind == kind, m.CommitmentFulfilment.commitment_id == commitment_id)) or ZERO


def held(kind, row):
    """What a reservation holds on its batch before any delivery: an
    allocation not yet turned into an app order, or an approved market
    reservation."""
    if kind == 'demand_allocation':
        return row.allocated_quantity if row.status == 'reserved' and row.listing_id is None else ZERO
    return (row.quantity_approved or ZERO) if row.status == 'approved' else ZERO


def outstanding(db, kind, row):
    """Still held on the batch: what it holds less what notes filled."""
    return max(ZERO, held(kind, row) - fulfilled(db, kind, row.id))


def commitments(db, batch_id):
    """Reservations holding birds on this batch, with what is outstanding."""
    out = []
    for row, demand in db.execute(select(m.DemandAllocation, m.SourcingRequest).join(m.SourcingRequest,
            m.SourcingRequest.id == m.DemandAllocation.demand_id).where(m.DemandAllocation.supplier_batch_id == batch_id)).all():
        left = outstanding(db, 'demand_allocation', row)
        if left > 0:
            out.append({'kind': 'demand_allocation', 'id': row.id, 'outstanding': left,
                'label': f'Buyer demand {demand.requirement_number or demand.id[:8].upper()} (needed by {demand.needed_by_date})'})
    for row, slot in db.execute(select(m.MarketReservation, m.MarketSlot).join(m.MarketSlot,
            m.MarketSlot.id == m.MarketReservation.market_slot_id).where(m.MarketReservation.supplier_batch_id == batch_id)).all():
        left = outstanding(db, 'market_reservation', row)
        if left > 0:
            out.append({'kind': 'market_reservation', 'id': row.id, 'outstanding': left,
                'label': f'Market day {slot.delivery_date.isoformat()}'})
    return out


def _fill_commitment(db, batch, kind, commitment_id, accepted):
    """How much of `accepted` fills the named reservation (locked), or 0."""
    if not kind or not commitment_id:
        return ZERO, None
    model = m.DemandAllocation if kind == 'demand_allocation' else m.MarketReservation
    batch_column = model.supplier_batch_id
    row = db.scalar(select(model).where(model.id == commitment_id, batch_column == batch.id).with_for_update())
    if not row or outstanding(db, kind, row) <= 0:
        fail('err.reservation_not_on_this_batch', 422)
    return min(accepted, outstanding(db, kind, row)), row


def batch_flows(db, batches):
    """Where each batch's birds are (build plan M2.1), the same for staff,
    the supplier app and the portal: registered (the supplier's
    declaration, never Omoterra stock), reserved for buyers, received by
    Omoterra on delivery notes, then of those sold, lost (died, other
    losses, not recovered), returned to the supplier, still at Omoterra,
    and left with the supplier. Received figures come from the notes'
    dated movements (lots.py)."""
    from .lots import movements, summary
    batches = list(batches)
    notes = defaultdict(list)
    if batches:
        for id, batch_id in db.execute(select(m.SupplierCollection.id, m.SupplierCollection.batch_id)
                .where(m.SupplierCollection.batch_id.in_([b.id for b in batches]))).all():
            notes[batch_id].append(id)
    moves = defaultdict(list)
    ids = [id for group in notes.values() for id in group]
    for row in movements(db, 'supplier_collections', ids) if ids else []:
        moves[row['lot_id']].append(row)
    out = {}
    for batch in batches:
        lot = summary([row for id in notes[batch.id] for row in moves[id]])
        received = lot['received'] - lot['corrected']
        out[batch.id] = {'registered': batch.current_quantity, 'reserved': batch.reserved_quantity,
            'received': received, 'sold': lot['sold'], 'lost': lot['died'] + lot['lost'] + lot['not_recovered'],
            'returned': lot['returned_to_supplier'], 'at_kitchens': lot['at_locations'], 'at_omoterra': lot['on_hand'],
            'sold_elsewhere': batch.externally_sold_quantity,
            'left': max(ZERO, batch.current_quantity - batch.sold_quantity - batch.externally_sold_quantity)}
    return out


def collection_stock(db, collection_id, as_of=None):
    """Sold (active sales), out by a physical event, at kitchens, and on
    hand, from the note's dated movements (lots.py, M2.1)."""
    from .lots import lot_summary
    lot = lot_summary(db, 'supplier_collections', collection_id, as_of)
    return {'sold': lot['sold'], 'not_recovered': lot['not_recovered'], 'returned': lot['returned_to_supplier'],
            'lost': lot['died'] + lot['lost'], 'allocated': lot['at_locations'], 'on_hand': lot['on_hand']}


def take_collection_stock(db, collection_id, quantity, taken=ZERO):
    row = db.scalar(select(m.SupplierCollection).where(
        m.SupplierCollection.id == collection_id, m.SupplierCollection.cancelled_at.is_(None)).with_for_update())
    if not row:
        fail('err.supplier_collection_stock_not_found', 404)
    on_hand = collection_stock(db, row.id)['on_hand'] - taken
    if quantity > on_hand:
        fail('err.not_enough_received_batch_stock', 422, available=s.quantity(on_hand))
    return row, db.get(m.SupplierBatch, row.batch_id)


def _operator(db, id):
    if not id:
        return None
    row = db.get(m.Operator, id)
    return row.name if row else id


def _credit_view(row):
    return {k: getattr(row, k) for k in ('id', 'movement_id', 'amount', 'issued_on', 'reference', 'note', 'created_at')}


def collection_view(db, row, detail=False):
    """A delivery note with its stock. `detail` (staff) adds its physical
    events, credit notes, returns awaiting supplier credit and its payable."""
    batch = db.get(m.SupplierBatch, row.batch_id)
    supplier = db.get(m.User, row.supplier_id)
    stock = collection_stock(db, row.id)
    view = {**{key: getattr(row, key) for key in (
        'id', 'collection_number', 'supplier_id', 'batch_id', 'received_on', 'delivered_quantity',
        'accepted_quantity', 'rejected_quantity', 'average_weight_kg', 'unit_cost', 'amount',
        'notes', 'debt_id', 'created_at', 'cancelled_at', 'cancel_reason', 'origin')},
        'supplier_name': supplier.name if supplier else 'Supplier',
        'supplier_phone': supplier.phone if supplier else '',
        'category': batch.category if batch else '',
        'subtype': batch.subtype if batch else '',
        'unit': c.UNITS.get(batch.category, 'unit') if batch else 'unit',
        **stock}
    if not detail:
        return view
    movements = db.scalars(select(m.CollectionMovement).where(m.CollectionMovement.collection_id == row.id)
        .order_by(m.CollectionMovement.occurred_on, m.CollectionMovement.created_at)).all()
    credits = db.scalars(select(m.SupplierCreditNote).where(m.SupplierCreditNote.collection_id == row.id)
        .order_by(m.SupplierCreditNote.issued_on, m.SupplierCreditNote.created_at)).all()
    credited = {credit.movement_id: credit for credit in credits}
    sale_numbers = dict(db.execute(select(m.Sale.id, m.Sale.sale_number).where(m.Sale.id.in_(
        [x for x in [row.sale_id, *(move.sale_id for move in movements)] if x]))).all())
    debt = db.get(m.LedgerDebt, row.debt_id) if row.debt_id else None
    awaiting = [move for move in movements if move.kind == 'returned_to_supplier' and move.id not in credited]
    view.update(
        confirmed_by=row.confirmed_by_name or _operator(db, row.confirmed_by), confirmed_at=row.confirmed_at,
        recorded_by=_operator(db, row.recorded_by), sale_id=row.sale_id, sale_number=sale_numbers.get(row.sale_id),
        movements=[{**{k: getattr(move, k) for k in ('id', 'kind', 'quantity', 'occurred_on', 'unit_cost', 'sale_id',
            'reason', 'evidence', 'note', 'created_at', 'loss_reason', 'cancelled_at', 'cancel_reason')},
            'value': s.money(move.quantity * move.unit_cost), 'cancelled_by': _operator(db, move.cancelled_by),
            'sale_number': sale_numbers.get(move.sale_id), 'recorded_by': _operator(db, move.recorded_by),
            'credit_note': _credit_view(credited[move.id]) if move.id in credited else None,
            'awaiting_credit': move.kind == 'returned_to_supplier' and move.id not in credited} for move in movements],
        credit_notes=[_credit_view(credit) for credit in credits],
        credited=sum((credit.amount for credit in credits), ZERO),
        awaiting_credit_quantity=sum((move.quantity for move in awaiting), ZERO),
        awaiting_credit_value=s.money(sum((move.quantity * move.unit_cost for move in awaiting), ZERO)),
        payable=None if debt is None else {k: getattr(debt, k) for k in ('id', 'amount', 'paid_amount', 'status')}
            | {'balance': debt.balance})
    return view


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
    # Which reservation this fills (M2.1): the rest must come from birds no
    # reservation holds, so a delivery never silently uses up a buyer's or a
    # market day's reservation.
    filled, commitment = _fill_commitment(db, batch, data.commitment_kind, data.commitment_id, data.accepted_quantity)
    if data.accepted_quantity - filled > max(ZERO, batch.available_to_commit):
        fail('err.name_the_reservation_this_fills', 422, available=s.quantity(max(ZERO, batch.available_to_commit)))
    row = record_note(db, batch, user, received_on=data.received_on, delivered=data.delivered_quantity,
        accepted=data.accepted_quantity, unit_cost=data.unit_cost, notes=data.notes, recorded_by=operator.id,
        average_weight_kg=data.average_weight_kg, payment_terms_days=data.payment_terms_days,
        confirmed_by=operator.id)
    if data.accepted_quantity:
        if filled:
            db.add(m.CommitmentFulfilment(collection_id=row.id, commitment_kind=data.commitment_kind,
                commitment_id=commitment.id, quantity=filled))
            batch.reserved_quantity -= filled
        batch.sold_quantity += data.accepted_quantity
        if batch.current_quantity - batch.sold_quantity - batch.externally_sold_quantity <= 0:
            batch.status = 'sold'
        elif batch.available_to_commit <= 0:
            batch.status = 'fully_reserved'
        elif batch.reserved_quantity:
            batch.status = 'partially_reserved'
    db.flush()
    s.remember(db, key, fingerprint, row.id)
    return _result(collection_view(db, row), 201)


def record_note(db, batch, user, *, received_on, delivered, accepted, unit_cost, notes='', recorded_by=None,
                average_weight_kg=None, payment_terms_days=0, origin='delivery', confirmed_by=None,
                confirmed_by_name='', sale_id=None, sale_number=None, notify=True):
    """A delivery note for goods physically received from `batch`, and its
    batch_receipt payable for the accepted quantity: the supplier's only
    liability for them. The caller updates the batch's quantities."""
    amount = s.money(accepted * unit_cost)
    collection_id = m.identifier()
    row = m.SupplierCollection(id=collection_id,
        collection_number=f'DN-{received_on:%Y%m%d}-{collection_id.replace("-", "")[:6].upper()}',
        supplier_id=user.id, batch_id=batch.id, received_on=received_on, delivered_quantity=delivered,
        accepted_quantity=accepted, rejected_quantity=delivered - accepted, average_weight_kg=average_weight_kg,
        unit_cost=unit_cost, amount=amount, notes=notes, recorded_by=recorded_by, origin=origin,
        confirmed_by=confirmed_by, confirmed_by_name=confirmed_by_name, confirmed_at=m.now(), sale_id=sale_id)
    db.add(row)
    db.flush()
    if accepted:
        product = batch.category.replace('_', ' ')
        extra = f' (collected for sale {sale_number})' if sale_number else ''
        debt = m.LedgerDebt(direction='payable', party_kind='supplier', supplier_id=user.id,
            party_name=user.name or 'Supplier', party_phone=user.phone,
            description=f'{row.collection_number}: {s.quantity(accepted)} {product} accepted{extra}'[:500],
            amount=amount, incurred_on=received_on, due_on=received_on + timedelta(days=payment_terms_days),
            source='batch_receipt', created_by=recorded_by)
        db.add(debt)
        db.flush()
        row.debt_id = debt.id
    if notify:
        notes_module.notify(db, user.id, 'supplier', 'batch_collected',
            M('notify.batch_collected', quantity=s.quantity(accepted),
              product=batch.category.replace('_', ' '), date=received_on.isoformat()),
            '/account?view=stock')
    db.flush()
    return row


def collect_for_sale(db, batch_id, supplier_id, quantity, unit_cost, received_on, operator, sale):
    """A sale line from a supplier batch whose collection staff confirmed:
    take the birds from the batch and record the same-day delivery note the
    line then sells from (build plan M1.6). The supplier is owed through the
    note's payable only; the sale opens no cost debt for it."""
    batch = take_from_batch(db, batch_id, supplier_id, quantity)
    user = db.get(m.User, supplier_id)
    row = record_note(db, batch, user, received_on=received_on, delivered=quantity, accepted=quantity,
        unit_cost=unit_cost, notes=f'Collected from the batch and sold the same day (sale {sale.sale_number}).',
        recorded_by=operator.id, origin='sale', confirmed_by=operator.id, sale_id=sale.id,
        sale_number=sale.sale_number)
    return row


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
    return _result(collection_view(db, row, True))


# ---- after receipt: corrections, returns, credit notes (rule R2) -----------

def _lock_note(db, id):
    row = db.scalar(select(m.SupplierCollection).where(m.SupplierCollection.id == id).with_for_update())
    if not row:
        fail('err.supplier_collection_not_found', 404)
    if row.cancelled_at is not None:
        fail('err.delivery_note_cancelled')
    return row


def _within_on_hand(db, row, quantity):
    """A movement out never takes more than is on hand on the note now; the
    dated check on every later day is StockGuard (R8, M2.2)."""
    if c.UNITS.get(db.get(m.SupplierBatch, row.batch_id).category) != 'kg' and quantity % 1:
        fail('err.birds_animals_require_whole_quantities', 422)
    on_hand = collection_stock(db, row.id)['on_hand']
    if quantity > on_hand:
        fail('err.more_than_on_hand_on_note', 422, available=s.quantity(max(on_hand, ZERO)))


def _note_state(row, debt):
    from .finance import DEBT_FIELDS, _snapshot
    return {'note': _snapshot(row, ('id', 'delivered_quantity', 'accepted_quantity', 'amount', 'cancelled_at')),
            'debt': _snapshot(debt, DEBT_FIELDS) if debt else None}


@router.post('/ops/supplier-collections/{id}/corrections')
def correct_receipt(id: str, data: c.ReceiptCorrectionInput, idempotency_key: str = Header(),
                    operator=Depends(auth.ops_admin), db=Depends(database)):
    """The supplier never delivered `quantity` of this note: it is removed
    from the note and its payable, and goes back to the supplier's batch.
    Only stock still on hand can be corrected (never what active sales
    consumed). Money already paid above the new payable stays with the
    supplier who received it, as credit or unresolved (R1, R6). Admin only."""
    from .finance import record_adjustment, shrink_payable
    key, fingerprint, prior = s.replay(db, operator.id, 'receipt-correction', idempotency_key, {'id': id, **data.model_dump()})
    if not prior:
        row = _lock_note(db, id)
        _within_on_hand(db, row, data.quantity)
        guard = StockGuard(db).watch('supplier_collections', row.id)
        debt = db.scalar(select(m.LedgerDebt).where(m.LedgerDebt.id == row.debt_id).with_for_update()) if row.debt_id else None
        before = _note_state(row, debt)
        reason = data.reason.strip()
        batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == row.batch_id).with_for_update())
        batch.sold_quantity = max(ZERO, batch.sold_quantity - data.quantity)
        refresh_batch_status(batch)
        accepted = row.accepted_quantity - data.quantity
        if accepted == 0:
            row.cancelled_at, row.cancelled_by, row.cancel_reason = m.now(), operator.id, f'Never delivered: {reason}'[:500]
        else:
            row.accepted_quantity, row.delivered_quantity = accepted, row.delivered_quantity - data.quantity
            row.amount = s.money(accepted * row.unit_cost)
        released = {}
        if debt is not None and debt.status != 'cancelled':
            new_amount = max(ZERO, debt.amount - s.money(data.quantity * row.unit_cost))
            released = shrink_payable(db, debt, new_amount, data.payments, f'Receipt corrected: {reason}', operator)
        movement = m.CollectionMovement(collection_id=row.id, kind='receipt_correction', quantity=data.quantity,
            occurred_on=c.business_today(), unit_cost=row.unit_cost, reason=reason, evidence=data.evidence.strip(),
            recorded_by=operator.id)
        db.add(movement)
        db.flush()
        guard.check()
        record_adjustment(db, 'receipt_correction', row, debt, reason, before, _note_state(row, debt),
            {'movement_id': movement.id, 'batch_id': batch.id, 'quantity': str(data.quantity),
             'evidence': data.evidence.strip(), **released}, operator)
        s.remember(db, key, fingerprint, row.id)
    return _result(collection_view(db, db.get(m.SupplierCollection, id), True))


@router.post('/ops/supplier-collections/{id}/losses', status_code=201)
def record_delivery_loss(id: str, data: c.DeliveryLossInput, idempotency_key: str = Header(),
                         operator=Depends(auth.ops), db=Depends(database)):
    """Goods from this note died, were culled, stolen or spoiled before they
    were sold. They leave stock on hand and their cost at the note's unit
    cost counts against profit. The payable is unchanged: Omoterra received
    them, so what it owes the supplier still stands."""
    key, fingerprint, prior = s.replay(db, operator.id, 'delivery-loss', idempotency_key, {'id': id, **data.model_dump()})
    if not prior:
        row = _lock_note(db, id)
        if data.lost_on < row.received_on:
            fail('err.loss_before_receipt', 422)
        late = late_entry(operator, data.lost_on, data.late_reason)
        _within_on_hand(db, row, data.quantity)
        guard = StockGuard(db).watch('supplier_collections', row.id)
        movement = m.CollectionMovement(collection_id=row.id, kind='lost', loss_reason=data.reason, quantity=data.quantity,
            occurred_on=data.lost_on, unit_cost=row.unit_cost, note=data.note.strip(), recorded_by=operator.id)
        db.add(movement)
        guard.check()
        log_late(db, late, 'collection_movements', movement.id, data.lost_on, operator)
        db.flush()
        s.remember(db, key, fingerprint, row.id)
    return _result(collection_view(db, db.get(m.SupplierCollection, id), True), 201)


@router.post('/ops/supplier-collections/{id}/losses/{movement_id}/cancel')
def cancel_delivery_loss(id: str, movement_id: str, data: c.ReasonInput, operator=Depends(auth.ops_admin),
                         db=Depends(database)):
    """A loss recorded by mistake: the goods count as on hand again. The loss
    stays in the note's history, marked cancelled with who and why."""
    s.commerce_lock(db)
    movement = db.scalar(select(m.CollectionMovement).where(m.CollectionMovement.id == movement_id).with_for_update())
    if not movement or movement.collection_id != id or movement.kind != 'lost' or movement.cancelled_at:
        fail('err.record_unavailable', 404)
    _lock_note(db, id)
    movement.cancelled_at, movement.cancelled_by, movement.cancel_reason = m.now(), operator.id, data.reason.strip()
    db.flush()
    return _result(collection_view(db, db.get(m.SupplierCollection, id), True))


@router.post('/ops/supplier-collections/{id}/returns', status_code=201)
def return_to_supplier(id: str, data: c.SupplierReturnInput, idempotency_key: str = Header(),
                       operator=Depends(auth.ops_admin), db=Depends(database)):
    """Goods from this note went back to the supplier: stock drops when they
    leave. The payable is unchanged and the return is listed as awaiting
    supplier credit until their agreed credit note is recorded (R2)."""
    key, fingerprint, prior = s.replay(db, operator.id, 'supplier-return', idempotency_key, {'id': id, **data.model_dump()})
    if not prior:
        row = _lock_note(db, id)
        if data.returned_on < row.received_on:
            fail('err.return_before_receipt', 422)
        late = late_entry(operator, data.returned_on, data.late_reason)
        _within_on_hand(db, row, data.quantity)
        guard = StockGuard(db).watch('supplier_collections', row.id)
        movement = m.CollectionMovement(collection_id=row.id, kind='returned_to_supplier', quantity=data.quantity,
            occurred_on=data.returned_on, unit_cost=row.unit_cost, reason=data.reason.strip(), recorded_by=operator.id)
        db.add(movement)
        guard.check()
        log_late(db, late, 'collection_movements', movement.id, data.returned_on, operator)
        db.flush()
        s.remember(db, key, fingerprint, row.id)
    return _result(collection_view(db, db.get(m.SupplierCollection, id), True), 201)


@router.post('/ops/supplier-collections/{id}/returns/{movement_id}/credit-note', status_code=201)
def record_credit_note(id: str, movement_id: str, data: c.SupplierCreditNoteInput, idempotency_key: str = Header(),
                       operator=Depends(auth.ops_admin), db=Depends(database)):
    """The supplier agreed a credit for a return: it lowers the note's
    payable. Money already paid above the new payable becomes that
    supplier's credit (R1): it stays with them for their next invoice."""
    from .finance import record_adjustment, shrink_payable
    key, fingerprint, prior = s.replay(db, operator.id, 'supplier-credit-note', idempotency_key,
        {'id': id, 'movement_id': movement_id, **data.model_dump()})
    if not prior:
        row = db.scalar(select(m.SupplierCollection).where(m.SupplierCollection.id == id).with_for_update())
        movement = db.get(m.CollectionMovement, movement_id)
        if not row or not movement or movement.collection_id != row.id or movement.kind != 'returned_to_supplier':
            fail('err.return_not_found', 404)
        if db.scalar(select(m.SupplierCreditNote.id).where(m.SupplierCreditNote.movement_id == movement.id)):
            fail('err.credit_note_already_recorded')
        if data.issued_on < movement.occurred_on:
            fail('err.credit_note_before_return', 422)
        value = s.money(movement.quantity * movement.unit_cost)
        if data.amount > value:
            fail('err.credit_note_more_than_return', 422, value=f'{value:,.2f}')
        debt = db.scalar(select(m.LedgerDebt).where(m.LedgerDebt.id == row.debt_id).with_for_update()) if row.debt_id else None
        if debt is None or debt.status == 'cancelled' or data.amount > debt.amount:
            fail('err.credit_note_more_than_payable', 422)
        before = _note_state(row, debt)
        reason = f'Supplier credit note {data.reference}'
        released = shrink_payable(db, debt, debt.amount - data.amount, 'credit', reason, operator)
        credit = m.SupplierCreditNote(supplier_id=row.supplier_id, collection_id=row.id, movement_id=movement.id,
            debt_id=debt.id, amount=data.amount, issued_on=data.issued_on, reference=data.reference.strip(),
            note=data.note.strip(), recorded_by=operator.id)
        db.add(credit)
        db.flush()
        record_adjustment(db, 'supplier_credit_note', row, debt, f'{reason}: {data.note.strip() or "agreed"}',
            before, _note_state(row, debt), {'movement_id': movement.id, 'credit_note_id': credit.id, **released}, operator)
        s.remember(db, key, fingerprint, row.id)
    return _result(collection_view(db, db.get(m.SupplierCollection, id), True), 201)


@router.get('/supplier/collections')
def supplier_collections(user=Depends(supplier_member), db=Depends(database)):
    rows = db.scalars(select(m.SupplierCollection).where(m.SupplierCollection.supplier_id == user.id)
        .order_by(m.SupplierCollection.received_on.desc(), m.SupplierCollection.created_at.desc())).all()
    return _result([collection_view(db, row) for row in rows])
