import type { Page } from './paging';

/** Received lots and their dated movements (backend app/lots.py, build plan M2.1). */
export type LotTable = 'supplier_collections' | 'lpo_lines' | 'opening_stock';

export interface LotFigures {
  received: string;
  corrected: string;
  sold: string;
  returned_by_buyers: string;
  not_recovered: string;
  died: string;
  lost: string;
  returned_to_supplier: string;
  at_locations: string;
  counted: string;
  on_hand: string;
}

export interface Lot extends LotFigures {
  lot_table: LotTable;
  lot_id: string;
  number: string;
  category: string;
  description: string;
  unit: string;
  unit_cost: string;
  received_on: string | null;
  supplier_id: string | null;
  supplier_name: string;
  batch_id: string | null;
  href: string;
  value_on_hand: string;
}

export type LotPage = Page<Lot> & {
  summary: { as_of: string; on_hand_value: string; lots_with_stock: number; on_hand: Record<string, string> };
};

export interface LotMovement {
  kind: string;
  date: string;
  delta: string;
  quantity: string;
  unit_cost: string | null;
  source_table: string;
  source_id: string;
  sale_id: string | null;
  sale_number: string | null;
  note: string;
  recorded_by: string;
  on_hand: string;
  counted_quantity: string | null;
  evidence: string | null;
}

export type LotDetail = Omit<Lot, 'value_on_hand'> & {
  as_of: string | null;
  movements: LotMovement[];
  cancelled_adjustments: { id: string; kind: string; occurred_on: string; quantity: string; reason: string; cancel_reason: string; cancelled_at: string }[];
};

export const LOT_KINDS: Record<LotTable, string> = {
  supplier_collections: 'Delivery note',
  lpo_lines: 'LPO',
  opening_stock: 'Opening stock',
};

export const MOVEMENT_LABELS: Record<string, string> = {
  received: 'Received',
  receipt_correction: 'Receipt corrected (never delivered)',
  sold: 'Sold',
  buyer_return_accepted: 'Returned by buyer, accepted back',
  sale_cancelled_never_left: 'Sale cancelled, goods never left',
  not_recovered: 'Not recovered from a sale',
  mortality: 'Died',
  lost: 'Lost',
  returned_to_supplier: 'Returned to supplier',
  to_location: 'Moved to a kitchen',
  from_location: 'Back from a kitchen',
  count_adjustment: 'Stock count difference',
};

export const lotHref = (table: LotTable, id: string) => `/stock/${table}/${id}`;
