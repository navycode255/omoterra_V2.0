-- Buyer ratings of delivered orders, which build each supplier's reputation.
BEGIN;
CREATE TABLE IF NOT EXISTS order_ratings (
 id VARCHAR(36) PRIMARY KEY,
 created_at TIMESTAMPTZ NOT NULL,
 order_id VARCHAR(36) NOT NULL UNIQUE REFERENCES orders(id),
 buyer_id VARCHAR(36) NOT NULL REFERENCES users(id),
 stars INTEGER NOT NULL,
 comment TEXT NOT NULL DEFAULT '',
 updated_at TIMESTAMPTZ NOT NULL,
 hidden BOOLEAN NOT NULL DEFAULT false,
 hidden_by VARCHAR(36) REFERENCES operators(id),
 CONSTRAINT valid_rating_stars CHECK (stars BETWEEN 1 AND 5)
);
CREATE INDEX IF NOT EXISTS ix_order_ratings_buyer_id ON order_ratings(buyer_id);
COMMIT;
