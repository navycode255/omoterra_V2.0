"""Published future markets and supplier supply commitments."""
from __future__ import annotations

import re
from datetime import date, timedelta
from decimal import Decimal

from fastapi import APIRouter, Depends, Header
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError

from . import auth, contracts as c, models as m, notifications as notes, services as s
from .db import database
from .i18n import M, fail

router = APIRouter(prefix='/api/v1')
supplier = auth.role('supplier')
ZERO = Decimal('0')
ACTIVE = ('requested', 'approved')


def _result(value, status_code=200):
    from .main import result
    return result(value, status_code)


def approved_total(db, slot_id, exclude=None):
    query = select(func.coalesce(func.sum(m.MarketReservation.quantity_approved), 0)).where(
        m.MarketReservation.market_slot_id == slot_id, m.MarketReservation.status == 'approved')
    if exclude:
        query = query.where(m.MarketReservation.id != exclude)
    return db.scalar(query) or ZERO


def remaining(db, slot, exclude=None):
    return max(ZERO, slot.quantity_required - approved_total(db, slot.id, exclude))


def _display_status(slot, left):
    if slot.status == 'open' and left <= 0:
        return 'full'
    if slot.status == 'open' and slot.reservation_deadline < c.business_today():
        return 'closed'
    return slot.status


def _suggested_start(profile, delivery, category):
    text = ''
    if profile:
        detail = (profile.production_profile or {}).get(category, {})
        text = str(detail.get('frequency') or profile.production_frequency or '')
    match = re.search(r'(\d+)\s*(day|week|month)', text, re.I)
    if not match:
        return None
    count, unit = int(match.group(1)), match.group(2).lower()
    days = count * (1 if unit == 'day' else 7 if unit == 'week' else 30)
    return delivery - timedelta(days=days)


def slot_view(db, slot, supplier_id=None, detail=False):
    left = remaining(db, slot)
    committed = slot.quantity_required - left
    view = {key: getattr(slot, key) for key in ('id', 'category', 'delivery_date', 'reservation_deadline',
        'quantity_required', 'unit_type', 'region', 'collection_point', 'minimum_weight_kg', 'maximum_weight_kg',
        'supply_type', 'price_per_unit', 'collection_method', 'status', 'created_at', 'updated_at')}
    view.update(status=_display_status(slot, left), committed_quantity=committed, remaining_quantity=left,
        supplier_count=db.scalar(select(func.count()).select_from(m.MarketReservation).where(
            m.MarketReservation.market_slot_id == slot.id, m.MarketReservation.status == 'approved')) or 0,
        reservations_open=slot.status == 'open' and left > 0 and slot.reservation_deadline >= c.business_today())
    if detail:
        view['internal_note'] = slot.internal_note
    if supplier_id:
        own = db.scalar(select(m.MarketReservation).where(m.MarketReservation.market_slot_id == slot.id,
            m.MarketReservation.supplier_id == supplier_id))
        view['my_reservation'] = reservation_view(db, own) if own else None
        profile = db.get(m.SupplierProfile, supplier_id)
        view['suggested_start_date'] = _suggested_start(profile, slot.delivery_date, slot.category)
        batches = db.scalars(select(m.SupplierBatch).where(m.SupplierBatch.supplier_id == supplier_id,
            m.SupplierBatch.category == slot.category).order_by(m.SupplierBatch.expected_ready_date)).all()
        view['eligible_batches'] = [batch_view(row) for row in batches if row.available_to_commit > 0 and
            (not row.expected_ready_date or row.expected_ready_date <= slot.delivery_date.isoformat())]
    return view


def batch_view(row):
    return {'id': row.id, 'category': row.category, 'initial_quantity': row.initial_quantity,
        'available_quantity': row.available_to_commit, 'expected_ready_date': row.expected_ready_date,
        'status': row.status, 'form': row.form}


def reservation_view(db, row, ops=False):
    if row is None:
        return None
    slot = db.get(m.MarketSlot, row.market_slot_id)
    batch = db.get(m.SupplierBatch, row.supplier_batch_id) if row.supplier_batch_id else None
    view = {key: getattr(row, key) for key in ('id', 'market_slot_id', 'supplier_id', 'supplier_batch_id',
        'quantity_requested', 'quantity_approved', 'status', 'production_choice', 'requested_at', 'reviewed_at',
        'rejection_reason', 'cancelled_at', 'created_at', 'updated_at')}
    view.update(slot=slot_view(db, slot), batch=batch_view(batch) if batch else None)
    if ops:
        user = db.get(m.User, row.supplier_id)
        profile = db.get(m.SupplierProfile, row.supplier_id)
        view.update(supplier_name=(profile.legal_name if profile else user.name) or user.phone,
            supplier_phone=user.phone, reviewed_by=row.reviewed_by)
    return view


def _slot(db, id, lock=False):
    query = select(m.MarketSlot).where(m.MarketSlot.id == id)
    row = db.scalar(query.with_for_update() if lock else query)
    if not row:
        fail('err.market_not_found', 404)
    return row


@router.get('/market-schedule')
def supplier_schedule(user=Depends(supplier), db=Depends(database)):
    rows = db.scalars(select(m.MarketSlot).where(m.MarketSlot.status.in_(('open', 'full', 'closed')),
        m.MarketSlot.delivery_date >= c.business_today()).order_by(m.MarketSlot.delivery_date)).all()
    return _result([slot_view(db, row, user.id) for row in rows])


@router.get('/market-schedule/{id}')
def supplier_slot(id: str, user=Depends(supplier), db=Depends(database)):
    row = _slot(db, id)
    if row.status in ('draft', 'cancelled', 'completed'):
        fail('err.market_not_found', 404)
    return _result(slot_view(db, row, user.id))


@router.post('/market-schedule/{id}/reservations', status_code=201)
def request_reservation(id: str, data: c.MarketReservationInput, idempotency_key: str = Header(),
                        user=Depends(supplier), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'market-reservation', idempotency_key,
        {'slot_id': id, **data.model_dump()})
    if prior:
        return _result(reservation_view(db, db.get(m.MarketReservation, prior)), 201)
    profile = db.get(m.SupplierProfile, user.id)
    if not profile or profile.status != 'approved':
        fail('err.market_supplier_must_be_approved', 403)
    slot = _slot(db, id, True)
    left = remaining(db, slot)
    if slot.status in ('draft', 'cancelled', 'completed'):
        fail('err.market_not_found', 404)
    if slot.status == 'closed' or slot.reservation_deadline < c.business_today():
        fail('err.market_reservations_closed', 409)
    if slot.status != 'open' or left <= 0:
        fail('err.market_fully_booked', 409)
    if db.scalar(select(m.MarketReservation.id).where(m.MarketReservation.market_slot_id == id,
            m.MarketReservation.supplier_id == user.id)):
        fail('err.market_duplicate_reservation', 409)
    if data.production_choice == 'existing':
        batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == data.supplier_batch_id,
            m.SupplierBatch.supplier_id == user.id).with_for_update())
        if not batch or batch.category != slot.category:
            fail('err.market_batch_unavailable', 422)
        if data.quantity > batch.available_to_commit:
            fail('err.market_batch_only_available', 409, quantity=batch.available_to_commit)
        if batch.expected_ready_date and batch.expected_ready_date > slot.delivery_date.isoformat():
            fail('err.market_batch_ready_too_late', 422)
    else:
        batch = m.SupplierBatch(supplier_id=user.id, category=slot.category, subtype='',
            initial_quantity=data.quantity, current_quantity=data.quantity, expected_ready_date=slot.delivery_date.isoformat(),
            expected_min_weight_kg=slot.minimum_weight_kg, expected_max_weight_kg=slot.maximum_weight_kg,
            form=slot.supply_type, asking_price_per_unit=slot.price_per_unit,
            region=slot.region or profile.region, private_pickup_location=profile.internal_pickup_address,
            status='growing')
        db.add(batch); db.flush()
    row = m.MarketReservation(market_slot_id=id, supplier_id=user.id, supplier_batch_id=batch.id,
        quantity_requested=data.quantity, production_choice=data.production_choice)
    db.add(row); db.flush()
    notes.notify(db, user.id, 'supplier', 'market_requested', M('notify.market_requested',
        quantity=f'{data.quantity:g}', product=slot.category.replace('_', ' ')), '/account/market-schedule')
    s.remember(db, key, fingerprint, row.id)
    return _result(reservation_view(db, row), 201)


@router.get('/supplier/market-reservations')
def my_reservations(user=Depends(supplier), db=Depends(database)):
    rows = db.scalars(select(m.MarketReservation).where(m.MarketReservation.supplier_id == user.id)
        .order_by(m.MarketReservation.created_at.desc())).all()
    return _result([reservation_view(db, row) for row in rows])


@router.get('/supplier/market-reservations/{id}')
def my_reservation(id: str, user=Depends(supplier), db=Depends(database)):
    row = db.scalar(select(m.MarketReservation).where(m.MarketReservation.id == id,
        m.MarketReservation.supplier_id == user.id))
    if not row:
        fail('err.market_reservation_not_found', 404)
    return _result(reservation_view(db, row))


def _release_batch(db, reservation):
    if reservation.status == 'approved' and reservation.quantity_approved and reservation.supplier_batch_id:
        batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == reservation.supplier_batch_id).with_for_update())
        # Only what delivery notes have not filled is still held (M2.1).
        from .batch_stock import outstanding
        batch.reserved_quantity -= outstanding(db, 'market_reservation', reservation)
        if batch.status in ('fully_reserved', 'partially_reserved'):
            batch.status = 'partially_reserved' if batch.reserved_quantity else ('ready' if batch.expected_ready_date and batch.expected_ready_date <= c.business_today().isoformat() else 'growing')


@router.post('/supplier/market-reservations/{id}/cancel')
def cancel_own_reservation(id: str, idempotency_key: str = Header(), user=Depends(supplier), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'market-reservation-cancel', idempotency_key, {'id': id})
    row = db.scalar(select(m.MarketReservation).where(m.MarketReservation.id == id,
        m.MarketReservation.supplier_id == user.id).with_for_update())
    if not row:
        fail('err.market_reservation_not_found', 404)
    slot = _slot(db, row.market_slot_id, True)
    if not prior:
        if row.status not in ACTIVE or (row.status == 'approved' and slot.reservation_deadline < c.business_today()):
            fail('err.market_reservation_cannot_cancel', 409)
        _release_batch(db, row)
        row.status, row.cancelled_at = 'cancelled', m.now()
        if slot.status == 'full' and slot.reservation_deadline >= c.business_today():
            slot.status = 'open'
        s.remember(db, key, fingerprint, row.id)
    return _result(reservation_view(db, row))


# Operations -----------------------------------------------------------------

@router.get('/ops/market-slots')
def ops_slots(operator=Depends(auth.ops), db=Depends(database)):
    rows = db.scalars(select(m.MarketSlot).order_by(m.MarketSlot.delivery_date.desc())).all()
    return _result([slot_view(db, row, detail=True) for row in rows])


@router.post('/ops/market-slots', status_code=201)
def create_slot(data: c.MarketSlotInput, idempotency_key: str = Header(), operator=Depends(auth.ops_admin),
                db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'market-slot', idempotency_key, data.model_dump())
    if prior:
        return _result(slot_view(db, db.get(m.MarketSlot, prior), detail=True), 201)
    if data.status not in ('draft', 'open'):
        fail('err.market_new_status_invalid', 422)
    row = m.MarketSlot(**data.model_dump(), created_by=operator.id, updated_by=operator.id)
    db.add(row); db.flush()
    s.remember(db, key, fingerprint, row.id)
    if row.status == 'open':
        _announce_slot(db, row)
    return _result(slot_view(db, row, detail=True), 201)


@router.get('/ops/market-slots/{id}')
def ops_slot(id: str, operator=Depends(auth.ops), db=Depends(database)):
    return _result(slot_view(db, _slot(db, id), detail=True))


@router.patch('/ops/market-slots/{id}')
def edit_slot(id: str, data: c.MarketSlotInput, operator=Depends(auth.ops_admin), db=Depends(database)):
    row = _slot(db, id, True)
    committed = approved_total(db, id)
    if data.quantity_required < committed:
        fail('err.market_required_below_committed', 409, quantity=f'{committed:g}')
    before = (row.delivery_date, row.quantity_required, row.price_per_unit, row.collection_method)
    old_status = row.status
    for field, value in data.model_dump().items():
        setattr(row, field, value)
    row.updated_by = operator.id
    if committed >= row.quantity_required:
        row.status = 'full'
    elif old_status == 'full' and row.status == 'full' and row.reservation_deadline >= c.business_today():
        row.status = 'open'
    db.flush()
    after = (row.delivery_date, row.quantity_required, row.price_per_unit, row.collection_method)
    if old_status == 'draft' and row.status == 'open':
        _announce_slot(db, row)
    elif before != after:
        _notify_reservations(db, row, 'market_changed', M('notify.market_changed', date=row.delivery_date))
    return _result(slot_view(db, row, detail=True))


@router.post('/ops/market-slots/{id}/status')
def set_slot_status(id: str, data: c.MarketSlotStatusInput, idempotency_key: str = Header(),
                    operator=Depends(auth.ops_admin), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'market-slot-status', idempotency_key,
        {'id': id, **data.model_dump()})
    slot = _slot(db, id, True)
    if not prior:
        if data.status == 'open' and (slot.reservation_deadline < c.business_today() or remaining(db, slot) <= 0):
            fail('err.market_cannot_reopen', 409)
        slot.status, slot.updated_by = data.status, operator.id
        if data.status == 'cancelled':
            reservations = db.scalars(select(m.MarketReservation).where(m.MarketReservation.market_slot_id == id,
                m.MarketReservation.status.in_(ACTIVE)).with_for_update()).all()
            for reservation in reservations:
                _release_batch(db, reservation)
                reservation.status, reservation.cancelled_at = 'cancelled', m.now()
            _notify_reservations(db, slot, 'market_cancelled', M('notify.market_cancelled', date=slot.delivery_date), statuses=('cancelled',))
        elif data.status == 'open':
            _announce_slot(db, slot)
        s.remember(db, key, fingerprint, slot.id)
    return _result(slot_view(db, slot, detail=True))


@router.get('/ops/market-slots/{id}/reservations')
def ops_reservations(id: str, operator=Depends(auth.ops), db=Depends(database)):
    _slot(db, id)
    rows = db.scalars(select(m.MarketReservation).where(m.MarketReservation.market_slot_id == id)
        .order_by(m.MarketReservation.created_at)).all()
    return _result([reservation_view(db, row, True) for row in rows])


@router.post('/ops/market-reservations/{id}/review')
def review_reservation(id: str, data: c.MarketReservationReview, idempotency_key: str = Header(),
                       operator=Depends(auth.ops_admin), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, operator.id, 'market-reservation-review', idempotency_key,
        {'id': id, **data.model_dump()})
    row = db.scalar(select(m.MarketReservation).where(m.MarketReservation.id == id).with_for_update())
    if not row:
        fail('err.market_reservation_not_found', 404)
    slot = _slot(db, row.market_slot_id, True)
    if prior:
        return _result(reservation_view(db, row, True))
    if row.status not in ('requested', 'approved'):
        fail('err.market_reservation_already_reviewed', 409)
    old = row.quantity_approved if row.status == 'approved' else ZERO
    batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == row.supplier_batch_id).with_for_update())
    if data.action == 'reject':
        _release_batch(db, row)
        row.status, row.quantity_approved, row.rejection_reason = 'rejected', None, data.reason.strip()
        message = M('notify.market_rejected', date=slot.delivery_date)
        kind = 'market_rejected'
    else:
        quantity = data.approved_quantity
        if quantity > row.quantity_requested:
            fail('err.market_approval_above_request', 422)
        available = remaining(db, slot, row.id)
        if quantity > available:
            fail('err.market_only_remaining', 409, quantity=f'{available:,.3f}'.rstrip('0').rstrip('.'), unit=slot.unit_type)
        batch_available = batch.available_to_commit + old
        from .batch_stock import fulfilled
        if quantity < fulfilled(db, 'market_reservation', row.id):
            fail('err.reservation_below_received', 422)
        if quantity > batch_available:
            fail('err.market_batch_only_available', 409, quantity=batch_available)
        batch.reserved_quantity += quantity - old
        batch.status = 'fully_reserved' if batch.available_to_commit <= 0 else 'partially_reserved'
        row.status, row.quantity_approved, row.rejection_reason = 'approved', quantity, ''
        differing = quantity != row.quantity_requested
        message = M('notify.market_approved_changed' if differing else 'notify.market_approved',
            quantity=f'{quantity:g}', date=slot.delivery_date)
        kind = 'market_approved'
    row.reviewed_at, row.reviewed_by = m.now(), operator.id
    slot.status = 'full' if remaining(db, slot) <= 0 else ('open' if slot.status == 'full' else slot.status)
    notes.notify(db, row.supplier_id, 'supplier', kind, message, '/account/market-schedule')
    s.remember(db, key, fingerprint, row.id)
    return _result(reservation_view(db, row, True))


def _announce_slot(db, slot):
    profiles = db.scalars(select(m.SupplierProfile).where(m.SupplierProfile.status == 'approved')).all()
    for profile in profiles:
        if slot.category in (profile.categories or []):
            notes.notify(db, profile.user_id, 'supplier', 'market_available', M('notify.market_available',
                product=slot.category.replace('_', ' '), date=slot.delivery_date), '/account/market-schedule')


def _notify_reservations(db, slot, kind, message, statuses=ACTIVE):
    supplier_ids = db.scalars(select(m.MarketReservation.supplier_id).where(
        m.MarketReservation.market_slot_id == slot.id, m.MarketReservation.status.in_(statuses))).all()
    for supplier_id in set(supplier_ids):
        notes.notify(db, supplier_id, 'supplier', kind, message, '/account/market-schedule')
