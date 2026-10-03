-- Weight-banded market prices that operations publish for suppliers.
-- A price list is never edited: publishing creates a new list, and the
-- newest list already in effect is the current one for its category.
CREATE TABLE market_price_lists (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    category VARCHAR NOT NULL,
    unit_type VARCHAR NOT NULL CHECK (unit_type IN ('bird','animal','kg','tray')),
    effective_from DATE NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    published_by VARCHAR(36) REFERENCES operators(id),
    withdrawn_at TIMESTAMPTZ,
    withdrawn_by VARCHAR(36) REFERENCES operators(id),
    withdraw_reason TEXT NOT NULL DEFAULT ''
);
CREATE INDEX ix_market_price_lists_category ON market_price_lists(category);
CREATE INDEX ix_market_price_lists_effective_from ON market_price_lists(effective_from);

CREATE TABLE market_price_bands (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    price_list_id VARCHAR(36) NOT NULL REFERENCES market_price_lists(id),
    position INTEGER NOT NULL,
    label VARCHAR NOT NULL DEFAULT '',
    min_weight_kg NUMERIC(8,3),
    max_weight_kg NUMERIC(8,3),
    price_per_unit NUMERIC(14,2) NOT NULL,
    CONSTRAINT market_price_band_price_positive CHECK (price_per_unit > 0),
    CONSTRAINT market_price_band_weights CHECK ((min_weight_kg IS NULL OR min_weight_kg >= 0)
        AND (max_weight_kg IS NULL OR max_weight_kg > 0)
        AND (min_weight_kg IS NULL OR max_weight_kg IS NULL OR min_weight_kg < max_weight_kg)),
    CONSTRAINT uq_market_price_band_position UNIQUE (price_list_id, position)
);
CREATE INDEX ix_market_price_bands_price_list_id ON market_price_bands(price_list_id);
