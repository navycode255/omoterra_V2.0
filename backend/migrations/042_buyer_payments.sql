-- One payment received from a customer, spread over their open debts.
--
-- buyer_payments: the payment as it was received (amount, date, method,
--   reference). It is one row in the cash book however many debts it paid.
-- ledger_payments.buyer_payment_id: the allocations of that payment, one per
--   debt, oldest debt first. Each still moves its debt's balance as before.
--
-- Nothing existing is changed: payments recorded on one debt keep a null id.
BEGIN;

CREATE TABLE IF NOT EXISTS buyer_payments (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    buyer_profile_id VARCHAR(36) NOT NULL REFERENCES buyer_profiles(id),
    amount NUMERIC(14,2) NOT NULL,
    paid_on DATE NOT NULL,
    method VARCHAR(24) NOT NULL,
    reference TEXT NOT NULL DEFAULT '',
    note TEXT NOT NULL DEFAULT '',
    recorded_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT buyer_payments_amount_check CHECK (amount > 0),
    CONSTRAINT buyer_payments_method_check
        CHECK (method IN ('cash','mpesa','airtel_money','mixx_by_yas','halopesa','bank_transfer','cheque','other'))
);
CREATE INDEX IF NOT EXISTS ix_buyer_payments_buyer_profile_id ON buyer_payments(buyer_profile_id);
CREATE INDEX IF NOT EXISTS ix_buyer_payments_paid_on ON buyer_payments(paid_on);

ALTER TABLE ledger_payments ADD COLUMN IF NOT EXISTS buyer_payment_id VARCHAR(36) REFERENCES buyer_payments(id);
CREATE INDEX IF NOT EXISTS ix_ledger_payments_buyer_payment_id ON ledger_payments(buyer_payment_id);

COMMIT;
