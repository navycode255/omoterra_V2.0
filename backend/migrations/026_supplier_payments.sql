CREATE TABLE supplier_payments (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    supplier_id VARCHAR(36) NOT NULL REFERENCES users(id),
    amount NUMERIC(14,2) NOT NULL CHECK (amount > 0),
    paid_on DATE NOT NULL,
    method VARCHAR(24) NOT NULL CHECK (method IN ('cash','mpesa','airtel_money','mixx_by_yas','halopesa','bank_transfer','cheque','other')),
    reference TEXT NOT NULL DEFAULT '',
    sms_text TEXT NOT NULL DEFAULT '',
    receipt_media_id VARCHAR(36) REFERENCES media_assets(id),
    note TEXT NOT NULL DEFAULT '',
    recorded_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT supplier_payment_has_evidence CHECK (reference <> '' OR sms_text <> '' OR receipt_media_id IS NOT NULL)
);

CREATE INDEX ix_supplier_payments_supplier_id ON supplier_payments(supplier_id);
CREATE INDEX ix_supplier_payments_paid_on ON supplier_payments(paid_on);

ALTER TABLE ledger_payments ADD COLUMN supplier_payment_id VARCHAR(36) REFERENCES supplier_payments(id);
CREATE INDEX ix_ledger_payments_supplier_payment_id ON ledger_payments(supplier_payment_id);
