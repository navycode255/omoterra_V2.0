-- Buyer search reads live listings newest first and pages on (created_at, id).
BEGIN;
CREATE INDEX IF NOT EXISTS ix_listings_live_newest ON listings (created_at DESC, id DESC) WHERE listing_status = 'live';
COMMIT;
