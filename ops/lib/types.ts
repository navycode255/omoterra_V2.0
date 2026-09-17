// Shapes returned by the Omoterra backend's /ops endpoints. Money and quantity
// values cross the API as decimal strings and are never parsed into floats for
// display or arithmetic that affects what an operator acts on.

export type ListingStatus =
  | 'pending_review'
  | 'live'
  | 'needs_confirmation'
  | 'paused'
  | 'sold_out'
  | 'rejected';

export type InternalStatus =
  | 'requested'
  | 'supply_confirmed'
  | 'reserved'
  | 'pickup_scheduled'
  | 'collected'
  | 'quality_checked'
  | 'in_transit'
  | 'delivered'
  | 'completed'
  | 'cancelled'
  | 'payment_failed';

export type PaymentStatus = 'pending' | 'partial' | 'paid' | 'failed';

export type SourcingStatus =
  | 'submitted'
  | 'sourcing'
  | 'supply_found'
  | 'confirmed'
  | 'converted'
  | 'cancelled';

export type BusinessStatus =
  | 'new'
  | 'contacted'
  | 'interested'
  | 'setup_in_progress'
  | 'converted'
  | 'closed';

export interface Listing {
  id: string;
  supplier_id: string;
  category: string;
  unit_type: 'bird' | 'animal' | 'kg';
  region: string;
  photos: string[];
  specs: Record<string, string>;
  farmer_asking_price_per_unit: string;
  supplier_payout_price_per_unit: string | null;
  buyer_price_per_unit: string | null;
  quantity_total: string;
  quantity_reserved: string;
  quantity_sold: string;
  quantity_available: string;
  listing_status: ListingStatus;
  confirmation_due_at: string | null;
}

export interface OrderItem {
  id: string;
  category: string;
  unit_type: string;
  quantity: string;
  unit_price: string;
  subtotal: string;
}

export interface DeliverySnapshot {
  label?: string;
  recipient_name?: string;
  phone?: string;
  region?: string;
  district_area?: string;
  address_text?: string;
}

export interface Order {
  id: string;
  preferred_delivery_date: string;
  payment_method: 'pay_now' | 'pay_on_delivery';
  payment_status: PaymentStatus;
  total_amount: string;
  amount_received: string;
  created_at: string;
  activity: { label: string; at: string }[];
  customer_status: string;
  internal_status: InternalStatus;
  message: string | null;
  delivery_address: DeliverySnapshot | null;
  items: OrderItem[];
  expected_quantity: string;
  actual_quantity: string | null;
  rejected_quantity: string | null;
}

export interface OrderDetail extends Order {
  collection_notes: string;
  collection_photos: string[];
  suppliers: {
    listing_id: string;
    supplier_id: string;
    phone: string;
    legal_name: string;
    internal_pickup_address: string;
  }[];
}

export interface SourcingRequest {
  id: string;
  buyer_id: string;
  category: string;
  unit_type: string;
  quantity: string;
  weight_or_size_requirement: string;
  live_dressed_or_cut: string;
  needed_by_date: string;
  delivery_area: string;
  notes: string;
  quantity_secured: string;
  admin_notes: string;
  status: SourcingStatus;
  converted_order_id: string | null;
  created_at: string;
}

export interface Settlement {
  id: string;
  supplier_id: string;
  order_item_id: string;
  farmer_asking_price_per_unit: string;
  supplier_payout_price_per_unit: string;
  commission_amount_per_unit: string;
  quantity: string;
  total_payable: string;
  status: 'pending' | 'paid';
  paid_at: string | null;
  payment_reference: string | null;
  created_at: string;
}

export interface Payment {
  id: string;
  order_id: string;
  buyer_id: string;
  buyer_name: string;
  amount: string;
  received_amount: string;
  balance: string;
  method: 'pay_now' | 'pay_on_delivery';
  status: PaymentStatus;
  internal_status: InternalStatus;
  provider_transaction_id: string | null;
  paid_at: string | null;
  created_at: string;
}

export interface BusinessOpportunity {
  id: string;
  buyer_id: string;
  business_type: string;
  area: string;
  budget_range: string;
  has_premises: boolean;
  wants_stock: boolean;
  target_start_date: string;
  status: BusinessStatus;
  internal_notes: string;
}

export interface SupplierRow {
  id: string;
  phone: string;
  region: string;
  public_alias: string;
  alias_approved: boolean;
  legal_name: string;
  completed_supplies_count: number;
  live_listings: number;
  pending_listings: number;
  pending_settlement_total: string;
}

export interface SupplierDetail extends Omit<SupplierRow, 'live_listings' | 'pending_listings' | 'pending_settlement_total'> {
  name: string;
  internal_pickup_address: string;
  listings: Listing[];
  settlements: Settlement[];
}

export interface BuyerRow {
  id: string;
  name: string;
  phone: string;
  region: string;
  buyer_type: string | null;
  order_count: number;
  request_count: number;
}

export interface Address {
  id: string;
  label: string;
  recipient_name: string;
  phone: string;
  region: string;
  district_area: string;
  address_text: string;
}

export interface BuyerDetail extends Omit<BuyerRow, 'order_count' | 'request_count'> {
  created_at: string;
  addresses: Address[];
  orders: Order[];
  requests: SourcingRequest[];
}

export interface Summary {
  orders_today: number;
  sales_today: string;
  gross_margin_today: string;
  pending_settlements: string;
  attention: {
    listings_pending_review: number;
    listings_needing_confirmation: number;
    sourcing_unmatched: number;
    orders_in_progress: number;
    payments_pending: number;
    settlements_pending: number;
  };
}
