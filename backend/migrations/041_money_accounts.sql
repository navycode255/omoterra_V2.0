-- Build plan M2.3 (audit F05, decision D6): money accounts and reconciliation.
--
-- money_accounts: each cash box, bank account and mobile wallet, with the
--   opening balance the finance owner verified at the end of cutoff_on.
--   Movements dated on or before the cutoff are inside that balance: they stay
--   visible as history but never count again.
-- account_assignments: which account a cash book row went through, keyed by
--   the row's own table and id. New entries name their account; a historical
--   one is assigned only with evidence (rule R6). Rows with no assignment are
--   the "Unassigned (historical)" bucket. A row entered after the account was
--   set up but dated on or before its cutoff is a pre-cutoff adjustment until
--   the finance owner explains or restates it.
-- account_transfers: money moved between two Omoterra accounts (no change to
--   the business total). account_fees: bank and wallet charges (money out and
--   an expense).
-- account_checks: a cash count or statement balance against the recorded
--   balance; a difference is an exception to explain, never an adjustment.
--
-- Nothing existing is changed: every past movement starts unassigned.
BEGIN;

CREATE TABLE IF NOT EXISTS money_accounts (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    name VARCHAR(80) NOT NULL UNIQUE,
    kind VARCHAR(16) NOT NULL,
    provider VARCHAR(80) NOT NULL DEFAULT '',
    number VARCHAR(80) NOT NULL DEFAULT '',
    cutoff_on DATE NOT NULL,
    opening_balance NUMERIC(14,2) NOT NULL,
    opening_evidence TEXT NOT NULL,
    verified_by TEXT NOT NULL,
    recorded_by VARCHAR(36) REFERENCES operators(id),
    active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT money_accounts_kind_check CHECK (kind IN ('cash','bank','mobile_wallet')),
    CONSTRAINT money_accounts_evidence_check CHECK (length(btrim(opening_evidence)) >= 3 AND length(btrim(verified_by)) >= 2)
);

CREATE TABLE IF NOT EXISTS account_assignments (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_table VARCHAR(32) NOT NULL,
    source_id VARCHAR(36) NOT NULL,
    account_id VARCHAR(36) NOT NULL REFERENCES money_accounts(id),
    how VARCHAR(16) NOT NULL DEFAULT 'entered',
    evidence TEXT NOT NULL DEFAULT '',
    assigned_by VARCHAR(36) REFERENCES operators(id),
    confirmed_by TEXT NOT NULL DEFAULT '',
    pre_cutoff VARCHAR(16),
    pre_cutoff_note TEXT NOT NULL DEFAULT '',
    pre_cutoff_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT uq_account_assignment_source UNIQUE (source_table, source_id),
    CONSTRAINT account_assignments_how_check CHECK (how IN ('entered','historical')),
    CONSTRAINT account_assignments_evidence_check CHECK (how <> 'historical' OR length(btrim(evidence)) >= 3),
    CONSTRAINT account_assignments_pre_cutoff_check CHECK (pre_cutoff IS NULL OR (pre_cutoff IN ('inside_opening','restated') AND length(btrim(pre_cutoff_note)) >= 3))
);
CREATE INDEX IF NOT EXISTS ix_account_assignments_account_id ON account_assignments(account_id);

CREATE TABLE IF NOT EXISTS account_transfers (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    from_account_id VARCHAR(36) NOT NULL REFERENCES money_accounts(id),
    to_account_id VARCHAR(36) NOT NULL REFERENCES money_accounts(id),
    amount NUMERIC(14,2) NOT NULL,
    transferred_on DATE NOT NULL,
    reference TEXT NOT NULL DEFAULT '',
    note TEXT NOT NULL DEFAULT '',
    recorded_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT account_transfers_amount_check CHECK (amount > 0),
    CONSTRAINT account_transfers_accounts_check CHECK (from_account_id <> to_account_id)
);
CREATE INDEX IF NOT EXISTS ix_account_transfers_from_account_id ON account_transfers(from_account_id);
CREATE INDEX IF NOT EXISTS ix_account_transfers_to_account_id ON account_transfers(to_account_id);
CREATE INDEX IF NOT EXISTS ix_account_transfers_transferred_on ON account_transfers(transferred_on);

CREATE TABLE IF NOT EXISTS account_fees (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    account_id VARCHAR(36) NOT NULL REFERENCES money_accounts(id),
    amount NUMERIC(14,2) NOT NULL,
    charged_on DATE NOT NULL,
    description TEXT NOT NULL,
    reference TEXT NOT NULL DEFAULT '',
    transfer_id VARCHAR(36) REFERENCES account_transfers(id),
    recorded_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT account_fees_amount_check CHECK (amount > 0),
    CONSTRAINT account_fees_description_check CHECK (length(btrim(description)) >= 3)
);
CREATE INDEX IF NOT EXISTS ix_account_fees_account_id ON account_fees(account_id);
CREATE INDEX IF NOT EXISTS ix_account_fees_charged_on ON account_fees(charged_on);

CREATE TABLE IF NOT EXISTS account_checks (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    account_id VARCHAR(36) NOT NULL REFERENCES money_accounts(id),
    kind VARCHAR(16) NOT NULL,
    checked_on DATE NOT NULL,
    balance NUMERIC(14,2) NOT NULL,
    expected NUMERIC(14,2) NOT NULL,
    difference NUMERIC(14,2) NOT NULL,
    evidence TEXT NOT NULL,
    recorded_by VARCHAR(36) REFERENCES operators(id),
    resolution TEXT NOT NULL DEFAULT '',
    resolved_at TIMESTAMPTZ,
    resolved_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT account_checks_kind_check CHECK (kind IN ('count','statement')),
    CONSTRAINT account_checks_difference_check CHECK (difference = balance - expected),
    CONSTRAINT account_checks_evidence_check CHECK (length(btrim(evidence)) >= 3),
    CONSTRAINT account_checks_resolution_check CHECK (resolved_at IS NULL OR length(btrim(resolution)) >= 3)
);
CREATE INDEX IF NOT EXISTS ix_account_checks_account_id ON account_checks(account_id);
CREATE INDEX IF NOT EXISTS ix_account_checks_checked_on ON account_checks(checked_on);

COMMIT;
