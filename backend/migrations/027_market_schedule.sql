CREATE TABLE market_slots (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    category VARCHAR NOT NULL,
    delivery_date DATE NOT NULL,
    reservation_deadline DATE NOT NULL,
    quantity_required NUMERIC(14,3) NOT NULL CHECK (quantity_required > 0),
    unit_type VARCHAR NOT NULL CHECK (unit_type IN ('bird','animal','kg','tray')),
    region VARCHAR NOT NULL DEFAULT '',
    collection_point VARCHAR NOT NULL DEFAULT '',
    minimum_weight_kg NUMERIC(8,3),
    maximum_weight_kg NUMERIC(8,3),
    supply_type VARCHAR NOT NULL DEFAULT 'live' CHECK (supply_type IN ('live','dressed','chilled','frozen')),
    price_per_unit NUMERIC(14,2),
    collection_method VARCHAR NOT NULL CHECK (collection_method IN ('omoterra_collects','supplier_delivers')),
    status VARCHAR NOT NULL DEFAULT 'open' CHECK (status IN ('draft','open','full','closed','cancelled','completed')),
    internal_note TEXT NOT NULL DEFAULT '',
    created_by VARCHAR(36) REFERENCES operators(id),
    updated_by VARCHAR(36) REFERENCES operators(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT market_slot_deadline_before_delivery CHECK (reservation_deadline <= delivery_date),
    CONSTRAINT market_slot_weight_range CHECK (minimum_weight_kg IS NULL OR maximum_weight_kg IS NULL OR minimum_weight_kg <= maximum_weight_kg)
);
CREATE INDEX ix_market_slots_category ON market_slots(category);
CREATE INDEX ix_market_slots_delivery_date ON market_slots(delivery_date);
CREATE INDEX ix_market_slots_reservation_deadline ON market_slots(reservation_deadline);
CREATE INDEX ix_market_slots_region ON market_slots(region);
CREATE INDEX ix_market_slots_status ON market_slots(status);

CREATE TABLE market_reservations (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    market_slot_id VARCHAR(36) NOT NULL REFERENCES market_slots(id),
    supplier_id VARCHAR(36) NOT NULL REFERENCES users(id),
    supplier_batch_id VARCHAR(36) REFERENCES supplier_batches(id),
    quantity_requested NUMERIC(14,3) NOT NULL CHECK (quantity_requested > 0),
    quantity_approved NUMERIC(14,3) CHECK (quantity_approved IS NULL OR quantity_approved > 0),
    status VARCHAR NOT NULL DEFAULT 'requested' CHECK (status IN ('requested','approved','rejected','cancelled','completed')),
    production_choice VARCHAR NOT NULL CHECK (production_choice IN ('existing','planned')),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed_at TIMESTAMPTZ,
    reviewed_by VARCHAR(36) REFERENCES operators(id),
    rejection_reason TEXT NOT NULL DEFAULT '',
    cancelled_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_market_reservation_supplier_slot UNIQUE (market_slot_id, supplier_id)
);
CREATE INDEX ix_market_reservations_market_slot_id ON market_reservations(market_slot_id);
CREATE INDEX ix_market_reservations_supplier_id ON market_reservations(supplier_id);
CREATE INDEX ix_market_reservations_supplier_batch_id ON market_reservations(supplier_batch_id);
CREATE INDEX ix_market_reservations_status ON market_reservations(status);
