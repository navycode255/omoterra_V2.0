-- Omoterra V1 initial PostgreSQL schema. Apply once to an empty database.
BEGIN;
CREATE TABLE users (
	phone VARCHAR(20) NOT NULL, 
	name VARCHAR NOT NULL, 
	region VARCHAR NOT NULL, 
	language VARCHAR NOT NULL, 
	roles JSON NOT NULL, 
	buyer_type VARCHAR, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (phone)
);

CREATE TABLE otp_challenges (
	phone VARCHAR NOT NULL, 
	code_hash VARCHAR NOT NULL, 
	expires_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	attempts INTEGER NOT NULL, 
	consumed BOOLEAN NOT NULL, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id)
);

CREATE INDEX ix_otp_challenges_phone ON otp_challenges (phone);

CREATE TABLE idempotency (
	key VARCHAR NOT NULL, 
	fingerprint VARCHAR NOT NULL, 
	resource_id VARCHAR NOT NULL, 
	PRIMARY KEY (key)
);

CREATE TABLE supplier_profiles (
	user_id VARCHAR(36) NOT NULL, 
	public_alias VARCHAR NOT NULL, 
	alias_approved BOOLEAN NOT NULL, 
	legal_name VARCHAR NOT NULL, 
	internal_pickup_address TEXT NOT NULL, 
	completed_supplies_count INTEGER NOT NULL, 
	PRIMARY KEY (user_id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE TABLE addresses (
	user_id VARCHAR(36) NOT NULL, 
	label VARCHAR NOT NULL, 
	recipient_name VARCHAR NOT NULL, 
	phone VARCHAR NOT NULL, 
	region VARCHAR NOT NULL, 
	district_area VARCHAR NOT NULL, 
	address_text TEXT NOT NULL, 
	coordinates VARCHAR, 
	deleted BOOLEAN NOT NULL, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE INDEX ix_addresses_user_id ON addresses (user_id);

CREATE TABLE listings (
	supplier_id VARCHAR(36) NOT NULL, 
	category VARCHAR NOT NULL, 
	unit_type VARCHAR NOT NULL, 
	specs JSON NOT NULL, 
	region VARCHAR NOT NULL, 
	photos JSON NOT NULL, 
	farmer_asking_price_per_unit NUMERIC(14, 2) NOT NULL, 
	supplier_payout_price_per_unit NUMERIC(14, 2), 
	buyer_price_per_unit NUMERIC(14, 2), 
	quantity_total NUMERIC(14, 3) NOT NULL, 
	quantity_reserved NUMERIC(14, 3) NOT NULL, 
	quantity_sold NUMERIC(14, 3) NOT NULL, 
	listing_status VARCHAR NOT NULL, 
	last_confirmed_at TIMESTAMP WITH TIME ZONE, 
	confirmation_due_at TIMESTAMP WITH TIME ZONE, 
	approved_at TIMESTAMP WITH TIME ZONE, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT valid_inventory CHECK (quantity_total >= 0 AND quantity_reserved >= 0 AND quantity_sold >= 0 AND quantity_reserved + quantity_sold <= quantity_total), 
	CHECK (farmer_asking_price_per_unit > 0), 
	CHECK (supplier_payout_price_per_unit >= 0 AND supplier_payout_price_per_unit <= farmer_asking_price_per_unit), 
	CHECK (buyer_price_per_unit > 0), 
	FOREIGN KEY(supplier_id) REFERENCES users (id)
);

CREATE INDEX ix_listings_supplier_id ON listings (supplier_id);

CREATE INDEX ix_listings_confirmation_due_at ON listings (confirmation_due_at);

CREATE INDEX ix_listings_listing_status ON listings (listing_status);

CREATE TABLE sourcing_requests (
	buyer_id VARCHAR(36) NOT NULL, 
	category VARCHAR NOT NULL, 
	quantity NUMERIC(14, 3) NOT NULL, 
	unit_type VARCHAR NOT NULL, 
	weight_or_size_requirement VARCHAR NOT NULL, 
	live_dressed_or_cut VARCHAR NOT NULL, 
	needed_by_date VARCHAR NOT NULL, 
	delivery_area VARCHAR NOT NULL, 
	notes TEXT NOT NULL, 
	reference_photo VARCHAR, 
	quantity_secured NUMERIC(14, 3) NOT NULL, 
	status VARCHAR NOT NULL, 
	converted_order_id VARCHAR(36), 
	admin_notes TEXT NOT NULL, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(buyer_id) REFERENCES users (id)
);

CREATE INDEX ix_sourcing_requests_buyer_id ON sourcing_requests (buyer_id);

CREATE TABLE business_opportunities (
	buyer_id VARCHAR(36) NOT NULL, 
	business_type VARCHAR NOT NULL, 
	area VARCHAR NOT NULL, 
	budget_range VARCHAR NOT NULL, 
	has_premises BOOLEAN NOT NULL, 
	wants_stock BOOLEAN NOT NULL, 
	target_start_date VARCHAR NOT NULL, 
	status VARCHAR NOT NULL, 
	internal_notes TEXT NOT NULL, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(buyer_id) REFERENCES users (id)
);

CREATE INDEX ix_business_opportunities_buyer_id ON business_opportunities (buyer_id);

CREATE TABLE auth_sessions (
	user_id VARCHAR(36) NOT NULL, 
	token_hash VARCHAR NOT NULL, 
	expires_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id), 
	UNIQUE (token_hash)
);

CREATE TABLE media_assets (
	owner_id VARCHAR(36), 
	storage_name VARCHAR NOT NULL, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(owner_id) REFERENCES users (id), 
	UNIQUE (storage_name)
);

CREATE INDEX ix_media_assets_owner_id ON media_assets (owner_id);

CREATE TABLE stock_reservations (
	listing_id VARCHAR(36) NOT NULL, 
	buyer_id VARCHAR(36) NOT NULL, 
	quantity NUMERIC(14, 3) NOT NULL, 
	expires_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	status VARCHAR NOT NULL, 
	order_id VARCHAR(36), 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CHECK (quantity > 0), 
	FOREIGN KEY(listing_id) REFERENCES listings (id), 
	FOREIGN KEY(buyer_id) REFERENCES users (id), 
	UNIQUE (order_id)
);

CREATE INDEX ix_stock_reservations_buyer_id ON stock_reservations (buyer_id);

CREATE INDEX ix_stock_reservations_listing_id ON stock_reservations (listing_id);

CREATE INDEX ix_stock_reservations_expires_at ON stock_reservations (expires_at);

CREATE TABLE orders (
	buyer_id VARCHAR(36) NOT NULL, 
	delivery_address_id VARCHAR(36) NOT NULL, 
	delivery_snapshot JSON NOT NULL, 
	preferred_delivery_date VARCHAR NOT NULL, 
	expected_collection_date VARCHAR, 
	payment_method VARCHAR NOT NULL, 
	payment_status VARCHAR NOT NULL, 
	sourcing_request_id VARCHAR(36), 
	internal_status VARCHAR NOT NULL, 
	expected_quantity NUMERIC(14, 3) NOT NULL, 
	actual_quantity NUMERIC(14, 3), 
	rejected_quantity NUMERIC(14, 3), 
	actual_weight NUMERIC(14, 3), 
	collection_photos JSON NOT NULL, 
	collection_notes TEXT NOT NULL, 
	total_amount NUMERIC(14, 2) NOT NULL, 
	idempotency_key VARCHAR NOT NULL, 
	activity JSON NOT NULL, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(buyer_id) REFERENCES users (id), 
	FOREIGN KEY(delivery_address_id) REFERENCES addresses (id), 
	UNIQUE (sourcing_request_id), 
	UNIQUE (idempotency_key)
);

CREATE INDEX ix_orders_buyer_id ON orders (buyer_id);

CREATE TABLE sourcing_request_allocations (
	sourcing_request_id VARCHAR(36) NOT NULL, 
	listing_id VARCHAR(36) NOT NULL, 
	quantity_allocated NUMERIC(14, 3) NOT NULL, 
	unit_price NUMERIC(14, 2) NOT NULL, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(sourcing_request_id) REFERENCES sourcing_requests (id), 
	FOREIGN KEY(listing_id) REFERENCES listings (id)
);

CREATE TABLE order_items (
	order_id VARCHAR(36) NOT NULL, 
	listing_id VARCHAR(36) NOT NULL, 
	quantity NUMERIC(14, 3) NOT NULL, 
	unit_price NUMERIC(14, 2) NOT NULL, 
	subtotal NUMERIC(14, 2) NOT NULL, 
	asking_snapshot NUMERIC(14, 2) NOT NULL, 
	payout_snapshot NUMERIC(14, 2) NOT NULL, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(order_id) REFERENCES orders (id), 
	FOREIGN KEY(listing_id) REFERENCES listings (id)
);

CREATE INDEX ix_order_items_order_id ON order_items (order_id);

CREATE TABLE payments (
	order_id VARCHAR(36) NOT NULL, 
	amount NUMERIC(14, 2) NOT NULL, 
	method VARCHAR NOT NULL, 
	status VARCHAR NOT NULL, 
	received_amount NUMERIC(14, 2) NOT NULL, 
	provider_transaction_id VARCHAR, 
	idempotency_key VARCHAR NOT NULL, 
	paid_at TIMESTAMP WITH TIME ZONE, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (order_id), 
	FOREIGN KEY(order_id) REFERENCES orders (id), 
	UNIQUE (provider_transaction_id), 
	UNIQUE (idempotency_key)
);

CREATE TABLE settlements (
	supplier_id VARCHAR(36) NOT NULL, 
	order_item_id VARCHAR(36) NOT NULL, 
	farmer_asking_price_per_unit NUMERIC(14, 2) NOT NULL, 
	supplier_payout_price_per_unit NUMERIC(14, 2) NOT NULL, 
	commission_amount_per_unit NUMERIC(14, 2) NOT NULL, 
	quantity NUMERIC(14, 3) NOT NULL, 
	total_payable NUMERIC(14, 2) NOT NULL, 
	status VARCHAR NOT NULL, 
	paid_at TIMESTAMP WITH TIME ZONE, 
	payment_reference VARCHAR, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (order_item_id, supplier_id), 
	FOREIGN KEY(supplier_id) REFERENCES users (id), 
	FOREIGN KEY(order_item_id) REFERENCES order_items (id)
);

CREATE INDEX ix_settlements_supplier_id ON settlements (supplier_id);

CREATE TABLE payment_receipts (
	payment_id VARCHAR(36) NOT NULL, 
	amount NUMERIC(14, 2) NOT NULL, 
	reference VARCHAR NOT NULL, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CHECK (amount > 0), 
	FOREIGN KEY(payment_id) REFERENCES payments (id), 
	UNIQUE (reference)
);

CREATE INDEX ix_payment_receipts_payment_id ON payment_receipts (payment_id);

ALTER TABLE stock_reservations ADD FOREIGN KEY(order_id) REFERENCES orders (id);

ALTER TABLE sourcing_requests ADD FOREIGN KEY(converted_order_id) REFERENCES orders (id);

ALTER TABLE orders ADD FOREIGN KEY(sourcing_request_id) REFERENCES sourcing_requests (id);

COMMIT;
