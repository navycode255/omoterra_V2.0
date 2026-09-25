-- In-app notifications, phones registered for push, and a marker so the
-- stock reminder job sends one reminder per confirmation window.
BEGIN;
CREATE TABLE IF NOT EXISTS notifications (
 id VARCHAR(36) PRIMARY KEY,
 created_at TIMESTAMPTZ NOT NULL,
 user_id VARCHAR(36) NOT NULL REFERENCES users(id),
 role VARCHAR(16) NOT NULL,
 kind VARCHAR(48) NOT NULL,
 title VARCHAR NOT NULL,
 body TEXT NOT NULL DEFAULT '',
 link VARCHAR NOT NULL DEFAULT '',
 read_at TIMESTAMPTZ,
 CONSTRAINT valid_notification_role CHECK (role IN ('buyer','supplier'))
);
CREATE INDEX IF NOT EXISTS ix_notifications_user_id ON notifications(user_id);

CREATE TABLE IF NOT EXISTS device_tokens (
 id VARCHAR(36) PRIMARY KEY,
 created_at TIMESTAMPTZ NOT NULL,
 user_id VARCHAR(36) NOT NULL REFERENCES users(id),
 token VARCHAR NOT NULL UNIQUE,
 platform VARCHAR(16) NOT NULL DEFAULT 'android',
 last_seen_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_device_tokens_user_id ON device_tokens(user_id);

ALTER TABLE listings ADD COLUMN IF NOT EXISTS confirmation_reminded_at TIMESTAMPTZ;
COMMIT;
