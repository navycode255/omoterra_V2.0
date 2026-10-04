-- Stock received on a delivery note that died, was culled, stolen or spoiled
-- before it was sold. A 'lost' movement takes it out of stock on hand and its
-- cost (quantity x the note's unit cost) counts against profit. What Omoterra
-- owes the supplier does not change: the goods were received.
-- A loss recorded by mistake is cancelled (never deleted), with a reason.
BEGIN;

ALTER TABLE collection_movements ADD COLUMN IF NOT EXISTS loss_reason VARCHAR(16);
ALTER TABLE collection_movements ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;
ALTER TABLE collection_movements ADD COLUMN IF NOT EXISTS cancelled_by VARCHAR(36) REFERENCES operators(id);
ALTER TABLE collection_movements ADD COLUMN IF NOT EXISTS cancel_reason TEXT NOT NULL DEFAULT '';

ALTER TABLE collection_movements DROP CONSTRAINT IF EXISTS collection_movements_kind_check;
ALTER TABLE collection_movements ADD CONSTRAINT collection_movements_kind_check
    CHECK (kind IN ('never_left','buyer_return_accepted','not_recovered','returned_to_supplier','receipt_correction','lost'));

-- Only a loss has a loss reason and can be cancelled.
ALTER TABLE collection_movements DROP CONSTRAINT IF EXISTS collection_movement_loss_reason;
ALTER TABLE collection_movements ADD CONSTRAINT collection_movement_loss_reason
    CHECK ((kind = 'lost') = (loss_reason IS NOT NULL)
        AND (loss_reason IS NULL OR loss_reason IN ('died','sick','stolen','spoiled','other')));
ALTER TABLE collection_movements DROP CONSTRAINT IF EXISTS collection_movement_cancel;
ALTER TABLE collection_movements ADD CONSTRAINT collection_movement_cancel
    CHECK (cancelled_at IS NULL OR (kind = 'lost' AND length(btrim(cancel_reason)) >= 3));

COMMIT;
