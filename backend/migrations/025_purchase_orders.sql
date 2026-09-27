-- Local purchase orders (LPOs) to suppliers, the batches received against
-- them, and the stock they bring in.
--
-- Staff draft an LPO, usually from the most urgent buyer demand; only an
-- admin issues it, which freezes its content and puts the admin's signature
-- and the company stamp on it. Each batch received records what was
-- delivered, accepted and rejected; the accepted value becomes a payable to
-- the supplier in the ledger (source 'lpo'), due by the LPO's payment terms.
-- Birds received this way are stock: sales take from it (sale_items.
-- lpo_line_id, costed at the LPO price, no second payable) and losses are
-- recorded against it, so received = sold + lost + on hand.
BEGIN;
-- The company stamp and each admin's signature. Images live in media
-- storage; a newer one retires the older, and issued LPOs keep pointing at
-- the marks they were issued with.
CREATE TABLE IF NOT EXISTS document_marks (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    kind VARCHAR(16) NOT NULL CHECK (kind IN ('stamp', 'signature')),
    operator_id VARCHAR(36) REFERENCES operators(id),
    media_id VARCHAR(36) NOT NULL REFERENCES media_assets(id),
    uploaded_by VARCHAR(36) NOT NULL REFERENCES operators(id),
    retired_at TIMESTAMPTZ,
    CONSTRAINT mark_owner CHECK ((kind = 'signature') = (operator_id IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_document_marks_live ON document_marks(kind, COALESCE(operator_id, ''))
    WHERE retired_at IS NULL;

CREATE TABLE IF NOT EXISTS lpos (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    lpo_number VARCHAR(32) NOT NULL UNIQUE,
    supplier_id VARCHAR(36) NOT NULL REFERENCES users(id),
    -- Supplier details as printed; refreshed while a draft, frozen at issue.
    supplier_snapshot JSON NOT NULL,
    demand_id VARCHAR(36) REFERENCES buyer_requirements(id),
    lpo_date DATE NOT NULL,
    delivery_start DATE NOT NULL,
    delivery_end DATE NOT NULL,
    payment_terms_days INTEGER NOT NULL CHECK (payment_terms_days BETWEEN 0 AND 180),
    supply_basis VARCHAR(16) NOT NULL CHECK (supply_basis IN ('call_off', 'fixed')),
    collection_point TEXT NOT NULL DEFAULT '',
    delivery_notes JSON NOT NULL DEFAULT '[]',
    terms JSON NOT NULL DEFAULT '[]',
    internal_notes TEXT NOT NULL DEFAULT '',
    status VARCHAR(16) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'issued', 'accepted', 'closed', 'cancelled')),
    created_by VARCHAR(36) REFERENCES operators(id),
    issued_at TIMESTAMPTZ,
    issued_by VARCHAR(36) REFERENCES operators(id),
    issuer_name TEXT NOT NULL DEFAULT '',
    issuer_position TEXT NOT NULL DEFAULT '',
    stamp_mark_id VARCHAR(36) REFERENCES document_marks(id),
    signature_mark_id VARCHAR(36) REFERENCES document_marks(id),
    supplier_accepted_at DATE,
    supplier_accepted_name TEXT NOT NULL DEFAULT '',
    supplier_accepted_position TEXT NOT NULL DEFAULT '',
    signed_copy_media_id VARCHAR(36) REFERENCES media_assets(id),
    closed_at TIMESTAMPTZ,
    closed_by VARCHAR(36) REFERENCES operators(id),
    close_reason TEXT NOT NULL DEFAULT '',
    CONSTRAINT lpo_window CHECK (delivery_end >= delivery_start),
    CONSTRAINT lpo_issued_marked CHECK (status IN ('draft', 'cancelled')
        OR (issued_at IS NOT NULL AND stamp_mark_id IS NOT NULL AND signature_mark_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS ix_lpos_supplier ON lpos(supplier_id);
CREATE INDEX IF NOT EXISTS ix_lpos_demand ON lpos(demand_id);
CREATE INDEX IF NOT EXISTS ix_lpos_status ON lpos(status);

CREATE TABLE IF NOT EXISTS lpo_lines (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    lpo_id VARCHAR(36) NOT NULL REFERENCES lpos(id),
    position INTEGER NOT NULL,
    category VARCHAR(32) NOT NULL DEFAULT '',
    item TEXT NOT NULL,
    specification TEXT NOT NULL DEFAULT '',
    unit VARCHAR(16) NOT NULL,
    unit_price NUMERIC(14, 2) NOT NULL CHECK (unit_price > 0),
    -- NULL: "as requested per batch" (call-off, no fixed quantity).
    quantity NUMERIC(14, 3) CHECK (quantity > 0),
    min_weight_kg NUMERIC(8, 3),
    max_weight_kg NUMERIC(8, 3),
    CONSTRAINT lpo_line_weights CHECK (min_weight_kg IS NULL OR max_weight_kg IS NULL OR max_weight_kg >= min_weight_kg)
);
CREATE INDEX IF NOT EXISTS ix_lpo_lines_lpo ON lpo_lines(lpo_id);

CREATE TABLE IF NOT EXISTS lpo_receipts (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    lpo_id VARCHAR(36) NOT NULL REFERENCES lpos(id),
    received_on DATE NOT NULL,
    notes TEXT NOT NULL DEFAULT '',
    amount NUMERIC(14, 2) NOT NULL CHECK (amount >= 0),
    debt_id VARCHAR(36) REFERENCES ledger_debts(id),
    recorded_by VARCHAR(36) REFERENCES operators(id),
    cancelled_at TIMESTAMPTZ,
    cancelled_by VARCHAR(36) REFERENCES operators(id),
    cancel_reason TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS ix_lpo_receipts_lpo ON lpo_receipts(lpo_id);

CREATE TABLE IF NOT EXISTS lpo_receipt_lines (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    receipt_id VARCHAR(36) NOT NULL REFERENCES lpo_receipts(id),
    lpo_line_id VARCHAR(36) NOT NULL REFERENCES lpo_lines(id),
    delivered_quantity NUMERIC(14, 3) NOT NULL CHECK (delivered_quantity >= 0),
    accepted_quantity NUMERIC(14, 3) NOT NULL CHECK (accepted_quantity >= 0),
    rejected_quantity NUMERIC(14, 3) NOT NULL CHECK (rejected_quantity >= 0),
    average_weight_kg NUMERIC(8, 3),
    unit_price NUMERIC(14, 2) NOT NULL,
    amount NUMERIC(14, 2) NOT NULL,
    CONSTRAINT receipt_counts_add_up CHECK (accepted_quantity + rejected_quantity = delivered_quantity)
);
CREATE INDEX IF NOT EXISTS ix_lpo_receipt_lines_receipt ON lpo_receipt_lines(receipt_id);
CREATE INDEX IF NOT EXISTS ix_lpo_receipt_lines_line ON lpo_receipt_lines(lpo_line_id);

-- Received stock that died, was stolen or was spoiled before it was sold.
CREATE TABLE IF NOT EXISTS stock_losses (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    lpo_line_id VARCHAR(36) NOT NULL REFERENCES lpo_lines(id),
    lost_on DATE NOT NULL,
    quantity NUMERIC(14, 3) NOT NULL CHECK (quantity > 0),
    reason VARCHAR(16) NOT NULL CHECK (reason IN ('died', 'sick', 'stolen', 'spoiled', 'other')),
    note TEXT NOT NULL DEFAULT '',
    unit_cost NUMERIC(14, 2) NOT NULL,
    recorded_by VARCHAR(36) REFERENCES operators(id),
    cancelled_at TIMESTAMPTZ,
    cancelled_by VARCHAR(36) REFERENCES operators(id)
);
CREATE INDEX IF NOT EXISTS ix_stock_losses_line ON stock_losses(lpo_line_id);

-- A sale line can take LPO stock: costed at the LPO price, owed through the
-- LPO receipt's payable, never a second one.
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS lpo_line_id VARCHAR(36) REFERENCES lpo_lines(id);
CREATE INDEX IF NOT EXISTS ix_sale_items_lpo_line ON sale_items(lpo_line_id);

-- LPO receipts open supplier payables.
ALTER TABLE ledger_debts ADD COLUMN IF NOT EXISTS lpo_id VARCHAR(36) REFERENCES lpos(id);
ALTER TABLE ledger_debts DROP CONSTRAINT IF EXISTS ledger_debts_source_check;
ALTER TABLE ledger_debts ADD CONSTRAINT ledger_debts_source_check
    CHECK (source IN ('sale', 'sale_cost', 'manual', 'expense', 'lpo'));
ALTER TABLE ledger_debts DROP CONSTRAINT IF EXISTS ledger_sale_source;
ALTER TABLE ledger_debts ADD CONSTRAINT ledger_sale_source
    CHECK (source = 'expense' OR (source IN ('sale', 'sale_cost')) = (sale_id IS NOT NULL));
ALTER TABLE ledger_debts DROP CONSTRAINT IF EXISTS ledger_lpo_source;
ALTER TABLE ledger_debts ADD CONSTRAINT ledger_lpo_source CHECK ((source = 'lpo') = (lpo_id IS NOT NULL));
CREATE INDEX IF NOT EXISTS ix_ledger_debts_lpo ON ledger_debts(lpo_id);
COMMIT;
