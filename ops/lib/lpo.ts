// Local purchase orders (backend/app/purchasing.py).
import type { Debt } from './finance';
import type { Tone } from './format';

export type LpoStatus = 'draft' | 'issued' | 'accepted' | 'closed' | 'cancelled';

export interface LineStock { accepted: string; rejected: string; sold: string; lost: string; on_hand: string }

export interface LpoLine {
  id: string;
  position: number;
  category: string;
  item: string;
  specification: string;
  unit: string;
  unit_price: string;
  quantity: string | null;
  min_weight_kg: string | null;
  max_weight_kg: string | null;
  stock?: LineStock;
  outstanding?: string | null;
}

export interface SupplierSnapshot {
  name: string; alias: string; phone: string; district: string; region: string; farm_address: string; category: string;
}

export interface Lpo {
  id: string;
  lpo_number: string;
  supplier_id: string;
  supplier_snapshot: SupplierSnapshot;
  demand_id: string | null;
  lpo_date: string;
  delivery_start: string;
  delivery_end: string;
  payment_terms_days: number;
  supply_basis: 'call_off' | 'fixed';
  collection_point: string;
  delivery_notes: string[];
  terms: string[];
  status: LpoStatus;
  display_status: LpoStatus | 'expired';
  created_at: string;
  created_by: string | null;
  issued_at: string | null;
  issuer_name: string;
  issuer_position: string;
  supplier_accepted_at: string | null;
  supplier_accepted_name: string;
  supplier_accepted_position: string;
  signed_copy_media_id: string | null;
  closed_at: string | null;
  close_reason: string;
  stamped: boolean;
  received_value: string;
  paid_value: string;
  owed_value: string;
  lines: LpoLine[];
}

export interface LpoReceipt {
  id: string;
  received_on: string;
  notes: string;
  amount: string;
  debt_id: string | null;
  debt: Debt | null;
  created_at: string;
  recorded_by: string | null;
  cancelled_at: string | null;
  cancel_reason: string;
  lines: { lpo_line_id: string; item: string; delivered_quantity: string; accepted_quantity: string;
    rejected_quantity: string; average_weight_kg: string | null; unit_price: string; amount: string }[];
}

export interface LpoDetail extends Lpo {
  internal_notes: string;
  demand: { id: string; requirement_number: string | null; category: string; quantity: string; unit_type: string;
    needed_by_date: string; delivery_region: string; status: string } | null;
  receipts: LpoReceipt[];
  losses: { id: string; lpo_line_id: string; item: string; lost_on: string; quantity: string; reason: string; note: string;
    unit_cost: string; created_at: string; cancelled_at: string | null; recorded_by: string | null }[];
  sales: { sale_id: string; sale_number: string; sold_on: string; buyer_name: string; lpo_line_id: string;
    quantity: string; unit_price: string; status: string }[];
}

export interface SupplierSuggestion {
  supplier_id: string; name: string; alias: string; phone: string; region: string; district: string;
  score: number; available: string; last_price: string | null; reasons: string[];
}

export interface DemandRow {
  id: string;
  requirement_number: string | null;
  category: string;
  product_subtype: string;
  unit_type: string;
  quantity: string;
  secured: string;
  on_lpo: string;
  short: string;
  needed_by_date: string;
  days_left: number | null;
  urgency: 'overdue' | 'urgent' | 'soon' | 'planned';
  delivery_region: string;
  delivery_area: string;
  minimum_weight_kg: string | null;
  maximum_weight_kg: string | null;
  buyer_name: string;
  suppliers: SupplierSuggestion[];
}

export interface LpoStockRow extends LineStock {
  lpo_line_id: string; lpo_id: string; lpo_number: string; item: string; category: string; unit: string;
  unit_price: string; supplier_name: string;
}

export interface Marks {
  stamp: { id: string; created_at: string; uploaded_by: string | null } | null;
  my_signature: { id: string; created_at: string; uploaded_by: string | null } | null;
  admin: boolean;
}

export const LPO_STATUS: Record<string, string> = {
  draft: 'Draft', issued: 'Issued', accepted: 'Accepted by supplier', closed: 'Closed', cancelled: 'Cancelled', expired: 'Window over',
};

export const LOSS_REASONS: [string, string][] = [
  ['died', 'Died'], ['sick', 'Sick / culled'], ['stolen', 'Stolen'], ['spoiled', 'Spoiled'], ['other', 'Other'],
];

export function lpoTone(status: string): Tone {
  if (status === 'draft') return 'warning';
  return status === 'issued' || status === 'accepted' ? 'positive' : 'neutral';
}
