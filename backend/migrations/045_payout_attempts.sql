-- Build plan M2.7 (audit F12, decision D9): payout attempts, refunds and
-- second-admin approvals.
--
-- approval_requests: a request a second admin (never the requester) approves
--   before money moves. Used by app payouts now: every attempt after the
--   first, and a first attempt over TZS 500,000 (app/approvals.py
--   SECOND_ADMIN_THRESHOLD). M5 reuses it for other payment types.
-- settlement_transfers: one row per attempt to pay a settlement, with its
--   amount, method, account, reference, evidence and state:
--     initiated  sent, no debit confirmation: pending exposure, not money out;
--     debited    confirmed on a statement or by the provider: a permanent
--                outflow (rule R3) on debited_on;
--     failed     evidence that no debit happened: no outflow, evidence kept.
-- settlement_refunds: money a debited attempt brought back: a separate dated
--   inflow, never a change to the outflow. Append-only.
-- payout_confirmations.transfer_id: the attempt a supplier answer is about.
--
-- Backfill (rule R6, never guess):
-- * each settlement marked paid (with its paid time) becomes ONE debited
--   attempt dated the Dar es Salaam day it was marked paid, with its
--   reference, its account (the account assignment and the reference claim
--   move to the attempt), evidence "legacy: marked paid" and the supplier's
--   latest answer (a disputed payout stays disputed). The cash book, accounts
--   and reports count exactly what they counted before.
-- * a settlement re-sent after "not received" before this migration kept one
--   row whose reference and date the resend overwrote. The first transfer's
--   date is unknown, so no attempt is invented for it: the supplier's answers
--   still name its reference, and `python -m app.finance_exceptions` lists it
--   ("resent before payout attempts") for the finance owner to find on the
--   statement.
-- * older supplier answers keep transfer_id NULL: they belong to the
--   settlement's one legacy attempt (payout_confirmations is append-only).
BEGIN;

CREATE TABLE IF NOT EXISTS approval_requests (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    subject_table VARCHAR(32) NOT NULL,
    subject_id VARCHAR(36) NOT NULL,
    kind VARCHAR(32) NOT NULL,
    amount NUMERIC(14,2) NOT NULL,
    reason TEXT NOT NULL DEFAULT '',
    acknowledged BOOLEAN NOT NULL DEFAULT false,
    requested_by VARCHAR(36) NOT NULL REFERENCES operators(id),
    status VARCHAR(16) NOT NULL DEFAULT 'pending',
    decided_by VARCHAR(36) REFERENCES operators(id),
    decided_at TIMESTAMPTZ,
    decision_note TEXT NOT NULL DEFAULT '',
    used_by_table VARCHAR(32),
    used_by_id VARCHAR(36),
    used_at TIMESTAMPTZ,
    CONSTRAINT approval_requests_status_check CHECK (status IN ('pending','approved','rejected')),
    CONSTRAINT approval_requests_amount_check CHECK (amount > 0),
    CONSTRAINT approval_requests_second_admin_check
        CHECK (status <> 'approved' OR (decided_by IS NOT NULL AND decided_by <> requested_by))
);
CREATE INDEX IF NOT EXISTS ix_approval_requests_subject ON approval_requests (subject_table, subject_id);

CREATE TABLE IF NOT EXISTS settlement_transfers (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    settlement_id VARCHAR(36) NOT NULL REFERENCES settlements(id),
    attempt_no INTEGER NOT NULL,
    amount NUMERIC(14,2) NOT NULL,
    method VARCHAR(24) NOT NULL DEFAULT '',
    reference TEXT NOT NULL DEFAULT '',
    money_account_id VARCHAR(36) REFERENCES money_accounts(id),
    sent_on DATE NOT NULL,
    evidence TEXT NOT NULL DEFAULT '',
    state VARCHAR(16) NOT NULL DEFAULT 'initiated',
    initiated_by VARCHAR(36) REFERENCES operators(id),
    is_resend BOOLEAN NOT NULL DEFAULT false,
    approval_id VARCHAR(36) REFERENCES approval_requests(id),
    debited_on DATE,
    debit_evidence TEXT NOT NULL DEFAULT '',
    debit_confirmed_by VARCHAR(36) REFERENCES operators(id),
    debit_confirmed_at TIMESTAMPTZ,
    failed_on DATE,
    failure_evidence TEXT NOT NULL DEFAULT '',
    failed_by VARCHAR(36) REFERENCES operators(id),
    failed_at TIMESTAMPTZ,
    supplier_confirmation VARCHAR(16),
    supplier_confirmed_at TIMESTAMPTZ,
    legacy BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT uq_settlement_transfer_attempt UNIQUE (settlement_id, attempt_no),
    CONSTRAINT settlement_transfers_amount_check CHECK (amount > 0),
    CONSTRAINT settlement_transfers_state_check CHECK (state IN ('initiated','debited','failed')),
    CONSTRAINT settlement_transfers_debited_check CHECK (state <> 'debited' OR debited_on IS NOT NULL),
    CONSTRAINT settlement_transfers_failed_check
        CHECK (state <> 'failed' OR (failed_on IS NOT NULL AND length(btrim(failure_evidence)) >= 3))
);
CREATE INDEX IF NOT EXISTS ix_settlement_transfers_settlement_id ON settlement_transfers (settlement_id);
CREATE INDEX IF NOT EXISTS ix_settlement_transfers_state ON settlement_transfers (state);
CREATE INDEX IF NOT EXISTS ix_settlement_transfers_debited_on ON settlement_transfers (debited_on);

CREATE TABLE IF NOT EXISTS settlement_refunds (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    settlement_id VARCHAR(36) NOT NULL REFERENCES settlements(id),
    transfer_id VARCHAR(36) NOT NULL REFERENCES settlement_transfers(id),
    amount NUMERIC(14,2) NOT NULL,
    refunded_on DATE NOT NULL,
    method VARCHAR(24) NOT NULL DEFAULT '',
    reference TEXT NOT NULL DEFAULT '',
    money_account_id VARCHAR(36) REFERENCES money_accounts(id),
    evidence TEXT NOT NULL,
    recorded_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT settlement_refunds_amount_check CHECK (amount > 0),
    CONSTRAINT settlement_refunds_evidence_check CHECK (length(btrim(evidence)) >= 3)
);
CREATE INDEX IF NOT EXISTS ix_settlement_refunds_settlement_id ON settlement_refunds (settlement_id);
CREATE INDEX IF NOT EXISTS ix_settlement_refunds_transfer_id ON settlement_refunds (transfer_id);
CREATE INDEX IF NOT EXISTS ix_settlement_refunds_refunded_on ON settlement_refunds (refunded_on);
DROP TRIGGER IF EXISTS immutable_history ON settlement_refunds;
CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON settlement_refunds
    FOR EACH ROW EXECUTE FUNCTION omoterra_reject_history_edit();

ALTER TABLE payout_confirmations ADD COLUMN IF NOT EXISTS transfer_id VARCHAR(36) REFERENCES settlement_transfers(id);
CREATE INDEX IF NOT EXISTS ix_payout_confirmations_transfer_id ON payout_confirmations (transfer_id);

-- One debited attempt per settlement marked paid. The attempt id is derived
-- from the settlement id so the account and reference can follow it.
INSERT INTO settlement_transfers (id, created_at, settlement_id, attempt_no, amount, method, reference,
    money_account_id, sent_on, evidence, state, debited_on, debit_evidence, debit_confirmed_at,
    supplier_confirmation, supplier_confirmed_at, legacy)
SELECT md5('legacy-payout-attempt:' || s.id)::uuid::text, s.paid_at, s.id, 1, s.total_payable, '',
       COALESCE(s.payment_reference, ''), aa.account_id,
       (s.paid_at AT TIME ZONE 'Africa/Dar_es_Salaam')::date, 'legacy: marked paid', 'debited',
       (s.paid_at AT TIME ZONE 'Africa/Dar_es_Salaam')::date, 'legacy: marked paid', s.paid_at,
       s.supplier_confirmation, s.supplier_confirmed_at, true
  FROM settlements s
  LEFT JOIN account_assignments aa ON aa.source_table = 'settlements' AND aa.source_id = s.id
 WHERE s.status = 'paid' AND s.paid_at IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM settlement_transfers t WHERE t.settlement_id = s.id);

UPDATE account_assignments aa
   SET source_table = 'settlement_transfers', source_id = t.id
  FROM settlement_transfers t
 WHERE t.legacy AND aa.source_table = 'settlements' AND aa.source_id = t.settlement_id;

UPDATE money_references r
   SET source_table = 'settlement_transfers', source_id = t.id
  FROM settlement_transfers t
 WHERE t.legacy AND r.source_table = 'settlements' AND r.source_id = t.settlement_id;

COMMIT;
