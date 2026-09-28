export type MarketBatch = { id: string; category: string; initial_quantity: string; available_quantity: string; expected_ready_date: string | null; status: string; form: string };
export type MarketSlot = {
  id: string; category: string; delivery_date: string; reservation_deadline: string; quantity_required: string;
  committed_quantity: string; remaining_quantity: string; unit_type: string; region: string; collection_point: string;
  minimum_weight_kg: string | null; maximum_weight_kg: string | null; supply_type: string; price_per_unit: string | null;
  collection_method: string; status: string; reservations_open: boolean; supplier_count: number; internal_note?: string;
  suggested_start_date?: string | null; eligible_batches?: MarketBatch[]; my_reservation?: MarketReservation | null;
};
export type MarketReservation = {
  id: string; market_slot_id: string; supplier_id: string; supplier_batch_id: string | null;
  quantity_requested: string; quantity_approved: string | null; status: string; production_choice: string;
  requested_at: string; reviewed_at: string | null; rejection_reason: string; cancelled_at: string | null;
  slot: MarketSlot; batch: MarketBatch | null; supplier_name?: string; supplier_phone?: string;
};

export const MARKET_PRODUCTS = [
  ['broilers', 'Broilers', 'bird'], ['local_chicken', 'Local chicken', 'bird'], ['layers', 'Layers', 'bird'],
  ['goats', 'Goats', 'animal'], ['cattle', 'Cattle', 'animal'], ['chicken_meat', 'Chicken meat', 'kg'],
  ['beef', 'Beef', 'kg'], ['goat_meat', 'Goat meat', 'kg'], ['eggs', 'Eggs', 'tray'],
] as const;
