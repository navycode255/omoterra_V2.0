-- Operations lists page and search in the database (docs/plan-high-priority-gaps.md, phase 3).
-- Search is ILIKE '%text%' on names, phones and regions; trigram indexes keep
-- that indexed. Action queues (unpaid settlements, orders in progress,
-- outstanding payments) read by status, oldest first.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- The trigram operator class lives in whichever schema holds the extension.
DO $$
DECLARE
    ops text;
BEGIN
    SELECT quote_ident(n.nspname) || '.gin_trgm_ops' INTO ops
    FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace
    WHERE e.extname = 'pg_trgm';
    EXECUTE format('CREATE INDEX IF NOT EXISTS ix_supplier_profiles_alias_trgm ON supplier_profiles USING gin (public_alias %s)', ops);
    EXECUTE format('CREATE INDEX IF NOT EXISTS ix_supplier_profiles_legal_name_trgm ON supplier_profiles USING gin (legal_name %s)', ops);
    EXECUTE format('CREATE INDEX IF NOT EXISTS ix_users_name_trgm ON users USING gin (name %s)', ops);
    EXECUTE format('CREATE INDEX IF NOT EXISTS ix_users_phone_trgm ON users USING gin (phone %s)', ops);
    EXECUTE format('CREATE INDEX IF NOT EXISTS ix_buyer_profiles_business_name_trgm ON buyer_profiles USING gin (business_name %s)', ops);
    EXECUTE format('CREATE INDEX IF NOT EXISTS ix_buyer_profiles_phone_trgm ON buyer_profiles USING gin (phone %s)', ops);
    EXECUTE format('CREATE INDEX IF NOT EXISTS ix_listings_region_trgm ON listings USING gin (region %s)', ops);
    EXECUTE format('CREATE INDEX IF NOT EXISTS ix_buyer_requirements_delivery_region_trgm ON buyer_requirements USING gin (delivery_region %s)', ops);
END
$$;

-- Dashboard references (OR-3F2A9C) are id prefixes.
CREATE INDEX IF NOT EXISTS ix_orders_id_prefix ON orders (id varchar_pattern_ops);
CREATE INDEX IF NOT EXISTS ix_order_items_order_id_prefix ON order_items (order_id varchar_pattern_ops);

CREATE INDEX IF NOT EXISTS ix_orders_status_created ON orders (internal_status, created_at);
CREATE INDEX IF NOT EXISTS ix_settlements_status_created ON settlements (status, created_at);
CREATE INDEX IF NOT EXISTS ix_payments_status_created ON payments (status, created_at);
CREATE INDEX IF NOT EXISTS ix_order_items_listing ON order_items (listing_id);
CREATE INDEX IF NOT EXISTS ix_settlements_order_item ON settlements (order_item_id);
COMMIT;
