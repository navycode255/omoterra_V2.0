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
  kind: 'payout_resend' | 'payout_over_threshold' | 'payout_supplier_credit' | 'payout_write_off';
  amount: string; reason: string; acknowledged: boolean;
  requested_by: string; requested_by_name: string; status: 'pending' | 'approved' | 'rejected';
  decided_by: string | null; decided_by_name: string; decided_at: string | null; decision_note: string;
  used: boolean; used_by_id: string | null; used_at: string | null;
}

/** Money possibly paid twice, resolved with a second admin's approval (7 October 2026). */
export interface PayoutResolution {
  id: string; kind: 'supplier_credit' | 'write_off'; amount: string; resolved_on: string; evidence: string;
  approval_id: string; recorded_by: string; created_at: string;
}

export interface SettlementDetail extends Omit<Settlement, 'supplier_note'> {
  debited: string; refunded: string; net_paid: string; in_flight: string; outstanding: string; disputed: string;
  exposure: string; unresolved_count: number; threshold: string;
  // Resolved (credit + written off), supplier credit used on this payout, and what settled it.
  resolved: string; credited: string; written_off: string; credit_used: string; settled: string;
  // The supplier's payout credit still unused (used first by their next payouts).
  supplier_credit: string;
  next: { blocked: 'cancelled' | 'paid' | 'covered_by_credit' | null; limit: string; resend: boolean;
    retry_after_failure: boolean; unresolved: boolean; credit: string; approval_kind: SendApprovalKind | null };
  attempts: PayoutAttempt[];
  approvals: Approval[];
  resolutions: PayoutResolution[];
  credit_uses: { id: string; amount: string; used_on: string; created_at: string }[];
}

export type SendApprovalKind = 'payout_resend' | 'payout_over_threshold';
export const SEND_KINDS: Approval['kind'][] = ['payout_resend', 'payout_over_threshold'];
export const RESOLUTION_KINDS: Approval['kind'][] = ['payout_supplier_credit', 'payout_write_off'];

export const RESOLUTION: Record<PayoutResolution['kind'], string> = {
  supplier_credit: 'Supplier credit', write_off: 'Written off (payout loss)',
};

export const ATTEMPT_STATE: Record<AttemptState, string> = {
  initiated: 'Sent, debit not confirmed', debited: 'Debited', failed: 'Failed (no debit)',
};

export const APPROVAL_KIND: Record<Approval['kind'], string> = {
  payout_resend: 'Resend', payout_over_threshold: 'Over the approval limit',
  payout_supplier_credit: 'Possibly paid twice: supplier credit', payout_write_off: 'Possibly paid twice: write-off',
};
