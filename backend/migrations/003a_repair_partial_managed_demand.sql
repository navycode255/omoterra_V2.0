-- Repair for databases where supplier_batches was created (with all of its
-- 003 columns and indexes) before 003_managed_demand.sql ran, so 003 fails
-- at CREATE TABLE supplier_batches. This is 003 without that block.
-- Apply it INSTEAD of 003 only when supplier_batches exists and
-- buyer_requirements does not. Back up the database first.
BEGIN;
ALTER TABLE sourcing_requests RENAME TO buyer_requirements;
ALTER TABLE orders ALTER COLUMN buyer_id DROP NOT NULL;
ALTER TABLE orders ALTER COLUMN delivery_address_id DROP NOT NULL;
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_sourcing_request_id_key;
ALTER TABLE stock_reservations ALTER COLUMN buyer_id DROP NOT NULL;
ALTER TABLE stock_reservations DROP CONSTRAINT IF EXISTS stock_reservations_order_id_key;
ALTER TABLE buyer_requirements ALTER COLUMN buyer_id DROP NOT NULL;
ALTER TABLE buyer_requirements ADD COLUMN buyer_profile_id VARCHAR(36);
-- buyer_profiles is created below; defer this FK until its table exists.
ALTER TABLE buyer_requirements DROP CONSTRAINT IF EXISTS buyer_requirements_buyer_profile_id_fkey;
ALTER TABLE buyer_requirements ADD COLUMN requirement_number VARCHAR(24);
UPDATE buyer_requirements SET requirement_number = 'REQ-' || upper(substr(replace(id, '-', ''), 1, 8));
ALTER TABLE buyer_requirements ALTER COLUMN requirement_number SET NOT NULL;
ALTER TABLE buyer_requirements ADD COLUMN product_subtype VARCHAR NOT NULL DEFAULT '';
ALTER TABLE buyer_requirements ADD COLUMN minimum_weight_kg NUMERIC(8,3);
ALTER TABLE buyer_requirements ADD COLUMN maximum_weight_kg NUMERIC(8,3);
ALTER TABLE buyer_requirements ADD CONSTRAINT valid_requirement_weights CHECK(minimum_weight_kg IS NULL OR maximum_weight_kg IS NULL OR minimum_weight_kg <= maximum_weight_kg);
ALTER TABLE buyer_requirements ADD COLUMN delivery_region VARCHAR NOT NULL DEFAULT '';
ALTER TABLE buyer_requirements ADD COLUMN delivery_notes TEXT NOT NULL DEFAULT '';
ALTER TABLE buyer_requirements ADD COLUMN requirement_type VARCHAR NOT NULL DEFAULT 'one_time';
ALTER TABLE buyer_requirements ADD CONSTRAINT valid_requirement_type CHECK(requirement_type IN ('one_time','recurring'));
ALTER TABLE buyer_requirements ADD COLUMN recurrence_frequency VARCHAR NOT NULL DEFAULT '';
ALTER TABLE buyer_requirements ADD COLUMN preferred_weekdays JSON NOT NULL DEFAULT '[]'::json;
ALTER TABLE buyer_requirements ADD COLUMN created_by VARCHAR NOT NULL DEFAULT 'buyer';
ALTER TABLE buyer_requirements ADD COLUMN created_by_user_id VARCHAR(36) REFERENCES users(id);
CREATE UNIQUE INDEX ix_buyer_requirements_requirement_number ON buyer_requirements(requirement_number);
CREATE INDEX ix_buyer_requirements_category ON buyer_requirements(category);
CREATE INDEX ix_buyer_requirements_needed_by_date ON buyer_requirements(needed_by_date);
CREATE INDEX ix_buyer_requirements_delivery_region ON buyer_requirements(delivery_region);
CREATE INDEX ix_buyer_requirements_status ON buyer_requirements(status);

CREATE TABLE buyer_profiles (
 id VARCHAR(36) PRIMARY KEY,
 created_at TIMESTAMPTZ NOT NULL,
 user_id VARCHAR(36) UNIQUE REFERENCES users(id),
 business_name VARCHAR NOT NULL DEFAULT '',
 buyer_type VARCHAR NOT NULL DEFAULT 'other',
 contact_person VARCHAR NOT NULL DEFAULT '',
 phone VARCHAR NOT NULL DEFAULT '',
 region VARCHAR NOT NULL DEFAULT '',
 area VARCHAR NOT NULL DEFAULT '',
 internal_notes TEXT NOT NULL DEFAULT '',
 preferences JSON NOT NULL DEFAULT '{}'::json,
 last_known_buying_price NUMERIC(14,2),
 minimum_order NUMERIC(14,3),
 payment_terms VARCHAR NOT NULL DEFAULT ''
);
CREATE INDEX ix_buyer_profiles_user_id ON buyer_profiles(user_id);
ALTER TABLE buyer_requirements ADD CONSTRAINT buyer_requirements_buyer_profile_id_fkey FOREIGN KEY (buyer_profile_id) REFERENCES buyer_profiles(id);
CREATE INDEX ix_buyer_requirements_buyer_profile_id ON buyer_requirements(buyer_profile_id);


CREATE TABLE supplier_batch_movements (
 id VARCHAR(36) PRIMARY KEY,
 created_at TIMESTAMPTZ NOT NULL,
 batch_id VARCHAR(36) NOT NULL REFERENCES supplier_batches(id),
 supplier_id VARCHAR(36) NOT NULL REFERENCES users(id),
 kind VARCHAR NOT NULL DEFAULT 'external_sale',
 quantity NUMERIC(14,3) NOT NULL CHECK(quantity > 0),
 note TEXT NOT NULL DEFAULT '',
 idempotency_key VARCHAR NOT NULL UNIQUE
);
CREATE INDEX ix_supplier_batch_movements_batch_id ON supplier_batch_movements(batch_id);
CREATE INDEX ix_supplier_batch_movements_supplier_id ON supplier_batch_movements(supplier_id);

CREATE TABLE supply_offers (
 id VARCHAR(36) PRIMARY KEY,
 created_at TIMESTAMPTZ NOT NULL,
 demand_id VARCHAR(36) NOT NULL REFERENCES buyer_requirements(id),
 supplier_id VARCHAR(36) NOT NULL REFERENCES users(id),
 batch_id VARCHAR(36) REFERENCES supplier_batches(id),
 offered_quantity NUMERIC(14,3) NOT NULL CHECK(offered_quantity > 0),
 accepted_quantity NUMERIC(14,3),
 expected_ready_date VARCHAR,
 expected_min_weight_kg NUMERIC(8,3),
 expected_max_weight_kg NUMERIC(8,3),
 asking_price_per_unit NUMERIC(14,2),
 supplier_notes TEXT NOT NULL DEFAULT '',
 status VARCHAR NOT NULL DEFAULT 'pending',
 reviewed_at TIMESTAMPTZ
);
CREATE INDEX ix_supply_offers_demand_id ON supply_offers(demand_id);
CREATE INDEX ix_supply_offers_supplier_id ON supply_offers(supplier_id);
CREATE INDEX ix_supply_offers_batch_id ON supply_offers(batch_id);
CREATE INDEX ix_supply_offers_status ON supply_offers(status);

CREATE TABLE demand_allocations (
 id VARCHAR(36) PRIMARY KEY,
 created_at TIMESTAMPTZ NOT NULL,
 demand_id VARCHAR(36) NOT NULL REFERENCES buyer_requirements(id),
 supply_offer_id VARCHAR(36) REFERENCES supply_offers(id),
 supplier_id VARCHAR(36) NOT NULL REFERENCES users(id),
 supplier_batch_id VARCHAR(36) NOT NULL REFERENCES supplier_batches(id),
 allocated_quantity NUMERIC(14,3) NOT NULL CHECK(allocated_quantity > 0),
 listing_id VARCHAR(36) REFERENCES listings(id),
 accepted_quantity NUMERIC(14,3),
 rejected_quantity NUMERIC(14,3),
 status VARCHAR NOT NULL DEFAULT 'reserved',
 allocated_by VARCHAR(36) REFERENCES users(id),
 updated_by VARCHAR(36) REFERENCES users(id)
);
CREATE INDEX ix_demand_allocations_demand_id ON demand_allocations(demand_id);
CREATE INDEX ix_demand_allocations_offer_id ON demand_allocations(supply_offer_id);
CREATE INDEX ix_demand_allocations_supplier_id ON demand_allocations(supplier_id);
CREATE INDEX ix_demand_allocations_batch_id ON demand_allocations(supplier_batch_id);
ALTER TABLE order_items ADD COLUMN demand_allocation_id VARCHAR(36) UNIQUE REFERENCES demand_allocations(id);
ALTER TABLE order_items ADD COLUMN actual_quantity NUMERIC(14,3);
ALTER TABLE order_items ADD COLUMN rejected_quantity NUMERIC(14,3);
CREATE INDEX ix_demand_allocations_status ON demand_allocations(status);

CREATE TABLE batch_verifications (
 id VARCHAR(36) PRIMARY KEY,
 created_at TIMESTAMPTZ NOT NULL,
 batch_id VARCHAR(36) NOT NULL REFERENCES supplier_batches(id),
 inspected_by VARCHAR(36) REFERENCES users(id),
 inspected_at TIMESTAMPTZ NOT NULL,
 expected_quantity NUMERIC(14,3),
 verified_quantity NUMERIC(14,3),
 sampled_average_weight_kg NUMERIC(8,3),
 rejected_quantity NUMERIC(14,3),
 readiness_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
 location_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
 notes TEXT NOT NULL DEFAULT '',
 photos JSON NOT NULL DEFAULT '[]'::json,
 status VARCHAR NOT NULL DEFAULT 'pending'
);
CREATE INDEX ix_batch_verifications_batch_id ON batch_verifications(batch_id);
CREATE INDEX ix_batch_verifications_status ON batch_verifications(status);
COMMIT;
