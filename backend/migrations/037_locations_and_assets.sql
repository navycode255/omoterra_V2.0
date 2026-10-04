-- Location investment, assets, stock transfers and attribution.

BEGIN;


CREATE TABLE operating_locations (
	name VARCHAR(150) NOT NULL, 
	address TEXT NOT NULL, 
	notes TEXT NOT NULL, 
	daily_target NUMERIC(14, 3) NOT NULL, 
	active BOOLEAN NOT NULL, 
	created_by VARCHAR(36), 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT location_target_positive CHECK (daily_target >= 0), 
	UNIQUE (name), 
	FOREIGN KEY(created_by) REFERENCES operators (id)
)

;


CREATE TABLE business_assets (
	location_id VARCHAR(36) NOT NULL, 
	name VARCHAR(150) NOT NULL, 
	purchased_on DATE NOT NULL, 
	cost NUMERIC(14, 2) NOT NULL, 
	residual_value NUMERIC(14, 2) NOT NULL, 
	useful_months INTEGER NOT NULL, 
	depreciation_start DATE NOT NULL, 
	retired_on DATE, 
	notes TEXT NOT NULL, 
	created_by VARCHAR(36), 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT asset_cost_values CHECK (cost >= 0 AND residual_value >= 0 AND residual_value <= cost), 
	CONSTRAINT asset_useful_life CHECK (useful_months > 0 AND useful_months <= 1200), 
	CONSTRAINT asset_dates CHECK (depreciation_start >= purchased_on AND (retired_on IS NULL OR retired_on >= depreciation_start)), 
	FOREIGN KEY(location_id) REFERENCES operating_locations (id), 
	FOREIGN KEY(created_by) REFERENCES operators (id)
)

;

CREATE INDEX ix_business_assets_location_id ON business_assets (location_id);


CREATE TABLE location_investments (
	location_id VARCHAR(36) NOT NULL, 
	invested_on DATE NOT NULL, 
	description TEXT NOT NULL, 
	amount NUMERIC(14, 2) NOT NULL, 
	created_by VARCHAR(36), 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT location_investment_positive CHECK (amount > 0), 
	FOREIGN KEY(location_id) REFERENCES operating_locations (id), 
	FOREIGN KEY(created_by) REFERENCES operators (id)
)

;

CREATE INDEX ix_location_investments_location_id ON location_investments (location_id);


CREATE TABLE location_allocations (
	opening_source_id VARCHAR(36) REFERENCES location_allocations(id),
	location_id VARCHAR(36) NOT NULL, 
	allocated_on DATE NOT NULL, 
	category VARCHAR(32) NOT NULL, 
	description VARCHAR(200) NOT NULL, 
	unit VARCHAR(16) NOT NULL, 
	quantity NUMERIC(14, 3) NOT NULL, 
	unit_cost NUMERIC(14, 2) NOT NULL, 
	returned_quantity NUMERIC(14, 3) NOT NULL, 
	lpo_line_id VARCHAR(36), 
	supplier_collection_id VARCHAR(36), 
	notes TEXT NOT NULL, 
	created_by VARCHAR(36), 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT location_allocation_quantities CHECK (quantity > 0 AND unit_cost >= 0 AND returned_quantity >= 0 AND returned_quantity <= quantity), 
	CONSTRAINT location_allocation_source CHECK ((CASE WHEN lpo_line_id IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN supplier_collection_id IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN opening_source_id IS NOT NULL THEN 1 ELSE 0 END) <= 1), 
	CONSTRAINT location_allocation_unit CHECK (unit IN ('bird','animal','kg','tray','piece')), 
	FOREIGN KEY(location_id) REFERENCES operating_locations (id), 
	FOREIGN KEY(lpo_line_id) REFERENCES lpo_lines (id), 
	FOREIGN KEY(supplier_collection_id) REFERENCES supplier_collections (id), 
	FOREIGN KEY(created_by) REFERENCES operators (id)
)

;

CREATE INDEX ix_location_allocations_lpo_line_id ON location_allocations (lpo_line_id);

CREATE INDEX ix_location_allocations_opening_source_id ON location_allocations (opening_source_id);

CREATE INDEX ix_location_allocations_location_id ON location_allocations (location_id);

CREATE INDEX ix_location_allocations_supplier_collection_id ON location_allocations (supplier_collection_id);

CREATE INDEX ix_location_allocations_allocated_on ON location_allocations (allocated_on);


CREATE TABLE location_stock_events (
	allocation_id VARCHAR(36) NOT NULL, 
	occurred_on DATE NOT NULL, 
	kind VARCHAR(16) NOT NULL, 
	quantity NUMERIC(14, 3) NOT NULL, 
	note TEXT NOT NULL, 
	created_by VARCHAR(36), 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT location_stock_event_kind CHECK (kind IN ('returned','lost')), 
	CONSTRAINT location_stock_event_quantity CHECK (quantity > 0), 
	FOREIGN KEY(allocation_id) REFERENCES location_allocations (id), 
	FOREIGN KEY(created_by) REFERENCES operators (id)
)

;

CREATE INDEX ix_location_stock_events_allocation_id ON location_stock_events (allocation_id);

CREATE INDEX ix_location_stock_events_occurred_on ON location_stock_events (occurred_on);

ALTER TABLE sales ADD COLUMN location_id VARCHAR(36) REFERENCES operating_locations(id);

CREATE INDEX ix_sales_location_id ON sales (location_id);

ALTER TABLE ledger_debts ADD COLUMN location_id VARCHAR(36) REFERENCES operating_locations(id);

CREATE INDEX ix_ledger_debts_location_id ON ledger_debts (location_id);

ALTER TABLE sale_items ADD COLUMN location_allocation_id VARCHAR(36) REFERENCES location_allocations(id);

CREATE INDEX ix_sale_items_location_allocation_id ON sale_items (location_allocation_id);

ALTER TABLE sale_items DROP CONSTRAINT sale_item_cost_has_supplier;
ALTER TABLE sale_items ADD CONSTRAINT sale_item_cost_has_supplier CHECK (
 (unit_cost IS NULL AND supplier_id IS NULL AND supplier_name = '')
 OR (unit_cost IS NOT NULL AND (supplier_id IS NOT NULL OR supplier_name <> '' OR location_allocation_id IS NOT NULL))
);
COMMIT;
