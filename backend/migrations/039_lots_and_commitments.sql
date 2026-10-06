-- Build plan M2.1 (audit F09): one stock-movement model for received lots.
--
-- Movements of a lot (delivery note, LPO line, opening stock) are read from
-- the records that already hold each physical event (app/lots.py). This
-- adds the two events that had nowhere to live:
--
-- - count: staff counted a lot; quantity is counted minus what the records
--   expected that day (never 0). Admin only, with a reason and evidence.
-- - lost: opening stock that died or was lost (delivery notes and LPO lines
--   keep their own loss records).
--
-- commitment_fulfilments records which reservation (a buyer demand
-- allocation or an approved market reservation) a delivery note filled, so
-- receiving no longer takes min(reserved, accepted) from the batch
-- anonymously, and cancelling a reservation releases only what is still
-- outstanding.
--
-- Nothing existing is changed.
BEGIN;

CREATE TABLE IF NOT EXISTS lot_adjustments (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    lot_table VARCHAR(24) NOT NULL,
    lot_id VARCHAR(36) NOT NULL,
    kind VARCHAR(16) NOT NULL,
    occurred_on DATE NOT NULL,
    quantity NUMERIC(14,3) NOT NULL,
    counted_quantity NUMERIC(14,3),
    expected_quantity NUMERIC(14,3),
    unit_cost NUMERIC(14,2) NOT NULL,
    loss_reason VARCHAR(16),
    reason TEXT NOT NULL DEFAULT '',
    evidence TEXT NOT NULL DEFAULT '',
    recorded_by VARCHAR(36) REFERENCES operators(id),
    cancelled_at TIMESTAMPTZ,
    cancelled_by VARCHAR(36) REFERENCES operators(id),
    cancel_reason TEXT NOT NULL DEFAULT '',
    CONSTRAINT lot_adjustments_lot_table_check CHECK (lot_table IN ('supplier_collections','lpo_lines','opening_stock')),
    CONSTRAINT lot_adjustments_kind_check CHECK (kind IN ('count','lost')),
    CONSTRAINT lot_adjustments_count_check CHECK (kind <> 'count' OR (counted_quantity >= 0 AND expected_quantity IS NOT NULL
        AND quantity = counted_quantity - expected_quantity AND quantity <> 0
        AND length(btrim(reason)) >= 3 AND length(btrim(evidence)) >= 3)),
    CONSTRAINT lot_adjustments_lost_check CHECK (kind <> 'lost' OR (lot_table = 'opening_stock' AND quantity > 0 AND loss_reason IN
        ('died','sick','stolen','spoiled','other'))),
    CONSTRAINT lot_adjustments_unit_cost_check CHECK (unit_cost >= 0),
    CONSTRAINT lot_adjustments_cancel_check CHECK (cancelled_at IS NULL OR length(btrim(cancel_reason)) >= 3)
);
CREATE INDEX IF NOT EXISTS ix_lot_adjustments_lot_id ON lot_adjustments(lot_id);
CREATE INDEX IF NOT EXISTS ix_lot_adjustments_occurred_on ON lot_adjustments(occurred_on);

CREATE TABLE IF NOT EXISTS commitment_fulfilments (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    collection_id VARCHAR(36) NOT NULL REFERENCES supplier_collections(id),
    commitment_kind VARCHAR(24) NOT NULL,
    commitment_id VARCHAR(36) NOT NULL,
    quantity NUMERIC(14,3) NOT NULL,
    CONSTRAINT commitment_fulfilments_kind_check CHECK (commitment_kind IN ('demand_allocation','market_reservation')),
    CONSTRAINT commitment_fulfilments_quantity_check CHECK (quantity > 0)
);
CREATE INDEX IF NOT EXISTS ix_commitment_fulfilments_collection_id ON commitment_fulfilments(collection_id);
CREATE INDEX IF NOT EXISTS ix_commitment_fulfilments_commitment_id ON commitment_fulfilments(commitment_id);

COMMIT;
