// Orders staff take for a buyer by phone or in person (build plan M2.5).
// A commitment until delivered; "Mark delivered" records the sale.

export interface BuyerOrderLine {
  id: string;
  position: number;
  category: string;
  description: string;
  unit: string;
  quantity: string;
  unit_price: string;
  subtotal: string;
}

export interface BuyerOrderPayment {
  id: string;
  kind: 'deposit' | 'refund';
  refund_of: string | null;
  amount: string;
  paid_on: string;
  method: string;
  reference: string;
  note: string;
  applied_payment_id: string | null;
  voided_at: string | null;
  void_reason: string;
  created_at: string;
  // held: money held for the buyer; applied: part of the sale; given_back;
  // moved (to another order of the buyer, 7 October 2026); voided.
  state: 'held' | 'applied' | 'given_back' | 'moved' | 'voided';
  account_name: string | null;
  recorded_by: string | null;
  // For a deposit, on this order: held now, given back, applied to the sale,
  // moved away and moved in. A deposit moved here from another order names it.
  held: string;
  given_back?: string;
  applied?: string;
  moved_out?: string;
  moved_in?: string;
  origin_order_id?: string | null;
  origin_order_number?: string | null;
}

/** Part or all of a deposit moved between two open orders of one buyer. No money moves. */
export interface BuyerOrderDepositMove {
  id: string;
  deposit_id: string;
  amount: string;
  reason: string;
  created_at: string;
  moved_by: string | null;
  direction: 'in' | 'out';
  from_order_id: string;
  from_order_number: string | null;
  to_order_id: string;
  to_order_number: string | null;
}

export interface BuyerOrderMoveTarget { id: string; order_number: string; total_amount: string; ordered_on: string; deposit_held: string }

export interface BuyerOrder {
  id: string;
  order_number: string;
  buyer_profile_id: string;
  buyer_name: string;
  buyer_phone: string;
  ordered_on: string;
  expected_on: string | null;
  notes: string;
  total_amount: string;
  status: 'open' | 'delivered' | 'cancelled';
  sale_id: string | null;
  sale_number: string | null;
  sale_status: string | null;
  delivered_on: string | null;
  created_at: string;
  cancelled_at: string | null;
  cancel_reason: string;
  deposit_held: string;
  unpaid: string;
  overdue: boolean;
  created_by: string | null;
  summary: string;
}

export interface BuyerOrderDetail extends BuyerOrder {
  items: BuyerOrderLine[];
  payments: BuyerOrderPayment[];
  moves: BuyerOrderDepositMove[];
  move_targets: BuyerOrderMoveTarget[];
  updated_by: string | null;
  cancelled_by: string | null;
}

export interface BuyerOrderSummary { total: string; count: number; deposits: string; overdue: number }
