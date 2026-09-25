-- Exact farm location on the supplier profile, one optional video per stock
-- listing, and a content type on media so videos are served as videos.
BEGIN;
ALTER TABLE supplier_profiles
 ADD COLUMN IF NOT EXISTS farm_latitude NUMERIC(9, 6),
 ADD COLUMN IF NOT EXISTS farm_longitude NUMERIC(9, 6),
 ADD COLUMN IF NOT EXISTS farm_map_url VARCHAR NOT NULL DEFAULT '';

ALTER TABLE listings ADD COLUMN IF NOT EXISTS video VARCHAR;

ALTER TABLE media_assets ADD COLUMN IF NOT EXISTS content_type VARCHAR NOT NULL DEFAULT 'image/jpeg';
COMMIT;
