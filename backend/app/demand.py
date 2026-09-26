"""Managed demand operations, separated from short checkout holds and payments."""
from datetime import date
from decimal import Decimal
from sqlalchemy import func, select
from . import models as m, services as s

SECURED_ALLOCATION_STATES = ('reserved', 'supplier_confirmed', 'ready', 'collected', 'verified', 'delivered', 'completed')


def secured(db, demand_id):
    return db.scalar(select(func.coalesce(func.sum(m.DemandAllocation.allocated_quantity), 0)).where(
        m.DemandAllocation.demand_id == demand_id,
        m.DemandAllocation.status.in_(SECURED_ALLOCATION_STATES))) or Decimal('0')


def remaining(db, demand):
    return max(Decimal('0'), Decimal(demand.quantity) - Decimal(secured(db, demand.id)))


def refresh_demand_status(db, demand):
    if demand.status in ('cancelled', 'completed'):
        return
    amount = secured(db, demand.id)
    if amount <= 0:
        demand.status = 'open'
    elif amount < Decimal(demand.quantity):
        demand.status = 'partially_matched'
    else:
        demand.status = 'fully_matched'


BUYER_EDITABLE = ('open', 'submitted', 'sourcing')


def buyer_requirement(db, demand):
    secured_quantity = secured(db, demand.id)
    return {
        'id': demand.id,
        'requirement_number': demand.requirement_number,
        'category': demand.category,
        'product_subtype': demand.product_subtype,
        'quantity': demand.quantity,
        'unit_type': demand.unit_type,
        'minimum_weight_kg': demand.minimum_weight_kg,
        'maximum_weight_kg': demand.maximum_weight_kg,
        'weight_or_size_requirement': demand.weight_or_size_requirement,
        'live_dressed_or_cut': demand.live_dressed_or_cut,
        'needed_by_date': demand.needed_by_date,
        'delivery_area': demand.delivery_area,
        'delivery_region': demand.delivery_region,
        'delivery_notes': demand.delivery_notes,
        'requirement_type': demand.requirement_type,
        'recurrence_frequency': demand.recurrence_frequency,
        'preferred_weekdays': demand.preferred_weekdays,
        'notes': demand.notes,
        'created_by': demand.created_by,
        'status': 'confirmed' if demand.status == 'converted' else demand.status,
        'secured_quantity': secured_quantity,
        'remaining_quantity': max(Decimal('0'), Decimal(demand.quantity) - secured_quantity),
        # The buyer may still change it: nothing secured and not yet confirmed.
        'editable': demand.status in BUYER_EDITABLE and secured_quantity == 0,
        'created_at': demand.created_at,
        'converted_order_id': demand.converted_order_id,
    }


def supplier_requirement(db, demand):
    # Deliberately excludes buyer IDs, notes, contacts, and exact delivery instructions.
    row = buyer_requirement(db, demand)
    return {k: row[k] for k in (
        'id', 'requirement_number', 'category', 'product_subtype', 'quantity', 'unit_type',
        'minimum_weight_kg', 'maximum_weight_kg', 'weight_or_size_requirement',
        'live_dressed_or_cut', 'needed_by_date', 'delivery_region', 'requirement_type',
        'recurrence_frequency', 'preferred_weekdays', 'status', 'secured_quantity', 'remaining_quantity')}


def batch_view(batch, private=False):
    result = {k: getattr(batch, k) for k in (
        'id', 'category', 'subtype', 'initial_quantity', 'current_quantity', 'reserved_quantity',
        'sold_quantity', 'externally_sold_quantity', 'current_age', 'age_unit', 'expected_ready_date',
        'expected_min_weight_kg', 'expected_max_weight_kg', 'actual_average_weight_kg', 'form',
        'region', 'photos', 'status', 'approved_at')}
    result['available_to_commit'] = batch.available_to_commit
    if private:
        result.update(asking_price_per_unit=batch.asking_price_per_unit,
                      supplier_payout_price_per_unit=batch.supplier_payout_price_per_unit,
                      buyer_price_per_unit=batch.buyer_price_per_unit,
                      private_pickup_location=batch.private_pickup_location)
    return result


def offer_view(offer, private=False):
    result = {k: getattr(offer, k) for k in ('id', 'demand_id', 'batch_id', 'offered_quantity', 'expected_ready_date', 'expected_min_weight_kg', 'expected_max_weight_kg', 'accepted_quantity', 'status', 'created_at')}
    if private:
        result.update(supplier_id=offer.supplier_id, asking_price_per_unit=offer.asking_price_per_unit,
                      supplier_notes=offer.supplier_notes, reviewed_at=offer.reviewed_at)
    return result


def allocation_view(allocation, operator=False):
    result = {k: getattr(allocation, k) for k in ('id', 'allocated_quantity', 'accepted_quantity', 'rejected_quantity', 'status', 'created_at')}
    if operator:
        result.update(demand_id=allocation.demand_id, supplier_id=allocation.supplier_id,
                      supplier_batch_id=allocation.supplier_batch_id, supply_offer_id=allocation.supply_offer_id)
    return result


def candidate_batches(db, demand):
    query = select(m.SupplierBatch, m.User, m.SupplierProfile).join(m.User, m.User.id == m.SupplierBatch.supplier_id).outerjoin(
        m.SupplierProfile, m.SupplierProfile.user_id == m.SupplierBatch.supplier_id).where(
        m.SupplierBatch.category == demand.category,
        m.SupplierBatch.status.in_(('growing', 'ready', 'partially_reserved')),
        m.SupplierProfile.status == 'approved')
    rows = db.execute(query.order_by(m.SupplierBatch.expected_ready_date.asc().nullslast(), m.SupplierBatch.created_at.asc())).all()
    candidates = []
    target_date = demand.needed_by_date
    for batch, user, profile in rows:
        if batch.available_to_commit <= 0 or batch.approved_at is None:
            continue
        ready_date = batch.expected_ready_date or date.today().isoformat()
        if target_date and ready_date > target_date:
            continue
        low, high = demand.minimum_weight_kg, demand.maximum_weight_kg
        batch_low, batch_high = batch.expected_min_weight_kg, batch.expected_max_weight_kg
        if low is not None and batch_high is not None and batch_high < low:
            continue
        if high is not None and batch_low is not None and batch_low > high:
            continue
        if demand.live_dressed_or_cut and demand.live_dressed_or_cut.lower() not in (batch.form or '').lower():
            continue
        if demand.delivery_region and batch.region and demand.delivery_region.casefold() != batch.region.casefold():
            # Keep near-region decisions manual, but only present plausible same-region candidates in V1.
            if demand.delivery_region.casefold() not in batch.region.casefold() and batch.region.casefold() not in demand.delivery_region.casefold():
                continue
        candidates.append({
            'batch': batch_view(batch, private=True),
            'supplier_id': user.id,
            'supplier_name': profile.legal_name if profile else user.name,
            'supplier_phone': user.phone,
            'supplier_public_alias': profile.public_alias if profile and profile.alias_approved else 'Unapproved alias',
            'supplier_approved': bool(profile and profile.alias_approved),
            'available_quantity': batch.available_to_commit,
            'ready_date': ready_date,
            'asking_price_per_unit': batch.asking_price_per_unit,
        })
    return candidates


def allocation_create(db, demand, batch, quantity, actor_id, offer=None):
    s.commerce_lock(db)
    demand = db.scalar(select(m.SourcingRequest).where(m.SourcingRequest.id == demand.id).with_for_update())
    batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == batch.id).with_for_update())
    if demand.status in ('cancelled', 'completed'):
        s.fail('err.requirement_closed')
    if quantity <= 0 or quantity > remaining(db, demand):
        s.fail('err.allocation_exceeds_remaining_requirement', 422)
    if quantity > batch.available_to_commit:
        s.fail('err.supplier_batch_no_longer_quantity', 409)
    if batch.category != demand.category:
        s.fail('err.supplier_batch_category_does_not', 422)
    if offer and (offer.demand_id != demand.id or offer.supplier_id != batch.supplier_id or offer.batch_id != batch.id or offer.status not in ('accepted', 'partially_accepted')):
        s.fail('err.reviewed_supply_offer_does_not', 422)
    batch.reserved_quantity += quantity
    if batch.available_to_commit <= 0:
        batch.status = 'fully_reserved'
    elif batch.reserved_quantity:
        batch.status = 'partially_reserved'
    allocation = m.DemandAllocation(demand_id=demand.id, supply_offer_id=offer.id if offer else None,
        supplier_id=batch.supplier_id, supplier_batch_id=batch.id, allocated_quantity=quantity,
        status='reserved', allocated_by=actor_id, updated_by=actor_id)
    db.add(allocation)
    db.flush()
    refresh_demand_status(db, demand)
    return allocation


def allocation_update(db, allocation, quantity, status, actor_id):
    s.commerce_lock(db)
    allocation = db.scalar(select(m.DemandAllocation).where(m.DemandAllocation.id == allocation.id).with_for_update())
    batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == allocation.supplier_batch_id).with_for_update())
    demand = db.scalar(select(m.SourcingRequest).where(m.SourcingRequest.id == allocation.demand_id).with_for_update())
    active = allocation.status in SECURED_ALLOCATION_STATES
    if status == 'cancelled' and active:
        batch.reserved_quantity -= allocation.allocated_quantity
        allocation.status = 'cancelled'
    elif quantity is not None:
        if not active:
            s.fail('err.only_active_allocations_changed')
        delta = quantity - allocation.allocated_quantity
        if quantity <= 0 or quantity > allocation.allocated_quantity:
            s.fail('err.allocation_only_reduced_here_create', 422)
        batch.reserved_quantity += delta
        allocation.allocated_quantity = quantity
        if batch.reserved_quantity == 0 and batch.status == 'partially_reserved':
            batch.status = 'ready' if batch.expected_ready_date and batch.expected_ready_date <= date.today().isoformat() else 'growing'
    allocation.updated_by = actor_id
    if batch.available_to_commit > 0 and batch.status == 'fully_reserved':
        batch.status = 'partially_reserved' if batch.reserved_quantity else 'ready'
    refresh_demand_status(db, demand)
    db.flush()
    return allocation
