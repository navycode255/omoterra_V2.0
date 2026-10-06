'use server';

import { randomUUID } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { ApiError, post } from './api';
import type { ActionResult } from './actions';
import { requireSession } from './session';

// App payout attempts and second-admin approvals (build plan M2.7, D9). The
// backend owns every rule: who may approve, what may be sent, refund limits.
async function run(work: () => Promise<unknown>, settlementId: string): Promise<ActionResult> {
  await requireSession();
  try {
    await work();
  } catch (error) {
    if (error instanceof ApiError) return { ok: false, error: error.message };
    throw error;
  }
  for (const path of ['/settlements', `/settlements/${settlementId}`, '/finance', '/suppliers', '/manage']) {
    revalidatePath(path, 'layout');
  }
  return { ok: true };
}

const text = (formData: FormData, key: string) => String(formData.get(key) ?? '').trim();
const money = (formData: FormData, key: string) => text(formData, key).replace(/,/g, '');
const key = (formData: FormData) => text(formData, 'idempotency_key') || randomUUID();
const optional = (value: string) => value || null;

/** A new payout attempt: sent now, with its debit confirmed or not yet. */
export async function recordPayoutAttempt(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'settlement_id');
  const debited = formData.get('debited') === 'on';
  return run(() => post(`/ops/settlements/${id}/attempts`, {
    amount: money(formData, 'amount'), method: text(formData, 'method'),
    payment_reference: text(formData, 'payment_reference'),
    money_account_id: optional(text(formData, 'money_account_id')), sent_on: optional(text(formData, 'sent_on')),
    debited, evidence: text(formData, 'evidence'), approval_id: optional(text(formData, 'approval_id')),
  }, key(formData)), id);
}

/** Ask a second admin to approve a resend or a payout over the limit. */
export async function requestPayoutApproval(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'settlement_id');
  return run(() => post(`/ops/settlements/${id}/approvals`, {
    amount: money(formData, 'amount'), reason: text(formData, 'reason'),
    acknowledge_two_outflows: formData.get('acknowledge_two_outflows') === 'on',
  }, key(formData)), id);
}

export async function decidePayoutApproval(_: ActionResult | null, formData: FormData) {
  const decision = text(formData, 'decision') === 'approve' ? 'approve' : 'reject';
  return run(() => post(`/ops/approvals/${text(formData, 'approval_id')}/${decision}`, { note: text(formData, 'note') }),
    text(formData, 'settlement_id'));
}

export async function markPayoutDebited(_: ActionResult | null, formData: FormData) {
  return run(() => post(`/ops/settlement-transfers/${text(formData, 'attempt_id')}/debited`, {
    debited_on: text(formData, 'debited_on'), evidence: text(formData, 'evidence'),
  }), text(formData, 'settlement_id'));
}

export async function markPayoutFailed(_: ActionResult | null, formData: FormData) {
  return run(() => post(`/ops/settlement-transfers/${text(formData, 'attempt_id')}/failed`, {
    failed_on: text(formData, 'failed_on'), evidence: text(formData, 'evidence'),
  }), text(formData, 'settlement_id'));
}

export async function recordPayoutRefund(_: ActionResult | null, formData: FormData) {
  return run(() => post(`/ops/settlement-transfers/${text(formData, 'attempt_id')}/refunds`, {
    amount: money(formData, 'amount'), refunded_on: text(formData, 'refunded_on'), method: text(formData, 'method'),
    reference: text(formData, 'reference'), money_account_id: optional(text(formData, 'money_account_id')),
    evidence: text(formData, 'evidence'),
  }, key(formData)), text(formData, 'settlement_id'));
}

/** Ask a second admin to approve resolving money possibly paid twice. */
export async function requestPayoutResolution(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'settlement_id');
  return run(() => post(`/ops/settlements/${id}/resolutions/approvals`, {
    kind: text(formData, 'kind'), amount: money(formData, 'amount'), evidence: text(formData, 'evidence'),
  }, key(formData)), id);
}

/** Record an approved resolution: supplier credit, or a write-off (payout loss). No money moves. */
export async function recordPayoutResolution(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'settlement_id');
  return run(() => post(`/ops/settlements/${id}/resolutions`, {
    approval_id: text(formData, 'approval_id'), resolved_on: optional(text(formData, 'resolved_on')),
  }, key(formData)), id);
}

/** The supplier's payout credit covers this payout: set it off. No money moves. */
export async function useSupplierCredit(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'settlement_id');
  return run(() => post(`/ops/settlements/${id}/use-credit`, {}, key(formData)), id);
}
