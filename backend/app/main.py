from contextlib import asynccontextmanager
from datetime import timedelta
from decimal import Decimal
from fastapi import FastAPI, Depends, Header, Query, Request, HTTPException, UploadFile, File
from fastapi.responses import JSONResponse, FileResponse
from pathlib import Path
from fastapi.encoders import jsonable_encoder
from sqlalchemy import select, delete
from . import models as m, contracts as c, services as s, auth
from .db import database
from .config import settings
from .payments import DisabledPaymentProvider
from .media import save_photo, validate_owned_media
from . import inventory as inv


@asynccontextmanager
async def lifespan(app):
    settings().validate_runtime()
    yield


app = FastAPI(title='Omoterra', version='1.0.0', lifespan=lifespan)
# Decimal values cross the API as strings, never binary floats.
class DecimalResponse(JSONResponse):
    def render(self, content):
        return super().render(jsonable_encoder(content, custom_encoder={Decimal: str}))


# Explicitly encode decimals before FastAPI's generic encoder.
def result(value):
    return JSONResponse(jsonable_encoder(value, custom_encoder={Decimal: str}))


prefix = '/api/v1'
buyer = auth.role('buyer')
supplier = auth.role('supplier')


@app.get('/health')
def health():
    return {'status': 'ok'}


@app.get(prefix + '/config')
def config():
    return {'payment_methods': ['pay_on_delivery'], 'otp_length': settings().otp_length, 'media_upload_enabled': True, 'support_phone': settings().support_phone, 'terms_text': settings().terms_text, 'privacy_text': settings().privacy_text, 'environment': settings().environment}


@app.post(prefix + '/auth/otp')
def request_otp(data: c.Phone, db=Depends(database)):
    return auth.start_otp(db, data.phone)


@app.post(prefix + '/auth/verify')
def verify(data: c.Verify, db=Depends(database)):
    return auth.verify_otp(db, data.challenge_id, data.code)


@app.get(prefix + '/me')
def me(user=Depends(auth.current_user)):
    return auth.user_view(user)


@app.put(prefix + '/me')
def profile(data: c.Profile, user=Depends(auth.current_user), db=Depends(database)):
    # Enabling capabilities is additive so existing orders/stock remain accessible.
    for key, value in data.model_dump().items():
        setattr(user, key, sorted(set(user.roles) | set(value)) if key == 'roles' else value)
    db.flush()
    return auth.user_view(user)


@app.post(prefix + '/auth/logout', status_code=204)
def logout(authorization: str = Header(), user=Depends(auth.current_user), db=Depends(database)):
    db.execute(delete(m.AuthSession).where(m.AuthSession.token_hash == auth.digest(authorization.removeprefix('Bearer '))))


@app.get(prefix + '/addresses')
def addresses(user=Depends(buyer), db=Depends(database)):
    rows = db.scalars(select(m.Address).where(m.Address.user_id == user.id, m.Address.deleted.is_(False))).all()
    return result([{'id': row.id, **{k: getattr(row, k) for k in c.AddressInput.model_fields}} for row in rows])


@app.post(prefix + '/addresses', status_code=201)
def add_address(data: c.AddressInput, user=Depends(buyer), db=Depends(database)):
    address = m.Address(user_id=user.id, **data.model_dump())
    db.add(address)
    db.flush()
    return {'id': address.id, **data.model_dump()}


@app.put(prefix + '/addresses/{id}')
def edit_address(id: str, data: c.AddressInput, user=Depends(buyer), db=Depends(database)):
    address = s.owned(db, m.Address, id, user.id)
    if address.deleted:
        s.fail('This address was removed.', 404)
    for key, value in data.model_dump().items():
        setattr(address, key, value)
    return {'id': address.id, **data.model_dump()}


@app.delete(prefix + '/addresses/{id}', status_code=204)
def remove_address(id: str, user=Depends(buyer), db=Depends(database)):
    s.owned(db, m.Address, id, user.id).deleted = True


@app.get(prefix + '/listings')
def listings(category: c.Category | None = None, region: str | None = None, q: str = '', min_price: Decimal | None = None, max_price: Decimal | None = None, limit: int = Query(50, ge=1, le=100), user=Depends(buyer), db=Depends(database)):
    s.commerce_lock(db)
    # Read-time freshness is in SQL; never depends on scheduled writes.
    query = select(m.Listing).where(m.Listing.listing_status == 'live', m.Listing.confirmation_due_at > m.now(), m.Listing.buyer_price_per_unit.is_not(None))
    if category:
        query = query.where(m.Listing.category == category)
    if region:
        query = query.where(m.Listing.region.ilike(region))
    if q:
        query = query.where(m.Listing.category.ilike(f'%{q.replace(" ", "_")}%'))
    if min_price is not None:
        query = query.where(m.Listing.buyer_price_per_unit >= min_price)
    if max_price is not None:
        query = query.where(m.Listing.buyer_price_per_unit <= max_price)
    rows = db.scalars(query.order_by(m.Listing.created_at.desc()).limit(limit).with_for_update()).all()
    for row in rows:
        s.refresh_listing(db, row)
    return result([s.buyer_listing(db, row) for row in rows if s.fresh(row) and row.quantity_available > 0])


@app.get(prefix + '/listings/{id}')
def listing(id: str, user=Depends(buyer), db=Depends(database)):
    s.commerce_lock(db)
    row = db.scalar(select(m.Listing).where(m.Listing.id == id, m.Listing.listing_status == 'live', m.Listing.confirmation_due_at > m.now()).with_for_update())
    if not row:
        s.fail('This stock is no longer available. Explore current supply.', 404)
    s.refresh_listing(db, row)
    return result(s.buyer_listing(db, row, True))


@app.post(prefix + '/reservations')
def reservation(data: c.Reserve, idempotency_key: str = Header(), user=Depends(buyer), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'reserve', idempotency_key, data.model_dump())
    if prior:
        hold = db.get(m.StockReservation, prior)
        s.refresh_listing(db, db.get(m.Listing, hold.listing_id))
        return result(s.reservation_view(hold))
    hold = s.reserve(db, user.id, data)
    s.remember(db, key, fingerprint, hold.id)
    return result(s.reservation_view(hold))


@app.get(prefix + '/reservations/{id}')
def get_reservation(id: str, user=Depends(buyer), db=Depends(database)):
    s.commerce_lock(db)
    hold = s.owned(db, m.StockReservation, id, user.id, 'buyer_id')
    listing = db.get(m.Listing, hold.listing_id)
    s.refresh_listing(db, listing)
    if hold.status == 'active' and not s.fresh(listing):
        s.release(db, hold, listing, 'released')
    summary = s.buyer_listing(db, listing)
    if not s.fresh(listing):
        summary['quantity_available'] = Decimal('0')
    return result({**s.reservation_view(hold), 'listing': summary, 'payment_methods': ['pay_on_delivery']})


@app.delete(prefix + '/reservations/{id}', status_code=204)
def release_reservation(id: str, user=Depends(buyer), db=Depends(database)):
    s.commerce_lock(db)
    hold = s.owned(db, m.StockReservation, id, user.id, 'buyer_id', True)
    if hold.status == 'confirmed':
        s.fail('Cancel the order to release this reservation.')
    s.release(db, hold, db.get(m.Listing, hold.listing_id), 'cancelled')


@app.post(prefix + '/orders')
def create_order(data: c.Checkout, idempotency_key: str = Header(), user=Depends(buyer), db=Depends(database)):
    return result(s.buyer_order(db, s.checkout(db, user.id, data, idempotency_key)))


@app.get(prefix + '/orders')
def orders(user=Depends(buyer), db=Depends(database)):
    return result([s.buyer_order(db, o) for o in db.scalars(select(m.Order).where(m.Order.buyer_id == user.id).order_by(m.Order.created_at.desc()))])


@app.get(prefix + '/orders/{id}')
def order(id: str, user=Depends(buyer), db=Depends(database)):
    return result(s.buyer_order(db, s.owned(db, m.Order, id, user.id, 'buyer_id')))


@app.post(prefix + '/orders/{id}/cancel')
def cancel_order(id: str, idempotency_key: str = Header(), user=Depends(buyer), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'cancel', idempotency_key, {'id': id})
    order = s.owned(db, m.Order, id, user.id, 'buyer_id', True)
    if not prior:
        if order.internal_status not in ['reserved', 'requested', 'supply_confirmed', 'cancelled']:
            s.fail('Collection has started. Contact Omoterra for cancellation help.')
        s.advance(db, order, c.Progress(internal_status='cancelled'))
        s.remember(db, key, fingerprint, order.id)
    return result(s.buyer_order(db, order))


@app.post(prefix + '/requests')
def source(data: c.SourcingInput, idempotency_key: str = Header(), user=Depends(buyer), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'request', idempotency_key, data.model_dump())
    if prior:
        return result(s.buyer_request(db.get(m.SourcingRequest, prior)))
    validate_owned_media(db, [data.reference_photo] if data.reference_photo else [], user.id)
    values = data.model_dump()
    values['needed_by_date'] = data.needed_by_date.isoformat()
    row = m.SourcingRequest(buyer_id=user.id, **values)
    db.add(row)
    db.flush()
    s.remember(db, key, fingerprint, row.id)
    return result(s.buyer_request(row))


@app.get(prefix + '/requests')
def sources(user=Depends(buyer), db=Depends(database)):
    return result([s.buyer_request(r) for r in db.scalars(select(m.SourcingRequest).where(m.SourcingRequest.buyer_id == user.id))])


@app.get(prefix + '/requests/{id}')
def source_detail(id: str, user=Depends(buyer), db=Depends(database)):
    return result(s.buyer_request(s.owned(db, m.SourcingRequest, id, user.id, 'buyer_id')))


@app.post(prefix + '/business-opportunities')
def business(data: c.BusinessInput, idempotency_key: str = Header(), user=Depends(buyer), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'business', idempotency_key, data.model_dump())
    if prior:
        return {'id': prior}
    row = m.BusinessOpportunity(buyer_id=user.id, **data.model_dump())
    db.add(row)
    db.flush()
    s.remember(db, key, fingerprint, row.id)
    return {'id': row.id, 'message': 'Your request has been received. An Omoterra team member will contact you.'}


@app.get(prefix + '/supplier/profile')
def supplier_profile(user=Depends(supplier), db=Depends(database)):
    profile = db.get(m.SupplierProfile, user.id)
    return None if not profile else {k: getattr(profile, k) for k in ['legal_name', 'internal_pickup_address']}


@app.put(prefix + '/supplier/profile')
def save_supplier(data: c.SupplierInput, user=Depends(supplier), db=Depends(database)):
    s.commerce_lock(db)
    profile = db.get(m.SupplierProfile, user.id)
    if not profile:
        profile = m.SupplierProfile(user_id=user.id, **data.model_dump())
        db.add(profile)
    else:
        for key, value in data.model_dump().items():
            setattr(profile, key, value)
    return {'saved': True}


@app.post(prefix + '/supplier/stock')
def add_stock(data: c.ListingInput, idempotency_key: str = Header(), user=Depends(supplier), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'stock', idempotency_key, data.model_dump())
    if prior:
        return result(s.supplier_listing(db.get(m.Listing, prior)))
    if not db.get(m.SupplierProfile, user.id):
        s.fail('Complete your supplier pickup details first.', 422)
    validate_owned_media(db, data.photos, user.id)
    row = m.Listing(supplier_id=user.id, **data.model_dump())
    db.add(row)
    db.flush()
    inv.ensure_history(db, row)
    s.remember(db, key, fingerprint, row.id)
    return result(s.supplier_listing(row))


@app.get(prefix + '/supplier/stock')
def stock(user=Depends(supplier), db=Depends(database)):
    s.commerce_lock(db)
    rows = db.scalars(select(m.Listing).where(m.Listing.supplier_id == user.id).order_by(m.Listing.created_at.desc()).with_for_update()).all()
    for row in rows:
        s.refresh_listing(db, row)
    return result([s.supplier_listing(r) for r in rows])


@app.get(prefix + '/supplier/stock/{id}')
def stock_detail(id: str, user=Depends(supplier), db=Depends(database)):
    s.commerce_lock(db)
    row = s.owned(db, m.Listing, id, user.id, 'supplier_id', True)
    s.refresh_listing(db, row)
    return result(s.supplier_listing(row))


@app.patch(prefix + '/supplier/stock/{id}')
def update_stock(id: str, data: c.StockUpdate, idempotency_key: str = Header(), user=Depends(supplier), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'stock-update', idempotency_key, {'id': id, **data.model_dump()})
    row = s.owned(db, m.Listing, id, user.id, 'supplier_id', True)
    if prior:
        return result(s.supplier_listing(row))
    s.refresh_listing(db, row)
    if data.quantity_total is not None or data.action == 'update':
        s.fail('Use Correct stock count with a reason, or Record a sale. Stock history cannot be overwritten.', 422)
    inv.ensure_history(db, row)
    if data.action == 'pause':
        if row.approved_at is None:
            s.fail('Only approved listings can be paused.')
        row.listing_status = 'paused'
    if data.action == 'confirm':
        if row.approved_at is None or row.listing_status == 'rejected':
            s.fail('Omoterra must approve this stock first.')
        row.last_confirmed_at = m.now()
        row.confirmation_due_at = m.now() + timedelta(hours=settings().freshness_hours)
        row.listing_status = 'live' if row.quantity_available > 0 else 'sold_out'
    inv.movement(db, row, 'availability_confirmed' if data.action == 'confirm' else 'listing_paused', inv.balances(row), key, actor=user.id)
    s.remember(db, key, fingerprint, row.id)
    return result(s.supplier_listing(row))


def supplier_hold(db, hold):
    listing = db.get(m.Listing, hold.listing_id)
    order = db.get(m.Order, hold.order_id) if hold.order_id else None
    return {'id': hold.id, 'category': listing.category, 'unit_type': listing.unit_type, 'quantity': hold.quantity,
        'status': hold.status if not order else s.STATUS[order.internal_status],
        'expected_collection_date': order.expected_collection_date if order else None,
        'instructions': 'Omoterra will coordinate collection with you.',
        'settlements': [s.payout_view(p) for p in db.scalars(select(m.Settlement).join(m.OrderItem, m.OrderItem.id == m.Settlement.order_item_id).where(m.OrderItem.order_id == hold.order_id, m.Settlement.supplier_id == listing.supplier_id))] if order else []}


@app.get(prefix + '/supplier/orders')
def supplier_orders(user=Depends(supplier), db=Depends(database)):
    s.commerce_lock(db)
    for listing in db.scalars(select(m.Listing).where(m.Listing.supplier_id == user.id).with_for_update()):
        s.refresh_listing(db, listing)
    rows = db.scalars(select(m.StockReservation).join(m.Listing).where(m.Listing.supplier_id == user.id).order_by(m.StockReservation.created_at.desc())).all()
    return result([supplier_hold(db, row) for row in rows])


@app.get(prefix + '/supplier/orders/{id}')
def supplier_order(id: str, user=Depends(supplier), db=Depends(database)):
    s.commerce_lock(db)
    row = db.scalar(select(m.StockReservation).join(m.Listing).where(m.StockReservation.id == id, m.Listing.supplier_id == user.id))
    if not row:
        s.fail('This reservation is unavailable.', 404)
    s.refresh_listing(db, db.get(m.Listing, row.listing_id))
    return result(supplier_hold(db, row))


@app.get(prefix + '/supplier/payouts')
def payouts(user=Depends(supplier), db=Depends(database)):
    return result([s.payout_view(row) for row in db.scalars(select(m.Settlement).where(m.Settlement.supplier_id == user.id))])


@app.get(prefix + '/supplier/payouts/{id}')
def payout(id: str, user=Depends(supplier), db=Depends(database)):
    return result(s.payout_view(s.owned(db, m.Settlement, id, user.id, 'supplier_id'), True))


@app.post(prefix + '/ops/listings/{id}/approve', dependencies=[Depends(auth.ops)])
def approve(id: str, data: c.Approval, db=Depends(database)):
    s.commerce_lock(db)
    listing = db.get(m.Listing, id)
    if not listing:
        s.fail('Listing not found.', 404)
    payout = data.supplier_payout_price_per_unit if data.supplier_payout_price_per_unit is not None else listing.farmer_asking_price_per_unit
    if payout > listing.farmer_asking_price_per_unit:
        s.fail('Payout cannot exceed asking price.', 422)
    listing.supplier_payout_price_per_unit, listing.buyer_price_per_unit = payout, data.buyer_price_per_unit
    listing.listing_status = 'live'
    listing.approved_at = listing.last_confirmed_at = m.now()
    listing.confirmation_due_at = m.now() + timedelta(hours=settings().freshness_hours)
    profile = db.get(m.SupplierProfile, listing.supplier_id)
    # Operator must review alias AND all listing copy/media for identifying information.
    profile.public_alias, profile.alias_approved = data.public_alias, True
    return {'id': listing.id, 'status': listing.listing_status}


@app.post(prefix + '/ops/orders/{id}/progress', dependencies=[Depends(auth.ops)])
def progress(id: str, data: c.Progress, idempotency_key: str = Header(), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, 'ops', 'progress', idempotency_key, {'id': id, **data.model_dump()})
    order = db.get(m.Order, id)
    if not order:
        s.fail('Order not found.', 404)
    if not prior:
        s.advance(db, order, data)
        s.remember(db, key, fingerprint, id)
    return result(s.buyer_order(db, order))


@app.post(prefix + '/ops/orders/{id}/reconcile', dependencies=[Depends(auth.ops)])
def reconcile(id: str, data: c.Reconcile, idempotency_key: str = Header(), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, 'ops', 'payment', idempotency_key, {'id': id, **data.model_dump()})
    order = db.get(m.Order, id)
    if not order:
        s.fail('Order not found.', 404)
    payment = db.scalar(select(m.Payment).where(m.Payment.order_id == id))
    if not prior:
        if order.payment_method != 'pay_on_delivery' or order.internal_status not in ['delivered', 'completed']:
            s.fail('Pay on delivery can only be reconciled after delivery.')
        remaining = order.total_amount - payment.received_amount
        if data.amount > remaining or payment.status == 'paid':
            s.fail('The amount exceeds the outstanding balance or this payment is already paid.', 422)
        if db.scalar(select(m.PaymentReceipt).where(m.PaymentReceipt.reference == data.payment_reference)):
            s.fail('This payment reference is already recorded.')
        db.add(m.PaymentReceipt(payment_id=payment.id, amount=data.amount, reference=data.payment_reference))
        payment.received_amount += data.amount
        payment.status = order.payment_status = 'paid' if payment.received_amount == order.total_amount else 'partial'
        payment.paid_at = m.now() if payment.status == 'paid' else None
        s.remember(db, key, fingerprint, id)
    return result({'id': payment.id, 'status': payment.status, 'amount': payment.amount, 'received_amount': payment.received_amount})


@app.post(prefix + '/ops/settlements/{id}/pay', dependencies=[Depends(auth.ops)])
def pay_settlement(id: str, data: c.Reconcile, idempotency_key: str = Header(), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, 'ops', 'settlement', idempotency_key, {'id': id, **data.model_dump()})
    row = db.get(m.Settlement, id)
    if not row:
        s.fail('Settlement not found.', 404)
    if not prior:
        if row.status == 'paid' or row.total_payable != data.amount:
            s.fail('Settlement is already paid or the amount does not match.')
        row.status, row.paid_at, row.payment_reference = 'paid', m.now(), data.payment_reference
        s.remember(db, key, fingerprint, id)
    return result(s.payout_view(row, True))


@app.patch(prefix + '/ops/requests/{id}', dependencies=[Depends(auth.ops)])
def source_progress(id: str, data: c.SourceProgress, db=Depends(database)):
    s.commerce_lock(db)
    row = db.get(m.SourcingRequest, id)
    if not row:
        s.fail('Request not found.', 404)
    if row.status in ['converted', 'cancelled']:
        s.fail('This request is already closed.')
    for key, value in data.model_dump().items():
        setattr(row, key, value)
    return result(s.buyer_request(row))


@app.post(prefix + '/ops/requests/{id}/convert', dependencies=[Depends(auth.ops)])
def convert(id: str, data: c.Convert, idempotency_key: str = Header(), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, 'ops', 'convert', idempotency_key, {'id': id, **data.model_dump()})
    row = db.get(m.SourcingRequest, id)
    if not row:
        s.fail('Request not found.', 404)
    if prior:
        return result(s.buyer_order(db, db.get(m.Order, prior)))
    if row.converted_order_id or row.status != 'confirmed':
        s.fail('Only a confirmed, unconverted sourcing request can be converted.')
    hold = s.owned(db, m.StockReservation, data.reservation_id, row.buyer_id, 'buyer_id')
    listing = db.get(m.Listing, hold.listing_id)
    if listing.category != row.category or hold.quantity != row.quantity:
        s.fail('The reserved category and quantity must match the sourcing request.')
    order = s.checkout(db, row.buyer_id, data, idempotency_key, row.id)
    row.status, row.converted_order_id = 'converted', order.id
    s.remember(db, key, fingerprint, order.id)
    return result(s.buyer_order(db, order))


@app.post(prefix + '/payments/webhook')
async def payment_webhook(request: Request, idempotency_key: str = Header(), x_provider_signature: str = Header(default=''), db=Depends(database)):
    # Do not allow ops or mobile payloads to impersonate a provider confirmation.
    try:
        confirmation = DisabledPaymentProvider().verify_callback(await request.body(), x_provider_signature)
    except RuntimeError:
        raise HTTPException(503, 'Payment provider is not configured. No payment was recorded.')
    return apply_provider_confirmation(db, confirmation, idempotency_key)


def apply_provider_confirmation(db, confirmation, idempotency_key):
    key, fingerprint, prior = s.replay(db, 'provider', 'callback', idempotency_key, vars(confirmation))
    order = db.get(m.Order, confirmation.order_id)
    if not order or order.payment_method != 'pay_now':
        s.fail('Provider order is unavailable.', 404)
    payment = db.scalar(select(m.Payment).where(m.Payment.order_id == order.id).with_for_update())
    if prior:
        return {'received': True}
    if confirmation.amount != payment.amount or confirmation.status not in ['paid', 'failed']:
        s.fail('Payment confirmation does not match the transaction.')
    if payment.status == 'paid':
        if payment.provider_transaction_id != confirmation.transaction_id or confirmation.status != 'paid':
            s.fail('Payment is already confirmed with a different transaction.')
    elif confirmation.status == 'paid':
        if order.internal_status in ['cancelled', 'payment_failed']:
            s.fail('Late payment requires operator reconciliation; stock was already released.')
        payment.status = order.payment_status = 'paid'
        payment.received_amount = confirmation.amount
        payment.provider_transaction_id, payment.paid_at = confirmation.transaction_id, m.now()
    else:
        s.advance(db, order, c.Progress(internal_status='payment_failed'))
        payment.provider_transaction_id = confirmation.transaction_id
    s.remember(db, key, fingerprint, order.id)
    return {'received': True}


@app.post(prefix + '/media')
async def upload_photo(file: UploadFile = File(), user=Depends(auth.current_user), db=Depends(database)):
    if not set(user.roles) & {'buyer', 'supplier'}:
        s.fail('Finish account setup before uploading photos.', 403)
    raw = await file.read(settings().upload_max_bytes + 1)
    if len(raw) > settings().upload_max_bytes:
        s.fail('Choose a photo smaller than 8 MB.', 413)
    return save_photo(db, user.id, raw)


@app.get(prefix + '/media/{id}')
def photo(id: str, user=Depends(auth.current_user), db=Depends(database)):
    asset = db.get(m.MediaAsset, id)
    if not asset:
        s.fail('Photo not found.', 404)
    if asset.owner_id != user.id:
        # Only fresh, operator-reviewed listing photos cross the buyer boundary.
        approved = db.scalars(select(m.Listing).where(m.Listing.listing_status == 'live', m.Listing.confirmation_due_at > m.now())).all()
        if 'buyer' not in user.roles or not any(f'/media/{id}' in row.photos for row in approved):
            s.fail('Photo not found.', 404)
    path = Path(settings().media_directory) / asset.storage_name
    if not path.is_file():
        s.fail('Photo is unavailable. Please upload it again.', 404)
    return FileResponse(path, media_type='image/jpeg', headers={'Cache-Control': 'private, no-store'})


@app.get(prefix + '/ops/listings', dependencies=[Depends(auth.ops)])
def ops_listings(db=Depends(database)):
    return result([{**s.supplier_listing(row), 'supplier_id': row.supplier_id,
        'buyer_price_per_unit': row.buyer_price_per_unit,
        'supplier_payout_price_per_unit': row.supplier_payout_price_per_unit}
        for row in db.scalars(select(m.Listing).order_by(m.Listing.created_at.desc()).limit(100))])


@app.get(prefix + '/ops/requests', dependencies=[Depends(auth.ops)])
def ops_requests(db=Depends(database)):
    return result([{**s.buyer_request(row), 'buyer_id': row.buyer_id,
        'quantity_secured': row.quantity_secured, 'admin_notes': row.admin_notes}
        for row in db.scalars(select(m.SourcingRequest).order_by(m.SourcingRequest.created_at.desc()).limit(100))])


@app.post(prefix + '/ops/requests/{id}/reserve', dependencies=[Depends(auth.ops)])
def reserve_source(id: str, data: c.Reserve, idempotency_key: str = Header(), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, 'ops', 'source-reserve', idempotency_key, {'id': id, **data.model_dump()})
    if prior:
        return result(s.reservation_view(db.get(m.StockReservation, prior)))
    row = db.get(m.SourcingRequest, id)
    listing = db.get(m.Listing, data.listing_id)
    if not row or not listing:
        s.fail('Request or supply not found.', 404)
    if row.status != 'confirmed' or listing.category != row.category or data.quantity != row.quantity:
        s.fail('Confirm the request and reserve its exact category and quantity.')
    hold = s.reserve(db, row.buyer_id, data)
    s.remember(db, key, fingerprint, hold.id)
    return result(s.reservation_view(hold))


@app.get(prefix + '/ops/media/{id}', dependencies=[Depends(auth.ops)])
def ops_photo(id: str, db=Depends(database)):
    asset = db.get(m.MediaAsset, id)
    if not asset or not (Path(settings().media_directory) / asset.storage_name).is_file():
        s.fail('Photo not found.', 404)
    return FileResponse(Path(settings().media_directory) / asset.storage_name, media_type='image/jpeg', headers={'Cache-Control': 'private, no-store'})


@app.get(prefix + '/ops/orders', dependencies=[Depends(auth.ops)])
def ops_orders(db=Depends(database)):
    return result([{**s.buyer_order(db, row), 'internal_status': row.internal_status}
        for row in db.scalars(select(m.Order).order_by(m.Order.created_at.desc()).limit(100))])


@app.get(prefix + '/ops/orders/{id}', dependencies=[Depends(auth.ops)])
def ops_order(id: str, db=Depends(database)):
    row = db.get(m.Order, id)
    if not row:
        s.fail('Order not found.', 404)
    suppliers = []
    for item in db.scalars(select(m.OrderItem).where(m.OrderItem.order_id == id)):
        listing = db.get(m.Listing, item.listing_id)
        profile = db.get(m.SupplierProfile, listing.supplier_id)
        user = db.get(m.User, listing.supplier_id)
        suppliers.append({'listing_id': listing.id, 'supplier_id': user.id, 'phone': user.phone,
            'legal_name': profile.legal_name, 'internal_pickup_address': profile.internal_pickup_address})
    return result({**s.buyer_order(db, row), 'internal_status': row.internal_status,
        'suppliers': suppliers, 'collection_notes': row.collection_notes,
        'collection_photos': row.collection_photos})


@app.get(prefix + '/ops/buyers/{id}/addresses', dependencies=[Depends(auth.ops)])
def ops_addresses(id: str, db=Depends(database)):
    return result([{'id': row.id, **{key: getattr(row, key) for key in c.AddressInput.model_fields}}
        for row in db.scalars(select(m.Address).where(m.Address.user_id == id, m.Address.deleted.is_(False)))])


@app.get(prefix + '/ops/settlements', dependencies=[Depends(auth.ops)])
def ops_settlements(db=Depends(database)):
    return result([{**s.payout_view(row, True), 'supplier_id': row.supplier_id, 'order_item_id': row.order_item_id}
        for row in db.scalars(select(m.Settlement).order_by(m.Settlement.created_at.desc()).limit(100))])


@app.get(prefix + '/ops/business-opportunities', dependencies=[Depends(auth.ops)])
def ops_business(db=Depends(database)):
    return result([{'id': row.id, 'buyer_id': row.buyer_id, 'status': row.status,
        'internal_notes': row.internal_notes, **{key: getattr(row, key) for key in c.BusinessInput.model_fields}}
        for row in db.scalars(select(m.BusinessOpportunity).order_by(m.BusinessOpportunity.created_at.desc()).limit(100))])


@app.patch(prefix + '/ops/listings/{id}/status', dependencies=[Depends(auth.ops)])
def review_listing(id: str, data: c.ListingReview, idempotency_key: str = Header(), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, 'ops', 'listing-review', idempotency_key, {'id': id, **data.model_dump()})
    listing = db.get(m.Listing, id)
    if not listing:
        s.fail('Listing not found.', 404)
    if not prior:
        listing.listing_status = data.status
        # Checkout holds are released, but confirmed orders remain reserved for ops to resolve.
        for hold in db.scalars(select(m.StockReservation).where(m.StockReservation.listing_id == id, m.StockReservation.status == 'active')):
            s.release(db, hold, listing, 'released')
        s.remember(db, key, fingerprint, id)
    return {'id': id, 'status': listing.listing_status}


@app.patch(prefix + '/ops/business-opportunities/{id}', dependencies=[Depends(auth.ops)])
def business_progress(id: str, data: c.BusinessProgress, idempotency_key: str = Header(), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, 'ops', 'business-progress', idempotency_key, {'id': id, **data.model_dump()})
    row = db.get(m.BusinessOpportunity, id)
    if not row:
        s.fail('Business request not found.', 404)
    if not prior:
        row.status, row.internal_notes = data.status, data.internal_notes
        s.remember(db, key, fingerprint, id)
    return {'id': id, 'status': row.status}


@app.post(prefix + '/ops/orders/{id}/photos', dependencies=[Depends(auth.ops)])
async def collection_photo(id: str, file: UploadFile = File(), idempotency_key: str = Header(), db=Depends(database)):
    import hashlib
    raw = await file.read(settings().upload_max_bytes + 1)
    if len(raw) > settings().upload_max_bytes:
        s.fail('Choose a photo smaller than 8 MB.', 413)
    key, fingerprint, prior = s.replay(db, 'ops', 'collection-photo', idempotency_key, {'id': id, 'sha256': hashlib.sha256(raw).hexdigest()})
    if prior:
        return {'url': f'/media/{prior}'}
    order = db.get(m.Order, id)
    if not order:
        s.fail('Order not found.', 404)
    photo = save_photo(db, None, raw)
    order.collection_photos = [*order.collection_photos, photo['url']]
    s.remember(db, key, fingerprint, photo['id'])
    return photo


@app.get(prefix + '/supplier/stock/{id}/history')
def stock_history(id: str, user=Depends(supplier), db=Depends(database)):
    s.commerce_lock(db)
    row = s.owned(db, m.Listing, id, user.id, 'supplier_id', True)
    inv.ensure_history(db, row)
    s.refresh_listing(db, row)
    return result([inv.view(event) for event in db.scalars(select(m.StockMovement).where(m.StockMovement.listing_id == id).order_by(m.StockMovement.created_at.desc(), m.StockMovement.id.desc()))])


def stock_action(db, user, id, data, key, kind):
    scoped, fingerprint, prior = s.replay(db, user.id, kind, key, {'id': id, **data.model_dump()})
    listing = s.owned(db, m.Listing, id, user.id, 'supplier_id', True)
    if prior:
        return listing, scoped, fingerprint, True
    inv.ensure_history(db, listing)
    s.refresh_listing(db, listing)
    return listing, scoped, fingerprint, False


def stock_status(listing):
    if listing.listing_status in ['live', 'sold_out']:
        listing.listing_status = 'sold_out' if listing.quantity_available == 0 else ('live' if listing.confirmation_due_at and listing.confirmation_due_at > m.now() else 'needs_confirmation')


@app.post(prefix + '/supplier/stock/{id}/corrections')
def correct_stock(id: str, data: c.StockCorrection, idempotency_key: str = Header(), user=Depends(supplier), db=Depends(database)):
    row, key, fingerprint, prior = stock_action(db, user, id, data, idempotency_key, 'stock-correction')
    if not prior:
        if row.unit_type != 'kg' and data.counted_on_hand % 1:
            s.fail('Use a whole number of birds or animals.', 422)
        if data.counted_on_hand < row.quantity_reserved:
            s.fail('The count cannot be below reserved stock. Contact Omoterra to resolve the reserved quantity.')
        before = inv.balances(row)
        row.quantity_total = data.counted_on_hand + row.quantity_sold
        if before == inv.balances(row):
            s.fail('The count matches your records. No correction is needed.', 422)
        stock_status(row)
        inv.movement(db, row, 'correction', before, key, data.reason, user.id)
        s.remember(db, key, fingerprint, row.id)
    return result(s.supplier_listing(row))


@app.post(prefix + '/supplier/stock/{id}/additions')
def add_to_stock(id: str, data: c.StockAddition, idempotency_key: str = Header(), user=Depends(supplier), db=Depends(database)):
    row, key, fingerprint, prior = stock_action(db, user, id, data, idempotency_key, 'stock-addition')
    if not prior:
        if row.unit_type != 'kg' and data.quantity % 1:
            s.fail('Use a whole number of birds or animals.', 422)
        before = inv.balances(row)
        row.quantity_total += data.quantity
        stock_status(row)
        inv.movement(db, row, 'stock_added', before, key, data.reason, user.id)
        s.remember(db, key, fingerprint, row.id)
    return result(s.supplier_listing(row))


@app.post(prefix + '/supplier/stock/{id}/sales')
def record_sale(id: str, data: c.SaleInput, idempotency_key: str = Header(), user=Depends(supplier), db=Depends(database)):
    row, key, fingerprint, prior = stock_action(db, user, id, data, idempotency_key, 'external-sale')
    if prior:
        return result(inv.sale_view(db, db.get(m.StockSale, db.get(m.Idempotency, key).resource_id)))
    if row.unit_type != 'kg' and data.quantity % 1:
        s.fail('Use a whole number of birds or animals.', 422)
    if data.quantity > row.quantity_available:
        s.fail('This sale exceeds available stock. Reserved stock cannot be sold elsewhere.')
    if data.sold_on < row.created_at.date():
        s.fail('The sale date cannot be before this stock record was created.', 422)
    from datetime import datetime, timezone, time
    sale = m.StockSale(listing_id=id, supplier_id=user.id, source='external', quantity=data.quantity,
        sold_at=datetime.combine(data.sold_on, time.min, tzinfo=timezone.utc), unit_price=data.unit_price, note=data.note)
    db.add(sale)
    before = inv.balances(row)
    row.quantity_sold += data.quantity
    stock_status(row)
    inv.movement(db, row, 'sale_external', before, key, data.note or 'Sale outside Omoterra', user.id)
    s.remember(db, key, fingerprint, sale.id)
    return result(inv.sale_view(db, sale))


@app.get(prefix + '/supplier/sales')
def sales(listing_id: str | None = None, user=Depends(supplier), db=Depends(database)):
    query = select(m.StockSale).where(m.StockSale.supplier_id == user.id)
    if listing_id:
        query = query.where(m.StockSale.listing_id == listing_id)
    return result([inv.sale_view(db, sale) for sale in db.scalars(query.order_by(m.StockSale.sold_at.desc(), m.StockSale.created_at.desc()))])


@app.get(prefix + '/supplier/sales/{id}')
def sale_detail(id: str, user=Depends(supplier), db=Depends(database)):
    return result(inv.sale_view(db, s.owned(db, m.StockSale, id, user.id, 'supplier_id')))
