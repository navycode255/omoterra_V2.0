-- Supplier media: many photos per supplier, at most one video per supplier.
-- Photos move out of supplier_profiles.evidence_photos (a JSON list) into their
-- own table; the JSON column is kept for older clients but is no longer read.
BEGIN;
CREATE TABLE supplier_photos (
 id VARCHAR(36) PRIMARY KEY,
 created_at TIMESTAMPTZ NOT NULL,
 supplier_id VARCHAR(36) NOT NULL REFERENCES users(id),
 media_id VARCHAR(36) REFERENCES media_assets(id),
 image_url VARCHAR NOT NULL,
 CONSTRAINT uq_supplier_photo_url UNIQUE (supplier_id, image_url)
);
CREATE INDEX ix_supplier_photos_supplier_id ON supplier_photos(supplier_id);

-- Keep existing photos, in their original order.
INSERT INTO supplier_photos (id, created_at, supplier_id, media_id, image_url)
SELECT gen_random_uuid()::text, now() + (photo.position * interval '1 millisecond'), profile.user_id,
       (SELECT asset.id FROM media_assets asset WHERE asset.id = replace(photo.url, '/media/', '')),
       photo.url
FROM supplier_profiles profile
CROSS JOIN LATERAL json_array_elements_text(COALESCE(profile.evidence_photos, '[]'::json)) WITH ORDINALITY AS photo(url, position)
ON CONFLICT DO NOTHING;

CREATE TABLE supplier_videos (
 id VARCHAR(36) PRIMARY KEY,
 created_at TIMESTAMPTZ NOT NULL,
 updated_at TIMESTAMPTZ NOT NULL,
 supplier_id VARCHAR(36) NOT NULL UNIQUE REFERENCES users(id),
 youtube_video_id VARCHAR(32) NOT NULL,
 youtube_url VARCHAR NOT NULL,
 thumbnail_url VARCHAR NOT NULL,
 title VARCHAR NOT NULL DEFAULT '',
 source VARCHAR NOT NULL DEFAULT 'link',
 status VARCHAR NOT NULL DEFAULT 'ready',
 CONSTRAINT valid_supplier_video_status CHECK (status IN ('processing','ready','failed')),
 CONSTRAINT valid_supplier_video_source CHECK (source IN ('link','upload'))
);
COMMIT;
