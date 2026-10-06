-- Build plan M2.6 (audit F11): the same real transaction cannot be entered twice.
--
-- money_references: one row per transaction reference a money record claims,
--   keyed by (provider, account_key, reference). provider is the payment
--   method ('' for app receipts and payouts, which record none); account_key
--   the money account it went through ('' when none, and always '' for
--   mobile money, whose codes are unique network-wide); reference trimmed,
--   spaces removed and upper-cased. A unique index over the triple, for live
--   claims only, makes the database refuse a second claim.
-- duplicate_overrides: a payment entered without a reference although one
--   with the same party, amount, day and direction existed; who said it is a
--   separate payment and why.
--
-- History: for each identity only the EARLIEST existing record is claimed
-- (DISTINCT ON), so existing duplicates can never make this migration fail.
-- Later records sharing an identity keep counting exactly as before and are
-- listed by `python -m app.finance_exceptions` (historical duplicate
-- references) for the finance owner to explain with evidence (rule R6).
BEGIN;

CREATE TABLE IF NOT EXISTS money_references (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    provider VARCHAR(24) NOT NULL DEFAULT '',
    account_key VARCHAR(36) NOT NULL DEFAULT '',
    reference TEXT NOT NULL,
    flow VARCHAR(3) NOT NULL,
    source_table VARCHAR(32) NOT NULL,
    source_id VARCHAR(36) NOT NULL,
    recorded_by VARCHAR(36) REFERENCES operators(id),
    released_at TIMESTAMPTZ,
    release_reason TEXT NOT NULL DEFAULT '',
    CONSTRAINT money_references_reference_check CHECK (reference <> ''),
    CONSTRAINT money_references_flow_check CHECK (flow IN ('in','out'))
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_money_reference_live ON money_references (provider, account_key, reference)
    WHERE released_at IS NULL;
CREATE INDEX IF NOT EXISTS ix_money_references_reference ON money_references (reference);
CREATE INDEX IF NOT EXISTS ix_money_references_source ON money_references (source_table, source_id);

CREATE TABLE IF NOT EXISTS duplicate_overrides (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_table VARCHAR(32) NOT NULL,
    source_id VARCHAR(36) NOT NULL,
    earlier_table VARCHAR(32) NOT NULL,
    earlier_id VARCHAR(36) NOT NULL,
    flow VARCHAR(3) NOT NULL,
    amount NUMERIC(14,2) NOT NULL,
    paid_on DATE NOT NULL,
    reason TEXT NOT NULL,
    overridden_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT duplicate_overrides_reason_check CHECK (length(btrim(reason)) >= 3)
);
CREATE INDEX IF NOT EXISTS ix_duplicate_overrides_source ON duplicate_overrides (source_table, source_id);

-- Claim the references of existing money records, earliest per identity.
INSERT INTO money_references (id, created_at, provider, account_key, reference, flow, source_table, source_id, recorded_by)
SELECT gen_random_uuid()::text, now(), claims.provider, claims.account_key, claims.reference, claims.flow,
       claims.source_table, claims.source_id, claims.recorded_by
FROM (
    SELECT DISTINCT ON (c.provider, c.account_key, c.reference) c.*
    FROM (
        SELECT p.method AS provider, p.reference AS raw, CASE WHEN d.direction = 'receivable' THEN 'in' ELSE 'out' END AS flow,
               'ledger_payments' AS source_table, p.id AS source_id, p.recorded_by, p.created_at
          FROM ledger_payments p JOIN ledger_debts d ON d.id = p.debt_id
         WHERE p.reversed_at IS NULL AND p.supplier_payment_id IS NULL AND p.buyer_payment_id IS NULL
        UNION ALL
        SELECT t.method, t.reference, 'out', 'supplier_payments', t.id, t.recorded_by, t.created_at FROM supplier_payments t
        UNION ALL
        SELECT e.method, e.reference, 'in', 'transfer_events', e.id, e.recorded_by, e.created_at
          FROM transfer_events e WHERE e.kind = 'refund'
        UNION ALL
        SELECT b.method, b.reference, 'in', 'buyer_payments', b.id, b.recorded_by, b.created_at FROM buyer_payments b
         WHERE EXISTS (SELECT 1 FROM ledger_payments a WHERE a.buyer_payment_id = b.id AND a.reversed_at IS NULL)
        UNION ALL
        SELECT '', r.reference, 'in', 'payment_receipts', r.id, NULL, r.created_at FROM payment_receipts r
        UNION ALL
        SELECT '', s.payment_reference, 'out', 'settlements', s.id, NULL, s.created_at FROM settlements s
         WHERE s.status = 'paid' AND s.payment_reference IS NOT NULL
    ) AS rows_
    CROSS JOIN LATERAL (
        -- Mobile-money codes are unique across the whole network, so they
        -- are claimed once per provider whichever wallet they went through.
        SELECT rows_.provider,
               CASE WHEN rows_.provider IN ('mpesa','airtel_money','mixx_by_yas','halopesa') THEN ''
                    ELSE COALESCE(a.account_id, '') END AS account_key,
               upper(regexp_replace(rows_.raw, '\s+', '', 'g')) AS reference, rows_.flow, rows_.source_table,
               rows_.source_id, rows_.recorded_by, rows_.created_at
          FROM (SELECT 1) AS one
          LEFT JOIN account_assignments a ON a.source_table = rows_.source_table AND a.source_id = rows_.source_id
    ) AS c
    WHERE c.reference <> ''
    ORDER BY c.provider, c.account_key, c.reference, c.created_at, c.source_id
) AS claims
ON CONFLICT DO NOTHING;

COMMIT;
