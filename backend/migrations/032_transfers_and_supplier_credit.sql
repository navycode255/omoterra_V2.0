-- Build plan M1.2 (audit F04): money moved versus money allocated.
--
-- supplier_payments is now the transfer: the only record that money left an
-- account to a supplier. ledger_payments with supplier_payment_id are its
-- allocations to invoices. transfer_events records what happens to money
-- taken off an invoice: unapplied supplier credit, credit re-allocated to
-- another invoice of the same supplier, a refund (a separate dated inflow)
-- or an entry-error correction (no money moved).
--
-- Nothing existing is reclassified here (rule R6). A reversed allocation of
-- an existing transfer has no event yet, so it reads as *unresolved* until
-- the finance owner classifies it with `python -m app.classify_transfers`.
-- Single payments on supplier invoices recorded before this migration keep
-- no transfer until that command wraps them.
BEGIN;

-- Where a transfer came from: "Pay supplier" (proof required), a single
-- invoice payment (Record payment, cost paid with a sale), or a legacy
-- payment wrapped by the classification command.
ALTER TABLE supplier_payments ADD COLUMN IF NOT EXISTS origin VARCHAR(16) NOT NULL DEFAULT 'pay_supplier';
ALTER TABLE supplier_payments DROP CONSTRAINT IF EXISTS supplier_payments_origin_check;
ALTER TABLE supplier_payments ADD CONSTRAINT supplier_payments_origin_check
    CHECK (origin IN ('pay_supplier','single','legacy'));
ALTER TABLE supplier_payments DROP CONSTRAINT IF EXISTS supplier_payment_has_evidence;
ALTER TABLE supplier_payments ADD CONSTRAINT supplier_payment_has_evidence
    CHECK (origin <> 'pay_supplier' OR reference <> '' OR sms_text <> '' OR receipt_media_id IS NOT NULL);

CREATE TABLE IF NOT EXISTS transfer_events (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    supplier_payment_id VARCHAR(36) NOT NULL REFERENCES supplier_payments(id),
    -- The supplier who received the transfer (rule R1), never the invoice's.
    supplier_id VARCHAR(36) NOT NULL REFERENCES users(id),
    kind VARCHAR(16) NOT NULL,
    amount NUMERIC(14,2) NOT NULL,
    -- The reversed allocation this event classifies (credit, or a refund or
    -- entry error decided straight from an unresolved allocation).
    source_payment_id VARCHAR(36) REFERENCES ledger_payments(id),
    -- The new allocation a re-allocation created.
    allocation_id VARCHAR(36) REFERENCES ledger_payments(id),
    -- Credit: the day it arose. Re-allocation: the day applied. Refund: the
    -- day the money was actually received back. Entry error: the day found.
    occurred_on DATE NOT NULL,
    method VARCHAR(24),
    reference TEXT NOT NULL DEFAULT '',
    evidence TEXT NOT NULL DEFAULT '',
    receipt_media_id VARCHAR(36) REFERENCES media_assets(id),
    reason TEXT NOT NULL DEFAULT '',
    recorded_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT transfer_events_kind_check CHECK (kind IN ('credit','reallocation','refund','entry_error')),
    CONSTRAINT transfer_events_amount_check CHECK (amount > 0),
    CONSTRAINT transfer_events_method_check
        CHECK (method IS NULL OR method IN ('cash','mpesa','airtel_money','mixx_by_yas','halopesa','bank_transfer','cheque','other')),
    CONSTRAINT transfer_event_shape CHECK (
        ((kind = 'reallocation') = (allocation_id IS NOT NULL))
        AND (kind <> 'reallocation' OR source_payment_id IS NULL)
        AND (kind <> 'credit' OR source_payment_id IS NOT NULL)
        AND (kind <> 'refund' OR (method IS NOT NULL AND (reference <> '' OR evidence <> '' OR receipt_media_id IS NOT NULL)))
        AND (kind <> 'entry_error' OR (reason <> '' AND (reference <> '' OR evidence <> '' OR receipt_media_id IS NOT NULL)))
    )
);

CREATE INDEX IF NOT EXISTS ix_transfer_events_supplier_payment_id ON transfer_events(supplier_payment_id);
CREATE INDEX IF NOT EXISTS ix_transfer_events_supplier_id ON transfer_events(supplier_id);
CREATE INDEX IF NOT EXISTS ix_transfer_events_source_payment_id ON transfer_events(source_payment_id);
CREATE INDEX IF NOT EXISTS ix_transfer_events_occurred_on ON transfer_events(occurred_on);

COMMIT;
