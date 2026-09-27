-- Suppliers confirm, from the app or the website, that a payout Omoterra
-- recorded as paid actually reached them (or report that it did not). Every
-- answer is kept in payout_confirmations, which is append-only; the settlement
-- carries the latest answer for quick filtering.
BEGIN;
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS supplier_confirmation VARCHAR(16);
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS supplier_confirmed_at TIMESTAMP WITH TIME ZONE;
CREATE TABLE IF NOT EXISTS payout_confirmations (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    settlement_id VARCHAR(36) NOT NULL REFERENCES settlements(id),
    supplier_id VARCHAR(36) NOT NULL REFERENCES users(id),
    outcome VARCHAR(16) NOT NULL CONSTRAINT valid_payout_confirmation CHECK (outcome IN ('received', 'not_received')),
    note TEXT NOT NULL DEFAULT '',
    amount NUMERIC(14, 2) NOT NULL,
    payment_reference VARCHAR
);
CREATE INDEX IF NOT EXISTS ix_payout_confirmations_settlement_id ON payout_confirmations (settlement_id);
CREATE INDEX IF NOT EXISTS ix_payout_confirmations_supplier_id ON payout_confirmations (supplier_id);
DROP TRIGGER IF EXISTS immutable_history ON payout_confirmations;
CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON payout_confirmations FOR EACH ROW EXECUTE FUNCTION omoterra_reject_history_edit();
COMMIT;
