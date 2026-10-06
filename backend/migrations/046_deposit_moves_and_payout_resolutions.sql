-- Finance-owner decisions of 7 October 2026 on top of M2.5 and M2.7.
--
-- Order deposits (staff buyer orders):
-- * part refunds: a deposit may be given back in several dated parts, so
--   buyer_order_payments.refund_of is no longer unique. A refund row sits on
--   the order the money was held on when it was given back.
-- * buyer_order_deposit_moves: part or all of a held deposit moved to another
--   open order of the same buyer. It moves no money (rule R4): no cash book
--   row and no account movement; the deposit keeps its one money-in record.
--   Append-only.
-- * buyer_order_deposit_applications: the part of a deposit that became a
--   payment on an order's sale when that order was delivered. A deposit can
--   now be applied in parts (some on its own order, some on the order it was
--   moved to). Backfilled from buyer_order_payments.applied_payment_id (the
--   whole deposit, applied on its own order), which stays as history.
--
-- Possibly paid twice, not returned (D9):
-- * settlement_resolutions: the excess on an app payout resolved with
--   evidence, requested by an admin and approved by a second admin
--   (approval_requests, used once): 'supplier_credit' (the supplier received
--   and keeps it; set off against their next payouts) or 'write_off' (lost:
--   an expense "Payout loss" on resolved_on; no money moves). Append-only.
-- * payout_credit_uses: supplier payout credit set off against a settlement.
--   Moves no money. Append-only; a use on a payout later cancelled with its
--   order's delivery gives the credit back (computed, never edited).
BEGIN;

ALTER TABLE buyer_order_payments DROP CONSTRAINT IF EXISTS buyer_order_payments_refund_of_key;
CREATE INDEX IF NOT EXISTS ix_buyer_order_payments_refund_of ON buyer_order_payments (refund_of);

CREATE TABLE IF NOT EXISTS buyer_order_deposit_moves (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deposit_id VARCHAR(36) NOT NULL REFERENCES buyer_order_payments(id),
    from_order_id VARCHAR(36) NOT NULL REFERENCES buyer_orders(id),
    to_order_id VARCHAR(36) NOT NULL REFERENCES buyer_orders(id),
    amount NUMERIC(14,2) NOT NULL,
    reason TEXT NOT NULL,
    moved_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT buyer_order_deposit_moves_amount_check CHECK (amount > 0),
    CONSTRAINT buyer_order_deposit_moves_orders_check CHECK (from_order_id <> to_order_id),
    CONSTRAINT buyer_order_deposit_moves_reason_check CHECK (length(btrim(reason)) >= 3)
);
CREATE INDEX IF NOT EXISTS ix_buyer_order_deposit_moves_deposit_id ON buyer_order_deposit_moves (deposit_id);
CREATE INDEX IF NOT EXISTS ix_buyer_order_deposit_moves_from_order_id ON buyer_order_deposit_moves (from_order_id);
CREATE INDEX IF NOT EXISTS ix_buyer_order_deposit_moves_to_order_id ON buyer_order_deposit_moves (to_order_id);
DROP TRIGGER IF EXISTS immutable_history ON buyer_order_deposit_moves;
CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON buyer_order_deposit_moves
    FOR EACH ROW EXECUTE FUNCTION omoterra_reject_history_edit();

CREATE TABLE IF NOT EXISTS buyer_order_deposit_applications (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deposit_id VARCHAR(36) NOT NULL REFERENCES buyer_order_payments(id),
    buyer_order_id VARCHAR(36) NOT NULL REFERENCES buyer_orders(id),
    ledger_payment_id VARCHAR(36) NOT NULL UNIQUE REFERENCES ledger_payments(id),
    amount NUMERIC(14,2) NOT NULL,
    CONSTRAINT buyer_order_deposit_applications_amount_check CHECK (amount > 0)
);
CREATE INDEX IF NOT EXISTS ix_buyer_order_deposit_applications_deposit_id ON buyer_order_deposit_applications (deposit_id);
CREATE INDEX IF NOT EXISTS ix_buyer_order_deposit_applications_buyer_order_id ON buyer_order_deposit_applications (buyer_order_id);

INSERT INTO buyer_order_deposit_applications (id, created_at, deposit_id, buyer_order_id, ledger_payment_id, amount)
SELECT md5('deposit-application:' || p.id)::uuid::text, p.created_at, p.id, p.buyer_order_id, p.applied_payment_id, p.amount
  FROM buyer_order_payments p
 WHERE p.applied_payment_id IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM buyer_order_deposit_applications a WHERE a.ledger_payment_id = p.applied_payment_id);

CREATE TABLE IF NOT EXISTS settlement_resolutions (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    settlement_id VARCHAR(36) NOT NULL REFERENCES settlements(id),
    supplier_id VARCHAR(36) NOT NULL REFERENCES users(id),
    kind VARCHAR(16) NOT NULL,
    amount NUMERIC(14,2) NOT NULL,
    resolved_on DATE NOT NULL,
    evidence TEXT NOT NULL,
    approval_id VARCHAR(36) NOT NULL UNIQUE REFERENCES approval_requests(id),
    recorded_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT settlement_resolutions_kind_check CHECK (kind IN ('supplier_credit','write_off')),
    CONSTRAINT settlement_resolutions_amount_check CHECK (amount > 0),
    CONSTRAINT settlement_resolutions_evidence_check CHECK (length(btrim(evidence)) >= 3)
);
CREATE INDEX IF NOT EXISTS ix_settlement_resolutions_settlement_id ON settlement_resolutions (settlement_id);
CREATE INDEX IF NOT EXISTS ix_settlement_resolutions_supplier_id ON settlement_resolutions (supplier_id);
CREATE INDEX IF NOT EXISTS ix_settlement_resolutions_resolved_on ON settlement_resolutions (resolved_on);
DROP TRIGGER IF EXISTS immutable_history ON settlement_resolutions;
CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON settlement_resolutions
    FOR EACH ROW EXECUTE FUNCTION omoterra_reject_history_edit();

CREATE TABLE IF NOT EXISTS payout_credit_uses (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    supplier_id VARCHAR(36) NOT NULL REFERENCES users(id),
    settlement_id VARCHAR(36) NOT NULL REFERENCES settlements(id),
    amount NUMERIC(14,2) NOT NULL,
    used_on DATE NOT NULL,
    recorded_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT payout_credit_uses_amount_check CHECK (amount > 0)
);
CREATE INDEX IF NOT EXISTS ix_payout_credit_uses_supplier_id ON payout_credit_uses (supplier_id);
CREATE INDEX IF NOT EXISTS ix_payout_credit_uses_settlement_id ON payout_credit_uses (settlement_id);
DROP TRIGGER IF EXISTS immutable_history ON payout_credit_uses;
CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON payout_credit_uses
    FOR EACH ROW EXECUTE FUNCTION omoterra_reject_history_edit();

COMMIT;
