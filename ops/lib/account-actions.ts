'use server';

import { randomUUID } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { ApiError, get, post } from './api';
import type { ActionResult } from './actions';
import type { AccountOption, AccountsPage } from './accounts';
import { requireSession } from './session';

// Money accounts (build plan M2.3). The backend owns every rule: admins set
// accounts up and confirm historical assignments; a difference on a count or
// statement is listed, never adjusted.
async function run(work: () => Promise<unknown>, paths: string[]): Promise<ActionResult> {
  await requireSession();
  try {
    await work();
  } catch (error) {
    if (error instanceof ApiError) return { ok: false, error: error.message };
    throw error;
  }
  for (const path of paths) revalidatePath(path, 'layout');
  return { ok: true };
}

const text = (formData: FormData, key: string) => String(formData.get(key) ?? '').trim();
const money = (formData: FormData, key: string) => text(formData, key).replace(/,/g, '');
const key = (formData: FormData) => text(formData, 'idempotency_key') || randomUUID();
const PATHS = ['/finance'];

/** Active accounts for the account picker on money forms (empty until accounts exist). */
export async function activeAccounts(): Promise<AccountOption[]> {
  await requireSession();
  try {
    const data = await get<AccountsPage>('/ops/accounts?active=true');
    return data.items.map(({ id, name, kind, provider }) => ({ id, name, kind, provider }));
  } catch {
    return [];
  }
}

export async function createAccount(_: ActionResult | null, formData: FormData) {
  return run(() => post('/ops/accounts', {
    name: text(formData, 'name'), kind: text(formData, 'kind'), provider: text(formData, 'provider'),
    number: text(formData, 'number'), cutoff_on: text(formData, 'cutoff_on'),
    opening_balance: money(formData, 'opening_balance'), opening_evidence: text(formData, 'opening_evidence'),
    verified_by: text(formData, 'verified_by'),
  }, key(formData)), PATHS);
}

export async function transferBetweenAccounts(_: ActionResult | null, formData: FormData) {
  return run(() => post('/ops/accounts/transfers', {
    from_account_id: text(formData, 'from_account_id'), to_account_id: text(formData, 'to_account_id'),
    amount: money(formData, 'amount'), transferred_on: text(formData, 'transferred_on'),
    fee: money(formData, 'fee') || '0', reference: text(formData, 'reference'), note: text(formData, 'note'),
  }, key(formData)), PATHS);
}

export async function recordAccountFee(_: ActionResult | null, formData: FormData) {
  return run(() => post(`/ops/accounts/${text(formData, 'account_id')}/fees`, {
    amount: money(formData, 'amount'), charged_on: text(formData, 'charged_on'),
    description: text(formData, 'description'), reference: text(formData, 'reference'),
  }, key(formData)), PATHS);
}

export async function recordAccountCheck(_: ActionResult | null, formData: FormData) {
  return run(() => post(`/ops/accounts/${text(formData, 'account_id')}/checks`, {
    kind: text(formData, 'kind'), checked_on: text(formData, 'checked_on'), balance: money(formData, 'balance'),
    evidence: text(formData, 'evidence'),
  }, key(formData)), PATHS);
}

export async function explainAccountCheck(_: ActionResult | null, formData: FormData) {
  return run(() => post(`/ops/account-checks/${text(formData, 'check_id')}/resolve`, {
    reason: text(formData, 'reason'),
  }, key(formData)), PATHS);
}

export async function assignMovement(_: ActionResult | null, formData: FormData) {
  return run(() => post('/ops/accounts/assign', {
    source_table: text(formData, 'source_table'), source_id: text(formData, 'source_id'),
    account_id: text(formData, 'account_id'), evidence: text(formData, 'evidence'),
  }, key(formData)), PATHS);
}

export async function resolvePreCutoff(_: ActionResult | null, formData: FormData) {
  return run(() => post(`/ops/account-assignments/${text(formData, 'assignment_id')}/pre-cutoff`, {
    resolution: text(formData, 'resolution'), note: text(formData, 'note'),
  }, key(formData)), PATHS);
}
