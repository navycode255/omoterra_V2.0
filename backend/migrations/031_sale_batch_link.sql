-- A direct sale line from a registered supplier names the batch the birds came
-- from, so selling reduces that batch. Staff can also record what a supplier
-- sold to others (external_sale movements, already used by suppliers).
BEGIN;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS supplier_batch_id VARCHAR(36) REFERENCES supplier_batches(id);
CREATE INDEX IF NOT EXISTS ix_sale_items_supplier_batch_id ON sale_items(supplier_batch_id);
ALTER TABLE supplier_batch_movements ADD COLUMN IF NOT EXISTS recorded_by VARCHAR(36) REFERENCES operators(id);
COMMIT;
