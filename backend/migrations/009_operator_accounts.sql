-- Per-operator dashboard accounts, their sessions, an audit trail of every
-- change they make, and a purpose on OTP codes so app and ops codes can't be
-- used for each other.
BEGIN;
CREATE TABLE IF NOT EXISTS operators (
 id VARCHAR(36) PRIMARY KEY,
 created_at TIMESTAMPTZ NOT NULL,
 phone VARCHAR(20) NOT NULL UNIQUE,
 name VARCHAR NOT NULL,
 role VARCHAR(16) NOT NULL DEFAULT 'staff',
 active BOOLEAN NOT NULL DEFAULT true,
 created_by VARCHAR(36) REFERENCES operators(id),
 last_login_at TIMESTAMPTZ,
 CONSTRAINT valid_operator_role CHECK (role IN ('admin','staff'))
);

CREATE TABLE IF NOT EXISTS operator_sessions (
 id VARCHAR(36) PRIMARY KEY,
 created_at TIMESTAMPTZ NOT NULL,
 operator_id VARCHAR(36) NOT NULL REFERENCES operators(id),
 token_hash VARCHAR NOT NULL UNIQUE,
 expires_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_operator_sessions_operator_id ON operator_sessions(operator_id);

CREATE TABLE IF NOT EXISTS ops_audit (
 id VARCHAR(36) PRIMARY KEY,
 created_at TIMESTAMPTZ NOT NULL,
 operator_id VARCHAR(36) NOT NULL REFERENCES operators(id),
 method VARCHAR(8) NOT NULL,
 path VARCHAR NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_ops_audit_operator_id ON ops_audit(operator_id);

ALTER TABLE otp_challenges ADD COLUMN IF NOT EXISTS purpose VARCHAR(8) NOT NULL DEFAULT 'app';
COMMIT;
