-- Members sign in to the website with phone + PIN instead of an SMS code each
-- time; a code is texted only to set or reset the PIN (app/auth.py).
BEGIN;
ALTER TABLE users ADD COLUMN IF NOT EXISTS pin_hash VARCHAR(200);
ALTER TABLE users ADD COLUMN IF NOT EXISTS pin_failed_attempts INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS pin_locked_until TIMESTAMP WITH TIME ZONE;
COMMIT;
