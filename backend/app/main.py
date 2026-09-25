from __future__ import annotations

from contextlib import asynccontextmanager
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo
from decimal import Decimal
from typing import Optional, Union
from fastapi import FastAPI, Depends, Header, Query, Request, HTTPException, UploadFile, File
from fastapi.responses import JSONResponse, FileResponse
from pathlib import Path
from fastapi.encoders import jsonable_encoder
from sqlalchemy import select, delete, func
from . import models as m, contracts as c, services as s, auth
from .db import database
from .config import settings
from .payments import DisabledPaymentProvider
from .media import save_photo, validate_owned_media
from . import inventory as inv, demand as dm


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


@app.post(prefix + '/account/register-role')
def register_role(data: c.RoleRegistration, user=Depends(auth.current_user), db=Depends(database)):
    if data.role in user.roles:
        s.fail('This role is already registered on your account.', 409)
    user.roles = sorted(set(user.roles) | {data.role})
    if data.role == 'buyer':
        user.buyer_type = data.buyer_type
    else:
        profile = m.SupplierProfile(user_id=user.id, legal_name=data.legal_name,
                                    internal_pickup_address=data.internal_pickup_address)
        db.add(profile)
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
def listings(category: Optional[c.Category] = None, region: Optional[str] = None, q: str = '', min_price: Optional[Decimal] = None, max_price: Optional[Decimal] = None, limit: int = Query(50, ge=1, le=100), user=Depends(buyer), db=Depends(database)):
    s.commerce_lock(db)
    # Read-time freshness is in SQL; never depends on scheduled writes.
    query = select(m.Listing).join(m.SupplierProfile, m.SupplierProfile.user_id == m.Listing.supplier_id).where(m.SupplierProfile.status == 'approved', m.Listing.listing_status == 'live', m.Listing.confirmation_due_at > m.now(), m.Listing.buyer_price_per_unit.is_not(None))
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
    row = db.scalar(select(m.Listing).join(m.SupplierProfile, m.SupplierProfile.user_id == m.Listing.supplier_id).where(m.Listing.id == id, m.SupplierProfile.status == 'approved', m.Listing.listing_status == 'live', m.Listing.confirmation_due_at > m.now()).with_for_update())
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


@app.post(prefix + '/requirements')
@app.post(prefix + '/requests')
def source(data: c.SourcingInput, idempotency_key: str = Header(), user=Depends(buyer), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'request', idempotency_key, data.model_dump())
    if prior:
        return result(dm.buyer_requirement(db, db.get(m.SourcingRequest, prior)))
    validate_owned_media(db, [data.reference_photo] if data.reference_photo else [], user.id)
    values = data.model_dump()
    values['needed_by_date'] = data.needed_by_date.isoformat()
    values['delivery_region'] = data.delivery_region or user.region
    requirement_id = m.identifier()
    profile = db.scalar(select(m.BuyerProfile).where(m.BuyerProfile.user_id == user.id))
    if not profile:
        profile = m.BuyerProfile(user_id=user.id, business_name=user.name, buyer_type=user.buyer_type or 'personal', contact_person=user.name, phone=user.phone, region=user.region)
        db.add(profile); db.flush()
    row = m.SourcingRequest(id=requirement_id, requirement_number='REQ-' + requirement_id.replace('-', '')[:8].upper(), buyer_id=user.id, buyer_profile_id=profile.id, created_by='buyer', created_by_user_id=user.id, status='open', **values)
    db.add(row)
    db.flush()
    s.remember(db, key, fingerprint, row.id)
    return result(dm.buyer_requirement(db, row))


@app.get(prefix + '/requirements')
@app.get(prefix + '/requests')
def sources(user=Depends(buyer), db=Depends(database)):
    return result([dm.buyer_requirement(db, r) for r in db.scalars(select(m.SourcingRequest).where(m.SourcingRequest.buyer_id == user.id))])


@app.get(prefix + '/requirements/{id}')
@app.get(prefix + '/requests/{id}')
def source_detail(id: str, user=Depends(buyer), db=Depends(database)):
    return result(dm.buyer_requirement(db, s.owned(db, m.SourcingRequest, id, user.id, 'buyer_id')))


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


def _supplier_private_view(profile):
    return {k: getattr(profile, k) for k in (
        'public_alias', 'legal_name', 'alternate_phone', 'internal_pickup_address',
        'region', 'district', 'general_area', 'categories', 'primary_category', 'production_profile', 'evidence_photos',
        'production_frequency', 'pickup_instructions', 'omoterra_pickup', 'supplier_transport',
        'supply_forms', 'preferred_contact_method', 'operating_notes', 'status')}


def _apply_supplier_profile(db, user, data, created_by='supplier'):
    validate_owned_media(db, data.evidence_photos, user.id, allow_unowned=(created_by == 'ops'))
    values = data.model_dump(exclude={'name', 'current_batch', 'future_batches', 'phone', 'internal_notes', 'verification'})
    profile = db.get(m.SupplierProfile, user.id)
    if profile is None:
        profile = m.SupplierProfile(user_id=user.id, legal_name=values['legal_name'],
            internal_pickup_address=values['internal_pickup_address'], created_by_actor=created_by)
        db.add(profile)
    for key, value in values.items():
        setattr(profile, key, value)
    if not user.name:
        user.name = getattr(data, 'name', user.name)
    profile.status = 'under_review'
    profile.reviewed_at = profile.reviewed_by_actor = None
    return profile


def _create_supplier_batch(db, supplier_id, data, default_region, default_pickup='', allow_unowned=False):
    validate_owned_media(db, data.photos, supplier_id, allow_unowned=allow_unowned)
    ready = data.expected_ready_date.isoformat()
    return m.SupplierBatch(supplier_id=supplier_id, category=data.category, subtype=data.subtype,
        initial_quantity=data.initial_quantity, current_quantity=data.initial_quantity,
        current_age=data.current_age, age_unit=data.age_unit, expected_ready_date=ready,
        expected_min_weight_kg=data.expected_min_weight_kg, expected_max_weight_kg=data.expected_max_weight_kg,
        form=data.form, asking_price_per_unit=data.asking_price_per_unit,
        region=data.region or default_region,
        private_pickup_location=data.private_pickup_location or default_pickup,
        photos=data.photos, status='ready' if ready <= date.today().isoformat() else 'growing')


@app.get(prefix + '/supplier/profile')
def supplier_profile(user=Depends(supplier), db=Depends(database)):
    profile = db.get(m.SupplierProfile, user.id)
    return None if not profile else _supplier_private_view(profile)


@app.put(prefix + '/supplier/profile')
def save_supplier(data: Union[c.SupplierProfileInput, c.SupplierInput], user=Depends(supplier), db=Depends(database)):
    s.commerce_lock(db)
    if isinstance(data, c.SupplierProfileInput):
        profile = _apply_supplier_profile(db, user, data)
        db.flush()
        return {'saved': True, **_supplier_private_view(profile)}
    profile = db.get(m.SupplierProfile, user.id)
    if not profile:
        profile = m.SupplierProfile(user_id=user.id, **data.model_dump())
        db.add(profile)
    else:
        for key, value in data.model_dump().items():
            setattr(profile, key, value)
    return {'saved': True}


@app.post(prefix + '/supplier/onboarding')
def submit_supplier_onboarding(data: c.SupplierOnboardingInput, idempotency_key: str = Header(), user=Depends(auth.current_user), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'supplier-onboarding', idempotency_key, data.model_dump())
    if prior:
        profile = db.get(m.SupplierProfile, user.id)
        previous_batches = db.scalars(select(m.SupplierBatch).where(m.SupplierBatch.supplier_id == user.id).order_by(m.SupplierBatch.created_at.asc())).all()
        return result({'user': auth.user_view(user), 'profile': _supplier_private_view(profile),
            'batches': [dm.batch_view(row, private=True) for row in previous_batches],
            'message': 'Supplier registration was already submitted for review.'})
    profile = _apply_supplier_profile(db, user, data)
    user.roles = sorted(set(user.roles) | {'supplier'})
    rows = []
    if data.current_batch is not None:
        rows.append(data.current_batch)
    rows.extend(data.future_batches)
    batches = []
    for batch_data in rows:
        batch = _create_supplier_batch(db, user.id, batch_data, profile.region, profile.internal_pickup_address)
        db.add(batch)
        batches.append(batch)
    db.flush()
    s.remember(db, key, fingerprint, user.id)
    return result({'user': auth.user_view(user), 'profile': _supplier_private_view(profile),
        'batches': [dm.batch_view(row, private=True) for row in batches],
        'message': 'Supplier registration submitted for review.'})


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
    profile = db.get(m.SupplierProfile, listing.supplier_id)
    if not profile or profile.status != 'approved':
        s.fail('Approve the supplier profile before approving this stock.', 409)
    payout = data.supplier_payout_price_per_unit if data.supplier_payout_price_per_unit is not None else listing.farmer_asking_price_per_unit
    if payout > listing.farmer_asking_price_per_unit:
        s.fail('Payout cannot exceed asking price.', 422)
    listing.supplier_payout_price_per_unit, listing.buyer_price_per_unit = payout, data.buyer_price_per_unit
    listing.listing_status = 'live'
    listing.approved_at = listing.last_confirmed_at = m.now()
    listing.confirmation_due_at = m.now() + timedelta(hours=settings().freshness_hours)
    # Operator must review alias AND all listing copy/media for identifying information.
    profile.public_alias, profile.alias_approved = data.public_alias, True
    return {'id': listing.id, 'status': listing.listing_status}


@app.post(prefix + '/ops/requirements/{id}/convert', dependencies=[Depends(auth.ops)])
def convert_requirement_to_order(id: str, data: c.DemandOrderCreate, idempotency_key: str = Header(), db=Depends(database)):
    payload = {'id': id, **data.model_dump()}
    key, fingerprint, prior = s.replay(db, 'ops', 'requirement-order', idempotency_key, payload)
    demand = db.scalar(select(m.SourcingRequest).where(m.SourcingRequest.id == id).with_for_update())
    if not demand:
        s.fail('Requirement not found.', 404)
    if prior:
        return result(s.buyer_order(db, db.get(m.Order, prior)))
    if demand.converted_order_id or demand.status != 'confirmed':
        s.fail('Only a confirmed, unconverted requirement can become an order.')
    allocations = db.scalars(select(m.DemandAllocation).where(
        m.DemandAllocation.demand_id == id, m.DemandAllocation.status == 'reserved'
    ).order_by(m.DemandAllocation.created_at).with_for_update()).all()
    if not allocations or sum((a.allocated_quantity for a in allocations), Decimal('0')) != demand.quantity:
        s.fail('The full requirement must be actively allocated before conversion.', 422)
    profile = db.get(m.BuyerProfile, demand.buyer_profile_id) if demand.buyer_profile_id else None
    buyer_id = demand.buyer_id or (profile.user_id if profile else None)
    address = None
    if buyer_id:
        if not data.delivery_address_id:
            s.fail('Select the buyer’s saved delivery address before conversion.', 422)
        address = db.scalar(select(m.Address).where(m.Address.id == data.delivery_address_id,
            m.Address.user_id == buyer_id, m.Address.deleted.is_(False)))
        if not address:
            s.fail('The delivery address is unavailable for this buyer.', 422)
        delivery_snapshot = {k: getattr(address, k) for k in ('label', 'recipient_name', 'phone', 'region', 'district_area', 'address_text')}
        address_id = address.id
    else:
        if not profile or not (profile.region or demand.delivery_region) or not (profile.area or demand.delivery_area):
            s.fail('Record an offline buyer region and delivery area before conversion.', 422)
        delivery_snapshot = {'label': 'Business delivery', 'recipient_name': profile.contact_person or profile.business_name,
            'phone': profile.phone, 'region': profile.region or demand.delivery_region,
            'district_area': profile.area or demand.delivery_area, 'address_text': demand.delivery_notes or ''}
        address_id = None
    s.commerce_lock(db)
    item_rows = []
    total = Decimal('0')
    for allocation in allocations:
        batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == allocation.supplier_batch_id).with_for_update())
        verification = db.scalar(select(m.BatchVerification).where(m.BatchVerification.batch_id == batch.id)
            .order_by(m.BatchVerification.inspected_at.desc()).with_for_update())
        if not batch or not batch.approved_at or batch.available_to_commit < 0 or batch.asking_price_per_unit is None or not batch.buyer_price_per_unit or batch.supplier_payout_price_per_unit is None:
            s.fail('Every allocated batch needs current operator approval and complete pricing.', 422)
        if not verification or verification.status != 'approved' or not verification.readiness_confirmed or not verification.location_confirmed:
            s.fail('Every allocated batch needs a current readiness and location verification.', 422)
        if (batch.expected_ready_date or '') > date.today().isoformat():
            s.fail('A supplier batch is not ready for collection yet.', 422)
        if batch.reserved_quantity < allocation.allocated_quantity:
            s.fail('An allocated supplier batch no longer has the committed quantity.', 409)
        item_rows.append((allocation, batch))
        total += allocation.allocated_quantity * batch.buyer_price_per_unit
    total = s.money(total)
    order = m.Order(buyer_id=buyer_id, delivery_address_id=address_id, delivery_snapshot=delivery_snapshot,
        preferred_delivery_date=demand.needed_by_date, payment_method='pay_on_delivery', payment_status='pending',
        sourcing_request_id=demand.id, internal_status='reserved', expected_quantity=demand.quantity,
        total_amount=total, idempotency_key=key,
        activity=[{'label': 'Order confirmed', 'at': m.now().isoformat()}])
    db.add(order); db.flush()
    for allocation, batch in item_rows:
        if allocation.allocated_quantity % 1 and demand.unit_type != 'kg':
            s.fail('Birds and animals require whole quantities.', 422)
        batch.current_quantity -= allocation.allocated_quantity
        batch.reserved_quantity -= allocation.allocated_quantity
        listing = m.Listing(supplier_id=batch.supplier_id, category=batch.category, unit_type=demand.unit_type,
            specs={'subtype': batch.subtype, 'form': batch.form, 'minimum_weight_kg': str(batch.expected_min_weight_kg or ''),
                   'maximum_weight_kg': str(batch.expected_max_weight_kg or ''), 'demand_order': True},
            region=batch.region, photos=batch.photos or [], farmer_asking_price_per_unit=batch.asking_price_per_unit,
            supplier_payout_price_per_unit=batch.supplier_payout_price_per_unit, buyer_price_per_unit=batch.buyer_price_per_unit,
            quantity_total=allocation.allocated_quantity, quantity_reserved=allocation.allocated_quantity,
            quantity_sold=0, listing_status='paused', approved_at=batch.approved_at,
            last_confirmed_at=batch.approved_at, confirmation_due_at=None)
        db.add(listing); db.flush()
        batch.linked_listing_id = listing.id
        allocation.listing_id = listing.id
        allocation.status = 'supplier_confirmed'
        item_total = s.money(allocation.allocated_quantity * batch.buyer_price_per_unit)
        item = m.OrderItem(order_id=order.id, listing_id=listing.id, demand_allocation_id=allocation.id,
            quantity=allocation.allocated_quantity, unit_price=batch.buyer_price_per_unit, subtotal=item_total,
            asking_snapshot=batch.asking_price_per_unit, payout_snapshot=batch.supplier_payout_price_per_unit)
        db.add(item); db.flush()
        hold = m.StockReservation(listing_id=listing.id, buyer_id=buyer_id, quantity=allocation.allocated_quantity,
            expires_at=m.now() + timedelta(days=3650), status='confirmed', order_id=order.id)
        db.add(hold); db.flush()
        inv.movement(db, listing, 'hold_confirmed', (Decimal('0'), Decimal('0'), Decimal('0')),
            f'demand-order:{order.id}:item:{item.id}', 'Reserved for a confirmed buyer requirement')
    db.add(m.Payment(order_id=order.id, amount=total, method='pay_on_delivery', idempotency_key=key))
    demand.converted_order_id, demand.status = order.id, 'fulfilling'
    s.remember(db, key, fingerprint, order.id)
    return result(s.buyer_order(db, order))


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
    if data.quantity_secured != dm.secured(db, row.id):
        s.fail('Secured quantity is calculated from active allocations and cannot be edited directly.', 422)
    row.status = data.status
    row.admin_notes = data.admin_notes
    return result(dm.buyer_requirement(db, row))


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




# Managed demand, supplier production and commercial reservation APIs. These
# records never reuse StockReservation (the short-lived checkout hold).
@app.post(prefix + '/supplier/batches', status_code=201)
def create_supplier_batch(data: c.SupplierBatchInput, idempotency_key: str = Header(), user=Depends(supplier), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'supplier-batch', idempotency_key, data.model_dump())
    if prior:
        return result(dm.batch_view(db.get(m.SupplierBatch, prior), private=True))
    if not db.get(m.SupplierProfile, user.id):
        s.fail('Complete your supplier pickup details first.', 422)
    validate_owned_media(db, data.photos, user.id)
    today = date.today().isoformat()
    status = 'ready' if data.expected_ready_date.isoformat() <= today else 'growing'
    row = m.SupplierBatch(supplier_id=user.id, category=data.category, subtype=data.subtype,
        initial_quantity=data.initial_quantity, current_quantity=data.initial_quantity,
        current_age=data.current_age, age_unit=data.age_unit,
        expected_ready_date=data.expected_ready_date.isoformat(),
        expected_min_weight_kg=data.expected_min_weight_kg, expected_max_weight_kg=data.expected_max_weight_kg,
        form=data.form, asking_price_per_unit=data.asking_price_per_unit, region=data.region,
        private_pickup_location=data.private_pickup_location, photos=data.photos, status=status)
    db.add(row); db.flush(); s.remember(db, key, fingerprint, row.id)
    return result(dm.batch_view(row, private=True))


@app.get(prefix + '/supplier/batches')
def supplier_batches(user=Depends(supplier), db=Depends(database)):
    rows = db.scalars(select(m.SupplierBatch).where(m.SupplierBatch.supplier_id == user.id).order_by(m.SupplierBatch.expected_ready_date.asc().nullslast())).all()
    return result([dm.batch_view(row, private=True) for row in rows])


@app.post(prefix + '/supplier/batches/{id}/external-sales')
def supplier_batch_external_sale(id: str, data: c.BatchExternalSaleInput, idempotency_key: str = Header(), user=Depends(supplier), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'supplier-batch-external-sale', idempotency_key, {'id': id, **data.model_dump()})
    batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == id, m.SupplierBatch.supplier_id == user.id).with_for_update())
    if not batch:
        s.fail('Supplier batch not found.', 404)
    if not prior:
        if data.quantity > batch.available_to_commit:
            s.fail('External sale exceeds the unreserved batch quantity.', 422)
        batch.externally_sold_quantity += data.quantity
        if batch.available_to_commit <= 0:
            batch.status = 'fully_reserved'
        db.add(m.SupplierBatchMovement(batch_id=batch.id, supplier_id=user.id, kind='external_sale',
            quantity=data.quantity, note=data.notes, idempotency_key=key))
        s.remember(db, key, fingerprint, batch.id)
    return result(dm.batch_view(batch, private=True))


@app.get(prefix + '/supplier/demand')
def supplier_demand(category: Optional[c.Category] = None, region: Optional[str] = None, user=Depends(supplier), db=Depends(database)):
    query = select(m.SourcingRequest).where(m.SourcingRequest.status.in_(('open', 'partially_matched', 'submitted', 'sourcing', 'supply_found')))
    if category:
        query = query.where(m.SourcingRequest.category == category)
    rows = db.scalars(query.order_by(m.SourcingRequest.needed_by_date.asc()).limit(200)).all()
    output = []
    for demand in rows:
        if dm.remaining(db, demand) <= 0:
            continue
        public = dm.supplier_requirement(db, demand)
        # Buyers only expose a city/region on this route. Exact delivery instructions stay with ops.
        if region and region.casefold() not in str(public.get('delivery_region') or '').casefold():
            continue
        output.append(public)
    return result(output)


@app.get(prefix + '/supplier/demand/{id}')
def supplier_demand_detail(id: str, user=Depends(supplier), db=Depends(database)):
    demand = db.get(m.SourcingRequest, id)
    if not demand or demand.status in ('cancelled', 'completed') or dm.remaining(db, demand) <= 0:
        s.fail('This demand is no longer available.', 404)
    return result(dm.supplier_requirement(db, demand))


@app.post(prefix + '/supplier/demand/{id}/offers', status_code=201)
def submit_supply_offer(id: str, data: c.SupplyOfferInput, idempotency_key: str = Header(), user=Depends(supplier), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'supply-offer', idempotency_key, {'demand_id': id, **data.model_dump()})
    if prior:
        return result(dm.offer_view(db.get(m.SupplyOffer, prior)))
    demand = db.scalar(select(m.SourcingRequest).where(m.SourcingRequest.id == id).with_for_update())
    batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == data.batch_id, m.SupplierBatch.supplier_id == user.id).with_for_update())
    if not demand or not batch:
        s.fail('Demand or your supplier batch is unavailable.', 404)
    if demand.status in ('cancelled', 'completed') or dm.remaining(db, demand) <= 0:
        s.fail('This demand is no longer accepting offers.')
    if batch.category != demand.category or data.offered_quantity > batch.available_to_commit:
        s.fail('The batch category or available quantity does not match this offer.', 422)
    ready = data.expected_ready_date.isoformat() if data.expected_ready_date else batch.expected_ready_date
    if ready and ready > demand.needed_by_date:
        s.fail('The batch will not be ready by the required date.', 422)
    low = data.expected_min_weight_kg or batch.expected_min_weight_kg
    high = data.expected_max_weight_kg or batch.expected_max_weight_kg
    if demand.minimum_weight_kg and high and high < demand.minimum_weight_kg:
        s.fail('The batch weight range is below the requirement.', 422)
    if demand.maximum_weight_kg and low and low > demand.maximum_weight_kg:
        s.fail('The batch weight range is above the requirement.', 422)
    row = m.SupplyOffer(demand_id=demand.id, supplier_id=user.id, batch_id=batch.id,
        offered_quantity=data.offered_quantity, expected_ready_date=ready,
        expected_min_weight_kg=low, expected_max_weight_kg=high,
        asking_price_per_unit=data.asking_price_per_unit or batch.asking_price_per_unit,
        supplier_notes=data.supplier_notes, status='pending')
    db.add(row); db.flush(); s.remember(db, key, fingerprint, row.id)
    return result(dm.offer_view(row))


@app.get(prefix + '/supplier/offers')
def supplier_offers(user=Depends(supplier), db=Depends(database)):
    rows = db.scalars(select(m.SupplyOffer).where(m.SupplyOffer.supplier_id == user.id).order_by(m.SupplyOffer.created_at.desc())).all()
    return result([dm.offer_view(row) for row in rows])


@app.post(prefix + '/ops/buyer-crm', status_code=201, dependencies=[Depends(auth.ops)])
def create_buyer_profile(data: c.BuyerProfileInput, db=Depends(database)):
    values = data.model_dump()
    user_id = values.pop('user_id')
    if user_id:
        linked = db.get(m.User, user_id)
        if not linked or 'buyer' not in linked.roles:
            s.fail('Choose an existing buyer account.', 422)
    if user_id and db.scalar(select(m.BuyerProfile).where(m.BuyerProfile.user_id == user_id)):
        s.fail('This account already has a buyer CRM record.', 409)
    row = m.BuyerProfile(user_id=user_id, **values)
    db.add(row); db.flush()
    return result({'id': row.id, **{k: getattr(row, k) for k in ('business_name','buyer_type','contact_person','phone','region','area','internal_notes','preferences','last_known_buying_price','minimum_order','payment_terms')}})


@app.get(prefix + '/ops/buyer-crm', dependencies=[Depends(auth.ops)])
def ops_buyer_profiles(q: str = '', db=Depends(database)):
    query = select(m.BuyerProfile)
    if q:
        query = query.where(m.BuyerProfile.business_name.ilike(f'%{q}%'))
    rows = db.scalars(query.order_by(m.BuyerProfile.business_name).limit(200)).all()
    profiles = [{'id': b.id, 'user_id': b.user_id, 'business_name': b.business_name, 'buyer_type': b.buyer_type,
        'contact_person': b.contact_person, 'phone': b.phone, 'region': b.region, 'area': b.area, 'crm_record': True} for b in rows]
    linked = {b.user_id for b in rows if b.user_id}
    for user in db.scalars(select(m.User).order_by(m.User.created_at.desc()).limit(200)):
        if 'buyer' in user.roles and user.id not in linked and (not q or q.casefold() in user.name.casefold()):
            profiles.append({'id': user.id, 'user_id': user.id, 'business_name': user.name,
                'buyer_type': user.buyer_type or 'personal', 'contact_person': user.name,
                'phone': user.phone, 'region': user.region, 'area': '', 'crm_record': False})
    return result(profiles[:300])


@app.get(prefix + '/ops/buyer-crm/{id}', dependencies=[Depends(auth.ops)])
def ops_buyer_profile(id: str, db=Depends(database)):
    profile = db.get(m.BuyerProfile, id) or db.scalar(select(m.BuyerProfile).where(m.BuyerProfile.user_id == id))
    user = db.get(m.User, id)
    if not profile and (not user or 'buyer' not in user.roles):
        s.fail('Buyer not found.', 404)
    user_id = profile.user_id if profile else user.id
    requirements = db.scalars(select(m.SourcingRequest).where(m.SourcingRequest.buyer_profile_id == profile.id if profile else m.SourcingRequest.buyer_id == user_id).order_by(m.SourcingRequest.created_at.desc())).all()
    orders = db.scalars(select(m.Order).where(m.Order.buyer_id == user_id).order_by(m.Order.created_at.desc()).limit(100)).all() if user_id else []
    completed = [o for o in orders if o.internal_status == 'completed']
    cancelled = [o for o in orders if o.internal_status == 'cancelled']
    rejected_deliveries = [o for o in orders if Decimal(o.rejected_quantity or 0) > 0]
    rejected_quantity = sum((Decimal(o.rejected_quantity or 0) for o in orders), Decimal('0'))
    total_qty = sum((Decimal(o.actual_quantity or o.expected_quantity) for o in completed), Decimal('0'))
    return result({'id': profile.id if profile else user.id, 'user_id': user_id, 'crm_record': profile is not None,
        'business_name': profile.business_name if profile else user.name,
        'buyer_type': profile.buyer_type if profile else (user.buyer_type or 'personal'),
        'contact_person': profile.contact_person if profile else user.name,
        'phone': profile.phone if profile else user.phone,
        'region': profile.region if profile else user.region, 'area': profile.area if profile else '',
        'internal_notes': profile.internal_notes if profile else '',
        'preferences': profile.preferences if profile else {},
        'last_known_buying_price': profile.last_known_buying_price if profile else None,
        'minimum_order': profile.minimum_order if profile else None,
        'payment_terms': profile.payment_terms if profile else '',
        'completed_orders': len(completed), 'total_quantity_purchased': total_qty,
        'cancelled_orders': len(cancelled), 'rejected_deliveries': len(rejected_deliveries),
        'rejected_quantity': rejected_quantity, 'last_order_at': orders[0].created_at if orders else None,
        'active_requirements': [dm.buyer_requirement(db, r) for r in requirements if r.status not in ('completed','cancelled')]})


@app.post(prefix + '/ops/requirements', status_code=201, dependencies=[Depends(auth.ops)])
def ops_create_requirement(data: c.OperatorRequirementInput, idempotency_key: str = Header(), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, 'ops', 'requirement-create', idempotency_key, data.model_dump())
    if prior:
        return result(dm.buyer_requirement(db, db.get(m.SourcingRequest, prior)))
    profile_id = data.buyer_profile_id
    if data.buyer:
        buyer_data = data.buyer.model_dump()
        profile = m.BuyerProfile(**buyer_data)
        db.add(profile); db.flush(); profile_id = profile.id
    elif profile_id and not db.get(m.BuyerProfile, profile_id):
        s.fail('Buyer CRM record not found.', 404)
    values = data.model_dump(exclude={'buyer','buyer_profile_id','internal_notes'})
    values['needed_by_date'] = data.needed_by_date.isoformat()
    values['delivery_region'] = data.delivery_region or (db.get(m.BuyerProfile, profile_id).region if profile_id else '')
    demand_id = m.identifier()
    row = m.SourcingRequest(id=demand_id, requirement_number='REQ-' + demand_id.replace('-','')[:8].upper(),
        buyer_id=db.get(m.BuyerProfile, profile_id).user_id if profile_id else None,
        buyer_profile_id=profile_id, created_by='operator', created_by_user_id=None,
        status='open', admin_notes=data.internal_notes, **values)
    db.add(row); db.flush(); s.remember(db, key, fingerprint, row.id)
    return result(dm.buyer_requirement(db, row))


@app.get(prefix + '/ops/requirements', dependencies=[Depends(auth.ops)])
def ops_requirements(status: Optional[str] = None, category: Optional[c.Category] = None,
                     region: Optional[str] = None, buyer_id: Optional[str] = None,
                     requirement_type: Optional[str] = None, needed_from: Optional[date] = None,
                     needed_to: Optional[date] = None, db=Depends(database)):
    query = select(m.SourcingRequest)
    if status: query = query.where(m.SourcingRequest.status == status)
    if category: query = query.where(m.SourcingRequest.category == category)
    if region: query = query.where(m.SourcingRequest.delivery_region.ilike(f'%{region}%'))
    if buyer_id: query = query.where(m.SourcingRequest.buyer_profile_id == buyer_id)
    if requirement_type: query = query.where(m.SourcingRequest.requirement_type == requirement_type)
    if needed_from: query = query.where(m.SourcingRequest.needed_by_date >= needed_from.isoformat())
    if needed_to: query = query.where(m.SourcingRequest.needed_by_date <= needed_to.isoformat())
    rows = db.scalars(query.order_by(m.SourcingRequest.needed_by_date.asc()).limit(300)).all()
    result_rows = []
    for row in rows:
        profile = db.get(m.BuyerProfile, row.buyer_profile_id) if row.buyer_profile_id else None
        result_rows.append({**dm.buyer_requirement(db, row), 'buyer_profile_id': row.buyer_profile_id,
            'buyer_name': profile.business_name if profile else (db.get(m.User, row.buyer_id).name if row.buyer_id else 'Offline buyer'),
            'admin_notes': row.admin_notes})
    return result(result_rows)


@app.get(prefix + '/ops/requirements/{id}', dependencies=[Depends(auth.ops)])
def ops_requirement_detail(id: str, db=Depends(database)):
    row = db.get(m.SourcingRequest, id)
    if not row: s.fail('Requirement not found.', 404)
    profile = db.get(m.BuyerProfile, row.buyer_profile_id) if row.buyer_profile_id else None
    allocations = db.scalars(select(m.DemandAllocation).where(m.DemandAllocation.demand_id == id).order_by(m.DemandAllocation.created_at)).all()
    offers = db.scalars(select(m.SupplyOffer).where(m.SupplyOffer.demand_id == id).order_by(m.SupplyOffer.created_at.desc())).all()
    candidates = dm.candidate_batches(db, row)
    return result({**dm.buyer_requirement(db, row), 'buyer_profile_id': row.buyer_profile_id,
        'buyer_id': row.buyer_id or (profile.user_id if profile else None),
        'buyer': None if not profile else {'id': profile.id, 'business_name': profile.business_name, 'buyer_type': profile.buyer_type,
            'contact_person': profile.contact_person, 'phone': profile.phone, 'region': profile.region, 'area': profile.area},
        'delivery_addresses': ([{'id': a.id, 'label': a.label, 'recipient_name': a.recipient_name, 'region': a.region, 'area': a.district_area}
            for a in db.scalars(select(m.Address).where(m.Address.user_id == (row.buyer_id or (profile.user_id if profile else None)), m.Address.deleted.is_(False))) ]
            if (row.buyer_id or (profile and profile.user_id)) else []),
        'admin_notes': row.admin_notes, 'allocations': [dm.allocation_view(a, True) for a in allocations],
        'offers': [{**dm.offer_view(o, True), 'supplier_name': (db.get(m.SupplierProfile, o.supplier_id).legal_name if db.get(m.SupplierProfile, o.supplier_id) else db.get(m.User,o.supplier_id).name)} for o in offers],
        'candidates': candidates})


@app.get(prefix + '/ops/requirements/{id}/matching', dependencies=[Depends(auth.ops)])
def requirement_matching(id: str, db=Depends(database)):
    row = db.get(m.SourcingRequest, id)
    if not row: s.fail('Requirement not found.', 404)
    return result({'requirement': dm.buyer_requirement(db, row), 'candidates': dm.candidate_batches(db, row)})


@app.post(prefix + '/ops/offers/{id}/review', dependencies=[Depends(auth.ops)])
def review_offer(id: str, data: c.OfferReview, idempotency_key: str = Header(), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, 'ops', 'offer-review', idempotency_key, {'id': id, **data.model_dump()})
    offer = db.scalar(select(m.SupplyOffer).where(m.SupplyOffer.id == id).with_for_update())
    if not offer: s.fail('Supply offer not found.', 404)
    if prior: return result(dm.offer_view(offer, True))
    if offer.status != 'pending': s.fail('This supply offer has already been reviewed.')
    if data.status == 'partially_accepted':
        if data.accepted_quantity is None or data.accepted_quantity >= offer.offered_quantity:
            s.fail('Enter an accepted quantity below the offered quantity.', 422)
        offer.accepted_quantity = data.accepted_quantity
    elif data.status == 'accepted':
        if data.accepted_quantity and data.accepted_quantity != offer.offered_quantity:
            s.fail('Use partially accepted when accepting less than the offer.', 422)
        offer.accepted_quantity = offer.offered_quantity
    else:
        offer.accepted_quantity = Decimal('0')
    offer.status, offer.reviewed_at = data.status, m.now()
    s.remember(db, key, fingerprint, offer.id)
    return result(dm.offer_view(offer, True))


@app.post(prefix + '/ops/requirements/{id}/allocations', dependencies=[Depends(auth.ops)])
def create_demand_allocations(id: str, data: c.AllocationPlanInput, idempotency_key: str = Header(), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, 'ops', 'demand-allocation:' + id, idempotency_key, {'id': id, **data.model_dump()})
    demand = db.scalar(select(m.SourcingRequest).where(m.SourcingRequest.id == id).with_for_update())
    if not demand: s.fail('Requirement not found.', 404)
    if prior:
        rows = db.scalars(select(m.DemandAllocation).where(m.DemandAllocation.demand_id == id).order_by(m.DemandAllocation.created_at)).all()
        return result([dm.allocation_view(a, True) for a in rows])
    if len({item.supplier_batch_id for item in data.allocations}) != len(data.allocations):
        s.fail('Use one quantity per supplier batch in an allocation plan.', 422)
    if sum((item.allocated_quantity for item in data.allocations), Decimal('0')) > dm.remaining(db, demand):
        s.fail('Total allocation exceeds the remaining requirement.', 422)
    created = []
    for item in data.allocations:
        batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == item.supplier_batch_id).with_for_update())
        if not batch: s.fail('Supplier batch not found.', 404)
        if batch.approved_at is None: s.fail('Only reviewed supplier batches can be allocated.')
        offer = None
        if item.supply_offer_id:
            offer = db.scalar(select(m.SupplyOffer).where(m.SupplyOffer.id == item.supply_offer_id).with_for_update())
            if not offer or offer.accepted_quantity is None or item.allocated_quantity > offer.accepted_quantity:
                s.fail('Allocation exceeds an accepted supply offer.', 422)
        created.append(dm.allocation_create(db, demand, batch, item.allocated_quantity, None, offer))
    s.remember(db, key, fingerprint, demand.id)
    return result([dm.allocation_view(a, True) for a in created])


@app.patch(prefix + '/ops/allocations/{id}', dependencies=[Depends(auth.ops)])
def update_demand_allocation(id: str, data: c.AllocationUpdate, idempotency_key: str = Header(), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, 'ops', 'allocation-update', idempotency_key, {'id': id, **data.model_dump()})
    allocation = db.get(m.DemandAllocation, id)
    if not allocation: s.fail('Allocation not found.', 404)
    if not prior:
        allocation = dm.allocation_update(db, allocation, data.allocated_quantity, data.status, None)
        s.remember(db, key, fingerprint, allocation.id)
    return result(dm.allocation_view(allocation, True))


@app.patch(prefix + '/ops/requirements/{id}/progress', dependencies=[Depends(auth.ops)])
def update_requirement_progress(id: str, data: c.RequirementProgress, db=Depends(database)):
    row = db.scalar(select(m.SourcingRequest).where(m.SourcingRequest.id == id).with_for_update())
    if not row: s.fail('Requirement not found.', 404)
    allowed = {'open': {'confirmed','cancelled'}, 'partially_matched': {'confirmed','cancelled'},
        'fully_matched': {'confirmed','cancelled'}, 'confirmed': {'fulfilling','cancelled'},
        'fulfilling': {'completed','cancelled'}, 'completed': set(), 'cancelled': set(),
        'submitted': {'confirmed','cancelled'}, 'sourcing': {'confirmed','cancelled'}, 'supply_found': {'confirmed','cancelled'}}
    if data.status != row.status and data.status not in allowed.get(row.status, set()):
        s.fail('This requirement cannot move to that status.')
    if data.status == 'confirmed' and dm.secured(db, row.id) < row.quantity:
        s.fail('Secure the full requested quantity before confirming.')
    if data.status == 'cancelled':
        active = db.scalars(select(m.DemandAllocation).where(m.DemandAllocation.demand_id == id, m.DemandAllocation.status.in_(dm.SECURED_ALLOCATION_STATES)).with_for_update()).all()
        for allocation in active: dm.allocation_update(db, allocation, None, 'cancelled', None)
    row.status = data.status
    if data.internal_notes: row.admin_notes = data.internal_notes
    return result(dm.buyer_requirement(db, row))


@app.get(prefix + '/ops/batches', dependencies=[Depends(auth.ops)])
def ops_batches(status: Optional[str] = None, db=Depends(database)):
    query = select(m.SupplierBatch)
    if status: query = query.where(m.SupplierBatch.status == status)
    rows = db.scalars(query.order_by(m.SupplierBatch.expected_ready_date.asc().nullslast()).limit(300)).all()
    return result([dm.batch_view(row, private=True) | {'supplier_id': row.supplier_id,
        'supplier_name': db.get(m.SupplierProfile, row.supplier_id).legal_name if db.get(m.SupplierProfile,row.supplier_id) else db.get(m.User,row.supplier_id).name,
        'approved_at': row.approved_at} for row in rows])


@app.post(prefix + '/ops/batches/{id}/verify', dependencies=[Depends(auth.ops)])
def verify_supplier_batch(id: str, data: c.BatchVerificationInput, idempotency_key: str = Header(), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, 'ops', 'batch-verification', idempotency_key, {'id': id, **data.model_dump()})
    batch = db.scalar(select(m.SupplierBatch).where(m.SupplierBatch.id == id).with_for_update())
    if not batch: s.fail('Supplier batch not found.', 404)
    if prior:
        prior_row = db.get(m.BatchVerification, prior)
        return result({'id': prior_row.id, 'batch': dm.batch_view(batch, private=True), 'verification': {k: getattr(prior_row,k) for k in ('verified_quantity','sampled_average_weight_kg','rejected_quantity','readiness_confirmed','location_confirmed','status','inspected_at')}})
    validate_owned_media(db, data.photos, batch.supplier_id)
    if data.verified_quantity + data.rejected_quantity > batch.initial_quantity:
        s.fail('Verified and rejected quantities exceed the batch quantity.', 422)
    if data.verified_quantity < batch.reserved_quantity + batch.sold_quantity + batch.externally_sold_quantity:
        s.fail('Verified quantity cannot be below already reserved or sold quantities.', 422)
    asking = data.supplier_asking_price_per_unit if data.supplier_asking_price_per_unit is not None else batch.asking_price_per_unit
    if asking is None:
        s.fail('Record the agreed supplier asking price before approving this batch.', 422)
    payout = data.supplier_payout_price_per_unit if data.supplier_payout_price_per_unit is not None else asking
    if payout > asking:
        s.fail('Supplier payout cannot exceed the supplier asking price.', 422)
    row = m.BatchVerification(batch_id=id, inspected_by=None, expected_quantity=batch.initial_quantity,
        verified_quantity=data.verified_quantity, sampled_average_weight_kg=data.sampled_average_weight_kg,
        rejected_quantity=data.rejected_quantity, readiness_confirmed=data.readiness_confirmed,
        location_confirmed=data.location_confirmed, notes=data.notes, photos=data.photos,
        status='approved' if data.readiness_confirmed and data.location_confirmed else 'needs_follow_up')
    db.add(row)
    batch.approved_at = m.now()
    batch.current_quantity = data.verified_quantity
    batch.actual_average_weight_kg = data.sampled_average_weight_kg
    batch.asking_price_per_unit = asking
    batch.supplier_payout_price_per_unit = payout
    batch.buyer_price_per_unit = data.buyer_price_per_unit
    batch.status = 'ready' if data.readiness_confirmed and data.location_confirmed and batch.expected_ready_date and batch.expected_ready_date <= date.today().isoformat() else 'growing'
    db.flush(); s.remember(db, key, fingerprint, row.id)
    return result({'id': row.id, 'batch': dm.batch_view(batch, private=True), 'verification': {k: getattr(row,k) for k in ('verified_quantity','sampled_average_weight_kg','rejected_quantity','readiness_confirmed','location_confirmed','status','inspected_at')}})




@app.post(prefix + '/requirements/{id}/cancel')
def cancel_requirement(id: str, idempotency_key: str = Header(), user=Depends(buyer), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'requirement-cancel', idempotency_key, {'id': id})
    row = s.owned(db, m.SourcingRequest, id, user.id, 'buyer_id', True)
    if not prior:
        if row.status in ('completed', 'cancelled'):
            s.fail('This requirement is already closed.')
        active = db.scalars(select(m.DemandAllocation).where(m.DemandAllocation.demand_id == id,
            m.DemandAllocation.status.in_(dm.SECURED_ALLOCATION_STATES)).with_for_update()).all()
        for allocation in active:
            dm.allocation_update(db, allocation, None, 'cancelled', None)
        row.status = 'cancelled'
        s.remember(db, key, fingerprint, row.id)
    return result(dm.buyer_requirement(db, row))


@app.post(prefix + '/supplier/offers/{id}/withdraw')
def withdraw_offer(id: str, idempotency_key: str = Header(), user=Depends(supplier), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'offer-withdraw', idempotency_key, {'id': id})
    offer = db.scalar(select(m.SupplyOffer).where(m.SupplyOffer.id == id, m.SupplyOffer.supplier_id == user.id).with_for_update())
    if not offer: s.fail('Supply offer not found.', 404)
    if not prior:
        if offer.status != 'pending': s.fail('Only a pending offer can be withdrawn.')
        offer.status = 'withdrawn'
        s.remember(db, key, fingerprint, offer.id)
    return result(dm.offer_view(offer))


@app.patch(prefix + '/ops/buyer-crm/{id}', dependencies=[Depends(auth.ops)])
def update_buyer_profile(id: str, data: c.BuyerProfileInput, db=Depends(database)):
    profile = db.get(m.BuyerProfile, id)
    if not profile: s.fail('Buyer not found.', 404)
    values = data.model_dump()
    user_id = values.pop('user_id')
    if user_id and user_id != profile.user_id:
        linked = db.get(m.User, user_id)
        if not linked or 'buyer' not in linked.roles: s.fail('Choose an existing buyer account.', 422)
        duplicate = db.scalar(select(m.BuyerProfile).where(m.BuyerProfile.user_id == user_id, m.BuyerProfile.id != id))
        if duplicate: s.fail('This account already has a buyer CRM record.', 409)
    profile.user_id = user_id
    for field, value in values.items(): setattr(profile, field, value)
    return result({'id': profile.id, **{k: getattr(profile, k) for k in ('business_name','buyer_type','contact_person','phone','region','area','internal_notes','preferences','last_known_buying_price','minimum_order','payment_terms')}})


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
    return result([{**dm.buyer_requirement(db, row), 'buyer_id': row.buyer_id,
        'quantity_secured': dm.secured(db, row.id), 'admin_notes': row.admin_notes}
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
    suppliers, items = [], []
    for item in db.scalars(select(m.OrderItem).where(m.OrderItem.order_id == id)):
        listing = db.get(m.Listing, item.listing_id)
        profile = db.get(m.SupplierProfile, listing.supplier_id)
        user = db.get(m.User, listing.supplier_id)
        suppliers.append({'listing_id': listing.id, 'supplier_id': user.id, 'phone': user.phone,
            'legal_name': profile.legal_name, 'internal_pickup_address': profile.internal_pickup_address})
        items.append({'id': item.id, 'listing_id': listing.id, 'supplier_id': user.id,
            'category': listing.category, 'unit_type': listing.unit_type, 'quantity': item.quantity,
            'unit_price': item.unit_price, 'subtotal': item.subtotal,
            'asking_snapshot': item.asking_snapshot, 'payout_snapshot': item.payout_snapshot,
            'actual_quantity': item.actual_quantity, 'rejected_quantity': item.rejected_quantity})
    return result({**s.buyer_order(db, row), 'internal_status': row.internal_status,
        'items': items, 'suppliers': suppliers, 'collection_notes': row.collection_notes,
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
def sales(listing_id: Optional[str] = None, user=Depends(supplier), db=Depends(database)):
    query = select(m.StockSale).where(m.StockSale.supplier_id == user.id)
    if listing_id:
        query = query.where(m.StockSale.listing_id == listing_id)
    return result([inv.sale_view(db, sale) for sale in db.scalars(query.order_by(m.StockSale.sold_at.desc(), m.StockSale.created_at.desc()))])


@app.get(prefix + '/supplier/sales/{id}')
def sale_detail(id: str, user=Depends(supplier), db=Depends(database)):
    return result(inv.sale_view(db, s.owned(db, m.StockSale, id, user.id, 'supplier_id')))


# --- Operations dashboard read models -----------------------------------------
# These endpoints serve the ops web dashboard. They are operator-only and may
# expose both buyer and supplier internal identity, which no mobile contract does.

def _today_range():
    start = m.now().replace(hour=0, minute=0, second=0, microsecond=0)
    return start, start + timedelta(days=1)


@app.get(prefix + '/ops/summary', dependencies=[Depends(auth.ops)])
def ops_summary(db=Depends(database)):
    start, end = _today_range()
    today = select(m.Order).where(m.Order.created_at >= start, m.Order.created_at < end)
    counted = [o for o in db.scalars(today) if o.internal_status not in ('cancelled', 'payment_failed')]
    sales = sum((o.total_amount for o in counted), Decimal('0'))
    margin = Decimal('0')
    for order in counted:
        for item in db.scalars(select(m.OrderItem).where(m.OrderItem.order_id == order.id)):
            margin += (item.unit_price - item.payout_snapshot) * item.quantity
    listings = db.scalars(select(m.Listing)).all()
    open_orders = db.scalars(select(m.Order).where(m.Order.internal_status.notin_(
        ['delivered', 'completed', 'cancelled', 'payment_failed']))).all()
    requirements = db.scalars(select(m.SourcingRequest).where(m.SourcingRequest.status.notin_(['completed', 'cancelled']))).all()
    batches = db.scalars(select(m.SupplierBatch).where(m.SupplierBatch.status.notin_(['completed', 'paused', 'cancelled']))).all()
    active_demand = len(requirements)
    total_demanded = sum((Decimal(row.quantity) for row in requirements), Decimal('0'))
    total_reserved = sum((Decimal(row.reserved_quantity) for row in batches), Decimal('0'))
    expected_supplier_quantity = sum((Decimal(row.available_to_commit) + Decimal(row.reserved_quantity) for row in batches if row.approved_at), Decimal('0'))
    unmatched = [row for row in requirements if dm.remaining(db, row) > 0 and not dm.candidate_batches(db, row)]
    soon = [row for row in batches if row.approved_at and row.expected_ready_date and m.now().date().isoformat() <= row.expected_ready_date <= (m.now().date() + timedelta(days=7)).isoformat()]
    soon_unallocated = [row for row in soon if row.available_to_commit > 0 and row.reserved_quantity == 0]
    return result({
        'orders_today': len(counted),
        'sales_today': sales,
        'gross_margin_today': margin,
        'pending_settlements': sum((r.total_payable for r in db.scalars(
            select(m.Settlement).where(m.Settlement.status == 'pending'))), Decimal('0')),
        'demand_metrics': {
            'active_buyer_demand': active_demand,
            'total_quantity_demanded': total_demanded,
            'expected_supplier_quantity': expected_supplier_quantity,
            'commercially_reserved_quantity': total_reserved,
            'unmatched_demand': len(unmatched),
            'supply_ready_soon': len(soon),
            'ready_for_collection': sum(1 for row in open_orders if row.internal_status == 'pickup_scheduled'),
            'orders_fulfilling': len(open_orders),
        },
        'attention': {
            'demand_no_matching_supply': len(unmatched),
            'partially_secured_near_deadline': sum(1 for row in requirements if row.status == 'partially_matched' and row.needed_by_date <= (m.now().date() + timedelta(days=7)).isoformat()),
            'batches_ready_unallocated': len(soon_unallocated),
            'reservations_awaiting_confirmation': db.scalar(select(func.count()).select_from(m.DemandAllocation).where(m.DemandAllocation.status == 'reserved')) or 0,
            'verification_overdue': sum(1 for row in batches if row.status == 'pending_review' and row.expected_ready_date and row.expected_ready_date <= m.now().date().isoformat()),
            'listings_pending_review': sum(1 for r in listings if r.listing_status == 'pending_review'),
            'listings_needing_confirmation': sum(1 for r in listings if r.listing_status == 'needs_confirmation'
                or (r.listing_status == 'live' and r.confirmation_due_at <= m.now())),
            'sourcing_unmatched': len(db.scalars(select(m.SourcingRequest).where(
                m.SourcingRequest.status.in_(['submitted', 'sourcing']))).all()),
            'orders_in_progress': len(open_orders),
            'payments_pending': len(db.scalars(select(m.Payment).where(
                m.Payment.status.in_(['pending', 'partial']))).all()),
            'settlements_pending': len(db.scalars(select(m.Settlement).where(
                m.Settlement.status == 'pending')).all()),
        },
    })


# Operations run on Tanzanian time: month buckets and date ranges on the
# dashboard follow the local calendar, not UTC.
EAT = ZoneInfo('Africa/Dar_es_Salaam')
OPEN_BATCH = ('growing', 'ready', 'partially_reserved', 'fully_reserved', 'pending_review')


def _local_day(value: date):
    return datetime.combine(value, time.min, tzinfo=EAT)


def _buyer_label(db, order):
    if order.buyer_id:
        profile = db.scalar(select(m.BuyerProfile).where(m.BuyerProfile.user_id == order.buyer_id))
        if profile and profile.business_name:
            return profile.business_name
        user = db.get(m.User, order.buyer_id)
        if user:
            return user.name or user.phone
    return 'Managed order'


@app.get(prefix + '/ops/dashboard', dependencies=[Depends(auth.ops)])
def ops_dashboard(start: Optional[date] = None, end: Optional[date] = None, year: Optional[int] = None, db=Depends(database)):
    today = m.now().astimezone(EAT).date()
    start = start or today.replace(day=1)
    end = end or today
    if end < start:
        s.fail('The end date must be on or after the start date.', 422)
    year = year or today.year
    since, until = _local_day(start), _local_day(end + timedelta(days=1))

    profiles = db.scalars(select(m.SupplierProfile)).all()
    users = {u.id: u for u in db.scalars(select(m.User).where(m.User.id.in_([p.user_id for p in profiles])))} if profiles else {}
    batches = db.scalars(select(m.SupplierBatch)).all()
    open_orders = db.scalars(select(m.Order).where(m.Order.internal_status.notin_(
        ['delivered', 'completed', 'cancelled', 'payment_failed']))).all()
    pending_settlements = db.scalars(select(m.Settlement).where(m.Settlement.status == 'pending')).all()

    # Supplies recorded: stock listings and production batches suppliers submit.
    trend = [0] * 12
    year_start, year_end = _local_day(date(year, 1, 1)), _local_day(date(year + 1, 1, 1))
    for model in (m.Listing, m.SupplierBatch):
        for created in db.scalars(select(model.created_at).where(model.created_at >= year_start, model.created_at < year_end)):
            trend[created.astimezone(EAT).month - 1] += 1

    batch_status = {'live': 0, 'pending': 0, 'completed': 0}
    for batch in batches:
        if batch.status == 'completed':
            batch_status['completed'] += 1
        elif batch.status in OPEN_BATCH:
            batch_status['live' if batch.approved_at else 'pending'] += 1

    period_orders = [o for o in db.scalars(select(m.Order).where(m.Order.created_at >= since, m.Order.created_at < until))
        if o.internal_status not in ('cancelled', 'payment_failed')]
    margin = Decimal('0')
    for order in period_orders:
        for item in db.scalars(select(m.OrderItem).where(m.OrderItem.order_id == order.id)):
            margin += (item.unit_price - item.payout_snapshot) * item.quantity

    joined = sorted((p for p in profiles if since <= users[p.user_id].created_at < until),
        key=lambda p: users[p.user_id].created_at, reverse=True)
    recent_orders = db.scalars(select(m.Order).where(m.Order.created_at >= since, m.Order.created_at < until)
        .order_by(m.Order.created_at.desc()).limit(5)).all()

    alias = {p.user_id: p.public_alias or p.legal_name for p in profiles}
    activity = []
    for p in profiles:
        activity.append({'kind': 'supplier_registered', 'at': users[p.user_id].created_at, 'title': 'New supplier registered', 'detail': alias[p.user_id], 'href': f'/suppliers/{p.user_id}'})
        if p.approved_at:
            activity.append({'kind': 'supplier_approved', 'at': p.approved_at, 'title': 'Supplier approved', 'detail': alias[p.user_id], 'href': f'/suppliers/{p.user_id}'})
        if p.suspended_at:
            activity.append({'kind': 'supplier_suspended', 'at': p.suspended_at, 'title': 'Supplier suspended', 'detail': alias[p.user_id], 'href': f'/suppliers/{p.user_id}'})
        if p.reviewed_at and p.reviewed_at not in (p.approved_at, p.suspended_at):
            activity.append({'kind': 'supplier_status', 'at': p.reviewed_at, 'title': 'Supplier status updated', 'detail': f"{alias[p.user_id]} \u2192 {p.status.replace('_', ' ').capitalize()}", 'href': f'/suppliers/{p.user_id}'})
    for order in db.scalars(select(m.Order).where(m.Order.created_at >= since, m.Order.created_at < until)):
        activity.append({'kind': 'order_created', 'at': order.created_at, 'title': 'Order created', 'detail': _buyer_label(db, order), 'href': f'/orders/{order.id}'})
    for batch in batches:
        activity.append({'kind': 'batch_created', 'at': batch.created_at, 'title': 'Production batch created', 'detail': f"{alias.get(batch.supplier_id, 'Supplier')} \u00b7 {batch.category.replace('_', ' ').capitalize()}", 'href': '/batches'})
    for listing in db.scalars(select(m.Listing).where(m.Listing.created_at >= since, m.Listing.created_at < until)):
        activity.append({'kind': 'stock_submitted', 'at': listing.created_at, 'title': 'Stock submitted', 'detail': f"{alias.get(listing.supplier_id, 'Supplier')} \u00b7 {listing.category.replace('_', ' ').capitalize()}", 'href': f'/supply/{listing.id}'})
    for settlement in db.scalars(select(m.Settlement).where(m.Settlement.paid_at >= since, m.Settlement.paid_at < until)):
        activity.append({'kind': 'settlement_paid', 'at': settlement.paid_at, 'title': 'Supplier paid', 'detail': alias.get(settlement.supplier_id, 'Supplier'), 'href': '/settlements'})
    activity = sorted((a for a in activity if since <= a['at'] < until), key=lambda a: a['at'], reverse=True)

    return result({
        'period': {'start': start, 'end': end},
        'kpis': {
            'active_suppliers': sum(1 for p in profiles if p.status not in ('rejected', 'suspended')),
            'approved_suppliers': sum(1 for p in profiles if p.status == 'approved'),
            'active_batches': sum(1 for b in batches if b.status in OPEN_BATCH),
            'open_orders': len(open_orders),
            'pending_settlements': sum((r.total_payable for r in pending_settlements), Decimal('0')),
            'pending_settlement_count': len(pending_settlements),
        },
        'trading': {
            'orders': len(period_orders),
            'sales': sum((o.total_amount for o in period_orders), Decimal('0')),
            'gross_margin': margin,
        },
        'supply_trend': {'year': year, 'months': trend},
        'batch_status': batch_status,
        'recent_suppliers': [{'id': p.user_id, 'name': alias[p.user_id], 'region': p.region, 'district': p.district,
            'status': p.status, 'joined_at': users[p.user_id].created_at} for p in joined[:5]],
        'recent_orders': [{'id': o.id, 'buyer': _buyer_label(db, o), 'internal_status': o.internal_status,
            'total_amount': o.total_amount, 'created_at': o.created_at} for o in recent_orders],
        'recent_activity': activity[:6],
    })


@app.get(prefix + '/ops/payments', dependencies=[Depends(auth.ops)])
def ops_payments(db=Depends(database)):
    rows = []
    for payment in db.scalars(select(m.Payment).order_by(m.Payment.created_at.desc()).limit(200)):
        order = db.get(m.Order, payment.order_id)
        buyer = db.get(m.User, order.buyer_id) if order.buyer_id else None
        crm = db.get(m.BuyerProfile, db.get(m.SourcingRequest, order.sourcing_request_id).buyer_profile_id) if order.sourcing_request_id and db.get(m.SourcingRequest, order.sourcing_request_id) else None
        rows.append({'id': payment.id, 'order_id': order.id, 'buyer_id': buyer.id if buyer else None, 'buyer_name': buyer.name if buyer else (crm.business_name if crm else 'Offline buyer'),
            'amount': payment.amount, 'received_amount': payment.received_amount,
            'balance': payment.amount - payment.received_amount, 'method': payment.method,
            'status': payment.status, 'internal_status': order.internal_status,
            'provider_transaction_id': payment.provider_transaction_id,
            'paid_at': payment.paid_at, 'created_at': payment.created_at})
    return result(rows)


@app.post(prefix + '/ops/suppliers/photos', dependencies=[Depends(auth.ops)])
async def ops_supplier_photo(file: UploadFile = File(), db=Depends(database)):
    raw = await file.read(settings().upload_max_bytes + 1)
    if len(raw) > settings().upload_max_bytes:
        s.fail('Choose a photo smaller than 8 MB.', 413)
    return save_photo(db, None, raw)


@app.get(prefix + '/ops/suppliers', dependencies=[Depends(auth.ops)])
def ops_suppliers(db=Depends(database)):
    rows = []
    for profile in db.scalars(select(m.SupplierProfile).order_by(m.SupplierProfile.user_id)):
        user = db.get(m.User, profile.user_id)
        listings = db.scalars(select(m.Listing).where(m.Listing.supplier_id == profile.user_id)).all()
        pending = db.scalars(select(m.Settlement).where(
            m.Settlement.supplier_id == profile.user_id, m.Settlement.status == 'pending')).all()
        rows.append({'id': user.id, 'phone': user.phone, 'region': profile.region,
            'district': profile.district, 'categories': profile.categories,
            'public_alias': profile.public_alias, 'alias_approved': profile.alias_approved,
            'status': profile.status, 'legal_name': profile.legal_name,
            'completed_supplies_count': profile.completed_supplies_count,
            'live_listings': sum(1 for r in listings if r.listing_status == 'live'),
            'pending_listings': sum(1 for r in listings if r.listing_status == 'pending_review'),
            'pending_settlement_total': sum((r.total_payable for r in pending), Decimal('0'))})
    return result(rows)


@app.post(prefix + '/ops/suppliers', status_code=201, dependencies=[Depends(auth.ops)])
def ops_create_supplier(data: c.OperatorSupplierInput, idempotency_key: str = Header(), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, 'ops', 'supplier-onboarding', idempotency_key, data.model_dump())
    if prior:
        return result({'id': prior, 'status': db.get(m.SupplierProfile, prior).status})
    user = db.scalar(select(m.User).where(m.User.phone == data.phone).with_for_update())
    if user is None:
        user = m.User(phone=data.phone, roles=['supplier'], name=data.name, region=data.region)
        db.add(user)
        db.flush()
    else:
        user.roles = sorted(set(user.roles) | {'supplier'})
        user.name = user.name or data.name
        user.region = user.region or data.region
    if db.get(m.SupplierProfile, user.id):
        s.fail('A supplier profile already exists for this phone. Open that supplier record instead.', 409)
    allowed_checks = {'phone_confirmed', 'identity_reviewed', 'location_confirmed',
        'location_visited', 'production_seen', 'pickup_access_checked', 'photos_reviewed'}
    if set(data.verification) - allowed_checks:
        s.fail('Choose a valid verification item.', 422)
    profile = _apply_supplier_profile(db, user, data, created_by='ops')
    profile.internal_notes = data.internal_notes
    if data.verification:
        profile.verification = {**(profile.verification or {}), **data.verification}
    batches = ([data.current_batch] if data.current_batch else []) + data.future_batches
    for batch_data in batches:
        batch = _create_supplier_batch(db, user.id, batch_data, profile.region, profile.internal_pickup_address, allow_unowned=True)
        db.add(batch)
    db.flush()
    s.remember(db, key, fingerprint, user.id)
    return result({'id': user.id, 'status': profile.status, 'phone': user.phone,
        'batches_created': len(batches)})


@app.get(prefix + '/ops/suppliers/{id}', dependencies=[Depends(auth.ops)])
def ops_supplier(id: str, db=Depends(database)):
    profile = db.get(m.SupplierProfile, id)
    user = db.get(m.User, id)
    if not profile or not user:
        s.fail('Supplier not found.', 404)
    batches = db.scalars(select(m.SupplierBatch).where(m.SupplierBatch.supplier_id == id).order_by(
        m.SupplierBatch.expected_ready_date.asc().nullslast())).all()
    verifications = db.scalars(select(m.BatchVerification).where(
        m.BatchVerification.batch_id.in_([b.id for b in batches]))).all() if batches else []
    return result({'id': user.id, 'phone': user.phone, 'name': user.name, 'region': profile.region,
        'public_alias': profile.public_alias, 'alias_approved': profile.alias_approved,
        'legal_name': profile.legal_name, 'alternate_phone': profile.alternate_phone,
        'district': profile.district, 'general_area': profile.general_area,
        'categories': profile.categories, 'primary_category': profile.primary_category,
        'production_profile': profile.production_profile, 'production_frequency': profile.production_frequency,
        'evidence_photos': profile.evidence_photos,
        'internal_pickup_address': profile.internal_pickup_address,
        'pickup_instructions': profile.pickup_instructions, 'omoterra_pickup': profile.omoterra_pickup,
        'supplier_transport': profile.supplier_transport, 'supply_forms': profile.supply_forms,
        'preferred_contact_method': profile.preferred_contact_method,
        'operating_notes': profile.operating_notes, 'internal_notes': profile.internal_notes,
        'status': profile.status, 'verification': profile.verification,
        'reviewed_by_actor': profile.reviewed_by_actor, 'reviewed_at': profile.reviewed_at,
        'approved_by_actor': profile.approved_by_actor, 'approved_at': profile.approved_at,
        'suspended_by_actor': profile.suspended_by_actor, 'suspended_at': profile.suspended_at,
        'created_at': user.created_at,
        'batches': [dm.batch_view(b, private=True) for b in batches],
        'batch_verifications': [{'batch_id': v.batch_id, **{k: getattr(v, k) for k in (
            'verified_quantity', 'sampled_average_weight_kg', 'rejected_quantity',
            'readiness_confirmed', 'location_confirmed', 'notes', 'status', 'inspected_at')}} for v in verifications],
        'listings': [{**s.supplier_listing(row), 'buyer_price_per_unit': row.buyer_price_per_unit,
            'supplier_payout_price_per_unit': row.supplier_payout_price_per_unit}
            for row in db.scalars(select(m.Listing).where(m.Listing.supplier_id == id).order_by(m.Listing.created_at.desc()))],
        'settlements': [{**s.payout_view(row, True), 'order_item_id': row.order_item_id}
            for row in db.scalars(select(m.Settlement).where(m.Settlement.supplier_id == id).order_by(m.Settlement.created_at.desc()))]})


@app.put(prefix + '/ops/suppliers/{id}', dependencies=[Depends(auth.ops)])
def ops_update_supplier(id: str, data: c.SupplierProfileInput, db=Depends(database)):
    user = db.scalar(select(m.User).where(m.User.id == id).with_for_update())
    profile = db.scalar(select(m.SupplierProfile).where(m.SupplierProfile.user_id == id).with_for_update())
    if not user or not profile:
        s.fail('Supplier not found.', 404)
    if profile.public_alias != data.public_alias:
        profile.alias_approved = False
    _apply_supplier_profile(db, user, data, created_by='ops')
    return result({'id': id, 'status': profile.status})


@app.patch(prefix + '/ops/suppliers/{id}/status', dependencies=[Depends(auth.ops)])
def ops_supplier_status(id: str, data: c.SupplierStatusInput, db=Depends(database)):
    profile = db.scalar(select(m.SupplierProfile).where(m.SupplierProfile.user_id == id).with_for_update())
    if not profile:
        s.fail('Supplier not found.', 404)
    if data.status == 'approved':
        user = db.get(m.User, id)
        if not profile.public_alias or not profile.legal_name or not profile.internal_pickup_address or not profile.region:
            s.fail('Complete the supplier identity and pickup details before approval.', 422)
        if not profile.categories or not profile.district:
            s.fail('Add at least one supply category and district before approval.', 422)
        if not profile.production_profile or not profile.production_frequency:
            s.fail('Record normal production capacity and production frequency before approval.', 422)
        required_checks = ('phone_confirmed', 'identity_reviewed', 'location_confirmed',
            'production_seen', 'pickup_access_checked')
        if not all(profile.verification.get(check) is True for check in required_checks):
            s.fail('Complete the supplier verification checklist before approval.', 422)
        profile.approved_by_actor = profile.reviewed_by_actor = 'ops'
        profile.approved_at = profile.reviewed_at = m.now()
    elif data.status == 'suspended':
        profile.suspended_by_actor = 'ops'
        profile.suspended_at = m.now()
        for listing in db.scalars(select(m.Listing).where(m.Listing.supplier_id == id, m.Listing.listing_status == 'live')):
            listing.listing_status = 'paused'
    elif data.status in ('rejected', 'under_review'):
        profile.reviewed_by_actor = 'ops'
        profile.reviewed_at = m.now()
    profile.status = data.status
    if data.notes:
        profile.internal_notes = data.notes
    return result({'id': id, 'status': profile.status, 'reviewed_at': profile.reviewed_at,
        'approved_at': profile.approved_at, 'suspended_at': profile.suspended_at})


@app.patch(prefix + '/ops/suppliers/{id}/verification', dependencies=[Depends(auth.ops)])
def ops_supplier_verification(id: str, data: c.SupplierVerificationInput, db=Depends(database)):
    profile = db.scalar(select(m.SupplierProfile).where(m.SupplierProfile.user_id == id).with_for_update())
    if not profile:
        s.fail('Supplier not found.', 404)
    allowed = {'phone_confirmed', 'identity_reviewed', 'location_confirmed',
        'location_visited', 'production_seen', 'pickup_access_checked', 'photos_reviewed'}
    if set(data.checks) - allowed:
        s.fail('Choose a valid verification item.', 422)
    profile.verification = {**profile.verification, **data.checks}
    profile.reviewed_by_actor = 'ops'
    profile.reviewed_at = m.now()
    if data.notes:
        profile.internal_notes = data.notes
    return result({'verification': profile.verification, 'reviewed_at': profile.reviewed_at})


@app.get(prefix + '/ops/buyers', dependencies=[Depends(auth.ops)])
def ops_buyers(db=Depends(database)):
    rows = []
    for user in db.scalars(select(m.User).order_by(m.User.created_at.desc()).limit(200)):
        if 'buyer' not in user.roles:
            continue
        rows.append({'id': user.id, 'name': user.name, 'phone': user.phone, 'region': user.region,
            'buyer_type': user.buyer_type,
            'order_count': len(db.scalars(select(m.Order).where(m.Order.buyer_id == user.id)).all()),
            'request_count': len(db.scalars(select(m.SourcingRequest).where(
                m.SourcingRequest.buyer_id == user.id)).all())})
    return result(rows)


@app.get(prefix + '/ops/buyers/{id}', dependencies=[Depends(auth.ops)])
def ops_buyer(id: str, db=Depends(database)):
    user = db.get(m.User, id)
    if not user or 'buyer' not in user.roles:
        s.fail('Buyer not found.', 404)
    return result({'id': user.id, 'name': user.name, 'phone': user.phone, 'region': user.region,
        'buyer_type': user.buyer_type, 'created_at': user.created_at,
        'addresses': [{'id': row.id, **{key: getattr(row, key) for key in c.AddressInput.model_fields}}
            for row in db.scalars(select(m.Address).where(m.Address.user_id == id, m.Address.deleted.is_(False)))],
        'orders': [{**s.buyer_order(db, row), 'internal_status': row.internal_status}
            for row in db.scalars(select(m.Order).where(m.Order.buyer_id == id).order_by(m.Order.created_at.desc()))],
        'requests': [{**s.buyer_request(row), 'quantity_secured': row.quantity_secured, 'admin_notes': row.admin_notes}
            for row in db.scalars(select(m.SourcingRequest).where(m.SourcingRequest.buyer_id == id).order_by(m.SourcingRequest.created_at.desc()))]})


@app.post(prefix + '/supplier/sales/{id}/reverse')
def reverse_sale(id: str, data: c.SaleReversalInput, idempotency_key: str = Header(), user=Depends(supplier), db=Depends(database)):
    key, fingerprint, prior = s.replay(db, user.id, 'sale-reversal', idempotency_key, {'id': id, **data.model_dump()})
    sale = s.owned(db, m.StockSale, id, user.id, 'supplier_id', True)
    if prior:
        return result(inv.sale_view(db, sale))
    if sale.source != 'external':
        s.fail('Omoterra deliveries must be reconciled by the Omoterra team.')
    if db.scalar(select(m.StockSaleReversal).where(m.StockSaleReversal.sale_id == id)):
        s.fail('This sale has already been reversed.')
    listing = s.owned(db, m.Listing, sale.listing_id, user.id, 'supplier_id', True)
    before = inv.balances(listing)
    listing.quantity_sold -= sale.quantity
    stock_status(listing)
    db.add(m.StockSaleReversal(sale_id=id, supplier_id=user.id, reason=data.reason))
    inv.movement(db, listing, 'sale_reversed', before, key, data.reason, user.id)
    s.remember(db, key, fingerprint, id)
    return result(inv.sale_view(db, sale))
