import uuid
from datetime import datetime, timezone
from decimal import Decimal
from sqlalchemy import String, Numeric, DateTime, ForeignKey, UniqueConstraint, CheckConstraint, JSON, Boolean, Integer, Text
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
    buyer_type: Mapped[str | None]


class SupplierProfile(Base):
    __tablename__ = 'supplier_profiles'
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id'), primary_key=True)
    public_alias: Mapped[str] = mapped_column(default='Omoterra supply partner')
    alias_approved: Mapped[bool] = mapped_column(default=False)
    legal_name: Mapped[str]
    internal_pickup_address: Mapped[str] = mapped_column(Text)
    completed_supplies_count: Mapped[int] = mapped_column(default=0)


class Address(Entity, Base):
    __tablename__ = 'addresses'
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    label: Mapped[str]
    recipient_name: Mapped[str]
    phone: Mapped[str]
    region: Mapped[str]
    district_area: Mapped[str]
    address_text: Mapped[str] = mapped_column(Text)
    coordinates: Mapped[str | None]
    deleted: Mapped[bool] = mapped_column(default=False)


class Listing(Entity, Base):
    __tablename__ = 'listings'
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    category: Mapped[str]
    unit_type: Mapped[str]
    specs: Mapped[dict] = mapped_column(JSON, default=dict)
    region: Mapped[str]
    photos: Mapped[list] = mapped_column(JSON, default=list)
    farmer_asking_price_per_unit: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    supplier_payout_price_per_unit: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    buyer_price_per_unit: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    quantity_total: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    quantity_reserved: Mapped[Decimal] = mapped_column(Numeric(14, 3), default=0)
    quantity_sold: Mapped[Decimal] = mapped_column(Numeric(14, 3), default=0)
    listing_status: Mapped[str] = mapped_column(default='pending_review', index=True)
    last_confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    confirmation_due_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
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
    buyer_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    status: Mapped[str] = mapped_column(default='active')
    order_id: Mapped[str | None] = mapped_column(ForeignKey('orders.id', use_alter=True), unique=True)
    __table_args__ = (CheckConstraint('quantity > 0'),)


class Order(Entity, Base):
    __tablename__ = 'orders'
    buyer_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    delivery_address_id: Mapped[str] = mapped_column(ForeignKey('addresses.id'))
    delivery_snapshot: Mapped[dict] = mapped_column(JSON)
    preferred_delivery_date: Mapped[str]
    expected_collection_date: Mapped[str | None]
    payment_method: Mapped[str]
    payment_status: Mapped[str] = mapped_column(default='pending')
    sourcing_request_id: Mapped[str | None] = mapped_column(ForeignKey('sourcing_requests.id', use_alter=True), unique=True)
    internal_status: Mapped[str] = mapped_column(default='reserved')
    expected_quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    actual_quantity: Mapped[Decimal | None] = mapped_column(Numeric(14, 3))
    rejected_quantity: Mapped[Decimal | None] = mapped_column(Numeric(14, 3))
    actual_weight: Mapped[Decimal | None] = mapped_column(Numeric(14, 3))
    collection_photos: Mapped[list] = mapped_column(JSON, default=list)
    collection_notes: Mapped[str] = mapped_column(Text, default='')
    total_amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    idempotency_key: Mapped[str] = mapped_column(unique=True)
    activity: Mapped[list] = mapped_column(JSON, default=list)


class OrderItem(Entity, Base):
    __tablename__ = 'order_items'
    order_id: Mapped[str] = mapped_column(ForeignKey('orders.id'), index=True)
    listing_id: Mapped[str] = mapped_column(ForeignKey('listings.id'))
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    unit_price: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    subtotal: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    asking_snapshot: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    payout_snapshot: Mapped[Decimal] = mapped_column(Numeric(14, 2))


class SourcingRequest(Entity, Base):
    __tablename__ = 'sourcing_requests'
    buyer_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    category: Mapped[str]
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    unit_type: Mapped[str]
    weight_or_size_requirement: Mapped[str] = mapped_column(default='')
    live_dressed_or_cut: Mapped[str] = mapped_column(default='')
    needed_by_date: Mapped[str]
    delivery_area: Mapped[str]
    notes: Mapped[str] = mapped_column(Text, default='')
    reference_photo: Mapped[str | None]
    quantity_secured: Mapped[Decimal] = mapped_column(Numeric(14, 3), default=0)
    status: Mapped[str] = mapped_column(default='submitted')
    converted_order_id: Mapped[str | None] = mapped_column(ForeignKey('orders.id', use_alter=True))
    admin_notes: Mapped[str] = mapped_column(Text, default='')


class SourcingRequestAllocation(Entity, Base):
    __tablename__ = 'sourcing_request_allocations'
    sourcing_request_id: Mapped[str] = mapped_column(ForeignKey('sourcing_requests.id'))
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
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    payment_reference: Mapped[str | None]
    __table_args__ = (UniqueConstraint('order_item_id', 'supplier_id'),)


class Payment(Entity, Base):
    __tablename__ = 'payments'
    order_id: Mapped[str] = mapped_column(ForeignKey('orders.id'), unique=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    method: Mapped[str]
    status: Mapped[str] = mapped_column(default='pending')
    received_amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), default=0)
    provider_transaction_id: Mapped[str | None] = mapped_column(unique=True)
    idempotency_key: Mapped[str] = mapped_column(unique=True)
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


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


class Idempotency(Base):
    __tablename__ = 'idempotency'
    key: Mapped[str] = mapped_column(primary_key=True)
    fingerprint: Mapped[str]
    resource_id: Mapped[str]


class MediaAsset(Entity, Base):
    __tablename__ = 'media_assets'
    owner_id: Mapped[str | None] = mapped_column(ForeignKey('users.id'), index=True)
    storage_name: Mapped[str] = mapped_column(unique=True)


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
    actor_id: Mapped[str | None] = mapped_column(ForeignKey('users.id'))


class StockSale(Entity, Base):
    __tablename__ = 'stock_sales'
    listing_id: Mapped[str] = mapped_column(ForeignKey('listings.id'), index=True)
    supplier_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    source: Mapped[str]
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    sold_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    unit_price: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    order_item_id: Mapped[str | None] = mapped_column(ForeignKey('order_items.id'), unique=True)
    note: Mapped[str] = mapped_column(Text, default='')
    __table_args__ = (CheckConstraint('quantity > 0'), CheckConstraint("source IN ('external', 'omoterra')"))
