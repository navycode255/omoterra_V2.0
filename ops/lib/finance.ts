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
  // On cash book rows only.
  direction?: Direction;
  party_name?: string;
  description?: string;
  sale_id?: string | null;
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

export interface DebtDetail extends Debt {
  created_by: string | null;
  sale_number: string | null;
  payments: LedgerPayment[];
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
