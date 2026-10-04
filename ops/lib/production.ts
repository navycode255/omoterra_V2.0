import { titleCase } from './format';
export type Batch = { id: string; supplier_id: string; supplier_name: string; category: string; subtype: string; initial_quantity: string; current_quantity: string; reserved_quantity: string; available_to_commit: string; current_age: string | null; age_unit: string; expected_ready_date: string | null; expected_min_weight_kg: string | null; expected_max_weight_kg: string | null; actual_average_weight_kg: string | null; form: string; region: string; private_pickup_location: string; asking_price_per_unit: string | null; buyer_price_per_unit?: string | null; supplier_payout_price_per_unit?: string | null; status: string; approved_at: string | null };

export function batchTitle(batch: Batch) { return `${titleCase(batch.category)}${batch.subtype ? ` · ${batch.subtype}` : ''}`; }
export function batchStatus(batch: Batch) {
  if (batch.status === 'rejected') return { label: 'Rejected', tone: 'rejected' };
  if (batch.status === 'draft') return { label: 'Draft', tone: 'draft' };
  if (batch.approved_at) return { label: 'Reviewed', tone: 'reviewed' };
  if (batch.status === 'pending') return { label: 'Pending', tone: 'pending' };
  return { label: 'Needs review', tone: 'review' };
}
