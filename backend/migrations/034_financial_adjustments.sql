-- Build plan M1.4 (audit F06): correcting a supplier debt without erasing cost.
--
-- A supplier debt opened by a sale is no longer simply "reconciled" away.
-- Staff choose why it is wrong (wrong supplier, duplicate liability, free or
-- gift stock, cost never existed) and every correction writes one row here:
-- who, why, what kind, the record corrected, its state before and after
-- (JSON) and the records it links (the corrected supplier's debt, the debt
-- it duplicates, the sale lines it changed). Rows are never edited.
--
-- Free or gift stock is a known zero cost: sale lines may now carry
-- unit_cost 0 (still never negative). Only that correction sets it; the sale
-- form keeps requiring a positive cost. M1.3 adds sale_items.cost_state and
-- marks the lines listed in 'free_stock' adjustments as 'free'.
BEGIN;

CREATE TABLE IF NOT EXISTS financial_adjustments (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    kind VARCHAR(32) NOT NULL,
    entity_type VARCHAR(32) NOT NULL,
    entity_id VARCHAR(36) NOT NULL,
    sale_id VARCHAR(36) REFERENCES sales(id),
    -- The other debt involved: the corrected supplier's debt (wrong
    -- supplier) or the debt this one duplicates (duplicate liability).
    related_debt_id VARCHAR(36) REFERENCES ledger_debts(id),
    reason TEXT NOT NULL,
    before JSON NOT NULL,
    after JSON NOT NULL,
    linked_ids JSON NOT NULL,
    recorded_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT financial_adjustments_kind_check
        CHECK (kind IN ('wrong_supplier','duplicate_liability','free_stock','cost_never_existed')),
    CONSTRAINT financial_adjustments_reason_check CHECK (length(btrim(reason)) >= 3)
);
CREATE INDEX IF NOT EXISTS ix_financial_adjustments_entity_id ON financial_adjustments(entity_id);
CREATE INDEX IF NOT EXISTS ix_financial_adjustments_sale_id ON financial_adjustments(sale_id);
CREATE INDEX IF NOT EXISTS ix_financial_adjustments_related_debt_id ON financial_adjustments(related_debt_id);

ALTER TABLE sale_items DROP CONSTRAINT IF EXISTS sale_items_unit_cost_check;
ALTER TABLE sale_items ADD CONSTRAINT sale_items_unit_cost_check CHECK (unit_cost >= 0);

COMMIT;
