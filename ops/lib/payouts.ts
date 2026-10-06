import type { Settlement } from './types';

// App payout attempts (build plan M2.7, backend app/payouts.py). Each attempt
// is initiated (sent, debit not confirmed: not money out), debited (a
// permanent outflow on its debit day) or failed (no outflow, evidence kept).
// Refunds are separate inflows. A resend, or a first payout over the D9
// threshold, needs a second admin's approval.

export type AttemptState = 'initiated' | 'debited' | 'failed';

export interface PayoutRefund {
  id: string; amount: string; refunded_on: string; method: string; reference: string; account_name: string | null;
  evidence: string; recorded_by: string; created_at: string;
}

export interface PayoutAttempt {
  id: string; attempt_no: number; amount: string; method: string; reference: string; account_name: string | null;
  sent_on: string; evidence: string; state: AttemptState; initiated_by: string; created_at: string; is_resend: boolean;
  approval_id: string | null; legacy: boolean; debited_on: string | null; debit_evidence: string;
  debit_confirmed_by: string; failed_on: string | null; failure_evidence: string; failed_by: string;
  supplier_confirmation: 'received' | 'not_received' | null; supplier_confirmed_at: string | null;
  refunded: string; kept: string; refunds: PayoutRefund[];
  answers: { outcome: 'received' | 'not_received'; note: string; created_at: string }[];
}

export interface Approval {
  id: string; created_at: string; subject_table: string; subject_id: string;
  kind: 'payout_resend' | 'payout_over_threshold'; amount: string; reason: string; acknowledged: boolean;
  requested_by: string; requested_by_name: string; status: 'pending' | 'approved' | 'rejected';
  decided_by: string | null; decided_by_name: string; decided_at: string | null; decision_note: string;
  used: boolean; used_by_id: string | null; used_at: string | null;
}

export interface SettlementDetail extends Omit<Settlement, 'supplier_note'> {
  debited: string; refunded: string; net_paid: string; in_flight: string; outstanding: string; disputed: string;
  exposure: string; unresolved_count: number; threshold: string;
  next: { blocked: 'cancelled' | 'paid' | null; limit: string; resend: boolean; unresolved: boolean;
    approval_kind: Approval['kind'] | null };
  attempts: PayoutAttempt[];
  approvals: Approval[];
}

export const ATTEMPT_STATE: Record<AttemptState, string> = {
  initiated: 'Sent, debit not confirmed', debited: 'Debited', failed: 'Failed (no debit)',
};

export const APPROVAL_KIND: Record<Approval['kind'], string> = {
  payout_resend: 'Resend', payout_over_threshold: 'Over the approval limit',
};
