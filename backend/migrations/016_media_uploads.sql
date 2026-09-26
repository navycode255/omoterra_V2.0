-- Resumable video uploads: one row from start until confirm (or until the
-- hourly prune drops it a day later). Parts go straight to storage.
BEGIN;
CREATE TABLE IF NOT EXISTS media_uploads (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    owner_id VARCHAR(36) NOT NULL REFERENCES users(id),
    upload_id TEXT NOT NULL DEFAULT '',
    size INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_media_uploads_owner_id ON media_uploads(owner_id);
COMMIT;
