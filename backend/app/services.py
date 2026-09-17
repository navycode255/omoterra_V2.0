import hashlib
import json
from datetime import timedelta
from decimal import Decimal, ROUND_HALF_UP
from fastapi import HTTPException
from sqlalchemy import select, text
from . import models as m
from .config import settings
from . import inventory as inv

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


def fail(message, status=409):
    raise HTTPException(status, detail=message)


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
        fail('This record is unavailable.', 404)
    return result


def replay(db, actor, operation, key, payload):
    if not key or not 8 <= len(key) <= 128:
        fail('Provide an Idempotency-Key between 8 and 128 characters.', 422)
    commerce_lock(db)
    scoped = hashlib.sha256(f'{actor}:{operation}:{key}'.encode()).hexdigest()
    fingerprint = hashlib.sha256(json.dumps(payload, sort_keys=True, default=str).encode()).hexdigest()
    previous = db.get(m.Idempotency, scoped)
    if previous and previous.fingerprint != fingerprint:
        fail('This retry key was already used for a different action.')
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
        fail('This supply is no longer available.', 404)
    refresh_listing(db, listing)
    if listing.supplier_id == buyer:
        fail('You cannot reserve your own stock.')
    if not fresh(listing):
        db.commit()
        fail('This stock is awaiting confirmation or has been paused. Browse other supply.')
    if listing.unit_type != 'kg' and data.quantity % 1:
        fail('Choose a whole number of birds or animals.', 422)
    if data.quantity > listing.quantity_available:
        fail('The requested quantity is no longer available. Choose a smaller quantity.')
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
        fail('Your reservation has expired or has already been used. Reserve stock again.')
    if not fresh(listing):
        release(db, hold, listing, 'released')
        db.commit()
        fail('This listing is no longer available. Release your reservation and browse other supply.')
    address = owned(db, m.Address, data.delivery_address_id, buyer)
    if address.deleted:
        fail('Select a current delivery address.', 422)
    if data.payment_method != 'pay_on_delivery':
        fail('Pay Now is not available until the payment provider is connected.', 422)
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
    return order


def advance(db, order, data):
    commerce_lock(db)
    target = data.internal_status
    if data.expected_collection_date is not None:
        order.expected_collection_date = data.expected_collection_date.isoformat()
    if target == order.internal_status:
        return order
    if target not in TRANSITIONS[order.internal_status]:
        fail('This order cannot move to the requested status.')
    holds = db.scalars(select(m.StockReservation).where(m.StockReservation.order_id == order.id).with_for_update()).all()
    if target in ['cancelled', 'payment_failed']:
        if order.payment_status in ['paid', 'partial']:
            fail('A recorded payment requires manual refund reconciliation before cancellation.')
        for hold in holds:
            listing = db.scalar(select(m.Listing).where(m.Listing.id == hold.listing_id).with_for_update())
            release(db, hold, listing, 'cancelled')
        if target == 'payment_failed':
            order.payment_status = 'failed'
            db.scalar(select(m.Payment).where(m.Payment.order_id == order.id)).status = 'failed'
    if target == 'quality_checked':
        if data.actual_quantity is None or data.rejected_quantity is None:
            fail('Record accepted and rejected quantities before dispatch.', 422)
        if data.actual_quantity + data.rejected_quantity != order.expected_quantity:
            fail('Accepted plus rejected quantity must equal the reserved quantity.', 422)
        item = db.scalar(select(m.OrderItem).where(m.OrderItem.order_id == order.id))
        listing = db.get(m.Listing, item.listing_id)
        if listing.unit_type != 'kg' and (data.actual_quantity % 1 or data.rejected_quantity % 1):
            fail('Birds and animals require whole quantities.', 422)
        order.actual_quantity, order.rejected_quantity = data.actual_quantity, data.rejected_quantity
        order.actual_weight, order.collection_notes = data.actual_weight, data.collection_notes
        # Buyer is billed only accepted units; price snapshot never changes.
        order.total_amount = money(item.unit_price * order.actual_quantity)
        payment = db.scalar(select(m.Payment).where(m.Payment.order_id == order.id))
        payment.amount = order.total_amount
    if target == 'delivered':
        if order.actual_quantity is None:
            fail('Complete the quality check before delivery.')
        for hold in holds:
            listing = db.scalar(select(m.Listing).where(m.Listing.id == hold.listing_id).with_for_update())
            if hold.status != 'confirmed':
                fail('Order reservation is no longer confirmed.')
            # Release the exact original hold; only accepted units become sold.
            release(db, hold, listing, 'released')
            before_sale = inv.balances(listing)
            listing.quantity_sold += order.actual_quantity
            if listing.quantity_available == 0:
                listing.listing_status = 'sold_out'
            item = db.scalar(select(m.OrderItem).where(m.OrderItem.order_id == order.id, m.OrderItem.listing_id == listing.id))
            if order.actual_quantity > 0:
                db.add(m.StockSale(listing_id=listing.id, supplier_id=listing.supplier_id, source='omoterra', quantity=order.actual_quantity, sold_at=m.now(), order_item_id=item.id))
                inv.movement(db, listing, 'sale_omoterra', before_sale, f'order-item:{item.id}:sold', 'Delivered through Omoterra')
            db.add(m.Settlement(supplier_id=listing.supplier_id, order_item_id=item.id,
                farmer_asking_price_per_unit=item.asking_snapshot, supplier_payout_price_per_unit=item.payout_snapshot,
                commission_amount_per_unit=item.asking_snapshot - item.payout_snapshot,
                quantity=order.actual_quantity, total_payable=money(order.actual_quantity * item.payout_snapshot)))
            profile = db.get(m.SupplierProfile, listing.supplier_id)
            profile.completed_supplies_count += 1
    if target == 'completed' and order.payment_status != 'paid':
        fail('Reconcile the buyer payment before completing this order.')
    order.internal_status = target
    if target in ACTIVITY:
        order.activity = [*order.activity, {'label': ACTIVITY[target], 'at': m.now().isoformat()}]
    db.flush()
    return order


def buyer_listing(db, listing, detail=False):
    result = {k: getattr(listing, k) for k in ['id', 'category', 'unit_type', 'region', 'photos', 'specs', 'buyer_price_per_unit']}
    result['quantity_available'] = listing.quantity_available
    if detail:
        profile = db.get(m.SupplierProfile, listing.supplier_id)
        result['supplier'] = {'public_alias': profile.public_alias if profile and profile.alias_approved else 'Omoterra supply partner', 'region': listing.region, 'approval': 'Omoterra Approved'}
    return result


def supplier_listing(listing):
    result = {k: getattr(listing, k) for k in ['id', 'category', 'unit_type', 'region', 'photos', 'specs', 'farmer_asking_price_per_unit', 'quantity_total', 'quantity_reserved', 'quantity_sold', 'listing_status', 'confirmation_due_at']}
    result['quantity_available'] = listing.quantity_available
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
