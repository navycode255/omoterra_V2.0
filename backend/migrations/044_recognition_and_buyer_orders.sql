-- Build plan M2.5 (audit F07, decision D7): recognition date, and orders
-- staff take for a buyer.
--
-- orders.recognized_on: the Dar es Salaam business day an app order counts
--   as a sale (its delivery day). Revenue and cost both read it; until now
--   they read the "Delivered" entry of the order's activity log at query time.
-- orders.recognition_note: how it was set (delivery, backfill, evidence).
-- order_recognition_reversals: a delivered order reopened or returned. The
--   sale stays in the period it was recognised in; the reversal takes it out
--   again on the day it happens. Append-only.
-- buyer_orders, buyer_order_lines: an order taken by phone or in person. A
--   commitment until delivered; then a direct sale (sale_id) dated the
--   delivery day.
-- buyer_order_payments: deposits on those orders (money in, held for the
--   buyer) and deposits given back (money out). Applied to the sale's
--   receivable on delivery (applied_payment_id).
--
-- Backfill (rule R6): a delivered or completed order gets recognized_on only
-- when its history is unambiguous: every "Delivered" entry has a timestamp,
-- they all fall on the same Dar es Salaam day, that day is not before the
-- order was created and not in the future. Everything else stays NULL
-- (unresolved): listed by `python -m app.finance_exceptions` and by
-- `python -m app.recognition --dry-run`, and given a date only with evidence
-- (`python -m app.recognition --apply`). The same rule is
-- app/recognition.py:classify; the two are tested against each other.
BEGIN;

ALTER TABLE orders ADD COLUMN IF NOT EXISTS recognized_on DATE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS recognition_note TEXT NOT NULL DEFAULT '';
CREATE INDEX IF NOT EXISTS ix_orders_recognized_on ON orders (recognized_on);

CREATE TABLE IF NOT EXISTS order_recognition_reversals (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    order_id VARCHAR(36) NOT NULL REFERENCES orders(id),
    kind VARCHAR(16) NOT NULL,
    recognized_on DATE,
    reversed_on DATE NOT NULL,
    revenue NUMERIC(14,2) NOT NULL,
    cost NUMERIC(14,2) NOT NULL,
    reason TEXT NOT NULL,
    recorded_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT order_recognition_reversals_kind_check CHECK (kind IN ('reopen','return'))
);
CREATE INDEX IF NOT EXISTS ix_order_recognition_reversals_order_id ON order_recognition_reversals (order_id);
CREATE INDEX IF NOT EXISTS ix_order_recognition_reversals_reversed_on ON order_recognition_reversals (reversed_on);

CREATE TABLE IF NOT EXISTS buyer_orders (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    order_number VARCHAR(24) NOT NULL UNIQUE,
    buyer_profile_id VARCHAR(36) NOT NULL REFERENCES buyer_profiles(id),
    buyer_name TEXT NOT NULL,
    buyer_phone VARCHAR(20) NOT NULL DEFAULT '',
    ordered_on DATE NOT NULL,
    expected_on DATE,
    notes TEXT NOT NULL DEFAULT '',
    total_amount NUMERIC(14,2) NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'open',
    sale_id VARCHAR(36) UNIQUE REFERENCES sales(id),
    delivered_on DATE,
    created_by VARCHAR(36) REFERENCES operators(id),
    updated_at TIMESTAMPTZ,
    updated_by VARCHAR(36) REFERENCES operators(id),
    cancelled_at TIMESTAMPTZ,
    cancelled_by VARCHAR(36) REFERENCES operators(id),
    cancel_reason TEXT NOT NULL DEFAULT '',
    CONSTRAINT buyer_orders_status_check CHECK (status IN ('open','delivered','cancelled')),
    CONSTRAINT buyer_orders_total_check CHECK (total_amount > 0),
    CONSTRAINT buyer_orders_delivered_check
        CHECK ((status = 'delivered') = (sale_id IS NOT NULL AND delivered_on IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS ix_buyer_orders_buyer_profile_id ON buyer_orders (buyer_profile_id);
CREATE INDEX IF NOT EXISTS ix_buyer_orders_ordered_on ON buyer_orders (ordered_on);
CREATE INDEX IF NOT EXISTS ix_buyer_orders_status ON buyer_orders (status);

CREATE TABLE IF NOT EXISTS buyer_order_lines (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    buyer_order_id VARCHAR(36) NOT NULL REFERENCES buyer_orders(id),
    position INTEGER NOT NULL,
    category VARCHAR(32) NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    unit VARCHAR(16) NOT NULL,
    quantity NUMERIC(14,3) NOT NULL,
    unit_price NUMERIC(14,2) NOT NULL,
    subtotal NUMERIC(14,2) NOT NULL,
    CONSTRAINT buyer_order_lines_amounts_check CHECK (quantity > 0 AND unit_price > 0),
    CONSTRAINT buyer_order_lines_unit_check CHECK (unit IN ('bird','animal','kg','tray','piece'))
);
CREATE INDEX IF NOT EXISTS ix_buyer_order_lines_buyer_order_id ON buyer_order_lines (buyer_order_id);

CREATE TABLE IF NOT EXISTS buyer_order_payments (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    buyer_order_id VARCHAR(36) NOT NULL REFERENCES buyer_orders(id),
    kind VARCHAR(16) NOT NULL,
    refund_of VARCHAR(36) UNIQUE REFERENCES buyer_order_payments(id),
    amount NUMERIC(14,2) NOT NULL,
    paid_on DATE NOT NULL,
    method VARCHAR(24) NOT NULL,
    reference TEXT NOT NULL DEFAULT '',
    note TEXT NOT NULL DEFAULT '',
    recorded_by VARCHAR(36) REFERENCES operators(id),
    applied_payment_id VARCHAR(36) UNIQUE REFERENCES ledger_payments(id),
    voided_at TIMESTAMPTZ,
    voided_by VARCHAR(36) REFERENCES operators(id),
    void_reason TEXT NOT NULL DEFAULT '',
    CONSTRAINT buyer_order_payments_kind_check CHECK (kind IN ('deposit','refund')),
    CONSTRAINT buyer_order_payments_amount_check CHECK (amount > 0),
    CONSTRAINT buyer_order_payments_refund_check CHECK ((kind = 'refund') = (refund_of IS NOT NULL)),
    CONSTRAINT buyer_order_payments_method_check
        CHECK (method IN ('cash','mpesa','airtel_money','mixx_by_yas','halopesa','bank_transfer','cheque','other'))
);
CREATE INDEX IF NOT EXISTS ix_buyer_order_payments_buyer_order_id ON buyer_order_payments (buyer_order_id);
CREATE INDEX IF NOT EXISTS ix_buyer_order_payments_paid_on ON buyer_order_payments (paid_on);

-- Backfill recognized_on from the activity log (see the rule above).
WITH entries AS (
    SELECT o.id AS order_id, o.created_at,
           CASE WHEN COALESCE(e->>'at', '') ~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}'
                THEN CAST(timezone('Africa/Dar_es_Salaam', CAST(e->>'at' AS timestamptz)) AS date) END AS day
    FROM orders o
    CROSS JOIN LATERAL json_array_elements(
        CASE WHEN json_typeof(CAST(o.activity AS json)) = 'array' THEN CAST(o.activity AS json) ELSE '[]'::json END) AS e
    WHERE o.internal_status IN ('delivered', 'completed') AND o.recognized_on IS NULL
      AND e->>'label' = 'Delivered'
), resolved AS (
    SELECT order_id, min(day) AS day
    FROM entries
    GROUP BY order_id, created_at
    HAVING count(*) = count(day)
       AND count(DISTINCT day) = 1
       AND min(day) >= CAST(timezone('Africa/Dar_es_Salaam', created_at) AS date)
       AND min(day) <= CAST(timezone('Africa/Dar_es_Salaam', now()) AS date)
)
UPDATE orders SET recognized_on = resolved.day,
                  recognition_note = 'Backfilled from the order''s Delivered entry (migration 044)'
FROM resolved WHERE orders.id = resolved.order_id;

COMMIT;
