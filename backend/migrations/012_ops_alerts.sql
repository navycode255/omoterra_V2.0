-- Dashboard alerts: when a supplier sent their registration for review, and
-- how far each operator has read their alerts.
BEGIN;
ALTER TABLE supplier_profiles ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ;
ALTER TABLE operators ADD COLUMN IF NOT EXISTS alerts_seen_at TIMESTAMPTZ;
COMMIT;
