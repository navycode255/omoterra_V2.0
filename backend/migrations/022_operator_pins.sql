-- Staff sign in to the dashboard with the staff passphrase + phone + PIN; a
-- code is texted only to set or reset the PIN (app/auth.py).
BEGIN;
ALTER TABLE operators ADD COLUMN IF NOT EXISTS pin_hash VARCHAR(200);
ALTER TABLE operators ADD COLUMN IF NOT EXISTS pin_failed_attempts INTEGER NOT NULL DEFAULT 0;
ALTER TABLE operators ADD COLUMN IF NOT EXISTS pin_locked_until TIMESTAMP WITH TIME ZONE;
COMMIT;
