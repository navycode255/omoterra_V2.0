from __future__ import annotations

import uuid
from typing import Optional
from datetime import date, datetime, timezone
from decimal import Decimal
from sqlalchemy import String, Numeric, Date, DateTime, ForeignKey, UniqueConstraint, CheckConstraint, JSON, Boolean, Integer, Text, Index, text
from sqlalchemy.orm import Mapped, mapped_column
from .db import Base


def now():
    return datetime.now(timezone.utc)


def identifier():
    return str(uuid.uuid4())


class Entity:
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=identifier)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class User(Entity, Base):
    __tablename__ = 'users'
    phone: Mapped[str] = mapped_column(String(20), unique=True)
    name: Mapped[str] = mapped_column(default='')
    region: Mapped[str] = mapped_column(default='')
    language: Mapped[str] = mapped_column(default='en')
    roles: Mapped[list] = mapped_column(JSON, default=list)
    buyer_type: Mapped[Optional[str]]
    # Account deletion anonymizes and deactivates rather than removing the
    # row: orders, settlements and audit trails referencing this id must
    # survive. `phone` is rewritten to a unique placeholder so the real
    # number can sign up again.
    deleted: Mapped[bool] = mapped_column(default=False)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    # Website sign-in without an SMS each time (app/auth.py). Salted PBKDF2.
    pin_hash: Mapped[Optional[str]] = mapped_column(String(200))
    pin_failed_attempts: Mapped[int] = mapped_column(default=0)
    pin_locked_until: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))


class SupplierProfile(Base):
    __tablename__ = 'supplier_profiles'
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id'), primary_key=True)
    public_alias: Mapped[str] = mapped_column(default='Omoterra supply partner')
    alias_approved: Mapped[bool] = mapped_column(default=False)
    legal_name: Mapped[str]
    internal_pickup_address: Mapped[str] = mapped_column(Text)
    completed_supplies_count: Mapped[int] = mapped_column(default=0)
    alternate_phone: Mapped[str] = mapped_column(default='')
    region: Mapped[str] = mapped_column(default='', index=True)
    district: Mapped[str] = mapped_column(default='')
    general_area: Mapped[str] = mapped_column(default='')
    categories: Mapped[list] = mapped_column(JSON, default=list)
    # How the supplier chose to be paid (contracts.PayoutMethod). No account
    # numbers: those are asked for when a payout is due.
    payout_methods: Mapped[list] = mapped_column(JSON, default=list)
    primary_category: Mapped[Optional[str]]
    production_profile: Mapped[dict] = mapped_column(JSON, default=dict)
    evidence_photos: Mapped[list] = mapped_column(JSON, default=list)
    production_frequency: Mapped[str] = mapped_column(default='')
    operating_notes: Mapped[str] = mapped_column(Text, default='')
    pickup_instructions: Mapped[str] = mapped_column(Text, default='')
    omoterra_pickup: Mapped[bool] = mapped_column(default=False)
    supplier_transport: Mapped[bool] = mapped_column(default=False)
    supply_forms: Mapped[list] = mapped_column(JSON, default=list)
    preferred_contact_method: Mapped[str] = mapped_column(default='phone')
    # Exact farm pin, kept private to operations like the pickup address.
    farm_latitude: Mapped[Optional[Decimal]] = mapped_column(Numeric(9, 6))
    farm_longitude: Mapped[Optional[Decimal]] = mapped_column(Numeric(9, 6))
    farm_map_url: Mapped[str] = mapped_column(default='')
    status: Mapped[str] = mapped_column(default='new', index=True)
    # When the supplier last sent their registration for review (ops alerts).
    submitted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    verification: Mapped[dict] = mapped_column(JSON, default=dict)
    internal_notes: Mapped[str] = mapped_column(Text, default='')
    created_by_actor: Mapped[str] = mapped_column(default='supplier')
    reviewed_by_actor: Mapped[Optional[str]]
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    approved_by_actor: Mapped[Optional[str]]
    approved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    suspended_by_actor: Mapped[Optional[str]]
    suspended_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    __table_args__ = (CheckConstraint("status IN ('new','under_review','approved','suspended','rejected')", name='valid_supplier_status'),)


class BuyerProfile(Entity, Base):
    """Lightweight operations CRM record; may exist before the buyer has an app account."""
    __tablename__ = 'buyer_profiles'
    user_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), unique=True, index=True)
    business_name: Mapped[str] = mapped_column(default='')
    buyer_type: Mapped[str] = mapped_column(default='other')
    contact_person: Mapped[str] = mapped_column(default='')
    phone: Mapped[str] = mapped_column(default='')
    region: Mapped[str] = mapped_column(default='')
    area: Mapped[str] = mapped_column(default='')
    internal_notes: Mapped[str] = mapped_column(Text, default='')
    preferences: Mapped[dict] = mapped_column(JSON, default=dict)
    last_known_buying_price: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 2))
    minimum_order: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    payment_terms: Mapped[str] = mapped_column(default='')


class Address(Entity, Base):
    __tablename__ = 'addresses'
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    label: Mapped[str]
    recipient_name: Mapped[str]
    phone: Mapped[str]
    region: Mapped[str]
    district_area: Mapped[str]
    address_text: Mapped[str] = mapped_column(Text)
    coordinates: Mapped[Optional[str]]
    deleted: Mapped[bool] = mapped_column(default=False)
    # The buyer's default delivery address; checkout starts on it.
    is_default: Mapped[bool] = mapped_column(default=False)


class Listing(Entity, Base):
    __tablename__ = 'listings'
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    category: Mapped[str]
    unit_type: Mapped[str]
    specs: Mapped[dict] = mapped_column(JSON, default=dict)
    region: Mapped[str]
    photos: Mapped[list] = mapped_column(JSON, default=list)
    video: Mapped[Optional[str]]
    farmer_asking_price_per_unit: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    supplier_payout_price_per_unit: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 2))
    buyer_price_per_unit: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 2))
    quantity_total: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    quantity_reserved: Mapped[Decimal] = mapped_column(Numeric(14, 3), default=0)
    quantity_sold: Mapped[Decimal] = mapped_column(Numeric(14, 3), default=0)
    listing_status: Mapped[str] = mapped_column(default='pending_review', index=True)
    # What Omoterra asked the supplier to change ('changes_requested').
    review_note: Mapped[str] = mapped_column(Text, default='')
    last_confirmed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    confirmation_due_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), index=True)
    approved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    # When the supplier was last reminded to confirm availability, so the
    # reminder job sends one reminder per confirmation window.
    confirmation_reminded_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    __table_args__ = (
        CheckConstraint('quantity_total >= 0 AND quantity_reserved >= 0 AND quantity_sold >= 0 AND quantity_reserved + quantity_sold <= quantity_total', name='valid_inventory'),
        CheckConstraint('farmer_asking_price_per_unit > 0'),
        CheckConstraint('supplier_payout_price_per_unit >= 0 AND supplier_payout_price_per_unit <= farmer_asking_price_per_unit'),
        CheckConstraint('buyer_price_per_unit > 0'),
    )

    @property
    def quantity_available(self):
        return self.quantity_total - self.quantity_reserved - self.quantity_sold


class StockReservation(Entity, Base):
    __tablename__ = 'stock_reservations'
    listing_id: Mapped[str] = mapped_column(ForeignKey('listings.id'), index=True)
    buyer_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), index=True)
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    status: Mapped[str] = mapped_column(default='active')
    order_id: Mapped[Optional[str]] = mapped_column(ForeignKey('orders.id', use_alter=True), index=True)
    __table_args__ = (CheckConstraint('quantity > 0'),)


class Order(Entity, Base):
    __tablename__ = 'orders'
    buyer_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), index=True)
    delivery_address_id: Mapped[Optional[str]] = mapped_column(ForeignKey('addresses.id'))
    delivery_snapshot: Mapped[dict] = mapped_column(JSON)
    preferred_delivery_date: Mapped[str]
    expected_collection_date: Mapped[Optional[str]]
    payment_method: Mapped[str]
    payment_status: Mapped[str] = mapped_column(default='pending')
    sourcing_request_id: Mapped[Optional[str]] = mapped_column(ForeignKey('buyer_requirements.id', use_alter=True), index=True)
    internal_status: Mapped[str] = mapped_column(default='reserved')
    expected_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    actual_quantity: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    rejected_quantity: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    actual_weight: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    collection_photos: Mapped[list] = mapped_column(JSON, default=list)
    collection_notes: Mapped[str] = mapped_column(Text, default='')
    total_amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    idempotency_key: Mapped[str] = mapped_column(unique=True)
    activity: Mapped[list] = mapped_column(JSON, default=list)


class OrderItem(Entity, Base):
    __tablename__ = 'order_items'
    demand_allocation_id: Mapped[Optional[str]] = mapped_column(ForeignKey('demand_allocations.id'), unique=True)
    actual_quantity: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    rejected_quantity: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    order_id: Mapped[str] = mapped_column(ForeignKey('orders.id'), index=True)
    listing_id: Mapped[str] = mapped_column(ForeignKey('listings.id'))
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    unit_price: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    subtotal: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    asking_snapshot: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    payout_snapshot: Mapped[Decimal] = mapped_column(Numeric(14, 2))


class SourcingRequest(Entity, Base):
    # Existing Supply Requests evolve in place; /requests remains a compatible API alias.
    __tablename__ = 'buyer_requirements'
    buyer_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), index=True)
    buyer_profile_id: Mapped[Optional[str]] = mapped_column(ForeignKey('buyer_profiles.id'), index=True)
    requirement_number: Mapped[Optional[str]] = mapped_column(String(24), unique=True, index=True)
    category: Mapped[str] = mapped_column(index=True)
    product_subtype: Mapped[str] = mapped_column(default='')
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    unit_type: Mapped[str]
    minimum_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    maximum_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    weight_or_size_requirement: Mapped[str] = mapped_column(default='')
    live_dressed_or_cut: Mapped[str] = mapped_column(default='')
    needed_by_date: Mapped[str] = mapped_column(index=True)
    delivery_area: Mapped[str]
    delivery_region: Mapped[str] = mapped_column(default='', index=True)
    delivery_notes: Mapped[str] = mapped_column(Text, default='')
    requirement_type: Mapped[str] = mapped_column(default='one_time')
    recurrence_frequency: Mapped[str] = mapped_column(default='')
    preferred_weekdays: Mapped[list] = mapped_column(JSON, default=list)
    notes: Mapped[str] = mapped_column(Text, default='')
    reference_photo: Mapped[Optional[str]]
    quantity_secured: Mapped[Decimal] = mapped_column(Numeric(14, 3), default=0)
    status: Mapped[str] = mapped_column(default='submitted', index=True)
    converted_order_id: Mapped[Optional[str]] = mapped_column(ForeignKey('orders.id', use_alter=True))
    admin_notes: Mapped[str] = mapped_column(Text, default='')
    created_by: Mapped[str] = mapped_column(default='buyer')
    created_by_user_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'))


class SupplierBatch(Entity, Base):
    __tablename__ = 'supplier_batches'
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    category: Mapped[str] = mapped_column(index=True)
    subtype: Mapped[str] = mapped_column(default='')
    initial_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    current_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    reserved_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3), default=0)
    sold_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3), default=0)
    externally_sold_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3), default=0)
    current_age: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    age_unit: Mapped[str] = mapped_column(default='weeks')
    expected_ready_date: Mapped[Optional[str]] = mapped_column(index=True)
    expected_min_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    expected_max_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    actual_average_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    form: Mapped[str] = mapped_column(default='live')
    asking_price_per_unit: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 2))
    supplier_payout_price_per_unit: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 2))
    buyer_price_per_unit: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 2))
    linked_listing_id: Mapped[Optional[str]] = mapped_column(ForeignKey('listings.id'), index=True)
    region: Mapped[str] = mapped_column(default='', index=True)
    private_pickup_location: Mapped[str] = mapped_column(Text, default='')
    photos: Mapped[list] = mapped_column(JSON, default=list)
    status: Mapped[str] = mapped_column(default='growing', index=True)
    approved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    __table_args__ = (
        CheckConstraint('initial_quantity >= 0 AND current_quantity >= 0 AND reserved_quantity >= 0 AND sold_quantity >= 0 AND externally_sold_quantity >= 0', name='valid_batch_quantities'),
        CheckConstraint('reserved_quantity + sold_quantity + externally_sold_quantity <= current_quantity', name='valid_batch_allocatable'),
    )

    @property
    def available_to_commit(self):
        return self.current_quantity - self.reserved_quantity - self.sold_quantity - self.externally_sold_quantity


class MarketSlot(Entity, Base):
    """A future market requirement published by Omoterra operations."""
    __tablename__ = 'market_slots'
    category: Mapped[str] = mapped_column(index=True)
    delivery_date: Mapped[date] = mapped_column(Date, index=True)
    reservation_deadline: Mapped[date] = mapped_column(Date, index=True)
    quantity_required: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    unit_type: Mapped[str]
    region: Mapped[str] = mapped_column(default='', index=True)
    collection_point: Mapped[str] = mapped_column(default='')
    minimum_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    maximum_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    supply_type: Mapped[str] = mapped_column(default='live')
    price_per_unit: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 2))
    collection_method: Mapped[str]
    status: Mapped[str] = mapped_column(default='open', index=True)
    internal_note: Mapped[str] = mapped_column(Text, default='')
    created_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    updated_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, onupdate=now)
    __table_args__ = (
        CheckConstraint('quantity_required > 0', name='market_slot_quantity_positive'),
        CheckConstraint("unit_type IN ('bird','animal','kg','tray')", name='market_slot_unit_valid'),
        CheckConstraint("supply_type IN ('live','dressed','chilled','frozen')", name='market_slot_supply_type_valid'),
        CheckConstraint("collection_method IN ('omoterra_collects','supplier_delivers')", name='market_slot_collection_valid'),
        CheckConstraint("status IN ('draft','open','full','closed','cancelled','completed')", name='market_slot_status_valid'),
        CheckConstraint('reservation_deadline <= delivery_date', name='market_slot_deadline_before_delivery'),
        CheckConstraint('minimum_weight_kg IS NULL OR maximum_weight_kg IS NULL OR minimum_weight_kg <= maximum_weight_kg', name='market_slot_weight_range'),
    )


class MarketReservation(Entity, Base):
    """A supplier's immutable request and the quantity operations approved."""
    __tablename__ = 'market_reservations'
    market_slot_id: Mapped[str] = mapped_column(ForeignKey('market_slots.id'), index=True)
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    supplier_batch_id: Mapped[Optional[str]] = mapped_column(ForeignKey('supplier_batches.id'), index=True)
    quantity_requested: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    quantity_approved: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    status: Mapped[str] = mapped_column(default='requested', index=True)
    production_choice: Mapped[str]
    requested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    reviewed_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    rejection_reason: Mapped[str] = mapped_column(Text, default='')
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, onupdate=now)
    __table_args__ = (
        UniqueConstraint('market_slot_id', 'supplier_id', name='uq_market_reservation_supplier_slot'),
        CheckConstraint('quantity_requested > 0', name='market_reservation_requested_positive'),
        CheckConstraint('quantity_approved IS NULL OR quantity_approved > 0', name='market_reservation_approved_positive'),
        CheckConstraint("status IN ('requested','approved','rejected','cancelled','completed')", name='market_reservation_status_valid'),
        CheckConstraint("production_choice IN ('existing','planned')", name='market_reservation_production_valid'),
    )


class SupplierBatchMovement(Entity, Base):
    __tablename__ = 'supplier_batch_movements'
    batch_id: Mapped[str] = mapped_column(ForeignKey('supplier_batches.id'), index=True)
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    kind: Mapped[str] = mapped_column(default='external_sale')
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    note: Mapped[str] = mapped_column(Text, default='')
    idempotency_key: Mapped[str] = mapped_column(unique=True)


class SupplyOffer(Entity, Base):
    __tablename__ = 'supply_offers'
    demand_id: Mapped[str] = mapped_column(ForeignKey('buyer_requirements.id'), index=True)
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    batch_id: Mapped[Optional[str]] = mapped_column(ForeignKey('supplier_batches.id'), index=True)
    offered_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    accepted_quantity: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    expected_ready_date: Mapped[Optional[str]]
    expected_min_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    expected_max_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    asking_price_per_unit: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 2))
    supplier_notes: Mapped[str] = mapped_column(Text, default='')
    status: Mapped[str] = mapped_column(default='pending', index=True)
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    __table_args__ = (CheckConstraint('offered_quantity > 0'),)


class DemandAllocation(Entity, Base):
    __tablename__ = 'demand_allocations'
    demand_id: Mapped[str] = mapped_column(ForeignKey('buyer_requirements.id'), index=True)
    supply_offer_id: Mapped[Optional[str]] = mapped_column(ForeignKey('supply_offers.id'), index=True)
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    supplier_batch_id: Mapped[str] = mapped_column(ForeignKey('supplier_batches.id'), index=True)
    allocated_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    listing_id: Mapped[Optional[str]] = mapped_column(ForeignKey('listings.id'))
    accepted_quantity: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    rejected_quantity: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    status: Mapped[str] = mapped_column(default='reserved', index=True)
    allocated_by: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'))
    updated_by: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'))
    __table_args__ = (CheckConstraint('allocated_quantity > 0'),)


class BatchVerification(Entity, Base):
    __tablename__ = 'batch_verifications'
    batch_id: Mapped[str] = mapped_column(ForeignKey('supplier_batches.id'), index=True)
    inspected_by: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'))
    inspected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    expected_quantity: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    verified_quantity: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    sampled_average_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    rejected_quantity: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    readiness_confirmed: Mapped[bool] = mapped_column(default=False)
    location_confirmed: Mapped[bool] = mapped_column(default=False)
    notes: Mapped[str] = mapped_column(Text, default='')
    photos: Mapped[list] = mapped_column(JSON, default=list)
    status: Mapped[str] = mapped_column(default='pending', index=True)


class SourcingRequestAllocation(Entity, Base):
    __tablename__ = 'sourcing_request_allocations'
    sourcing_request_id: Mapped[str] = mapped_column(ForeignKey('buyer_requirements.id'))
    listing_id: Mapped[str] = mapped_column(ForeignKey('listings.id'))
    quantity_allocated: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    unit_price: Mapped[Decimal] = mapped_column(Numeric(14, 2))


class Settlement(Entity, Base):
    __tablename__ = 'settlements'
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    order_item_id: Mapped[str] = mapped_column(ForeignKey('order_items.id'))
    farmer_asking_price_per_unit: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    supplier_payout_price_per_unit: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    commission_amount_per_unit: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    total_payable: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    status: Mapped[str] = mapped_column(default='pending')
    paid_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    payment_reference: Mapped[Optional[str]]
    # The supplier's latest answer to "did this payout reach you?":
    # None (not asked yet or re-sent), 'received' or 'not_received'. Every
    # answer is kept in PayoutConfirmation.
    supplier_confirmation: Mapped[Optional[str]] = mapped_column(String(16))
    supplier_confirmed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    __table_args__ = (UniqueConstraint('order_item_id', 'supplier_id'),)


class PayoutConfirmation(Entity, Base):
    """One supplier answer about one paid settlement, with the amount and
    reference it answered about. Append-only (migration 023)."""
    __tablename__ = 'payout_confirmations'
    settlement_id: Mapped[str] = mapped_column(ForeignKey('settlements.id'), index=True)
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    outcome: Mapped[str] = mapped_column(String(16))
    note: Mapped[str] = mapped_column(Text, default='')
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    payment_reference: Mapped[Optional[str]]
    __table_args__ = (CheckConstraint("outcome IN ('received','not_received')", name='valid_payout_confirmation'),)


class Payment(Entity, Base):
    __tablename__ = 'payments'
    order_id: Mapped[str] = mapped_column(ForeignKey('orders.id'), unique=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    method: Mapped[str]
    status: Mapped[str] = mapped_column(default='pending')
    received_amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), default=0)
    provider_transaction_id: Mapped[Optional[str]] = mapped_column(unique=True)
    idempotency_key: Mapped[str] = mapped_column(unique=True)
    paid_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))


class BusinessOpportunity(Entity, Base):
    __tablename__ = 'business_opportunities'
    buyer_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    business_type: Mapped[str]
    area: Mapped[str]
    budget_range: Mapped[str]
    has_premises: Mapped[bool]
    wants_stock: Mapped[bool]
    target_start_date: Mapped[str]
    status: Mapped[str] = mapped_column(default='new')
    internal_notes: Mapped[str] = mapped_column(Text, default='')


class AuthSession(Entity, Base):
    __tablename__ = 'auth_sessions'
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id'))
    token_hash: Mapped[str] = mapped_column(unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class OtpChallenge(Entity, Base):
    __tablename__ = 'otp_challenges'
    phone: Mapped[str] = mapped_column(index=True)
    code_hash: Mapped[str]
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(default=0)
    consumed: Mapped[bool] = mapped_column(default=False)
    # 'app' codes sign in marketplace users; 'ops' codes sign in operators.
    # Each verify endpoint accepts only its own, so neither can open the other.
    purpose: Mapped[str] = mapped_column(String(8), default='app')


class Idempotency(Base):
    __tablename__ = 'idempotency'
    key: Mapped[str] = mapped_column(primary_key=True)
    fingerprint: Mapped[str]
    resource_id: Mapped[str]


class SupplierPhoto(Entity, Base):
    """One farm/stock photo of a supplier. The image file lives in media storage;
    only its URL is kept here. A supplier can have any number of photos."""
    __tablename__ = 'supplier_photos'
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    media_id: Mapped[Optional[str]] = mapped_column(ForeignKey('media_assets.id'))
    image_url: Mapped[str]
    __table_args__ = (UniqueConstraint('supplier_id', 'image_url', name='uq_supplier_photo_url'),)


class SupplierVideo(Entity, Base):
    """The single supplier/farm video. UNIQUE(supplier_id) makes "at most one
    video per supplier" a database guarantee, not just an API check."""
    __tablename__ = 'supplier_videos'
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), unique=True)
    youtube_video_id: Mapped[str] = mapped_column(String(32))
    youtube_url: Mapped[str]
    thumbnail_url: Mapped[str]
    title: Mapped[str] = mapped_column(default='')
    source: Mapped[str] = mapped_column(default='link')
    status: Mapped[str] = mapped_column(default='ready')
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, onupdate=now)
    __table_args__ = (CheckConstraint("status IN ('processing','ready','failed')", name='valid_supplier_video_status'),
        CheckConstraint("source IN ('link','upload')", name='valid_supplier_video_source'))


class MediaAsset(Entity, Base):
    __tablename__ = 'media_assets'
    owner_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), index=True)
    storage_name: Mapped[str] = mapped_column(unique=True)
    content_type: Mapped[str] = mapped_column(default='image/jpeg')


class MediaUpload(Entity, Base):
    """A resumable video upload between start and confirm. Its parts go to
    storage object pending/<id>; confirm turns it into a MediaAsset."""
    __tablename__ = 'media_uploads'
    owner_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    upload_id: Mapped[str] = mapped_column(Text, default='')
    size: Mapped[int] = mapped_column(Integer)


class MediaReference(Base):
    """Which record shows which media: one row per (media, record). Kept in
    step with the records' photo/video fields by app/media.py on every flush,
    so "is this photo used?" and "may this buyer see it?" are index lookups
    instead of text searches through JSON columns."""
    __tablename__ = 'media_references'
    media_id: Mapped[str] = mapped_column(ForeignKey('media_assets.id'), primary_key=True)
    owner_table: Mapped[str] = mapped_column(String(40), primary_key=True)
    owner_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    __table_args__ = (Index('ix_media_references_owner', 'owner_table', 'owner_id'),)


class PaymentReceipt(Entity, Base):
    __tablename__ = 'payment_receipts'
    payment_id: Mapped[str] = mapped_column(ForeignKey('payments.id'), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    reference: Mapped[str] = mapped_column(unique=True)
    __table_args__ = (CheckConstraint('amount > 0'),)


class StockMovement(Entity, Base):
    __tablename__ = 'stock_movements'
    listing_id: Mapped[str] = mapped_column(ForeignKey('listings.id'), index=True)
    kind: Mapped[str]
    total_delta: Mapped[Decimal] = mapped_column(Numeric(14, 3), default=0)
    reserved_delta: Mapped[Decimal] = mapped_column(Numeric(14, 3), default=0)
    sold_delta: Mapped[Decimal] = mapped_column(Numeric(14, 3), default=0)
    total_after: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    reserved_after: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    sold_after: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    reason: Mapped[str] = mapped_column(Text, default='')
    reference: Mapped[str] = mapped_column(unique=True)
    actor_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'))


class StockSale(Entity, Base):
    __tablename__ = 'stock_sales'
    listing_id: Mapped[str] = mapped_column(ForeignKey('listings.id'), index=True)
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    source: Mapped[str]
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    sold_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    unit_price: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 2))
    order_item_id: Mapped[Optional[str]] = mapped_column(ForeignKey('order_items.id'), unique=True)
    note: Mapped[str] = mapped_column(Text, default='')
    __table_args__ = (CheckConstraint('quantity > 0'), CheckConstraint("source IN ('external', 'omoterra')"))


class StockSaleReversal(Entity, Base):
    __tablename__ = 'stock_sale_reversals'
    sale_id: Mapped[str] = mapped_column(ForeignKey('stock_sales.id'), unique=True)
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'))
    reason: Mapped[str] = mapped_column(Text)


class Notification(Entity, Base):
    """Something a user should know about: kept as an in-app inbox entry and,
    when push is configured, also delivered to their phones."""
    __tablename__ = 'notifications'
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    # Which side of the account it concerns, so opening it can switch the
    # app to the matching role before navigating to `link`.
    role: Mapped[str] = mapped_column(String(16))
    kind: Mapped[str] = mapped_column(String(48))
    title: Mapped[str]
    body: Mapped[str] = mapped_column(Text, default='')
    link: Mapped[str] = mapped_column(default='')
    read_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    __table_args__ = (CheckConstraint("role IN ('buyer','supplier')", name='valid_notification_role'),)


class DeviceToken(Entity, Base):
    """A phone registered for push. A token belongs to one account at a time;
    signing in as someone else on the same phone moves it."""
    __tablename__ = 'device_tokens'
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    token: Mapped[str] = mapped_column(unique=True)
    platform: Mapped[str] = mapped_column(String(16), default='android')
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class Operator(Entity, Base):
    """An Omoterra staff member using the operations dashboard. Separate from
    marketplace users: signing in here never creates a buyer or supplier."""
    __tablename__ = 'operators'
    phone: Mapped[str] = mapped_column(String(20), unique=True)
    name: Mapped[str]
    role: Mapped[str] = mapped_column(String(16), default='staff')
    active: Mapped[bool] = mapped_column(default=True)
    created_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    last_login_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    # Everything in the dashboard's alerts newer than this is unread for them.
    alerts_seen_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    # Dashboard sign-in is staff passphrase + phone + PIN; a code is texted
    # only to set or reset the PIN (app/auth.py).
    pin_hash: Mapped[Optional[str]] = mapped_column(String(200))
    pin_failed_attempts: Mapped[int] = mapped_column(default=0)
    pin_locked_until: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    __table_args__ = (CheckConstraint("role IN ('admin','staff')", name='valid_operator_role'),)


class OperatorSession(Entity, Base):
    __tablename__ = 'operator_sessions'
    operator_id: Mapped[str] = mapped_column(ForeignKey('operators.id'), index=True)
    token_hash: Mapped[str] = mapped_column(unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class OpsAuditEntry(Entity, Base):
    """One change made through the dashboard, written in the same transaction
    as the change, so only actions that took effect are recorded."""
    __tablename__ = 'ops_audit'
    operator_id: Mapped[str] = mapped_column(ForeignKey('operators.id'), index=True)
    method: Mapped[str] = mapped_column(String(8))
    path: Mapped[str]


class AdminSetup(Entity, Base):
    """One run of the dashboard's "Admin setup": opened with the setup
    passphrase, approved by an existing admin's phone code when there already
    is an admin, and finished when the new admin confirms their own phone."""
    __tablename__ = 'admin_setups'
    token_hash: Mapped[str] = mapped_column(unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    needs_approval: Mapped[bool]
    approved_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    new_name: Mapped[str] = mapped_column(default='')
    new_phone: Mapped[str] = mapped_column(String(20), default='')
    completed_operator_id: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))


class Referral(Entity, Base):
    """Someone registered for a role by someone else. One row per role, so a
    buyer later referred as a supplier has two. This is the account
    registration only: a supplier's profile keeps its own verification
    (under_review → approved) whatever this row says."""
    __tablename__ = 'referrals'
    target_user_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    # Exactly one referrer, by source: operators today, members later.
    referred_by_operator_id: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'), index=True)
    referred_by_user_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), index=True)
    role_requested: Mapped[str] = mapped_column(String(16))
    source: Mapped[str] = mapped_column(String(16))
    status: Mapped[str] = mapped_column(String(16))
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    reviewed_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    rejection_reason: Mapped[str] = mapped_column(Text, default='')
    __table_args__ = (
        CheckConstraint("role_requested IN ('buyer','supplier')", name='valid_referral_role'),
        CheckConstraint("source IN ('admin','member','self_signup')", name='valid_referral_source'),
        CheckConstraint("status IN ('pending','confirmed','rejected','cancelled')", name='valid_referral_status'),
        CheckConstraint("(source = 'self_signup' AND referred_by_operator_id IS NULL AND referred_by_user_id IS NULL)"
            " OR (source = 'admin' AND referred_by_operator_id IS NOT NULL AND referred_by_user_id IS NULL)"
            " OR (source = 'member' AND referred_by_user_id IS NOT NULL AND referred_by_operator_id IS NULL)",
            name='one_referrer'),
        Index('uq_referrals_live_role', 'target_user_id', 'role_requested', unique=True,
            postgresql_where=text("status IN ('pending', 'confirmed')")),
    )


class AdminSetupAttempt(Entity, Base):
    """Every passphrase attempt, for rate limiting guesses."""
    __tablename__ = 'admin_setup_attempts'
    succeeded: Mapped[bool]
    # 'setup' (dashboard admin setup) or 'mobile' (mobile admin sign-in).
    kind: Mapped[str] = mapped_column(String(16), default='setup')


class OrderRating(Entity, Base):
    """A buyer's rating of one delivered order. It counts toward the
    reputation of every supplier whose stock was in the order. Comments are
    never shown to other buyers; suppliers see them without the buyer."""
    __tablename__ = 'order_ratings'
    order_id: Mapped[str] = mapped_column(ForeignKey('orders.id'), unique=True)
    buyer_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    stars: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str] = mapped_column(Text, default='')
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, onupdate=now)
    # Operations can hide an abusive or mistaken rating; it then stops
    # counting toward the supplier's reputation.
    hidden: Mapped[bool] = mapped_column(default=False)
    hidden_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (CheckConstraint('stars BETWEEN 1 AND 5', name='valid_rating_stars'),)


class Sale(Entity, Base):
    """A sale staff recorded directly (phone, market, walk-in). A money record
    only: it never moves listing or batch stock. Its buyer always has a CRM
    record, created on the spot for a new buyer, so they are kept for later."""
    __tablename__ = 'sales'
    sale_number: Mapped[str] = mapped_column(String(24), unique=True)
    sold_on: Mapped[date] = mapped_column(Date, index=True)
    buyer_profile_id: Mapped[str] = mapped_column(ForeignKey('buyer_profiles.id'), index=True)
    buyer_user_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'))
    buyer_name: Mapped[str] = mapped_column(Text)
    buyer_phone: Mapped[str] = mapped_column(String(20), default='')
    total_amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    cost_amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), default=0)
    notes: Mapped[str] = mapped_column(Text, default='')
    status: Mapped[str] = mapped_column(String(16), default='active')
    created_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    cancelled_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancel_reason: Mapped[str] = mapped_column(Text, default='')
    __table_args__ = (
        CheckConstraint('total_amount > 0', name='sales_total_amount_check'),
        CheckConstraint('cost_amount >= 0', name='sales_cost_amount_check'),
        CheckConstraint("status IN ('active','cancelled')", name='sales_status_check'),
    )


class SaleItem(Entity, Base):
    __tablename__ = 'sale_items'
    sale_id: Mapped[str] = mapped_column(ForeignKey('sales.id'), index=True)
    position: Mapped[int] = mapped_column(Integer)
    category: Mapped[str] = mapped_column(String(32), default='')
    description: Mapped[str] = mapped_column(Text)
    unit: Mapped[str] = mapped_column(String(16))
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    unit_price: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    subtotal: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    # Who Omoterra owes for this stock, if anyone: a registered supplier or a
    # named one not in the system. Blank means Omoterra's own stock.
    supplier_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), index=True)
    supplier_name: Mapped[str] = mapped_column(Text, default='')
    unit_cost: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 2))
    cost_total: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 2))
    # Stock received on an LPO: costed at its price, owed through the LPO.
    lpo_line_id: Mapped[Optional[str]] = mapped_column(ForeignKey('lpo_lines.id', use_alter=True), index=True)
    __table_args__ = (
        CheckConstraint('quantity > 0', name='sale_items_quantity_check'),
        CheckConstraint('unit_price > 0', name='sale_items_unit_price_check'),
        CheckConstraint('unit_cost > 0', name='sale_items_unit_cost_check'),
        CheckConstraint("(unit_cost IS NULL AND supplier_id IS NULL AND supplier_name = '')"
            " OR (unit_cost IS NOT NULL AND (supplier_id IS NOT NULL OR supplier_name <> ''))",
            name='sale_item_cost_has_supplier'),
    )


EXPENSE_CATEGORIES = ('labour', 'transport', 'fuel', 'feed', 'medicine_vet', 'packaging', 'processing',
    'market_fees', 'rent', 'utilities', 'airtime_data', 'equipment', 'repairs', 'other')


class LedgerDebt(Entity, Base):
    """Money someone owes: a buyer to Omoterra (receivable) or Omoterra to a
    supplier or anyone else (payable). Sales open these automatically; other
    debts are entered by hand. `paid_amount` always equals the sum of the
    unreversed payments and can never pass `amount`."""
    __tablename__ = 'ledger_debts'
    direction: Mapped[str] = mapped_column(String(16))
    party_kind: Mapped[str] = mapped_column(String(16))
    buyer_profile_id: Mapped[Optional[str]] = mapped_column(ForeignKey('buyer_profiles.id'), index=True)
    supplier_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), index=True)
    party_name: Mapped[str] = mapped_column(Text)
    party_phone: Mapped[str] = mapped_column(String(20), default='')
    description: Mapped[str] = mapped_column(Text, default='')
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    paid_amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), default=0)
    incurred_on: Mapped[date] = mapped_column(Date)
    due_on: Mapped[Optional[date]] = mapped_column(Date)
    source: Mapped[str] = mapped_column(String(16))
    # Set on operating expenses only (source 'expense').
    expense_category: Mapped[Optional[str]] = mapped_column(String(24))
    sale_id: Mapped[Optional[str]] = mapped_column(ForeignKey('sales.id'), index=True)
    # Payables for batches received on an LPO (source 'lpo').
    lpo_id: Mapped[Optional[str]] = mapped_column(ForeignKey('lpos.id', use_alter=True), index=True)
    status: Mapped[str] = mapped_column(String(16), default='open')
    created_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    cancelled_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancel_reason: Mapped[str] = mapped_column(Text, default='')
    __table_args__ = (
        CheckConstraint("direction IN ('receivable','payable')", name='ledger_debts_direction_check'),
        CheckConstraint("party_kind IN ('buyer','supplier','other')", name='ledger_debts_party_kind_check'),
        CheckConstraint('amount > 0', name='ledger_debts_amount_check'),
        CheckConstraint("source IN ('sale','sale_cost','manual','expense','lpo')", name='ledger_debts_source_check'),
        CheckConstraint("(source = 'lpo') = (lpo_id IS NOT NULL)", name='ledger_lpo_source'),
        CheckConstraint(f"expense_category IN ({', '.join(repr(v) for v in EXPENSE_CATEGORIES)})", name='ledger_debts_expense_category_check'),
        CheckConstraint("(source = 'expense') = (expense_category IS NOT NULL)", name='ledger_expense_category'),
        Index('ix_ledger_debts_expenses', 'incurred_on', postgresql_where=text("source = 'expense'")),
        CheckConstraint("status IN ('open','settled','cancelled')", name='ledger_debts_status_check'),
        CheckConstraint('paid_amount >= 0 AND paid_amount <= amount', name='ledger_paid_within_amount'),
        CheckConstraint("source = 'expense' OR (source IN ('sale','sale_cost')) = (sale_id IS NOT NULL)", name='ledger_sale_source'),
        Index('ix_ledger_debts_open', 'direction', 'status'),
    )

    @property
    def balance(self):
        return self.amount - self.paid_amount


LEDGER_METHODS = ('cash', 'mpesa', 'airtel_money', 'mixx_by_yas', 'halopesa', 'bank_transfer', 'cheque', 'other')


class SupplierPayment(Entity, Base):
    """One transfer to a supplier, allocated across one or more ledger debts."""
    __tablename__ = 'supplier_payments'
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    paid_on: Mapped[date] = mapped_column(Date, index=True)
    method: Mapped[str] = mapped_column(String(24))
    reference: Mapped[str] = mapped_column(Text, default='')
    sms_text: Mapped[str] = mapped_column(Text, default='')
    receipt_media_id: Mapped[Optional[str]] = mapped_column(ForeignKey('media_assets.id'))
    note: Mapped[str] = mapped_column(Text, default='')
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint('amount > 0', name='supplier_payments_amount_check'),
        CheckConstraint(f"method IN ({', '.join(repr(v) for v in LEDGER_METHODS)})", name='supplier_payments_method_check'),
        CheckConstraint("reference <> '' OR sms_text <> '' OR receipt_media_id IS NOT NULL", name='supplier_payment_has_evidence'),
    )


class LedgerPayment(Entity, Base):
    """One installment against a debt: money in for a receivable, money out
    for a payable. Never deleted; a wrong entry is reversed with a reason."""
    __tablename__ = 'ledger_payments'
    debt_id: Mapped[str] = mapped_column(ForeignKey('ledger_debts.id'), index=True)
    supplier_payment_id: Mapped[Optional[str]] = mapped_column(ForeignKey('supplier_payments.id'), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    paid_on: Mapped[date] = mapped_column(Date, index=True)
    method: Mapped[str] = mapped_column(String(24))
    reference: Mapped[str] = mapped_column(Text, default='')
    note: Mapped[str] = mapped_column(Text, default='')
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    reversed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    reversed_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    reverse_reason: Mapped[str] = mapped_column(Text, default='')
    __table_args__ = (
        CheckConstraint('amount > 0', name='ledger_payments_amount_check'),
        CheckConstraint(f"method IN ({', '.join(repr(v) for v in LEDGER_METHODS)})", name='ledger_payments_method_check'),
        Index('uq_ledger_payment_reference', 'debt_id', 'method', 'reference', unique=True,
            postgresql_where=text("reference <> '' AND reversed_at IS NULL")),
    )


class Promotion(Entity, Base):
    """A promotional message sent to buyers, suppliers or both, by SMS and/or
    as an in-app notification. SMS go out from a queue (app/promotions.py)."""
    __tablename__ = 'promotions'
    audience: Mapped[str] = mapped_column(String(16))
    title: Mapped[str] = mapped_column(Text)
    message: Mapped[str] = mapped_column(Text)
    send_sms: Mapped[bool] = mapped_column(Boolean)
    send_in_app: Mapped[bool] = mapped_column(Boolean)
    recipient_count: Mapped[int] = mapped_column(Integer, default=0)
    in_app_count: Mapped[int] = mapped_column(Integer, default=0)
    created_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint("audience IN ('buyers','suppliers','everyone')", name='promotions_audience_check'),
        CheckConstraint('send_sms OR send_in_app', name='promotion_has_channel'),
    )


class PromotionRecipient(Entity, Base):
    __tablename__ = 'promotion_recipients'
    promotion_id: Mapped[str] = mapped_column(ForeignKey('promotions.id'))
    phone: Mapped[str] = mapped_column(String(20))
    name: Mapped[str] = mapped_column(Text, default='')
    user_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'))
    buyer_profile_id: Mapped[Optional[str]] = mapped_column(ForeignKey('buyer_profiles.id'))
    sms_status: Mapped[str] = mapped_column(String(16))
    sms_error: Mapped[str] = mapped_column(Text, default='')
    sms_attempts: Mapped[int] = mapped_column(Integer, default=0)
    sent_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    __table_args__ = (
        CheckConstraint("sms_status IN ('queued','sent','failed','skipped')", name='promotion_recipients_sms_status_check'),
        UniqueConstraint('promotion_id', 'phone', name='uq_promotion_phone'),
        Index('ix_promotion_recipients_queued', 'sms_status', postgresql_where=text("sms_status = 'queued'")),
    )


class PromotionOptOut(Base):
    """A number that asked not to receive promotions."""
    __tablename__ = 'promotion_opt_outs'
    phone: Mapped[str] = mapped_column(String(20), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    note: Mapped[str] = mapped_column(Text, default='')


class DocumentMark(Entity, Base):
    """The company stamp, or one admin's signature, as put on issued
    documents. Uploading a new one retires the old; issued LPOs keep the
    marks they were issued with. Only admins upload them."""
    __tablename__ = 'document_marks'
    kind: Mapped[str] = mapped_column(String(16))
    operator_id: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    media_id: Mapped[str] = mapped_column(ForeignKey('media_assets.id'))
    uploaded_by: Mapped[str] = mapped_column(ForeignKey('operators.id'))
    retired_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    __table_args__ = (
        CheckConstraint("kind IN ('stamp','signature')", name='document_marks_kind_check'),
        CheckConstraint("(kind = 'signature') = (operator_id IS NOT NULL)", name='mark_owner'),
        Index('uq_document_marks_live', 'kind', text("COALESCE(operator_id, '')"), unique=True,
            postgresql_where=text('retired_at IS NULL')),
    )


class Lpo(Entity, Base):
    """A local purchase order to one supplier. Drafted by staff, issued (and
    so frozen, signed and stamped) only by an admin."""
    __tablename__ = 'lpos'
    lpo_number: Mapped[str] = mapped_column(String(32), unique=True)
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    supplier_snapshot: Mapped[dict] = mapped_column(JSON)
    demand_id: Mapped[Optional[str]] = mapped_column(ForeignKey('buyer_requirements.id'), index=True)
    lpo_date: Mapped[date] = mapped_column(Date)
    delivery_start: Mapped[date] = mapped_column(Date)
    delivery_end: Mapped[date] = mapped_column(Date)
    payment_terms_days: Mapped[int] = mapped_column(Integer)
    supply_basis: Mapped[str] = mapped_column(String(16))
    collection_point: Mapped[str] = mapped_column(Text, default='')
    delivery_notes: Mapped[list] = mapped_column(JSON, default=list)
    terms: Mapped[list] = mapped_column(JSON, default=list)
    internal_notes: Mapped[str] = mapped_column(Text, default='')
    status: Mapped[str] = mapped_column(String(16), default='draft', index=True)
    created_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    issued_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    issued_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    issuer_name: Mapped[str] = mapped_column(Text, default='')
    issuer_position: Mapped[str] = mapped_column(Text, default='')
    stamp_mark_id: Mapped[Optional[str]] = mapped_column(ForeignKey('document_marks.id'))
    signature_mark_id: Mapped[Optional[str]] = mapped_column(ForeignKey('document_marks.id'))
    supplier_accepted_at: Mapped[Optional[date]] = mapped_column(Date)
    supplier_accepted_name: Mapped[str] = mapped_column(Text, default='')
    supplier_accepted_position: Mapped[str] = mapped_column(Text, default='')
    signed_copy_media_id: Mapped[Optional[str]] = mapped_column(ForeignKey('media_assets.id'))
    closed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    closed_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    close_reason: Mapped[str] = mapped_column(Text, default='')
    __table_args__ = (
        CheckConstraint('payment_terms_days BETWEEN 0 AND 180', name='lpos_payment_terms_days_check'),
        CheckConstraint("supply_basis IN ('call_off','fixed')", name='lpos_supply_basis_check'),
        CheckConstraint("status IN ('draft','issued','accepted','closed','cancelled')", name='lpos_status_check'),
        CheckConstraint('delivery_end >= delivery_start', name='lpo_window'),
        CheckConstraint("status IN ('draft','cancelled') OR (issued_at IS NOT NULL AND stamp_mark_id IS NOT NULL"
            " AND signature_mark_id IS NOT NULL)", name='lpo_issued_marked'),
    )


class LpoLine(Entity, Base):
    __tablename__ = 'lpo_lines'
    lpo_id: Mapped[str] = mapped_column(ForeignKey('lpos.id'), index=True)
    position: Mapped[int] = mapped_column(Integer)
    category: Mapped[str] = mapped_column(String(32), default='')
    item: Mapped[str] = mapped_column(Text)
    specification: Mapped[str] = mapped_column(Text, default='')
    unit: Mapped[str] = mapped_column(String(16))
    unit_price: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    # None: as requested per batch (call-off).
    quantity: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    min_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    max_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    __table_args__ = (
        CheckConstraint('unit_price > 0', name='lpo_lines_unit_price_check'),
        CheckConstraint('quantity > 0', name='lpo_lines_quantity_check'),
        CheckConstraint('min_weight_kg IS NULL OR max_weight_kg IS NULL OR max_weight_kg >= min_weight_kg', name='lpo_line_weights'),
    )


class LpoReceipt(Entity, Base):
    """One batch received on an LPO; its accepted value is the supplier payable."""
    __tablename__ = 'lpo_receipts'
    lpo_id: Mapped[str] = mapped_column(ForeignKey('lpos.id'), index=True)
    received_on: Mapped[date] = mapped_column(Date)
    notes: Mapped[str] = mapped_column(Text, default='')
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    debt_id: Mapped[Optional[str]] = mapped_column(ForeignKey('ledger_debts.id'))
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    cancelled_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancel_reason: Mapped[str] = mapped_column(Text, default='')
    __table_args__ = (CheckConstraint('amount >= 0', name='lpo_receipts_amount_check'),)


class LpoReceiptLine(Entity, Base):
    __tablename__ = 'lpo_receipt_lines'
    receipt_id: Mapped[str] = mapped_column(ForeignKey('lpo_receipts.id'), index=True)
    lpo_line_id: Mapped[str] = mapped_column(ForeignKey('lpo_lines.id'), index=True)
    delivered_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    accepted_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    rejected_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    average_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    unit_price: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    __table_args__ = (
        CheckConstraint('delivered_quantity >= 0', name='lpo_receipt_lines_delivered_quantity_check'),
        CheckConstraint('accepted_quantity >= 0', name='lpo_receipt_lines_accepted_quantity_check'),
        CheckConstraint('rejected_quantity >= 0', name='lpo_receipt_lines_rejected_quantity_check'),
        CheckConstraint('accepted_quantity + rejected_quantity = delivered_quantity', name='receipt_counts_add_up'),
    )


LOSS_REASONS = ('died', 'sick', 'stolen', 'spoiled', 'other')


class StockLoss(Entity, Base):
    """Received LPO stock lost before it was sold; its cost counts against profit."""
    __tablename__ = 'stock_losses'
    lpo_line_id: Mapped[str] = mapped_column(ForeignKey('lpo_lines.id'), index=True)
    lost_on: Mapped[date] = mapped_column(Date)
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    reason: Mapped[str] = mapped_column(String(16))
    note: Mapped[str] = mapped_column(Text, default='')
    unit_cost: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    cancelled_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint('quantity > 0', name='stock_losses_quantity_check'),
        CheckConstraint(f"reason IN ({', '.join(repr(v) for v in LOSS_REASONS)})", name='stock_losses_reason_check'),
    )


# Registers the media_references hook wherever the models are loaded.
from . import media_refs  # noqa: E402,F401
