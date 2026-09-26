-- Buyers pick a default delivery address; checkout starts on it.
BEGIN;
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS is_default BOOLEAN NOT NULL DEFAULT false;
-- Each buyer's oldest saved address becomes their default.
UPDATE addresses SET is_default = true
WHERE id IN (
    SELECT DISTINCT ON (user_id) id FROM addresses
    WHERE NOT deleted ORDER BY user_id, created_at
) AND NOT EXISTS (
    SELECT 1 FROM addresses other WHERE other.user_id = addresses.user_id AND other.is_default
);
COMMIT;
