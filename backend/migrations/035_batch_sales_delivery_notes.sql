-- Build plan M1.6 (audit F09): batch sales become delivery notes.
--
-- A direct sale line from a supplier's batch no longer opens a sale-cost
-- payable. Staff confirm the goods were physically collected, the server
-- records a same-day delivery note (origin 'sale') whose batch_receipt debt is
-- the only supplier liability, and the line consumes that note.
--
-- collection_movements records the physical events on a delivery note after
-- it was received (rule R2). It is shaped to move into M2.1's lot_movements:
--   never_left             sale cancelled or reduced, goods never left (history only)
--   buyer_return_accepted  buyer returned them and they were accepted back (history only)
--   not_recovered          sale cancelled or reduced, goods not recovered: out of stock, a loss pending investigation
--   returned_to_supplier   goods went back to the supplier: out of stock; payable unchanged until a credit note
--   receipt_correction     the supplier never delivered them: the note's quantities and payable were reduced
-- On hand = accepted - active sales - not_recovered - returned_to_supplier.
--
-- supplier_credit_notes are the supplier's agreed credit for a return. Only a
-- credit note reduces the payable of a delivery note after a return.
BEGIN;

ALTER TABLE supplier_collections ADD COLUMN IF NOT EXISTS origin VARCHAR(16) NOT NULL DEFAULT 'delivery';
ALTER TABLE supplier_collections DROP CONSTRAINT IF EXISTS supplier_collections_origin_check;
ALTER TABLE supplier_collections ADD CONSTRAINT supplier_collections_origin_check
    CHECK (origin IN ('delivery','sale','historical'));
-- Who confirmed the goods were physically received: an operator (dashboard)
-- or a name (historical link command), and when.
ALTER TABLE supplier_collections ADD COLUMN IF NOT EXISTS confirmed_by VARCHAR(36) REFERENCES operators(id);
ALTER TABLE supplier_collections ADD COLUMN IF NOT EXISTS confirmed_by_name TEXT NOT NULL DEFAULT '';
ALTER TABLE supplier_collections ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ;
-- The sale the goods were collected for, when collected and sold together.
ALTER TABLE supplier_collections ADD COLUMN IF NOT EXISTS sale_id VARCHAR(36) REFERENCES sales(id);
CREATE INDEX IF NOT EXISTS ix_supplier_collections_sale_id ON supplier_collections(sale_id);

CREATE TABLE IF NOT EXISTS collection_movements (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    collection_id VARCHAR(36) NOT NULL REFERENCES supplier_collections(id),
    kind VARCHAR(24) NOT NULL,
    quantity NUMERIC(14,3) NOT NULL,
    occurred_on DATE NOT NULL,
    -- The note's cost per unit at the time: what a loss or return is worth.
    unit_cost NUMERIC(14,2) NOT NULL,
    sale_id VARCHAR(36) REFERENCES sales(id),
    reason TEXT NOT NULL DEFAULT '',
    evidence TEXT NOT NULL DEFAULT '',
    -- The goods' condition (a buyer return) or any other remark.
    note TEXT NOT NULL DEFAULT '',
    recorded_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT collection_movements_kind_check CHECK (kind IN
        ('never_left','buyer_return_accepted','not_recovered','returned_to_supplier','receipt_correction')),
    CONSTRAINT collection_movements_quantity_check CHECK (quantity > 0),
    CONSTRAINT collection_movements_unit_cost_check CHECK (unit_cost >= 0),
    CONSTRAINT collection_movement_has_reason CHECK (
        (kind NOT IN ('returned_to_supplier','receipt_correction') OR length(btrim(reason)) >= 3)
        AND (kind <> 'receipt_correction' OR length(btrim(evidence)) >= 3)
        AND (kind <> 'buyer_return_accepted' OR length(btrim(note)) >= 3))
);
CREATE INDEX IF NOT EXISTS ix_collection_movements_collection_id ON collection_movements(collection_id);
CREATE INDEX IF NOT EXISTS ix_collection_movements_sale_id ON collection_movements(sale_id);
CREATE INDEX IF NOT EXISTS ix_collection_movements_occurred_on ON collection_movements(occurred_on);

CREATE TABLE IF NOT EXISTS supplier_credit_notes (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    supplier_id VARCHAR(36) NOT NULL REFERENCES users(id),
    collection_id VARCHAR(36) NOT NULL REFERENCES supplier_collections(id),
    -- The return it credits: one agreed credit note per return.
    movement_id VARCHAR(36) NOT NULL UNIQUE REFERENCES collection_movements(id),
    debt_id VARCHAR(36) NOT NULL REFERENCES ledger_debts(id),
    amount NUMERIC(14,2) NOT NULL,
    issued_on DATE NOT NULL,
    reference TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    recorded_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT supplier_credit_notes_amount_check CHECK (amount > 0),
    CONSTRAINT supplier_credit_notes_reference_check CHECK (length(btrim(reference)) >= 1)
);
CREATE INDEX IF NOT EXISTS ix_supplier_credit_notes_supplier_id ON supplier_credit_notes(supplier_id);
CREATE INDEX IF NOT EXISTS ix_supplier_credit_notes_collection_id ON supplier_credit_notes(collection_id);
CREATE INDEX IF NOT EXISTS ix_supplier_credit_notes_debt_id ON supplier_credit_notes(debt_id);

-- What staff said happened to received goods when the sale was cancelled.
ALTER TABLE sales ADD COLUMN IF NOT EXISTS cancel_goods VARCHAR(24);
ALTER TABLE sales DROP CONSTRAINT IF EXISTS sales_cancel_goods_check;
ALTER TABLE sales ADD CONSTRAINT sales_cancel_goods_check
    CHECK (cancel_goods IS NULL OR cancel_goods IN ('never_left','buyer_return_accepted','not_recovered'));

ALTER TABLE financial_adjustments DROP CONSTRAINT IF EXISTS financial_adjustments_kind_check;
ALTER TABLE financial_adjustments ADD CONSTRAINT financial_adjustments_kind_check
    CHECK (kind IN ('wrong_supplier','duplicate_liability','free_stock','cost_never_existed',
                    'receipt_correction','supplier_credit_note','historical_batch_link'));

COMMIT;
