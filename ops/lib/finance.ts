// Types and labels for sales, the debts ledger and promotions
// (backend/app/finance.py and backend/app/promotions.py).

export type Direction = 'receivable' | 'payable';

export interface LedgerPayment {
  id: string;
  debt_id: string;
  amount: string;
  paid_on: string;
  method: string;
  reference: string;
  note: string;
  created_at: string;
  recorded_by: string | null;
  reversed: boolean;
  reversed_at: string | null;
  reversed_by: string | null;
  reverse_reason: string;
  /** The supplier transfer this payment is part of (supplier invoices only). */
  supplier_payment_id?: string | null;
  /** Taken off its invoice; the money stayed with the supplier as credit. */
  moved_to_credit?: boolean;
  // On cash book rows only.
  direction?: Direction;
  party_name?: string;
  description?: string;
  sale_id?: string | null;
}

/**
 * One cash book row (GET /ops/ledger/payments): a real movement of money.
 * A supplier transfer is one row however many invoices it pays; a refund is
 * its own money-in row; reversed installments are kept for the history.
 */
export interface CashMovement {
  id: string;
  kind: 'payment' | 'allocation' | 'transfer' | 'refund';
  flow: 'in' | 'out';
  direction: Direction;
  paid_on: string;
  amount: string;
  method: string;
  reference: string;
  note: string;
  party_name: string;
  description: string | null;
  debt_id: string | null;
  sale_id: string | null;
  supplier_id: string | null;
  transfer_id: string | null;
  invoices: number;
  created_at: string;
  recorded_by: string | null;
  reversed: boolean;
  moved_to_credit: boolean;
  reversed_by: string | null;
  reverse_reason: string;
}

/** A supplier transfer with where its money is now (backend/app/transfers.py). */
export interface TransferMoney {
  amount: string;
  allocated: string;
  credit: string;
  refunded: string;
  entry_error: string;
  unresolved: string;
  transferred: string;
  net_paid: string;
}

export interface SupplierCredit {
  supplier_id: string;
  credit: string;
  unresolved: string;
  transfers: (TransferMoney & { id: string; paid_on: string; method: string; reference: string; origin: string })[];
}

export interface Debt {
  id: string;
  direction: Direction;
  party_kind: 'buyer' | 'supplier' | 'other';
  buyer_profile_id: string | null;
  supplier_id: string | null;
  party_name: string;
  party_phone: string;
  description: string;
  amount: string;
  paid_amount: string;
  balance: string;
  incurred_on: string;
  due_on: string | null;
  overdue: boolean;
  source: 'sale' | 'sale_cost' | 'manual' | 'expense' | 'lpo' | 'batch_receipt';
  expense_category: string | null;
  sale_id: string | null;
  lpo_id: string | null;
  status: 'open' | 'settled' | 'cancelled';
  created_at: string;
  cancelled_at: string | null;
  cancel_reason: string;
}

/** One reasoned correction of a supplier debt (backend financial_adjustments, M1.4). */
export interface FinancialAdjustment {
  id: string;
  kind: 'wrong_supplier' | 'duplicate_liability' | 'free_stock' | 'cost_never_existed'
    | 'receipt_correction' | 'supplier_credit_note' | 'historical_batch_link';
  entity_type: string;
  /** The debt corrected. */
  entity_id: string;
  sale_id: string | null;
  /** The corrected supplier's debt (wrong supplier) or the debt duplicated. */
  related_debt_id: string | null;
  reason: string;
  before: Record<string, unknown>;
  after: Record<string, unknown>;
  linked_ids: Record<string, unknown>;
  created_at: string;
  recorded_by: string | null;
}

export const ADJUSTMENT_LABELS: Record<FinancialAdjustment['kind'], string> = {
  wrong_supplier: 'Wrong supplier',
  duplicate_liability: 'Duplicate liability',
  free_stock: 'Free or gift stock',
  cost_never_existed: 'Cost never existed',
  receipt_correction: 'Receipt corrected',
  supplier_credit_note: 'Supplier credit note',
  historical_batch_link: 'Linked to a delivery note',
};

export interface DebtDetail extends Debt {
  created_by: string | null;
  sale_number: string | null;
  /** A delivery note's payable: corrected, returned and credited on the note (M1.6). */
  collection_id?: string | null;
  collection_number?: string | null;
  payments: LedgerPayment[];
  adjustments: FinancialAdjustment[];
  /** Other open debts to the same supplier this one may duplicate. */
  duplicate_candidates: Pick<Debt, 'id' | 'description' | 'amount' | 'paid_amount' | 'incurred_on' | 'source' | 'status'>[];
}


export interface SupplierCollectionStock {
  id: string;
  collection_number: string;
  supplier_id: string;
  supplier_name: string;
  supplier_phone: string;
  batch_id: string;
  category: string;
  subtype: string;
  unit: string;
  received_on: string;
  delivered_quantity: string;
  accepted_quantity: string;
  rejected_quantity: string;
  average_weight_kg: string | null;
  unit_cost: string;
  amount: string;
  sold: string;
  on_hand: string;
  notes: string;
  debt_id: string | null;
  created_at: string;
  cancelled_at: string | null;
  cancel_reason: string;
  /** 'delivery' (Receive stock), 'sale' (collected and sold together) or 'historical' (linked later). */
  origin?: 'delivery' | 'sale' | 'historical';
  sale_id?: string | null;
  not_recovered?: string;
  returned?: string;
  /** Died, culled, stolen or spoiled before sale (uncancelled losses). */
  lost?: string;
}

/** What happened to received goods a sale no longer sells (rule R2). */
export type GoodsOutcome = 'never_left' | 'buyer_return_accepted' | 'not_recovered';

export const GOODS_OUTCOMES: [GoodsOutcome, string][] = [
  ['never_left', 'They never left Omoterra: back on hand'],
  ['buyer_return_accepted', 'The buyer returned them and we accepted them back: back on hand'],
  ['not_recovered', 'Not recovered: record as a loss pending investigation'],
];

export interface CollectionMovement {
  id: string;
  kind: GoodsOutcome | 'returned_to_supplier' | 'receipt_correction' | 'lost';
  /** 'lost' only: died, sick, stolen, spoiled or other. */
  loss_reason?: string | null;
  cancelled_at?: string | null;
  cancelled_by?: string | null;
  cancel_reason?: string;
  quantity: string;
  occurred_on: string;
  unit_cost: string;
  value: string;
  sale_id: string | null;
  sale_number: string | null;
  reason: string;
  evidence: string;
  note: string;
  created_at: string;
  recorded_by: string | null;
  credit_note: SupplierCreditNote | null;
  awaiting_credit: boolean;
}

export interface SupplierCreditNote {
  id: string; movement_id: string; amount: string; issued_on: string; reference: string; note: string; created_at: string;
}

/** GET /ops/supplier-collections/{id}: a delivery note with its physical events (M1.6). */
export interface DeliveryNoteDetail extends SupplierCollectionStock {
  confirmed_by: string | null;
  confirmed_at: string | null;
  recorded_by: string | null;
  sale_number: string | null;
  movements: CollectionMovement[];
  credit_notes: SupplierCreditNote[];
  credited: string;
  awaiting_credit_quantity: string;
  awaiting_credit_value: string;
  payable: { id: string; amount: string; paid_amount: string; status: string; balance: string } | null;
}

export interface SaleItem {
  id: string;
  category: string;
  description: string;
  unit: string;
  quantity: string;
  unit_price: string;
  subtotal: string;
  supplier_id: string | null;
  supplier_name: string;
  unit_cost: string | null;
  cost_total: string | null;
  lpo_line_id: string | null;
  supplier_collection_id: string | null;
  supplier_batch_id?: string | null;
}

// A supplier batch with birds still to take (GET /ops/supplier-batches/open).
export interface OpenBatch {
  id: string; supplier_id: string; category: string; subtype: string;
  registered: string; remaining: string; created_at: string; asking_price_per_unit: string | null;
}

// Totals for the sales a list shows (GET /ops/sales -> summary).
export interface SalesSummary {
  sales_total: string; sales_count: number; received: string;
  buyer_owes: string; buyer_owes_count: number; supplier_owed: string; supplier_owed_count: number;
}

export interface Sale {
  id: string;
  sale_number: string;
  sold_on: string;
  buyer_profile_id: string;
  buyer_user_id: string | null;
  buyer_name: string;
  buyer_phone: string;
  total_amount: string;
  cost_amount: string;
  margin: string;
  received_amount: string;
  balance: string;
  supplier_balance: string;
  notes: string;
  status: 'active' | 'cancelled';
  created_at: string;
  created_by: string | null;
  cancelled_at: string | null;
  cancel_reason: string;
  cancel_goods?: GoodsOutcome | null;
  receivable_id: string | null;
}

export interface SaleDetail extends Sale {
  items: SaleItem[];
  debts: (Debt & { payments: LedgerPayment[] })[];
}

export interface Party {
  party_name: string;
  party_phone: string;
  party_kind: string;
  buyer_profile_id: string | null;
  supplier_id: string | null;
  balance: string;
  debts: number;
  oldest: string;
  overdue: string;
}

export interface FinanceSummary {
  today: { date: string; sales: string; sales_count: number; money_in: string; money_out: string };
  month: { start: string; sales: string; money_in: string; money_out: string };
  all_time: { sales: string; money_in: string; money_out: string };
  profit_today: ProfitTotals;
  profit_month: ProfitTotals;
  owed_to_me: { ledger: string; marketplace: string; total: string; overdue: string };
  i_owe: { ledger: string; marketplace: string; total: string; overdue: string };
  by_method: { method: string; in: string; out: string; net: string }[];
  debtors: Party[];
  creditors: Party[];
  recent_payments: LedgerPayment[];
  /** Last 30 days, oldest first. */
  trends: { owed_to_me: string[]; i_owe: string[]; revenue: string[]; net_profit: string[] };
}

export interface ProfitTotals {
  start: string;
  end: string;
  sales: string;
  stock_cost: string;
  marketplace_sales: string;
  marketplace_cost: string;
  revenue: string;
  gross_profit: string;
  expenses: string;
  stock_lost: string;
  net_profit: string;
  expenses_by_category: { category: string; amount: string }[];
}

export interface ProfitReport extends ProfitTotals {
  days: (Omit<ProfitTotals, 'start' | 'end' | 'expenses_by_category'> & { date: string })[];
}

export const EXPENSE_CATEGORIES: [string, string][] = [
  ['labour', 'Labour / casual workers'],
  ['transport', 'Transport'],
  ['fuel', 'Fuel'],
  ['feed', 'Feed'],
  ['medicine_vet', 'Medicine / vet'],
  ['packaging', 'Packaging'],
  ['processing', 'Slaughter / processing'],
  ['market_fees', 'Market fees / levies'],
  ['rent', 'Rent'],
  ['utilities', 'Water / electricity'],
  ['airtime_data', 'Airtime / data'],
  ['equipment', 'Equipment'],
  ['repairs', 'Repairs'],
  ['other', 'Other'],
];

export function expenseLabel(value: string | null) {
  return EXPENSE_CATEGORIES.find(([key]) => key === value)?.[1] ?? value ?? '';
}

export interface Parties {
  buyers: { kind: 'profile' | 'user'; id: string; name: string; phone: string; region: string }[];
  suppliers: { id: string; name: string; alias: string; phone: string }[];
}

export interface Promotion {
  id: string;
  created_at: string;
  audience: 'buyers' | 'suppliers' | 'everyone';
  title: string;
  message: string;
  send_sms: boolean;
  send_in_app: boolean;
  recipient_count: number;
  in_app_count: number;
  created_by: string | null;
  sms: { queued: number; sent: number; failed: number; skipped: number };
}

export interface PromotionDetail extends Promotion {
  recipients: {
    id: string;
    phone: string;
    name: string;
    user_id: string | null;
    buyer_profile_id: string | null;
    sms_status: 'queued' | 'sent' | 'failed' | 'skipped';
    sms_error: string;
    sms_attempts: number;
    sent_at: string | null;
  }[];
}

export const METHODS: [string, string][] = [
  ['cash', 'Cash'],
  ['mpesa', 'M-Pesa'],
  ['airtel_money', 'Airtel Money'],
  ['mixx_by_yas', 'Mixx by Yas'],
  ['halopesa', 'HaloPesa'],
  ['bank_transfer', 'Bank transfer'],
  ['cheque', 'Cheque'],
  ['other', 'Other'],
];

export function methodLabel(value: string) {
  return METHODS.find(([key]) => key === value)?.[1] ?? value;
}

export const UNITS: [string, string][] = [
  ['bird', 'Birds'],
  ['animal', 'Animals'],
  ['kg', 'Kg'],
  ['tray', 'Trays'],
  ['piece', 'Pieces'],
];

// The unit a product is normally sold in.
export const DEFAULT_UNIT: Record<string, string> = {
  broilers: 'bird', local_chicken: 'bird', layers: 'bird', goats: 'animal', cattle: 'animal',
  chicken_meat: 'kg', beef: 'kg', goat_meat: 'kg', eggs: 'tray',
};

export const PRODUCTS: [string, string][] = [
  ['local_chicken', 'Local chicken'],
  ['broilers', 'Broilers'],
  ['layers', 'Layers'],
  ['eggs', 'Eggs'],
  ['chicken_meat', 'Chicken meat'],
  ['goats', 'Goats'],
  ['goat_meat', 'Goat meat'],
  ['cattle', 'Cattle'],
  ['beef', 'Beef'],
];

/** Today's date (YYYY-MM-DD) on Omoterra's clock, for date inputs. */
/** The first and last day of today's calendar month (YYYY-MM-DD). */
export function thisMonth() {
  const now = today();
  const [year, month] = now.split('-').map(Number);
  return { start: `${now.slice(0, 8)}01`, end: new Date(Date.UTC(year, month, 0)).toISOString().slice(0, 10) };
}

export function today() {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Dar_es_Salaam' }).format(new Date());
}

/** A calendar date (YYYY-MM-DD) as "27 Sept 2026", without shifting time zones. */
export function day(value: string | null | undefined) {
  if (!value) return '—';
  const [year, month, date] = value.split('-').map(Number);
  if (!year || !month || !date) return value;
  return new Date(Date.UTC(year, month - 1, date)).toLocaleDateString('en-GB', {
    day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC',
  });
}
