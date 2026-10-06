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
  // held: money held for the buyer; applied: part of the sale; given_back; voided.
  state: 'held' | 'applied' | 'given_back' | 'voided';
  account_name: string | null;
  recorded_by: string | null;
}

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
  updated_by: string | null;
  cancelled_by: string | null;
}

export interface BuyerOrderSummary { total: string; count: number; deposits: string; overdue: number }
