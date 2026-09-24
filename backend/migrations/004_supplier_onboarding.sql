-- Extend the canonical supplier profile with operating, lifecycle and verification data.
-- Existing supplier identities and production batches remain in place.
BEGIN;
ALTER TABLE supplier_profiles ADD COLUMN alternate_phone VARCHAR NOT NULL DEFAULT '';
ALTER TABLE supplier_profiles ADD COLUMN region VARCHAR NOT NULL DEFAULT '';
ALTER TABLE supplier_profiles ADD COLUMN district VARCHAR NOT NULL DEFAULT '';
ALTER TABLE supplier_profiles ADD COLUMN general_area VARCHAR NOT NULL DEFAULT '';
ALTER TABLE supplier_profiles ADD COLUMN categories JSON NOT NULL DEFAULT '[]'::json;
ALTER TABLE supplier_profiles ADD COLUMN primary_category VARCHAR;
ALTER TABLE supplier_profiles ADD COLUMN production_profile JSON NOT NULL DEFAULT '{}'::json;
ALTER TABLE supplier_profiles ADD COLUMN evidence_photos JSON NOT NULL DEFAULT '[]'::json;
ALTER TABLE supplier_profiles ADD COLUMN production_frequency VARCHAR NOT NULL DEFAULT '';
ALTER TABLE supplier_profiles ADD COLUMN operating_notes TEXT NOT NULL DEFAULT '';
ALTER TABLE supplier_profiles ADD COLUMN pickup_instructions TEXT NOT NULL DEFAULT '';
ALTER TABLE supplier_profiles ADD COLUMN omoterra_pickup BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE supplier_profiles ADD COLUMN supplier_transport BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE supplier_profiles ADD COLUMN supply_forms JSON NOT NULL DEFAULT '[]'::json;
ALTER TABLE supplier_profiles ADD COLUMN preferred_contact_method VARCHAR NOT NULL DEFAULT 'phone';
ALTER TABLE supplier_profiles ADD COLUMN status VARCHAR NOT NULL DEFAULT 'new';
ALTER TABLE supplier_profiles ADD COLUMN verification JSON NOT NULL DEFAULT '{"phone_confirmed":false,"identity_reviewed":false,"location_confirmed":false,"location_visited":false,"production_seen":false,"pickup_access_checked":false,"photos_reviewed":false}'::json;
ALTER TABLE supplier_profiles ADD COLUMN internal_notes TEXT NOT NULL DEFAULT '';
ALTER TABLE supplier_profiles ADD COLUMN created_by_actor VARCHAR NOT NULL DEFAULT 'supplier';
ALTER TABLE supplier_profiles ADD COLUMN reviewed_by_actor VARCHAR;
ALTER TABLE supplier_profiles ADD COLUMN reviewed_at TIMESTAMPTZ;
ALTER TABLE supplier_profiles ADD COLUMN approved_by_actor VARCHAR;
ALTER TABLE supplier_profiles ADD COLUMN approved_at TIMESTAMPTZ;
ALTER TABLE supplier_profiles ADD COLUMN suspended_by_actor VARCHAR;
ALTER TABLE supplier_profiles ADD COLUMN suspended_at TIMESTAMPTZ;

-- Existing live, operator-approved inventory remains usable. Other existing profiles
-- enter review so capability registration alone never implies operational approval.
UPDATE supplier_profiles sp SET status = CASE
  WHEN EXISTS (SELECT 1 FROM listings l WHERE l.supplier_id = sp.user_id AND l.listing_status = 'live' AND l.approved_at IS NOT NULL)
    THEN 'approved' ELSE 'under_review' END;
UPDATE supplier_profiles sp SET region = COALESCE((SELECT u.region FROM users u WHERE u.id = sp.user_id), '');
UPDATE supplier_profiles sp SET categories = COALESCE((
  SELECT json_agg(DISTINCT l.category) FROM listings l WHERE l.supplier_id = sp.user_id
), '[]'::json);
UPDATE supplier_profiles sp SET approved_at = now(), approved_by_actor = 'migration'
WHERE status = 'approved';
ALTER TABLE supplier_profiles ADD CONSTRAINT valid_supplier_status CHECK(status IN ('new','under_review','approved','suspended','rejected'));
CREATE INDEX ix_supplier_profiles_status ON supplier_profiles(status);
CREATE INDEX ix_supplier_profiles_region ON supplier_profiles(region);
CREATE INDEX ix_supplier_batches_supplier_status ON supplier_batches(supplier_id, status);
COMMIT;
