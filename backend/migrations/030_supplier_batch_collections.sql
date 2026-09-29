CREATE TABLE supplier_collections (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    collection_number VARCHAR(32) NOT NULL UNIQUE,
    supplier_id VARCHAR(36) NOT NULL REFERENCES users(id),
    batch_id VARCHAR(36) NOT NULL REFERENCES supplier_batches(id),
    received_on DATE NOT NULL,
    delivered_quantity NUMERIC(14,3) NOT NULL CHECK (delivered_quantity > 0),
    accepted_quantity NUMERIC(14,3) NOT NULL,
    rejected_quantity NUMERIC(14,3) NOT NULL,
    average_weight_kg NUMERIC(8,3),
    unit_cost NUMERIC(14,2) NOT NULL,
    amount NUMERIC(14,2) NOT NULL,
    notes TEXT NOT NULL DEFAULT '',
    debt_id VARCHAR(36) REFERENCES ledger_debts(id),
    recorded_by VARCHAR(36) REFERENCES operators(id),
    cancelled_at TIMESTAMPTZ,
    cancelled_by VARCHAR(36) REFERENCES operators(id),
    cancel_reason TEXT NOT NULL DEFAULT '',
    CONSTRAINT supplier_collections_quantities_nonnegative CHECK (accepted_quantity >= 0 AND rejected_quantity >= 0),
    CONSTRAINT supplier_collections_counts_add_up CHECK (accepted_quantity + rejected_quantity = delivered_quantity),
    CONSTRAINT supplier_collections_cost_valid CHECK (unit_cost > 0 AND amount >= 0)
);
CREATE INDEX ix_supplier_collections_supplier_id ON supplier_collections(supplier_id);
CREATE INDEX ix_supplier_collections_batch_id ON supplier_collections(batch_id);
CREATE INDEX ix_supplier_collections_received_on ON supplier_collections(received_on);
CREATE UNIQUE INDEX ix_supplier_collections_collection_number ON supplier_collections(collection_number);

ALTER TABLE sale_items ADD COLUMN supplier_collection_id VARCHAR(36) REFERENCES supplier_collections(id);
CREATE INDEX ix_sale_items_supplier_collection_id ON sale_items(supplier_collection_id);

ALTER TABLE ledger_debts DROP CONSTRAINT IF EXISTS ledger_debts_source_check;
ALTER TABLE ledger_debts ADD CONSTRAINT ledger_debts_source_check
    CHECK (source IN ('sale','sale_cost','manual','expense','lpo','batch_receipt'));
