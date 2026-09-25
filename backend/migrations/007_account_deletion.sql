-- Account deletion anonymizes the user row rather than removing it (orders,
-- settlements and audit trails reference it); these columns record that a
-- row is a tombstone rather than a live account.
BEGIN;
ALTER TABLE users
 ADD COLUMN IF NOT EXISTS deleted BOOLEAN NOT NULL DEFAULT false,
 ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
COMMIT;
