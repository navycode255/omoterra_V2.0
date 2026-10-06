-- Build plan M2.2 (audit F03 part 2): stock as of the sale date.
--
-- Every change that moves stock out of or back into a received lot is now
-- replayed by date (app/lots.py StockGuard): it is refused if any later day
-- would end below zero (rule R8), and a sale cannot use stock before it was
-- received. That needs no schema change.
--
-- late_entries records a stock entry dated more than 7 days before the day
-- it was entered (a sale from received stock, a loss, a return to the
-- supplier): only an admin may enter it, with a reason, and it still has to
-- keep every later day at or above zero. Nothing existing is changed.
BEGIN;

CREATE TABLE IF NOT EXISTS late_entries (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    entity_table VARCHAR(32) NOT NULL,
    entity_id VARCHAR(36) NOT NULL,
    entry_date DATE NOT NULL,
    entered_on DATE NOT NULL,
    reason TEXT NOT NULL,
    approved_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT late_entries_reason_check CHECK (length(btrim(reason)) >= 3),
    CONSTRAINT late_entries_dates_check CHECK (entry_date < entered_on)
);
CREATE INDEX IF NOT EXISTS ix_late_entries_entity_id ON late_entries(entity_id);

COMMIT;
