-- Additive migration. Existing stock balances are preserved.
BEGIN;
CREATE TABLE stock_movements (
	listing_id VARCHAR(36) NOT NULL, 
	kind VARCHAR NOT NULL, 
	total_delta NUMERIC(14, 3) NOT NULL, 
	reserved_delta NUMERIC(14, 3) NOT NULL, 
	sold_delta NUMERIC(14, 3) NOT NULL, 
	total_after NUMERIC(14, 3) NOT NULL, 
	reserved_after NUMERIC(14, 3) NOT NULL, 
	sold_after NUMERIC(14, 3) NOT NULL, 
	reason TEXT NOT NULL, 
	reference VARCHAR NOT NULL, 
	actor_id VARCHAR(36), 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(listing_id) REFERENCES listings (id), 
	UNIQUE (reference), 
	FOREIGN KEY(actor_id) REFERENCES users (id)
);

CREATE INDEX ix_stock_movements_listing_id ON stock_movements (listing_id);

CREATE TABLE stock_sales (
	listing_id VARCHAR(36) NOT NULL, 
	supplier_id VARCHAR(36) NOT NULL, 
	source VARCHAR NOT NULL, 
	quantity NUMERIC(14, 3) NOT NULL, 
	sold_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	unit_price NUMERIC(14, 2), 
	order_item_id VARCHAR(36), 
	note TEXT NOT NULL, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CHECK (quantity > 0), 
	CHECK (source IN ('external', 'omoterra')), 
	FOREIGN KEY(listing_id) REFERENCES listings (id), 
	FOREIGN KEY(supplier_id) REFERENCES users (id), 
	UNIQUE (order_item_id), 
	FOREIGN KEY(order_item_id) REFERENCES order_items (id)
);

CREATE INDEX ix_stock_sales_listing_id ON stock_sales (listing_id);

CREATE INDEX ix_stock_sales_supplier_id ON stock_sales (supplier_id);

CREATE TABLE stock_sale_reversals (
	sale_id VARCHAR(36) NOT NULL, 
	supplier_id VARCHAR(36) NOT NULL, 
	reason TEXT NOT NULL, 
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (sale_id), 
	FOREIGN KEY(sale_id) REFERENCES stock_sales (id), 
	FOREIGN KEY(supplier_id) REFERENCES users (id)
);

CREATE FUNCTION omoterra_reject_history_edit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Stock history and sale records are append-only'; END; $$;
CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON stock_movements FOR EACH ROW EXECUTE FUNCTION omoterra_reject_history_edit();
CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON stock_sales FOR EACH ROW EXECUTE FUNCTION omoterra_reject_history_edit();
CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON stock_sale_reversals FOR EACH ROW EXECUTE FUNCTION omoterra_reject_history_edit();
COMMIT;
