import type { Page } from './paging';

/** Money accounts and reconciliation (backend app/accounts.py, build plan M2.3). */
export type AccountKind = 'cash' | 'bank' | 'mobile_wallet';

export interface AccountOption { id: string; name: string; kind: AccountKind; provider: string }

export interface AccountCheck {
  id: string; kind: 'count' | 'statement'; checked_on: string; balance: string; expected: string; difference: string;
  evidence: string; resolution: string; resolved_at: string | null; created_at: string;
}

export interface MoneyAccount extends AccountOption {
  number: string; cutoff_on: string; opening_balance: string; opening_evidence: string; verified_by: string;
  active: boolean; balance: string | null; as_of: string; last_check: AccountCheck | null;
  reconciled_through: string | null; open_differences: number; pre_cutoff_open: number;
}

export interface AccountsPage {
  items: MoneyAccount[]; total: string;
  unassigned: { count: number; in: string; out: string };
  pre_cutoff_open: number; open_differences: number;
}

export interface AccountLine {
  source_table: string; id: string; kind: string; date: string; flow: 'in' | 'out'; amount: string; method: string;
  reference: string; party_name: string; description: string; balance: string; restated: boolean;
}

export interface PreCutoffRow {
  assignment_id: string; account: string; source_table: string; id: string; date: string; flow: 'in' | 'out';
  amount: string; description: string; party_name: string; resolution: string | null; note: string;
}

export type AccountDetail = MoneyAccount & { movements: Page<AccountLine>; checks: AccountCheck[]; pre_cutoff: PreCutoffRow[] };

export interface UnassignedRow {
  id: string; source_table: string; kind: string; flow: 'in' | 'out'; paid_on: string; amount: string; method: string;
  reference: string; party_name: string; description: string; note: string;
}

export const ACCOUNT_KINDS: [AccountKind, string][] = [['cash', 'Cash box'], ['bank', 'Bank account'], ['mobile_wallet', 'Mobile wallet']];

/** The account a payment method most likely went through, when exactly one fits. Staff can change it. */
export function accountForMethod(accounts: AccountOption[], method: string): string {
  const words: Record<string, string> = { mpesa: 'pesa', airtel_money: 'airtel', mixx_by_yas: 'mixx', halopesa: 'halo' };
  const fits = accounts.filter((a) => method === 'cash' ? a.kind === 'cash'
    : method === 'bank_transfer' || method === 'cheque' ? a.kind === 'bank'
    : words[method] ? a.kind === 'mobile_wallet' && `${a.provider} ${a.name}`.toLowerCase().includes(words[method]) : false);
  return fits.length === 1 ? fits[0].id : '';
}
