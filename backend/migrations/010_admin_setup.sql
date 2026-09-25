-- "Admin setup" on the dashboard sign-in screen: setup sessions opened with
-- the setup passphrase, and passphrase attempts for rate limiting.
BEGIN;
CREATE TABLE IF NOT EXISTS admin_setups (
 id VARCHAR(36) PRIMARY KEY,
 created_at TIMESTAMPTZ NOT NULL,
 token_hash VARCHAR NOT NULL UNIQUE,
 expires_at TIMESTAMPTZ NOT NULL,
 needs_approval BOOLEAN NOT NULL,
 approved_by VARCHAR(36) REFERENCES operators(id),
 new_name VARCHAR NOT NULL DEFAULT '',
 new_phone VARCHAR(20) NOT NULL DEFAULT '',
 completed_operator_id VARCHAR(36) REFERENCES operators(id)
);

CREATE TABLE IF NOT EXISTS admin_setup_attempts (
 id VARCHAR(36) PRIMARY KEY,
 created_at TIMESTAMPTZ NOT NULL,
 succeeded BOOLEAN NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_admin_setup_attempts_created_at ON admin_setup_attempts(created_at);
COMMIT;
