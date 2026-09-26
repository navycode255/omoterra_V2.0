-- How each supplier chose to be paid (M-Pesa, bank transfer, ...). Account
-- numbers are not stored here; they are collected when a payout is due.
BEGIN;
ALTER TABLE supplier_profiles ADD COLUMN IF NOT EXISTS payout_methods JSON NOT NULL DEFAULT '[]';
COMMIT;
