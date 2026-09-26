-- Which record shows which media, so "is this photo used?" and "may this
-- buyer see it?" are index lookups instead of text searches through JSON.
-- app/media.py keeps it in step on every write; this backfills what exists.
BEGIN;
CREATE TABLE IF NOT EXISTS media_references (
    media_id VARCHAR(36) NOT NULL REFERENCES media_assets(id),
    owner_table VARCHAR(40) NOT NULL,
    owner_id VARCHAR(36) NOT NULL,
    PRIMARY KEY (media_id, owner_table, owner_id)
);
CREATE INDEX IF NOT EXISTS ix_media_references_owner ON media_references(owner_table, owner_id);

INSERT INTO media_references (media_id, owner_table, owner_id)
SELECT DISTINCT refs.media_id, refs.owner_table, refs.owner_id
FROM (
    SELECT substring(u FROM '/media/([0-9a-f-]{36})') AS media_id, 'listings' AS owner_table, l.id AS owner_id
      FROM listings l, json_array_elements_text(CASE WHEN json_typeof(l.photos) = 'array' THEN l.photos ELSE '[]'::json END) AS u
    UNION ALL SELECT substring(l.video FROM '/media/([0-9a-f-]{36})'), 'listings', l.id FROM listings l
    UNION ALL SELECT substring(p.image_url FROM '/media/([0-9a-f-]{36})'), 'supplier_photos', p.id FROM supplier_photos p
    UNION ALL SELECT substring(u FROM '/media/([0-9a-f-]{36})'), 'supplier_profiles', s.user_id
      FROM supplier_profiles s, json_array_elements_text(CASE WHEN json_typeof(s.evidence_photos) = 'array' THEN s.evidence_photos ELSE '[]'::json END) AS u
    UNION ALL SELECT substring(u FROM '/media/([0-9a-f-]{36})'), 'supplier_batches', b.id
      FROM supplier_batches b, json_array_elements_text(CASE WHEN json_typeof(b.photos) = 'array' THEN b.photos ELSE '[]'::json END) AS u
    UNION ALL SELECT substring(u FROM '/media/([0-9a-f-]{36})'), 'batch_verifications', v.id
      FROM batch_verifications v, json_array_elements_text(CASE WHEN json_typeof(v.photos) = 'array' THEN v.photos ELSE '[]'::json END) AS u
    UNION ALL SELECT substring(r.reference_photo FROM '/media/([0-9a-f-]{36})'), 'buyer_requirements', r.id FROM buyer_requirements r
    UNION ALL SELECT substring(u FROM '/media/([0-9a-f-]{36})'), 'orders', o.id
      FROM orders o, json_array_elements_text(CASE WHEN json_typeof(o.collection_photos) = 'array' THEN o.collection_photos ELSE '[]'::json END) AS u
) AS refs
JOIN media_assets a ON a.id = refs.media_id
ON CONFLICT DO NOTHING;
COMMIT;
