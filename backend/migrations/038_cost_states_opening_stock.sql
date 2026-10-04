-- Build plan M1.3 (audit F02): known, free and unknown buying costs, and
-- opening stock (decision D3).
--
-- 1. sale_items.cost_state says what is known about a line's buying cost:
--    'known' (a positive cost), 'free' (a known zero an admin approved with a
--    reason) or 'unknown' (no cost). Unknown is never zero (rule R5): it
--    counts for nothing in cost of goods and makes every period and margin
--    containing it "Provisional: buying costs incomplete".
--
--    Backfill (changes no cost, supplier or debt; only labels lines):
--    - unit_cost > 0                                  -> known
--    - unit_cost = 0 with a 'free_stock' correction (M1.4) on the same sale
--      for that line or its supplier                  -> free (the admin's
--      recorded approval and reason; backfill never infers free)
--    - unit_cost = 0 without one                      -> unknown
--    - unit_cost NULL (own stock, or 'cost never existed') -> unknown
--    Before 034 a cost had to be > 0, and since 034 only the free-stock
--    correction (or an edit keeping it) sets 0, so the middle case is a
--    safeguard rather than an expected row.
--
-- 2. opening_stock: stock Omoterra held before the system, with the value
--    the finance owner gives it and the evidence for it. It opens NO payable
--    (it was paid for before records began). Sale lines sell from it
--    (sale_items.opening_stock_id) at its cost, so their margin is known.
--    opening_stock_movements records what happened to opening stock a
--    cancelled or edited sale no longer sells (rule R2).
--
-- 3. Own stock may now carry a cost without a supplier (an evidenced cost,
--    or opening stock); a supplier still always needs a cost.
-- 4. financial_adjustments gains 'cost_resolved' (an unknown line given a
--    cost later, with before/after) and 'opening_stock_cancelled'.
BEGIN;

CREATE TABLE IF NOT EXISTS opening_stock (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    receipt_number VARCHAR(32) NOT NULL UNIQUE,
    category VARCHAR(32) NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    unit VARCHAR(16) NOT NULL,
    quantity NUMERIC(14,3) NOT NULL,
    unit_cost NUMERIC(14,2) NOT NULL,
    amount NUMERIC(14,2) NOT NULL,
    as_of DATE NOT NULL,
    evidence TEXT NOT NULL,
    valued_by TEXT NOT NULL,
    recorded_by VARCHAR(36) REFERENCES operators(id),
    cancelled_at TIMESTAMPTZ,
    cancelled_by VARCHAR(36) REFERENCES operators(id),
    cancel_reason TEXT NOT NULL DEFAULT '',
    CONSTRAINT opening_stock_quantity_check CHECK (quantity > 0),
    CONSTRAINT opening_stock_value_check CHECK (unit_cost > 0 AND amount > 0),
    CONSTRAINT opening_stock_unit_check CHECK (unit IN ('bird','animal','kg','tray','piece')),
    CONSTRAINT opening_stock_evidence_check CHECK (length(btrim(evidence)) >= 3 AND length(btrim(valued_by)) >= 2),
    CONSTRAINT opening_stock_cancel_check CHECK (cancelled_at IS NULL OR length(btrim(cancel_reason)) >= 3)
);
CREATE INDEX IF NOT EXISTS ix_opening_stock_receipt_number ON opening_stock(receipt_number);
CREATE INDEX IF NOT EXISTS ix_opening_stock_as_of ON opening_stock(as_of);

CREATE TABLE IF NOT EXISTS opening_stock_movements (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    opening_stock_id VARCHAR(36) NOT NULL REFERENCES opening_stock(id),
    kind VARCHAR(24) NOT NULL,
    quantity NUMERIC(14,3) NOT NULL,
    occurred_on DATE NOT NULL,
    unit_cost NUMERIC(14,2) NOT NULL,
    sale_id VARCHAR(36) REFERENCES sales(id),
    reason TEXT NOT NULL DEFAULT '',
    note TEXT NOT NULL DEFAULT '',
    recorded_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT opening_stock_movements_kind_check CHECK (kind IN ('never_left','buyer_return_accepted','not_recovered')),
    CONSTRAINT opening_stock_movements_values_check CHECK (quantity > 0 AND unit_cost >= 0)
);
CREATE INDEX IF NOT EXISTS ix_opening_stock_movements_opening_stock_id ON opening_stock_movements(opening_stock_id);
CREATE INDEX IF NOT EXISTS ix_opening_stock_movements_occurred_on ON opening_stock_movements(occurred_on);
CREATE INDEX IF NOT EXISTS ix_opening_stock_movements_sale_id ON opening_stock_movements(sale_id);

ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS opening_stock_id VARCHAR(36) REFERENCES opening_stock(id);
CREATE INDEX IF NOT EXISTS ix_sale_items_opening_stock_id ON sale_items(opening_stock_id);

ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS cost_state VARCHAR(16);
UPDATE sale_items si SET cost_state = CASE
    WHEN si.unit_cost > 0 THEN 'known'
    WHEN si.unit_cost = 0 AND EXISTS (
        SELECT 1 FROM financial_adjustments fa
        WHERE fa.kind = 'free_stock' AND fa.sale_id = si.sale_id AND (
            (fa.linked_ids::jsonb -> 'item_ids') @> jsonb_build_array(si.id)
            -- A sale edit re-creates its lines with new ids; the correction
            -- still names the supplier whose lines it made free.
            OR (si.supplier_id IS NOT NULL AND fa.before::jsonb -> 'debt' ->> 'supplier_id' = si.supplier_id)
            OR (si.supplier_id IS NULL AND si.supplier_name <> ''
                AND lower(fa.before::jsonb -> 'debt' ->> 'party_name') = lower(si.supplier_name))))
        THEN 'free'
    ELSE 'unknown'
END
WHERE si.cost_state IS NULL;
ALTER TABLE sale_items ALTER COLUMN cost_state SET DEFAULT 'known';
ALTER TABLE sale_items ALTER COLUMN cost_state SET NOT NULL;

ALTER TABLE sale_items DROP CONSTRAINT IF EXISTS sale_item_cost_has_supplier;
ALTER TABLE sale_items ADD CONSTRAINT sale_item_cost_has_supplier
    CHECK (unit_cost IS NOT NULL OR (supplier_id IS NULL AND supplier_name = ''));
ALTER TABLE sale_items DROP CONSTRAINT IF EXISTS sale_items_cost_state_check;
ALTER TABLE sale_items ADD CONSTRAINT sale_items_cost_state_check
    CHECK ((cost_state = 'known' AND coalesce(unit_cost, 0) > 0)
        OR (cost_state = 'free' AND coalesce(unit_cost, -1) = 0)
        OR (cost_state = 'unknown' AND coalesce(unit_cost, 0) = 0));

ALTER TABLE financial_adjustments DROP CONSTRAINT IF EXISTS financial_adjustments_kind_check;
ALTER TABLE financial_adjustments ADD CONSTRAINT financial_adjustments_kind_check
    CHECK (kind IN ('wrong_supplier','duplicate_liability','free_stock','cost_never_existed',
                    'receipt_correction','supplier_credit_note','historical_batch_link',
                    'cost_resolved','opening_stock_cancelled'));

COMMIT;
