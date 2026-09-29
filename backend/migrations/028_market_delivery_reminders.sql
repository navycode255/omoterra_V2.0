ALTER TABLE market_reservations
    ADD COLUMN IF NOT EXISTS delivery_reminded_at TIMESTAMPTZ;
