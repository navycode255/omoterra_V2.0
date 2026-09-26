-- Ops can ask a supplier to change stock under review, with a note saying
-- what to change; the supplier fixes it and sends it back for review.
BEGIN;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS review_note TEXT NOT NULL DEFAULT '';
-- Stock ops paused while it was still under review ("Request changes") had
-- no way back. It is really waiting on the supplier: give it the new status.
-- Stock a demand order created, and deleted accounts' stock, stay paused.
UPDATE listings SET listing_status = 'changes_requested'
WHERE listing_status = 'paused' AND approved_at IS NULL
  AND COALESCE(specs::jsonb ->> 'demand_order', '') <> 'true'
  AND supplier_id NOT IN (SELECT id FROM users WHERE deleted);
COMMIT;
