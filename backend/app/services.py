import hashlib
import json
from datetime import timedelta
from decimal import Decimal, ROUND_HALF_UP
from sqlalchemy import select, text
from . import models as m
from .config import settings
from . import inventory as inv
from . import notifications as notes, i18n
from .i18n import M, fail  # noqa: F401  (s.fail is used across the app)

STATUS = {
    'requested': 'confirmed', 'supply_confirmed': 'confirmed', 'reserved': 'confirmed',
    'pickup_scheduled': 'preparing', 'collected': 'preparing', 'quality_checked': 'preparing',
    'in_transit': 'on_the_way', 'delivered': 'delivered', 'completed': 'delivered',
    'cancelled': 'cancelled', 'payment_failed': 'cancelled',
}
ACTIVITY = {'reserved': 'Order confirmed', 'supply_confirmed': 'Stock secured', 'collected': 'Collection completed', 'in_transit': 'Order dispatched', 'delivered': 'Delivered', 'cancelled': 'Order cancelled', 'payment_failed': 'Payment failed'}
TRANSITIONS = {
    'reserved': {'supply_confirmed', 'pickup_scheduled', 'cancelled', 'payment_failed'},
    'requested': {'supply_confirmed', 'cancelled', 'payment_failed'},
    'supply_confirmed': {'pickup_scheduled', 'cancelled', 'payment_failed'},
    'pickup_scheduled': {'collected', 'cancelled', 'payment_failed'},
    'collected': {'quality_checked', 'cancelled', 'payment_failed'},
    'quality_checked': {'in_transit', 'cancelled', 'payment_failed'},
    'in_transit': {'delivered', 'cancelled', 'payment_failed'},
    'delivered': {'completed'}, 'completed': set(), 'cancelled': set(), 'payment_failed': set(),
}


def money(value):
    return Decimal(value).quantize(Decimal('.01'), rounding=ROUND_HALF_UP)


def commerce_lock(db):
    # Transaction-scoped PostgreSQL serialization, intentionally simple for V1.
    # Every inventory/order/payment mutation takes this lock before row locks.
    db.execute(text('SELECT pg_advisory_xact_lock(734129001)'))


def owned(db, model, id, owner, field='user_id', lock=False):
    q = select(model).where(model.id == id, getattr(model, field) == owner)
    if lock:
        q = q.with_for_update()
    result = db.scalar(q)
    if not result:
        fail('err.record_unavailable', 404)
    return result


def replay(db, actor, operation, key, payload):
    if not key or not 8 <= len(key) <= 128:
        fail('err.provide_idempotency_key_between_8', 422)
    commerce_lock(db)
    scoped = hashlib.sha256(f'{actor}:{operation}:{key}'.encode()).hexdigest()
    fingerprint = hashlib.sha256(json.dumps(payload, sort_keys=True, default=str).encode()).hexdigest()
    previous = db.get(m.Idempotency, scoped)
    if previous and previous.fingerprint != fingerprint:
        fail('err.retry_key_already_used_different')
    return scoped, fingerprint, previous.resource_id if previous else None


def remember(db, key, fingerprint, resource):
    db.add(m.Idempotency(key=key, fingerprint=fingerprint, resource_id=resource))
    db.flush()


def fresh(listing, at=None):
    at = at or m.now()
    return listing.listing_status == 'live' and listing.confirmation_due_at is not None and listing.confirmation_due_at > at


def refresh_listing(db, listing):
    at = m.now()
    holds = db.scalars(select(m.StockReservation).where(m.StockReservation.listing_id == listing.id, m.StockReservation.status == 'active', m.StockReservation.expires_at <= at).with_for_update()).all()
    for hold in holds:
        release(db, hold, listing, 'expired')
    if listing.listing_status == 'live' and (listing.confirmation_due_at is None or listing.confirmation_due_at <= at):
        listing.listing_status = 'needs_confirmation'
    db.flush()


def release(db, hold, listing, status):
    if hold.status not in ['active', 'confirmed']:
        return
    inv.ensure_history(db, listing)
    before = inv.balances(listing)
    listing.quantity_reserved -= hold.quantity
    hold.status = status
    inv.movement(db, listing, 'hold_' + status, before, f'hold:{hold.id}:{status}')
    if listing.listing_status == 'sold_out' and listing.quantity_available > 0:
        listing.listing_status = 'live' if listing.confirmation_due_at and listing.confirmation_due_at > m.now() else 'needs_confirmation'
    db.flush()


def reserve(db, buyer, data):
    commerce_lock(db)
    listing = db.scalar(select(m.Listing).where(m.Listing.id == data.listing_id).with_for_update())
    if not listing:
        fail('err.supply_no_longer_available', 404)
    refresh_listing(db, listing)
    supplier_profile = db.get(m.SupplierProfile, listing.supplier_id)
    if not supplier_profile or supplier_profile.status != 'approved':
        fail('err.supply_not_available_right_now', 404)
    if listing.supplier_id == buyer:
        fail('err.cannot_reserve_own_stock')
    if not fresh(listing):
        db.commit()
        fail('err.stock_awaiting_confirmation_paused_browse')
    if listing.unit_type != 'kg' and data.quantity % 1:
        fail('err.choose_whole_number_birds_animals', 422)
    if data.quantity > listing.quantity_available:
        fail('err.requested_quantity_no_longer_available')
    inv.ensure_history(db, listing)
    before = inv.balances(listing)
    hold = m.StockReservation(listing_id=listing.id, buyer_id=buyer, quantity=data.quantity, expires_at=m.now() + timedelta(minutes=settings().reservation_minutes))
    db.add(hold)
    listing.quantity_reserved += data.quantity
    db.flush()
    inv.movement(db, listing, 'hold_created', before, f'hold:{hold.id}:created')
    return hold


def checkout(db, buyer, data, key, sourcing_id=None):
    scoped, fingerprint, prior = replay(db, buyer, 'order', key, data.model_dump() | {'sourcing_request_id': sourcing_id})
    if prior:
        return db.get(m.Order, prior)
    hold = owned(db, m.StockReservation, data.reservation_id, buyer, 'buyer_id', True)
    listing = db.scalar(select(m.Listing).where(m.Listing.id == hold.listing_id).with_for_update())
    refresh_listing(db, listing)
    if hold.status != 'active':
        db.commit()  # Preserve exact expiry releases even though checkout is rejected.
        fail('err.reservation_expired_already_used_reserve')
    if not fresh(listing):
        release(db, hold, listing, 'released')
        db.commit()
        fail('err.listing_no_longer_available_release')
    address = owned(db, m.Address, data.delivery_address_id, buyer)
    if address.deleted:
        fail('err.select_current_delivery_address', 422)
    if data.payment_method != 'pay_on_delivery':
        fail('err.pay_now_not_available_until', 422)
    total = money(hold.quantity * listing.buyer_price_per_unit)
    order = m.Order(buyer_id=buyer, delivery_address_id=address.id,
        delivery_snapshot={k: getattr(address, k) for k in ['label', 'recipient_name', 'phone', 'region', 'district_area', 'address_text']},
        preferred_delivery_date=data.preferred_delivery_date.isoformat(), payment_method=data.payment_method,
        expected_quantity=hold.quantity, total_amount=total, idempotency_key=scoped,
        sourcing_request_id=sourcing_id, activity=[{'label': 'Order confirmed', 'at': m.now().isoformat()}])
    db.add(order)
    db.flush()
    db.add(m.OrderItem(order_id=order.id, listing_id=listing.id, quantity=hold.quantity, unit_price=listing.buyer_price_per_unit,
        subtotal=total, asking_snapshot=listing.farmer_asking_price_per_unit, payout_snapshot=listing.supplier_payout_price_per_unit))
    db.add(m.Payment(order_id=order.id, amount=total, method=data.payment_method, idempotency_key=scoped))
    hold.status = 'confirmed'
    hold.order_id = order.id
    inv.movement(db, listing, 'hold_confirmed', inv.balances(listing), f'hold:{hold.id}:confirmed')
    remember(db, scoped, fingerprint, order.id)
    notes.notify(db, listing.supplier_id, 'supplier', 'order_new',
        M('notify.order_new', quantity=quantity(hold.quantity), what=i18n.category(listing.category)),
        f'/supplier-orders/{hold.id}')
    return order


def quantity(value):
    return format(Decimal(value).normalize(), 'f')


def category(value):
    return value.replace('_', ' ')


BUYER_UPDATES = {
    'supply_confirmed': 'notify.order_supply_confirmed', 'pickup_scheduled': 'notify.order_pickup_scheduled',
    'in_transit': 'notify.order_in_transit', 'delivered': 'notify.order_delivered',
    'cancelled': 'notify.order_cancelled', 'payment_failed': 'notify.order_payment_failed',
}


def _notify_order_update(db, order, target, holds, by_buyer):
    if target in BUYER_UPDATES and not (by_buyer and target == 'cancelled'):
        notes.notify(db, order.buyer_id, 'buyer', f'order_{target}', M(BUYER_UPDATES[target]), f'/order/{order.id}')
    if target not in ('pickup_scheduled', 'delivered', 'cancelled', 'payment_failed'):
        return
    for hold in holds:
        listing = db.get(m.Listing, hold.listing_id)
        what = dict(quantity=quantity(hold.quantity), what=i18n.category(listing.category))
        if target == 'pickup_scheduled':
            when = M('notify.on_date', date=order.expected_collection_date) if order.expected_collection_date else ''
            notes.notify(db, listing.supplier_id, 'supplier', 'collection_scheduled',
                M('notify.collection_scheduled', when=when, **what), f'/supplier-orders/{hold.id}')
        elif target == 'delivered':
            notes.notify(db, listing.supplier_id, 'supplier', 'supply_delivered',
                M('notify.supply_delivered', what=i18n.category(listing.category)), '/payouts')
        else:
            notes.notify(db, listing.supplier_id, 'supplier', 'order_cancelled',
                M('notify.supplier_order_cancelled', **what), f'/stock/{listing.id}')


def advance(db, order, data, by_buyer=False):
    commerce_lock(db)
    target = data.internal_status
    if data.expected_collection_date is not None:
        order.expected_collection_date = data.expected_collection_date.isoformat()
    if target == order.internal_status:
        return order
    if target not in TRANSITIONS[order.internal_status]:
        fail('err.order_cannot_move_requested_status')
    holds = db.scalars(select(m.StockReservation).where(m.StockReservation.order_id == order.id).with_for_update()).all()
    if target in ['cancelled', 'payment_failed']:
        if order.payment_status in ['paid', 'partial']:
            fail('err.recorded_payment_requires_manual_refund')
        for hold in holds:
            listing = db.scalar(select(m.Listing).where(m.Listing.id == hold.listing_id).with_for_update())
            release(db, hold, listing, 'cancelled')
        if target == 'payment_failed':
            order.payment_status = 'failed'
            db.scalar(select(m.Payment).where(m.Payment.order_id == order.id)).status = 'failed'
    if target == 'quality_checked':
        items = db.scalars(select(m.OrderItem).where(m.OrderItem.order_id == order.id).with_for_update()).all()
        if data.collection_results:
            by_id = {item.id: item for item in items}
            submitted = {row.order_item_id: row for row in data.collection_results}
            if len(submitted) != len(data.collection_results) or set(submitted) != set(by_id):
                fail('err.record_collection_results_every_supplier', 422)
            accepted_total = rejected_total = Decimal('0')
            for item in items:
                row = submitted[item.id]
                if row.actual_quantity + row.rejected_quantity != item.quantity:
                    fail('err.accepted_plus_rejected_quantity_must', 422)
                listing = db.get(m.Listing, item.listing_id)
                if listing.unit_type != 'kg' and (row.actual_quantity % 1 or row.rejected_quantity % 1):
                    fail('err.birds_animals_require_whole_quantities', 422)
                item.actual_quantity, item.rejected_quantity = row.actual_quantity, row.rejected_quantity
                accepted_total += row.actual_quantity
                rejected_total += row.rejected_quantity
            order.actual_quantity, order.rejected_quantity = accepted_total, rejected_total
        else:
            if len(items) != 1 or data.actual_quantity is None or data.rejected_quantity is None:
                fail('err.record_collection_results_every_supplier_2', 422)
            item = items[0]
            if data.actual_quantity + data.rejected_quantity != item.quantity:
                fail('err.accepted_plus_rejected_quantity_must_2', 422)
            listing = db.get(m.Listing, item.listing_id)
            if listing.unit_type != 'kg' and (data.actual_quantity % 1 or data.rejected_quantity % 1):
                fail('err.birds_animals_require_whole_quantities', 422)
            item.actual_quantity, item.rejected_quantity = data.actual_quantity, data.rejected_quantity
            order.actual_quantity, order.rejected_quantity = data.actual_quantity, data.rejected_quantity
        order.actual_weight, order.collection_notes = data.actual_weight, data.collection_notes
        # Buyer is billed only accepted units at each item's agreed price.
        order.total_amount = money(sum((item.unit_price * item.actual_quantity for item in items), Decimal('0')))
        payment = db.scalar(select(m.Payment).where(m.Payment.order_id == order.id))
        payment.amount = order.total_amount
        if order.total_amount == 0:
            payment.status = order.payment_status = 'paid'
            payment.paid_at = m.now()
    if target == 'delivered':
        if order.actual_quantity is None:
            fail('err.complete_quality_check_before_delivery')
        for hold in holds:
            listing = db.scalar(select(m.Listing).where(m.Listing.id == hold.listing_id).with_for_update())
            if hold.status != 'confirmed':
                fail('err.order_reservation_no_longer_confirmed')
            # Release the exact original hold; only this supplier item's accepted units become sold.
            item = db.scalar(select(m.OrderItem).where(m.OrderItem.order_id == order.id, m.OrderItem.listing_id == listing.id))
            accepted = item.actual_quantity if item.actual_quantity is not None else order.actual_quantity
            release(db, hold, listing, 'released')
            before_sale = inv.balances(listing)
            listing.quantity_sold += accepted
            if listing.quantity_available == 0:
                listing.listing_status = 'sold_out'
            if accepted > 0:
                db.add(m.StockSale(listing_id=listing.id, supplier_id=listing.supplier_id, source='omoterra', quantity=accepted, sold_at=m.now(), order_item_id=item.id))
                inv.movement(db, listing, 'sale_omoterra', before_sale, f'order-item:{item.id}:sold', 'Delivered through Omoterra')
            if accepted > 0:
                db.add(m.Settlement(supplier_id=listing.supplier_id, order_item_id=item.id,
                    farmer_asking_price_per_unit=item.asking_snapshot, supplier_payout_price_per_unit=item.payout_snapshot,
                    commission_amount_per_unit=item.asking_snapshot - item.payout_snapshot,
                    quantity=accepted, total_payable=money(accepted * item.payout_snapshot)))
            profile = db.get(m.SupplierProfile, listing.supplier_id)
            if accepted > 0:
                profile.completed_supplies_count += 1
            if item.demand_allocation_id:
                allocation = db.get(m.DemandAllocation, item.demand_allocation_id)
                if allocation:
                    allocation.accepted_quantity = accepted
                    allocation.rejected_quantity = item.rejected_quantity or Decimal('0')
                    allocation.status = 'delivered'
    if target == 'completed' and order.payment_status != 'paid':
        fail('err.reconcile_buyer_payment_before_completing')
    order.internal_status = target
    if order.sourcing_request_id:
        from . import demand as dm
        request = db.scalar(select(m.SourcingRequest).where(m.SourcingRequest.id == order.sourcing_request_id).with_for_update())
        if request:
            allocations = db.scalars(select(m.DemandAllocation).where(m.DemandAllocation.demand_id == request.id).with_for_update()).all()
            if target == 'cancelled':
                for allocation in allocations:
                    if allocation.status in dm.SECURED_ALLOCATION_STATES:
                        batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == allocation.supplier_batch_id).with_for_update())
                        batch.current_quantity += allocation.allocated_quantity
                        batch.status = ('partially_reserved' if batch.reserved_quantity > 0 else
                            'ready' if batch.expected_ready_date and batch.expected_ready_date <= m.now().date().isoformat() else 'growing')
                        allocation.status = 'cancelled'
                request.converted_order_id = None
                dm.refresh_demand_status(db, request)
            elif target in ('supply_confirmed', 'pickup_scheduled', 'collected', 'quality_checked', 'in_transit'):
                request.status = 'fulfilling'
                for allocation in allocations:
                    if allocation.status in dm.SECURED_ALLOCATION_STATES: allocation.status = target
            elif target in ('delivered', 'completed'):
                request.status = 'completed'
    if target in ACTIVITY:
        order.activity = [*order.activity, {'label': ACTIVITY[target], 'at': m.now().isoformat()}]
    _notify_order_update(db, order, target, holds, by_buyer)
    db.flush()
    return order


def buyer_listing(db, listing, detail=False, reputations=None):
    from . import ratings
    result = {k: getattr(listing, k) for k in ['id', 'category', 'unit_type', 'region', 'photos', 'video', 'specs', 'buyer_price_per_unit']}
    result['quantity_available'] = listing.quantity_available
    # One lookup per supplier per request, however many of their listings show.
    cache = reputations if reputations is not None else {}
    if listing.supplier_id not in cache:
        cache[listing.supplier_id] = ratings.reputation(db, listing.supplier_id)
    reputation = cache[listing.supplier_id]
    result['supplier_rating'] = {'rating': reputation['rating'], 'ratings': reputation['ratings']}
    if detail:
        profile = db.get(m.SupplierProfile, listing.supplier_id)
        result['supplier'] = {'public_alias': profile.public_alias if profile and profile.alias_approved else 'Omoterra supply partner', 'region': listing.region, 'approval': 'Omoterra Approved',
            'reputation': reputation}
    return result


def supplier_listing(listing):
    result = {k: getattr(listing, k) for k in ['id', 'category', 'unit_type', 'region', 'photos', 'video', 'specs', 'farmer_asking_price_per_unit', 'quantity_total', 'quantity_reserved', 'quantity_sold', 'listing_status', 'confirmation_due_at', 'review_note']}
    result['quantity_available'] = listing.quantity_available
    result['approved'] = listing.approved_at is not None
    return result


def buyer_order(db, order):
    result = {k: getattr(order, k) for k in ['id', 'preferred_delivery_date', 'payment_method', 'payment_status', 'total_amount', 'created_at', 'activity', 'expected_quantity', 'actual_quantity', 'rejected_quantity']}
    payment = db.scalar(select(m.Payment).where(m.Payment.order_id == order.id))
    result['amount_received'] = payment.received_amount if payment else Decimal('0')
    result['customer_status'] = STATUS[order.internal_status]
    result['message'] = 'Payment failed. Your stock reservation has been released.' if order.internal_status == 'payment_failed' else None
    result['delivery_address'] = order.delivery_snapshot
    result['items'] = []
    for item in db.scalars(select(m.OrderItem).where(m.OrderItem.order_id == order.id)):
        listing = db.get(m.Listing, item.listing_id)
        result['items'].append({'id': item.id, 'category': listing.category, 'unit_type': listing.unit_type, 'quantity': item.quantity, 'unit_price': item.unit_price, 'subtotal': item.subtotal})
    from . import ratings
    rating = db.scalar(select(m.OrderRating).where(m.OrderRating.order_id == order.id))
    result['rating'] = ratings.rating_view(rating) if rating else None
    result['can_rate'] = order.internal_status in ('delivered', 'completed') and (rating is None or ratings.can_edit(rating))
    return result


def buyer_request(request):
    result = {k: getattr(request, k) for k in ['id', 'category', 'quantity', 'unit_type', 'weight_or_size_requirement', 'live_dressed_or_cut', 'needed_by_date', 'delivery_area', 'notes', 'converted_order_id', 'created_at']}
    result['status'] = 'confirmed' if request.status == 'converted' else request.status
    return result


def reservation_view(hold):
    return {k: getattr(hold, k) for k in ['id', 'listing_id', 'quantity', 'expires_at', 'status', 'order_id']}


def payout_view(payout, detail=False):
    fields = ['id', 'quantity', 'total_payable', 'status', 'paid_at', 'payment_reference', 'created_at']
    if detail:
        fields += ['farmer_asking_price_per_unit', 'supplier_payout_price_per_unit', 'commission_amount_per_unit']
    return {k: getattr(payout, k) for k in fields}
