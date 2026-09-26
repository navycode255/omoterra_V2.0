-- Referrals: one row each time someone is registered for a role by someone
-- else. Today only operators register people (from the mobile admin app);
-- later ordinary members will too, as 'pending' rows ops confirms or
-- rejects. A referral is the account registration only: a referred
-- supplier's profile still goes through its own under_review → approved
-- verification.
BEGIN;
CREATE TABLE IF NOT EXISTS referrals (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    target_user_id VARCHAR(36) NOT NULL REFERENCES users(id),
    referred_by_operator_id VARCHAR(36) REFERENCES operators(id),
    referred_by_user_id VARCHAR(36) REFERENCES users(id),
    role_requested VARCHAR(16) NOT NULL CHECK (role_requested IN ('buyer', 'supplier')),
    source VARCHAR(16) NOT NULL CHECK (source IN ('admin', 'member', 'self_signup')),
    status VARCHAR(16) NOT NULL CHECK (status IN ('pending', 'confirmed', 'rejected', 'cancelled')),
    reviewed_at TIMESTAMPTZ,
    reviewed_by VARCHAR(36) REFERENCES operators(id),
    rejection_reason TEXT NOT NULL DEFAULT '',
    CONSTRAINT one_referrer CHECK (
        (source = 'self_signup' AND referred_by_operator_id IS NULL AND referred_by_user_id IS NULL)
        OR (source = 'admin' AND referred_by_operator_id IS NOT NULL AND referred_by_user_id IS NULL)
        OR (source = 'member' AND referred_by_user_id IS NOT NULL AND referred_by_operator_id IS NULL))
);
CREATE INDEX IF NOT EXISTS ix_referrals_target ON referrals(target_user_id);
CREATE INDEX IF NOT EXISTS ix_referrals_by_operator ON referrals(referred_by_operator_id);
CREATE INDEX IF NOT EXISTS ix_referrals_by_user ON referrals(referred_by_user_id);
-- A person holds at most one live referral per role; rejected and cancelled
-- ones stay as history.
CREATE UNIQUE INDEX IF NOT EXISTS uq_referrals_live_role ON referrals(target_user_id, role_requested)
    WHERE status IN ('pending', 'confirmed');
-- Mobile admin passphrase guesses are rate limited apart from admin setup's.
ALTER TABLE admin_setup_attempts ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'setup';
COMMIT;
