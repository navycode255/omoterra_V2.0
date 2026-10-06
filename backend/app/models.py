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
    # Build plan M2.5 (F07, D7): the Dar es Salaam business day the order
    # counts as a sale, i.e. the day it was delivered. Set on delivery;
    # cleared when the delivery is reversed (the reversal is its own dated
    # record, OrderRecognitionReversal). Null on a delivered order means
    # unresolved: listed, never in a period.
    recognized_on: Mapped[Optional[date]] = mapped_column(Date, index=True)
    # How it was set: 'delivery' (marked delivered), 'backfill' (migration
    # 044 from the activity log) or the finance owner's evidence.
    recognition_note: Mapped[str] = mapped_column(Text, default='')


class OrderRecognitionReversal(Entity, Base):
    """A delivered app order taken back (build plan M2.5): reopened because
    it was not really delivered, or returned by the buyer. Append-only. The
    sale stays in the period it was recognised in (`recognized_on`), and this
    record takes it out again on `reversed_on`, with the revenue and cost
    counted then, so an earlier period is never rewritten."""
    __tablename__ = 'order_recognition_reversals'
    order_id: Mapped[str] = mapped_column(ForeignKey('orders.id'), index=True)
    kind: Mapped[str] = mapped_column(String(16))
    recognized_on: Mapped[Optional[date]] = mapped_column(Date)
    reversed_on: Mapped[date] = mapped_column(Date, index=True)
    revenue: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    cost: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    reason: Mapped[str] = mapped_column(Text)
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint("kind IN ('reopen','return')", name='order_recognition_reversals_kind_check'),
    )


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


class SupplierCollection(Entity, Base):
    # A dated delivery note for stock physically accepted from one supplier batch.
    __tablename__ = 'supplier_collections'
    collection_number: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    batch_id: Mapped[str] = mapped_column(ForeignKey('supplier_batches.id'), index=True)
    received_on: Mapped[date] = mapped_column(Date, index=True)
    delivered_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    accepted_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    rejected_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    average_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    unit_cost: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    notes: Mapped[str] = mapped_column(Text, default='')
    debt_id: Mapped[Optional[str]] = mapped_column(ForeignKey('ledger_debts.id', use_alter=True))
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    cancelled_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancel_reason: Mapped[str] = mapped_column(Text, default='')
    # 'delivery' (Receive stock), 'sale' (collected and sold together, build
    # plan M1.6) or 'historical' (an old sale line linked by link_batch_sales).
    origin: Mapped[str] = mapped_column(String(16), default='delivery')
    # Who confirmed the goods were physically received, and when (rule R2).
    confirmed_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    confirmed_by_name: Mapped[str] = mapped_column(Text, default='')
    confirmed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    sale_id: Mapped[Optional[str]] = mapped_column(ForeignKey('sales.id', use_alter=True), index=True)
    __table_args__ = (
        CheckConstraint("origin IN ('delivery','sale','historical')", name='supplier_collections_origin_check'),
        CheckConstraint('delivered_quantity > 0', name='supplier_collections_delivered_positive'),
        CheckConstraint('accepted_quantity >= 0 AND rejected_quantity >= 0', name='supplier_collections_quantities_nonnegative'),
        CheckConstraint('accepted_quantity + rejected_quantity = delivered_quantity', name='supplier_collections_counts_add_up'),
        CheckConstraint('unit_cost > 0 AND amount >= 0', name='supplier_collections_cost_valid'),
    )


COLLECTION_MOVEMENT_KINDS = ('never_left', 'buyer_return_accepted', 'not_recovered', 'returned_to_supplier',
    'receipt_correction', 'lost')
# Kinds that take goods out of a delivery note's stock (unless cancelled).
# receipt_correction lowers the note's accepted quantity itself; the other
# two are history.
COLLECTION_STOCK_OUT = ('not_recovered', 'returned_to_supplier', 'lost')
# Kinds whose cost counts against profit as lost stock.
COLLECTION_LOSSES = ('not_recovered', 'lost')


class CollectionMovement(Entity, Base):
    """A physical event on a delivery note after it was received (rule R2),
    shaped to move into M2.1's lot movements. On hand = accepted - active
    sales - not_recovered - returned_to_supplier - lost (uncancelled)."""
    __tablename__ = 'collection_movements'
    collection_id: Mapped[str] = mapped_column(ForeignKey('supplier_collections.id'), index=True)
    kind: Mapped[str] = mapped_column(String(24))
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    occurred_on: Mapped[date] = mapped_column(Date, index=True)
    unit_cost: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    sale_id: Mapped[Optional[str]] = mapped_column(ForeignKey('sales.id'), index=True)
    reason: Mapped[str] = mapped_column(Text, default='')
    evidence: Mapped[str] = mapped_column(Text, default='')
    note: Mapped[str] = mapped_column(Text, default='')
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    # 'lost' only: why the goods were lost (LOSS_REASONS). A loss recorded by
    # mistake is cancelled with a reason, never deleted (migration 036).
    loss_reason: Mapped[Optional[str]] = mapped_column(String(16))
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    cancelled_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancel_reason: Mapped[str] = mapped_column(Text, default='')
    __table_args__ = (
        CheckConstraint(f"kind IN ({', '.join(repr(v) for v in COLLECTION_MOVEMENT_KINDS)})",
            name='collection_movements_kind_check'),
        CheckConstraint('quantity > 0', name='collection_movements_quantity_check'),
        CheckConstraint('unit_cost >= 0', name='collection_movements_unit_cost_check'),
        CheckConstraint("(kind NOT IN ('returned_to_supplier','receipt_correction') OR length(btrim(reason)) >= 3)"
            " AND (kind <> 'receipt_correction' OR length(btrim(evidence)) >= 3)"
            " AND (kind <> 'buyer_return_accepted' OR length(btrim(note)) >= 3)",
            name='collection_movement_has_reason'),
        CheckConstraint("(kind = 'lost') = (loss_reason IS NOT NULL) AND (loss_reason IS NULL OR "
            "loss_reason IN ('died','sick','stolen','spoiled','other'))", name='collection_movement_loss_reason'),
        CheckConstraint("cancelled_at IS NULL OR (kind = 'lost' AND length(btrim(cancel_reason)) >= 3)",
            name='collection_movement_cancel'),
    )


class SupplierCreditNote(Entity, Base):
    """A supplier's agreed credit for goods returned to them: the only thing
    that lowers a delivery note's payable after a return (rule R2)."""
    __tablename__ = 'supplier_credit_notes'
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    collection_id: Mapped[str] = mapped_column(ForeignKey('supplier_collections.id'), index=True)
    movement_id: Mapped[str] = mapped_column(ForeignKey('collection_movements.id'), unique=True)
    debt_id: Mapped[str] = mapped_column(ForeignKey('ledger_debts.id'), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    issued_on: Mapped[date] = mapped_column(Date)
    reference: Mapped[str] = mapped_column(Text)
    note: Mapped[str] = mapped_column(Text, default='')
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint('amount > 0', name='supplier_credit_notes_amount_check'),
        CheckConstraint('length(btrim(reference)) >= 1', name='supplier_credit_notes_reference_check'),
    )


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
    delivery_reminded_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
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
    # Set when Omoterra staff recorded it rather than the supplier.
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))


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
    # The payout attempt it answered about (M2.7). Answers given before
    # attempts existed have none: they belong to the settlement's one legacy
    # attempt (migration 045).
    transfer_id: Mapped[Optional[str]] = mapped_column(ForeignKey('settlement_transfers.id'), index=True)
    __table_args__ = (CheckConstraint("outcome IN ('received','not_received')", name='valid_payout_confirmation'),)


class ApprovalRequest(Entity, Base):
    """A request that a second admin approves before money moves (decision
    D9; build plan M2.7, reusable by M5). The approver is never the
    requester; the database refuses it too. An approved request is used
    once (`used_by_*`)."""
    __tablename__ = 'approval_requests'
    subject_table: Mapped[str] = mapped_column(String(32))
    subject_id: Mapped[str] = mapped_column(String(36))
    kind: Mapped[str] = mapped_column(String(32))
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    reason: Mapped[str] = mapped_column(Text, default='')
    # "I understand two outflows may exist" (a resend while an earlier attempt is unresolved).
    acknowledged: Mapped[bool] = mapped_column(Boolean, default=False)
    requested_by: Mapped[str] = mapped_column(ForeignKey('operators.id'))
    status: Mapped[str] = mapped_column(String(16), default='pending')
    decided_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    decided_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    decision_note: Mapped[str] = mapped_column(Text, default='')
    used_by_table: Mapped[Optional[str]] = mapped_column(String(32))
    used_by_id: Mapped[Optional[str]] = mapped_column(String(36))
    used_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    __table_args__ = (
        Index('ix_approval_requests_subject', 'subject_table', 'subject_id'),
        CheckConstraint("status IN ('pending','approved','rejected')", name='approval_requests_status_check'),
        CheckConstraint('amount > 0', name='approval_requests_amount_check'),
        CheckConstraint("status <> 'approved' OR (decided_by IS NOT NULL AND decided_by <> requested_by)",
            name='approval_requests_second_admin_check'),
    )


class SettlementTransfer(Entity, Base):
    """One attempt to pay an app payout (build plan M2.7, audit F12).

    - initiated: sent, no debit confirmation yet. Pending exposure, not money out.
    - debited: confirmed on a statement or by the provider. A permanent
      outflow (rule R3) dated `debited_on`; it never becomes failed.
    - failed: evidence that no debit happened. No outflow; evidence kept.
    """
    __tablename__ = 'settlement_transfers'
    settlement_id: Mapped[str] = mapped_column(ForeignKey('settlements.id'), index=True)
    attempt_no: Mapped[int] = mapped_column(Integer)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    method: Mapped[str] = mapped_column(String(24), default='')
    reference: Mapped[str] = mapped_column(Text, default='')
    money_account_id: Mapped[Optional[str]] = mapped_column(ForeignKey('money_accounts.id'))
    sent_on: Mapped[date] = mapped_column(Date)
    evidence: Mapped[str] = mapped_column(Text, default='')
    state: Mapped[str] = mapped_column(String(16), default='initiated', index=True)
    initiated_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    is_resend: Mapped[bool] = mapped_column(Boolean, default=False)
    approval_id: Mapped[Optional[str]] = mapped_column(ForeignKey('approval_requests.id'))
    debited_on: Mapped[Optional[date]] = mapped_column(Date, index=True)
    debit_evidence: Mapped[str] = mapped_column(Text, default='')
    debit_confirmed_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    debit_confirmed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    failed_on: Mapped[Optional[date]] = mapped_column(Date)
    failure_evidence: Mapped[str] = mapped_column(Text, default='')
    failed_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    failed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    # The supplier's latest answer about this attempt (every answer is in payout_confirmations).
    supplier_confirmation: Mapped[Optional[str]] = mapped_column(String(16))
    supplier_confirmed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    # Made by migration 045 from a settlement marked paid before attempts existed.
    legacy: Mapped[bool] = mapped_column(Boolean, default=False)
    __table_args__ = (
        UniqueConstraint('settlement_id', 'attempt_no', name='uq_settlement_transfer_attempt'),
        CheckConstraint('amount > 0', name='settlement_transfers_amount_check'),
        CheckConstraint("state IN ('initiated','debited','failed')", name='settlement_transfers_state_check'),
        CheckConstraint("state <> 'debited' OR debited_on IS NOT NULL", name='settlement_transfers_debited_check'),
        CheckConstraint("state <> 'failed' OR (failed_on IS NOT NULL AND length(btrim(failure_evidence)) >= 3)",
            name='settlement_transfers_failed_check'),
    )


class SettlementRefund(Entity, Base):
    """Money a debited payout attempt brought back: a separate dated inflow
    (rule R3). It never changes or removes the attempt's outflow.
    Append-only."""
    __tablename__ = 'settlement_refunds'
    settlement_id: Mapped[str] = mapped_column(ForeignKey('settlements.id'), index=True)
    transfer_id: Mapped[str] = mapped_column(ForeignKey('settlement_transfers.id'), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    refunded_on: Mapped[date] = mapped_column(Date, index=True)
    method: Mapped[str] = mapped_column(String(24), default='')
    reference: Mapped[str] = mapped_column(Text, default='')
    money_account_id: Mapped[Optional[str]] = mapped_column(ForeignKey('money_accounts.id'))
    evidence: Mapped[str] = mapped_column(Text)
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint('amount > 0', name='settlement_refunds_amount_check'),
        CheckConstraint('length(btrim(evidence)) >= 3', name='settlement_refunds_evidence_check'),
    )


class SettlementResolution(Entity, Base):
    """Money possibly paid twice on an app payout, resolved with evidence
    (finance owner, 7 October 2026; D9): requested by an admin, approved by a
    second admin (`approval_id`, used once).

    - supplier_credit: the supplier received the excess and keeps it; it is
      their payout credit, set off against their next payouts
      (`PayoutCreditUse`). No money moves.
    - write_off: the excess is lost (wrong number, fraud): an expense
      "Payout loss" on `resolved_on`. No money moves (it left on its debit
      day).
    Append-only."""
    __tablename__ = 'settlement_resolutions'
    settlement_id: Mapped[str] = mapped_column(ForeignKey('settlements.id'), index=True)
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    kind: Mapped[str] = mapped_column(String(16))
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    resolved_on: Mapped[date] = mapped_column(Date, index=True)
    evidence: Mapped[str] = mapped_column(Text)
    approval_id: Mapped[str] = mapped_column(ForeignKey('approval_requests.id'), unique=True)
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint("kind IN ('supplier_credit','write_off')", name='settlement_resolutions_kind_check'),
        CheckConstraint('amount > 0', name='settlement_resolutions_amount_check'),
        CheckConstraint('length(btrim(evidence)) >= 3', name='settlement_resolutions_evidence_check'),
    )


class PayoutCreditUse(Entity, Base):
    """Supplier payout credit (a `supplier_credit` resolution) set off
    against one of that supplier's settlements. Moves no money (rule R4).
    Append-only; a use on a settlement later cancelled counts for nothing,
    so the credit is available again."""
    __tablename__ = 'payout_credit_uses'
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    settlement_id: Mapped[str] = mapped_column(ForeignKey('settlements.id'), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    used_on: Mapped[date] = mapped_column(Date)
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (CheckConstraint('amount > 0', name='payout_credit_uses_amount_check'),)


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
    location_id: Mapped[Optional[str]] = mapped_column(ForeignKey('operating_locations.id'), index=True)
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
    # What staff said happened to received goods when cancelling (rule R2).
    cancel_goods: Mapped[Optional[str]] = mapped_column(String(24))
    __table_args__ = (
        CheckConstraint('total_amount > 0', name='sales_total_amount_check'),
        CheckConstraint("cancel_goods IS NULL OR cancel_goods IN ('never_left','buyer_return_accepted','not_recovered')",
            name='sales_cancel_goods_check'),
        CheckConstraint('cost_amount >= 0', name='sales_cost_amount_check'),
        CheckConstraint("status IN ('active','cancelled')", name='sales_status_check'),
    )


COST_STATES = ('known', 'free', 'unknown')


class OpeningStock(Entity, Base):
    """Stock Omoterra held before the system existed, valued by the finance
    owner (decision D3, build plan M1.3): a receipt with a value and no
    payable, because it was paid for before records began. Sales sell from
    it at its cost, so their margin is known. On hand = quantity - active
    sale lines - goods not recovered from a cancelled or edited sale. A
    mistaken entry is cancelled by an admin with a reason, only while
    nothing has been sold from it; it is never edited or deleted."""
    __tablename__ = 'opening_stock'
    receipt_number: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    category: Mapped[str] = mapped_column(String(32), default='')
    description: Mapped[str] = mapped_column(Text, default='')
    unit: Mapped[str] = mapped_column(String(16))
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    unit_cost: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    # The value given: quantity x unit cost, or the total typed in.
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    as_of: Mapped[date] = mapped_column(Date, index=True)
    # Why this value: the evidence or reasoning behind it (rule R6).
    evidence: Mapped[str] = mapped_column(Text)
    # Who supplied the value (the finance owner), as they are known.
    valued_by: Mapped[str] = mapped_column(Text)
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    cancelled_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancel_reason: Mapped[str] = mapped_column(Text, default='')
    __table_args__ = (
        CheckConstraint('quantity > 0', name='opening_stock_quantity_check'),
        CheckConstraint('unit_cost > 0 AND amount > 0', name='opening_stock_value_check'),
        CheckConstraint("unit IN ('bird','animal','kg','tray','piece')", name='opening_stock_unit_check'),
        CheckConstraint('length(btrim(evidence)) >= 3 AND length(btrim(valued_by)) >= 2', name='opening_stock_evidence_check'),
        CheckConstraint('cancelled_at IS NULL OR length(btrim(cancel_reason)) >= 3', name='opening_stock_cancel_check'),
    )


OPENING_MOVEMENT_KINDS = ('never_left', 'buyer_return_accepted', 'not_recovered')


class OpeningStockMovement(Entity, Base):
    """What happened to opening stock a sale no longer sells (rule R2):
    back on hand (never left, or returned and accepted, recorded as history)
    or not recovered (out of stock, a loss at its cost)."""
    __tablename__ = 'opening_stock_movements'
    opening_stock_id: Mapped[str] = mapped_column(ForeignKey('opening_stock.id'), index=True)
    kind: Mapped[str] = mapped_column(String(24))
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    occurred_on: Mapped[date] = mapped_column(Date, index=True)
    unit_cost: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    sale_id: Mapped[Optional[str]] = mapped_column(ForeignKey('sales.id'), index=True)
    reason: Mapped[str] = mapped_column(Text, default='')
    note: Mapped[str] = mapped_column(Text, default='')
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint(f"kind IN ({', '.join(repr(v) for v in OPENING_MOVEMENT_KINDS)})",
            name='opening_stock_movements_kind_check'),
        CheckConstraint('quantity > 0 AND unit_cost >= 0', name='opening_stock_movements_values_check'),
    )


class SaleItem(Entity, Base):
    __tablename__ = 'sale_items'
    location_allocation_id: Mapped[Optional[str]] = mapped_column(ForeignKey('location_allocations.id'), index=True)
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
    # Stock physically accepted from a registered supplier batch.
    supplier_collection_id: Mapped[Optional[str]] = mapped_column(ForeignKey('supplier_collections.id', use_alter=True), index=True)
    # Bought from a registered supplier's batch: selling reduces that batch.
    supplier_batch_id: Mapped[Optional[str]] = mapped_column(ForeignKey('supplier_batches.id', use_alter=True), index=True)
    # Stock held before the system, sold at its opening value (M1.3, D3).
    opening_stock_id: Mapped[Optional[str]] = mapped_column(ForeignKey('opening_stock.id'), index=True)
    # What is known about the buying cost (build plan M1.3, rule R5):
    # - known: unit_cost > 0, from a supplier, a receipt, opening stock or an
    #   evidenced cost;
    # - free: a known zero (gift stock), only by an admin with a reason;
    # - unknown: no cost (unit_cost null, or a 0 nobody approved as free).
    #   It counts for nothing in cost of goods and makes every period and
    #   margin that contains it provisional, never final.
    cost_state: Mapped[str] = mapped_column(String(16), default='known')
    __table_args__ = (
        CheckConstraint('quantity > 0', name='sale_items_quantity_check'),
        CheckConstraint('unit_price > 0', name='sale_items_unit_price_check'),
        # 0 only for free or gift stock, set by an admin (M1.4, M1.3).
        CheckConstraint('unit_cost >= 0', name='sale_items_unit_cost_check'),
        # Owed to a supplier means a cost is known; own stock may carry one.
        CheckConstraint("unit_cost IS NOT NULL OR (supplier_id IS NULL AND supplier_name = '')",
            name='sale_item_cost_has_supplier'),
        CheckConstraint("(cost_state = 'known' AND coalesce(unit_cost, 0) > 0)"
            " OR (cost_state = 'free' AND coalesce(unit_cost, -1) = 0)"
            " OR (cost_state = 'unknown' AND coalesce(unit_cost, 0) = 0)", name='sale_items_cost_state_check'),
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
    location_id: Mapped[Optional[str]] = mapped_column(ForeignKey('operating_locations.id'), index=True)
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
        CheckConstraint("source IN ('sale','sale_cost','manual','expense','lpo','batch_receipt')", name='ledger_debts_source_check'),
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


TRANSFER_ORIGINS = ('pay_supplier', 'single', 'legacy')


class SupplierPayment(Entity, Base):
    """One transfer to a supplier: the only record that money left an account
    to them (build plan M1.2). Its allocations (ledger payments with this id)
    spread it over invoices; `transfer_events` record what happens to money
    taken off an invoice. `amount` is never changed: a refund is a separate
    inflow and an entry error a separate correction (rule R3).

    origin: 'pay_supplier' (proof required), 'single' (one invoice paid from
    Record payment or with a sale) or 'legacy' (a payment from before
    transfers existed, wrapped by app.classify_transfers or on reversal)."""
    __tablename__ = 'supplier_payments'
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    origin: Mapped[str] = mapped_column(String(16), default='pay_supplier')
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    paid_on: Mapped[date] = mapped_column(Date, index=True)
    method: Mapped[str] = mapped_column(String(24))
    reference: Mapped[str] = mapped_column(Text, default='')
    sms_text: Mapped[str] = mapped_column(Text, default='')
    receipt_media_id: Mapped[Optional[str]] = mapped_column(ForeignKey('media_assets.id'))
    note: Mapped[str] = mapped_column(Text, default='')
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    receipt_sms_status: Mapped[str] = mapped_column(String(16), default='skipped')
    receipt_sms_language: Mapped[str] = mapped_column(String(2), default='en')
    receipt_sms_phone: Mapped[str] = mapped_column(String(20), default='')
    receipt_sms_message: Mapped[str] = mapped_column(Text, default='')
    receipt_sms_error: Mapped[str] = mapped_column(Text, default='')
    receipt_sms_attempts: Mapped[int] = mapped_column(Integer, default=0)
    receipt_sms_sent_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    __table_args__ = (
        CheckConstraint('amount > 0', name='supplier_payments_amount_check'),
        CheckConstraint(f"method IN ({', '.join(repr(v) for v in LEDGER_METHODS)})", name='supplier_payments_method_check'),
        CheckConstraint(f"origin IN ({', '.join(repr(v) for v in TRANSFER_ORIGINS)})", name='supplier_payments_origin_check'),
        CheckConstraint("origin <> 'pay_supplier' OR reference <> '' OR sms_text <> '' OR receipt_media_id IS NOT NULL",
            name='supplier_payment_has_evidence'),
        CheckConstraint("receipt_sms_status IN ('queued','sent','failed','skipped')", name='supplier_payment_receipt_sms_status_check'),
        CheckConstraint("receipt_sms_language IN ('en','sw')", name='supplier_payment_receipt_sms_language_check'),
        Index('ix_supplier_payments_receipt_sms_queued', 'receipt_sms_status',
            postgresql_where=text("receipt_sms_status = 'queued'")),
    )


class BuyerPayment(Entity, Base):
    """One payment received from a customer, entered once and spread over
    their open debts, oldest first. It is the cash book's single record of
    that money; its allocations (ledger payments carrying its id) say which
    debts it paid. Its amount is what was received; a reversed allocation
    stops counting, so the cash book shows the unreversed total."""
    __tablename__ = 'buyer_payments'
    buyer_profile_id: Mapped[str] = mapped_column(ForeignKey('buyer_profiles.id'), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    paid_on: Mapped[date] = mapped_column(Date, index=True)
    method: Mapped[str] = mapped_column(String(24))
    reference: Mapped[str] = mapped_column(Text, default='')
    note: Mapped[str] = mapped_column(Text, default='')
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint('amount > 0', name='buyer_payments_amount_check'),
        CheckConstraint(f"method IN ({', '.join(repr(v) for v in LEDGER_METHODS)})", name='buyer_payments_method_check'),
    )


class LedgerPayment(Entity, Base):
    """One installment against a debt: money in for a receivable, money out
    for a payable. Never deleted; a wrong entry is reversed with a reason."""
    __tablename__ = 'ledger_payments'
    debt_id: Mapped[str] = mapped_column(ForeignKey('ledger_debts.id'), index=True)
    supplier_payment_id: Mapped[Optional[str]] = mapped_column(ForeignKey('supplier_payments.id'), index=True)
    # Part of one customer payment spread over several debts.
    buyer_payment_id: Mapped[Optional[str]] = mapped_column(ForeignKey('buyer_payments.id'), index=True)
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


TRANSFER_EVENT_KINDS = ('credit', 'reallocation', 'refund', 'entry_error')


class TransferEvent(Entity, Base):
    """What happened to part of a transfer after it left its invoice.

    - credit: an allocation was reversed; the money stays with the supplier
      who received it as unapplied credit (rules R1, R4; decision D5).
    - reallocation: credit applied to another open invoice of the same
      supplier; `allocation_id` is the new allocation. No money moves.
    - refund: money the supplier actually sent back, a separate dated inflow
      with evidence (R3). Partial refunds are separate rows.
    - entry_error: the transfer was recorded too high and no money moved for
      this part. Admin only, with reason and evidence.

    `source_payment_id` names the reversed allocation an event classifies;
    a reversed allocation without such events is *unresolved* (R6). For
    every transfer: active allocations + unapplied credit + refunded + entry
    errors + unresolved = amount."""
    __tablename__ = 'transfer_events'
    supplier_payment_id: Mapped[str] = mapped_column(ForeignKey('supplier_payments.id'), index=True)
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    kind: Mapped[str] = mapped_column(String(16))
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    source_payment_id: Mapped[Optional[str]] = mapped_column(ForeignKey('ledger_payments.id'), index=True)
    allocation_id: Mapped[Optional[str]] = mapped_column(ForeignKey('ledger_payments.id'))
    occurred_on: Mapped[date] = mapped_column(Date, index=True)
    method: Mapped[Optional[str]] = mapped_column(String(24))
    reference: Mapped[str] = mapped_column(Text, default='')
    evidence: Mapped[str] = mapped_column(Text, default='')
    receipt_media_id: Mapped[Optional[str]] = mapped_column(ForeignKey('media_assets.id'))
    reason: Mapped[str] = mapped_column(Text, default='')
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint(f"kind IN ({', '.join(repr(v) for v in TRANSFER_EVENT_KINDS)})", name='transfer_events_kind_check'),
        CheckConstraint('amount > 0', name='transfer_events_amount_check'),
        CheckConstraint(f"method IS NULL OR method IN ({', '.join(repr(v) for v in LEDGER_METHODS)})",
            name='transfer_events_method_check'),
        CheckConstraint("((kind = 'reallocation') = (allocation_id IS NOT NULL))"
            " AND (kind <> 'reallocation' OR source_payment_id IS NULL)"
            " AND (kind <> 'credit' OR source_payment_id IS NOT NULL)"
            " AND (kind <> 'refund' OR (method IS NOT NULL AND (reference <> '' OR evidence <> '' OR receipt_media_id IS NOT NULL)))"
            " AND (kind <> 'entry_error' OR (reason <> '' AND (reference <> '' OR evidence <> '' OR receipt_media_id IS NOT NULL)))",
            name='transfer_event_shape'),
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



class CommitmentFulfilment(Entity, Base):
    """Which reservation a delivery note filled (build plan M2.1): a buyer
    demand allocation or an approved market reservation on the same batch.
    The reservation's outstanding quantity is what it holds less what
    notes have filled; only that is released when it is cancelled."""
    __tablename__ = 'commitment_fulfilments'
    collection_id: Mapped[str] = mapped_column(ForeignKey('supplier_collections.id'), index=True)
    commitment_kind: Mapped[str] = mapped_column(String(24))
    commitment_id: Mapped[str] = mapped_column(String(36), index=True)
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    __table_args__ = (
        CheckConstraint("commitment_kind IN ('demand_allocation','market_reservation')", name='commitment_fulfilments_kind_check'),
        CheckConstraint('quantity > 0', name='commitment_fulfilments_quantity_check'),
    )


class LateEntry(Entity, Base):
    """A stock record dated more than LATE_ENTRY_DAYS before the day it was
    entered (build plan M2.2): only an admin may enter it, with a reason.
    It must still keep every later day at or above zero (rule R8)."""
    __tablename__ = 'late_entries'
    entity_table: Mapped[str] = mapped_column(String(32))
    entity_id: Mapped[str] = mapped_column(String(36), index=True)
    entry_date: Mapped[date] = mapped_column(Date)
    entered_on: Mapped[date] = mapped_column(Date)
    reason: Mapped[str] = mapped_column(Text)
    approved_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint('length(btrim(reason)) >= 3', name='late_entries_reason_check'),
        CheckConstraint('entry_date < entered_on', name='late_entries_dates_check'),
    )


BUYER_ORDER_STATUSES = ('open', 'delivered', 'cancelled')


class BuyerOrder(Entity, Base):
    """An order staff took from a buyer by phone or in person (build plan
    M2.5, decision D7). Until delivered it is a commitment only: not a sale,
    nothing owed, no stock taken. Marking it delivered records a direct sale
    dated the delivery day through the normal sale path (`sale_id`)."""
    __tablename__ = 'buyer_orders'
    order_number: Mapped[str] = mapped_column(String(24), unique=True)
    buyer_profile_id: Mapped[str] = mapped_column(ForeignKey('buyer_profiles.id'), index=True)
    buyer_name: Mapped[str] = mapped_column(Text)
    buyer_phone: Mapped[str] = mapped_column(String(20), default='')
    ordered_on: Mapped[date] = mapped_column(Date, index=True)
    expected_on: Mapped[Optional[date]] = mapped_column(Date)
    notes: Mapped[str] = mapped_column(Text, default='')
    total_amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    status: Mapped[str] = mapped_column(String(16), default='open', index=True)
    sale_id: Mapped[Optional[str]] = mapped_column(ForeignKey('sales.id'), unique=True)
    delivered_on: Mapped[Optional[date]] = mapped_column(Date)
    created_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    updated_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    cancelled_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancel_reason: Mapped[str] = mapped_column(Text, default='')
    __table_args__ = (
        CheckConstraint("status IN ('open','delivered','cancelled')", name='buyer_orders_status_check'),
        CheckConstraint('total_amount > 0', name='buyer_orders_total_check'),
        CheckConstraint("(status = 'delivered') = (sale_id IS NOT NULL AND delivered_on IS NOT NULL)",
            name='buyer_orders_delivered_check'),
    )


class BuyerOrderLine(Entity, Base):
    __tablename__ = 'buyer_order_lines'
    buyer_order_id: Mapped[str] = mapped_column(ForeignKey('buyer_orders.id'), index=True)
    position: Mapped[int] = mapped_column(Integer)
    category: Mapped[str] = mapped_column(String(32), default='')
    description: Mapped[str] = mapped_column(Text, default='')
    unit: Mapped[str] = mapped_column(String(16))
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    unit_price: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    subtotal: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    __table_args__ = (
        CheckConstraint('quantity > 0 AND unit_price > 0', name='buyer_order_lines_amounts_check'),
        CheckConstraint("unit IN ('bird','animal','kg','tray','piece')", name='buyer_order_lines_unit_check'),
    )


class BuyerOrderPayment(Entity, Base):
    """Money on a staff buyer order before delivery: a deposit the buyer paid
    (money in, held for them) or a deposit given back (money out, its own
    dated record). On delivery each held deposit becomes a payment on the
    sale's receivable with the same date, method, reference and account
    (`applied_payment_id`); from then the cash book counts that payment
    instead, so the money is counted once and its day never moves. A deposit
    entered by mistake is voided by an admin with a reason while held."""
    __tablename__ = 'buyer_order_payments'
    buyer_order_id: Mapped[str] = mapped_column(ForeignKey('buyer_orders.id'), index=True)
    kind: Mapped[str] = mapped_column(String(16))
    # Several part refunds may give back one deposit (7 October 2026).
    refund_of: Mapped[Optional[str]] = mapped_column(ForeignKey('buyer_order_payments.id'), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    paid_on: Mapped[date] = mapped_column(Date, index=True)
    method: Mapped[str] = mapped_column(String(24))
    reference: Mapped[str] = mapped_column(Text, default='')
    note: Mapped[str] = mapped_column(Text, default='')
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    applied_payment_id: Mapped[Optional[str]] = mapped_column(ForeignKey('ledger_payments.id'), unique=True)
    voided_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    voided_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    void_reason: Mapped[str] = mapped_column(Text, default='')
    __table_args__ = (
        CheckConstraint("kind IN ('deposit','refund')", name='buyer_order_payments_kind_check'),
        CheckConstraint('amount > 0', name='buyer_order_payments_amount_check'),
        CheckConstraint("(kind = 'refund') = (refund_of IS NOT NULL)", name='buyer_order_payments_refund_check'),
        CheckConstraint(f"method IN ({', '.join(repr(v) for v in LEDGER_METHODS)})",
            name='buyer_order_payments_method_check'),
    )


class BuyerOrderDepositMove(Entity, Base):
    """Part or all of a held deposit moved to another open order of the same
    buyer (finance owner, 7 October 2026). Moves no money (rule R4): no cash
    book row, no account movement; the deposit keeps its one money-in record.
    Append-only."""
    __tablename__ = 'buyer_order_deposit_moves'
    deposit_id: Mapped[str] = mapped_column(ForeignKey('buyer_order_payments.id'), index=True)
    from_order_id: Mapped[str] = mapped_column(ForeignKey('buyer_orders.id'), index=True)
    to_order_id: Mapped[str] = mapped_column(ForeignKey('buyer_orders.id'), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    reason: Mapped[str] = mapped_column(Text)
    moved_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint('amount > 0', name='buyer_order_deposit_moves_amount_check'),
        CheckConstraint('from_order_id <> to_order_id', name='buyer_order_deposit_moves_orders_check'),
        CheckConstraint('length(btrim(reason)) >= 3', name='buyer_order_deposit_moves_reason_check'),
    )


class BuyerOrderDepositApplication(Entity, Base):
    """The part of a deposit held on an order that became a payment on that
    order's sale when it was delivered (same day, method, reference and
    account as the deposit). From then the cash book counts that part from
    the payment, and the rest (if any) from the deposit."""
    __tablename__ = 'buyer_order_deposit_applications'
    deposit_id: Mapped[str] = mapped_column(ForeignKey('buyer_order_payments.id'), index=True)
    buyer_order_id: Mapped[str] = mapped_column(ForeignKey('buyer_orders.id'), index=True)
    ledger_payment_id: Mapped[str] = mapped_column(ForeignKey('ledger_payments.id'), unique=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    __table_args__ = (CheckConstraint('amount > 0', name='buyer_order_deposit_applications_amount_check'),)


ACCOUNT_KINDS = ('cash', 'bank', 'mobile_wallet')


class MoneyAccount(Entity, Base):
    """Where Omoterra's money is: a cash box, a bank account or a mobile
    wallet (build plan M2.3, decision D6). Its balance starts from an
    opening balance the finance owner verified at the end of `cutoff_on`;
    movements dated on or before the cutoff are inside that balance."""
    __tablename__ = 'money_accounts'
    name: Mapped[str] = mapped_column(String(80), unique=True)
    kind: Mapped[str] = mapped_column(String(16))
    provider: Mapped[str] = mapped_column(String(80), default='')
    number: Mapped[str] = mapped_column(String(80), default='')
    cutoff_on: Mapped[date] = mapped_column(Date)
    opening_balance: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    opening_evidence: Mapped[str] = mapped_column(Text)
    verified_by: Mapped[str] = mapped_column(Text)
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    active: Mapped[bool] = mapped_column(default=True)
    __table_args__ = (
        CheckConstraint("kind IN ('cash','bank','mobile_wallet')", name='money_accounts_kind_check'),
        CheckConstraint('length(btrim(opening_evidence)) >= 3 AND length(btrim(verified_by)) >= 2',
            name='money_accounts_evidence_check'),
    )


class AccountAssignment(Entity, Base):
    """Which account a recorded money movement (a cash book row) went
    through. New entries name it; a historical one is assigned only with
    evidence the finance owner confirmed (rule R6). A movement entered after
    the account was set up but dated on or before its cutoff is a pre-cutoff
    adjustment until the finance owner says it was already inside the
    opening balance, or restates the opening balance with it."""
    __tablename__ = 'account_assignments'
    source_table: Mapped[str] = mapped_column(String(32))
    source_id: Mapped[str] = mapped_column(String(36))
    account_id: Mapped[str] = mapped_column(ForeignKey('money_accounts.id'), index=True)
    how: Mapped[str] = mapped_column(String(16), default='entered')
    evidence: Mapped[str] = mapped_column(Text, default='')
    assigned_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    confirmed_by: Mapped[str] = mapped_column(Text, default='')
    pre_cutoff: Mapped[Optional[str]] = mapped_column(String(16))
    pre_cutoff_note: Mapped[str] = mapped_column(Text, default='')
    pre_cutoff_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        UniqueConstraint('source_table', 'source_id', name='uq_account_assignment_source'),
        CheckConstraint("how IN ('entered','historical')", name='account_assignments_how_check'),
        CheckConstraint("how <> 'historical' OR length(btrim(evidence)) >= 3", name='account_assignments_evidence_check'),
        CheckConstraint("pre_cutoff IS NULL OR (pre_cutoff IN ('inside_opening','restated') AND length(btrim(pre_cutoff_note)) >= 3)",
            name='account_assignments_pre_cutoff_check'),
    )


class MoneyReference(Entity, Base):
    """A transaction reference claimed by one money record (build plan M2.6,
    audit F11): (provider, account, reference) is unique while the claim is
    live, so the same real transaction cannot be entered twice with a new
    retry key. `reference` is normalised (no spaces, upper case); `provider`
    is the payment method ('' when the record has none); `account_key` the
    money account id ('' when none). See app/duplicates.py."""
    __tablename__ = 'money_references'
    provider: Mapped[str] = mapped_column(String(24), default='')
    account_key: Mapped[str] = mapped_column(String(36), default='')
    reference: Mapped[str] = mapped_column(Text)
    flow: Mapped[str] = mapped_column(String(3))
    source_table: Mapped[str] = mapped_column(String(32))
    source_id: Mapped[str] = mapped_column(String(36))
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    released_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    release_reason: Mapped[str] = mapped_column(Text, default='')
    __table_args__ = (
        CheckConstraint("reference <> ''", name='money_references_reference_check'),
        CheckConstraint("flow IN ('in','out')", name='money_references_flow_check'),
        Index('uq_money_reference_live', 'provider', 'account_key', 'reference', unique=True,
            postgresql_where=text('released_at IS NULL')),
        Index('ix_money_references_reference', 'reference'),
        Index('ix_money_references_source', 'source_table', 'source_id'),
    )


class DuplicateOverride(Entity, Base):
    """A payment entered without a reference although one with the same
    party, amount, day and direction already existed: who said it is a
    separate payment, and why (M2.6)."""
    __tablename__ = 'duplicate_overrides'
    source_table: Mapped[str] = mapped_column(String(32))
    source_id: Mapped[str] = mapped_column(String(36))
    earlier_table: Mapped[str] = mapped_column(String(32))
    earlier_id: Mapped[str] = mapped_column(String(36))
    flow: Mapped[str] = mapped_column(String(3))
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    paid_on: Mapped[date] = mapped_column(Date)
    reason: Mapped[str] = mapped_column(Text)
    overridden_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint('length(btrim(reason)) >= 3', name='duplicate_overrides_reason_check'),
        Index('ix_duplicate_overrides_source', 'source_table', 'source_id'),
    )


class AccountTransfer(Entity, Base):
    """Money moved between two of Omoterra's own accounts: out of one, into
    the other, so the business total does not change. A fee charged on it
    is recorded as an account fee."""
    __tablename__ = 'account_transfers'
    from_account_id: Mapped[str] = mapped_column(ForeignKey('money_accounts.id'), index=True)
    to_account_id: Mapped[str] = mapped_column(ForeignKey('money_accounts.id'), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    transferred_on: Mapped[date] = mapped_column(Date, index=True)
    reference: Mapped[str] = mapped_column(Text, default='')
    note: Mapped[str] = mapped_column(Text, default='')
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint('amount > 0', name='account_transfers_amount_check'),
        CheckConstraint('from_account_id <> to_account_id', name='account_transfers_accounts_check'),
    )


class AccountFee(Entity, Base):
    """A bank or wallet charge: money out of the account and a business
    expense."""
    __tablename__ = 'account_fees'
    account_id: Mapped[str] = mapped_column(ForeignKey('money_accounts.id'), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    charged_on: Mapped[date] = mapped_column(Date, index=True)
    description: Mapped[str] = mapped_column(Text)
    reference: Mapped[str] = mapped_column(Text, default='')
    transfer_id: Mapped[Optional[str]] = mapped_column(ForeignKey('account_transfers.id'))
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint('amount > 0', name='account_fees_amount_check'),
        CheckConstraint('length(btrim(description)) >= 3', name='account_fees_description_check'),
    )


class AccountCheck(Entity, Base):
    """A cash count or a statement balance at the end of a day, against the
    recorded balance then. A difference is an exception to explain, never
    a silent adjustment: the balance only changes when the missing record
    itself is entered."""
    __tablename__ = 'account_checks'
    account_id: Mapped[str] = mapped_column(ForeignKey('money_accounts.id'), index=True)
    kind: Mapped[str] = mapped_column(String(16))
    checked_on: Mapped[date] = mapped_column(Date, index=True)
    balance: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    expected: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    difference: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    evidence: Mapped[str] = mapped_column(Text)
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    resolution: Mapped[str] = mapped_column(Text, default='')
    resolved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    resolved_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint("kind IN ('count','statement')", name='account_checks_kind_check'),
        CheckConstraint('difference = balance - expected', name='account_checks_difference_check'),
        CheckConstraint('length(btrim(evidence)) >= 3', name='account_checks_evidence_check'),
        CheckConstraint('resolved_at IS NULL OR length(btrim(resolution)) >= 3', name='account_checks_resolution_check'),
    )


LOT_TABLES = ('supplier_collections', 'lpo_lines', 'opening_stock')


class LotAdjustment(Entity, Base):
    """A physical event on a received lot that has no other record (build
    plan M2.1, rule R2):

    - count: staff counted the lot; `quantity` is counted minus what the
      records expected on that day (never 0). Admin only, with a reason and
      evidence. A shortage counts as stock lost, a surplus as a gain.
    - lost: opening stock that died or was lost (delivery notes and LPO
      lines keep their own loss records).

    Never edited or deleted; a mistake is cancelled with a reason."""
    __tablename__ = 'lot_adjustments'
    lot_table: Mapped[str] = mapped_column(String(24))
    lot_id: Mapped[str] = mapped_column(String(36), index=True)
    kind: Mapped[str] = mapped_column(String(16))
    occurred_on: Mapped[date] = mapped_column(Date, index=True)
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    counted_quantity: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    expected_quantity: Mapped[Optional[Decimal]] = mapped_column(Numeric(14, 3))
    unit_cost: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    loss_reason: Mapped[Optional[str]] = mapped_column(String(16))
    reason: Mapped[str] = mapped_column(Text, default='')
    evidence: Mapped[str] = mapped_column(Text, default='')
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    cancelled_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    cancel_reason: Mapped[str] = mapped_column(Text, default='')
    __table_args__ = (
        CheckConstraint("lot_table IN ('supplier_collections','lpo_lines','opening_stock')", name='lot_adjustments_lot_table_check'),
        CheckConstraint("kind IN ('count','lost')", name='lot_adjustments_kind_check'),
        CheckConstraint("kind <> 'count' OR (counted_quantity >= 0 AND expected_quantity IS NOT NULL"
            " AND quantity = counted_quantity - expected_quantity AND quantity <> 0"
            " AND length(btrim(reason)) >= 3 AND length(btrim(evidence)) >= 3)", name='lot_adjustments_count_check'),
        CheckConstraint("kind <> 'lost' OR (lot_table = 'opening_stock' AND quantity > 0 AND loss_reason IN "
            "('died','sick','stolen','spoiled','other'))", name='lot_adjustments_lost_check'),
        CheckConstraint('unit_cost >= 0', name='lot_adjustments_unit_cost_check'),
        CheckConstraint('cancelled_at IS NULL OR length(btrim(cancel_reason)) >= 3', name='lot_adjustments_cancel_check'),
    )


ADJUSTMENT_KINDS = ('wrong_supplier', 'duplicate_liability', 'free_stock', 'cost_never_existed',
    'receipt_correction', 'supplier_credit_note', 'historical_batch_link', 'cost_resolved',
    'opening_stock_cancelled')


class FinancialAdjustment(Entity, Base):
    """One reasoned correction of a financial record (build plan M1.4): who,
    why, what kind, the record corrected (`entity_type`, `entity_id`), its
    state before and after, and the records it links. Never edited.

    - wrong_supplier: the whole obligation moved to the correct supplier
      (`related_debt_id`); payments stay with whoever received them (R1).
    - duplicate_liability: cancelled as a copy of `related_debt_id`.
    - free_stock: the stock cost nothing; its lines carry unit_cost 0.
    - cost_never_existed: the lines' cost is unknown again (R5).
    - receipt_correction, supplier_credit_note: a delivery note and its
      payable reduced (never delivered; agreed credit for a return), M1.6.
    - historical_batch_link: an old sale line linked to a delivery note by
      `python -m app.link_batch_sales` (entity: the sale line).
    - cost_resolved: an unknown-cost sale line given a cost later (M1.3):
      linked to opening stock, an evidenced cost, or free (entity: the line).
    - opening_stock_cancelled: an opening stock entry made by mistake,
      cancelled before anything was sold from it (entity: the entry)."""
    __tablename__ = 'financial_adjustments'
    kind: Mapped[str] = mapped_column(String(32))
    entity_type: Mapped[str] = mapped_column(String(32))
    entity_id: Mapped[str] = mapped_column(String(36), index=True)
    sale_id: Mapped[Optional[str]] = mapped_column(ForeignKey('sales.id'), index=True)
    related_debt_id: Mapped[Optional[str]] = mapped_column(ForeignKey('ledger_debts.id'), index=True)
    reason: Mapped[str] = mapped_column(Text)
    before: Mapped[dict] = mapped_column(JSON)
    after: Mapped[dict] = mapped_column(JSON)
    linked_ids: Mapped[dict] = mapped_column(JSON, default=dict)
    recorded_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint(f"kind IN ({', '.join(repr(v) for v in ADJUSTMENT_KINDS)})", name='financial_adjustments_kind_check'),
        CheckConstraint('length(btrim(reason)) >= 3', name='financial_adjustments_reason_check'),
    )


class MarketPriceList(Entity, Base):
    """Prices by weight band for one category, from `effective_from`. Never
    edited: publishing again creates a new list (see market_prices.py)."""
    __tablename__ = 'market_price_lists'
    category: Mapped[str] = mapped_column(index=True)
    unit_type: Mapped[str]
    effective_from: Mapped[date] = mapped_column(Date, index=True)
    note: Mapped[str] = mapped_column(Text, default='')
    published_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    withdrawn_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    withdrawn_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    withdraw_reason: Mapped[str] = mapped_column(Text, default='')
    __table_args__ = (
        CheckConstraint("unit_type IN ('bird','animal','kg','tray')", name='market_price_list_unit_valid'),
    )


class MarketPriceBand(Entity, Base):
    """One weight band: `min_weight_kg` <= weight < `max_weight_kg`; a missing
    bound leaves that side open."""
    __tablename__ = 'market_price_bands'
    price_list_id: Mapped[str] = mapped_column(ForeignKey('market_price_lists.id'), index=True)
    position: Mapped[int] = mapped_column(Integer)
    label: Mapped[str] = mapped_column(default='')
    min_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    max_weight_kg: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    price_per_unit: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    __table_args__ = (
        CheckConstraint('price_per_unit > 0', name='market_price_band_price_positive'),
        CheckConstraint('(min_weight_kg IS NULL OR min_weight_kg >= 0) AND (max_weight_kg IS NULL OR max_weight_kg > 0) '
                        'AND (min_weight_kg IS NULL OR max_weight_kg IS NULL OR min_weight_kg < max_weight_kg)',
                        name='market_price_band_weights'),
        UniqueConstraint('price_list_id', 'position', name='uq_market_price_band_position'),
    )

# Registers the media_references hook wherever the models are loaded.
from . import media_refs  # noqa: E402,F401


class OperatingLocation(Entity, Base):
    __tablename__ = 'operating_locations'
    name: Mapped[str] = mapped_column(String(150), unique=True)
    address: Mapped[str] = mapped_column(Text, default='')
    notes: Mapped[str] = mapped_column(Text, default='')
    daily_target: Mapped[Decimal] = mapped_column(Numeric(14, 3), default=0)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (CheckConstraint('daily_target >= 0', name='location_target_positive'),)


class BusinessAsset(Entity, Base):
    __tablename__ = 'business_assets'
    location_id: Mapped[str] = mapped_column(ForeignKey('operating_locations.id'), index=True)
    name: Mapped[str] = mapped_column(String(150))
    purchased_on: Mapped[date] = mapped_column(Date)
    cost: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    residual_value: Mapped[Decimal] = mapped_column(Numeric(14, 2), default=0)
    useful_months: Mapped[int] = mapped_column(Integer)
    depreciation_start: Mapped[date] = mapped_column(Date)
    retired_on: Mapped[Optional[date]] = mapped_column(Date)
    notes: Mapped[str] = mapped_column(Text, default='')
    created_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint('cost >= 0 AND residual_value >= 0 AND residual_value <= cost', name='asset_cost_values'),
        CheckConstraint('useful_months > 0 AND useful_months <= 1200', name='asset_useful_life'),
        CheckConstraint('depreciation_start >= purchased_on AND (retired_on IS NULL OR retired_on >= depreciation_start)', name='asset_dates'),
    )


class LocationInvestment(Entity, Base):
    __tablename__ = 'location_investments'
    location_id: Mapped[str] = mapped_column(ForeignKey('operating_locations.id'), index=True)
    invested_on: Mapped[date] = mapped_column(Date)
    description: Mapped[str] = mapped_column(Text)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    created_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (CheckConstraint('amount > 0', name='location_investment_positive'),)


class LocationAllocation(Entity, Base):
    __tablename__ = 'location_allocations'
    opening_source_id: Mapped[Optional[str]] = mapped_column(ForeignKey('location_allocations.id'), index=True)
    location_id: Mapped[str] = mapped_column(ForeignKey('operating_locations.id'), index=True)
    allocated_on: Mapped[date] = mapped_column(Date, index=True)
    category: Mapped[str] = mapped_column(String(32))
    description: Mapped[str] = mapped_column(String(200))
    unit: Mapped[str] = mapped_column(String(16))
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    unit_cost: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    returned_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3), default=0)
    lpo_line_id: Mapped[Optional[str]] = mapped_column(ForeignKey('lpo_lines.id'), index=True)
    supplier_collection_id: Mapped[Optional[str]] = mapped_column(ForeignKey('supplier_collections.id'), index=True)
    notes: Mapped[str] = mapped_column(Text, default='')
    created_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint('quantity > 0 AND unit_cost >= 0 AND returned_quantity >= 0 AND returned_quantity <= quantity', name='location_allocation_quantities'),
        CheckConstraint('(CASE WHEN lpo_line_id IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN supplier_collection_id IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN opening_source_id IS NOT NULL THEN 1 ELSE 0 END) <= 1', name='location_allocation_source'),
        CheckConstraint("unit IN ('bird','animal','kg','tray','piece')", name='location_allocation_unit'),
    )


class LocationStockEvent(Entity, Base):
    __tablename__ = 'location_stock_events'
    allocation_id: Mapped[str] = mapped_column(ForeignKey('location_allocations.id'), index=True)
    occurred_on: Mapped[date] = mapped_column(Date, index=True)
    kind: Mapped[str] = mapped_column(String(16))
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    note: Mapped[str] = mapped_column(Text)
    created_by: Mapped[Optional[str]] = mapped_column(ForeignKey('operators.id'))
    __table_args__ = (
        CheckConstraint("kind IN ('returned','lost')", name='location_stock_event_kind'),
        CheckConstraint('quantity > 0', name='location_stock_event_quantity'),
    )
