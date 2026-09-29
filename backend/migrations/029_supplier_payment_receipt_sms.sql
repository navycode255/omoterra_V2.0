ALTER TABLE supplier_payments
    ADD COLUMN receipt_sms_status VARCHAR(16) NOT NULL DEFAULT 'skipped',
    ADD COLUMN receipt_sms_language VARCHAR(2) NOT NULL DEFAULT 'en',
    ADD COLUMN receipt_sms_phone VARCHAR(20) NOT NULL DEFAULT '',
    ADD COLUMN receipt_sms_message TEXT NOT NULL DEFAULT '',
    ADD COLUMN receipt_sms_error TEXT NOT NULL DEFAULT '',
    ADD COLUMN receipt_sms_attempts INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN receipt_sms_sent_at TIMESTAMPTZ,
    ADD CONSTRAINT supplier_payment_receipt_sms_status_check
        CHECK (receipt_sms_status IN ('queued','sent','failed','skipped')),
    ADD CONSTRAINT supplier_payment_receipt_sms_language_check
        CHECK (receipt_sms_language IN ('en','sw'));

CREATE INDEX ix_supplier_payments_receipt_sms_queued
    ON supplier_payments(receipt_sms_status)
    WHERE receipt_sms_status = 'queued';
