'use server';

import { randomUUID } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { ApiError, del, post } from './api';
import type { ActionResult } from './actions';
import type { SaleDetail } from './finance';
import { tanzanianMobile } from './phone';
import { requireSession } from './session';

// Same contract as lib/actions.ts: every action re-checks the session, and
// the backend owns the rules (balances, no overpayment, idempotency).
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

// The form renders one key; a double click or a retry after a lost answer
// then records the payment once. A refused attempt stores nothing, so the
// same key can be sent again once the input is fixed.
function key(formData: FormData) {
  return text(formData, 'idempotency_key') || randomUUID();
}

const FINANCE = ['/finance', '/sales'];

/** The sale form posts its whole order as JSON; on success, open the sale. */
export async function createSale(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  await requireSession();
  let sale: SaleDetail;
  try {
    sale = await post<SaleDetail>('/ops/sales', JSON.parse(text(formData, 'payload')), key(formData));
  } catch (error) {
    if (error instanceof ApiError) return { ok: false, error: error.message };
    if (error instanceof SyntaxError) return { ok: false, error: 'The order could not be read. Reload the page and try again.' };
    throw error;
  }
  for (const path of [...FINANCE, '/buyers']) revalidatePath(path, 'layout');
  redirect(`/sales/${sale.id}?created=1`);
}

function paymentBody(formData: FormData) {
  return {
    amount: text(formData, 'amount').replace(/,/g, ''),
    paid_on: text(formData, 'paid_on'),
    method: text(formData, 'method'),
    reference: text(formData, 'reference'),
    note: text(formData, 'note'),
  };
}

export async function recordLedgerPayment(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'debt_id');
  const sale = text(formData, 'sale_id');
  return run(() => post(`/ops/ledger/debts/${id}/payments`, paymentBody(formData), key(formData)),
    [...FINANCE, `/finance/debts/${id}`, ...(sale ? [`/sales/${sale}`] : [])]);
}

export async function reverseLedgerPayment(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'payment_id');
  return run(() => post(`/ops/ledger/payments/${id}/reverse`, { reason: text(formData, 'reason') }, key(formData)),
    [...FINANCE]);
}

export async function cancelSale(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'sale_id');
  return run(() => post(`/ops/sales/${id}/cancel`, { reason: text(formData, 'reason') }, key(formData)),
    [...FINANCE, `/sales/${id}`]);
}

export async function cancelDebt(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'debt_id');
  return run(() => post(`/ops/ledger/debts/${id}/cancel`, { reason: text(formData, 'reason') }, key(formData)),
    [...FINANCE, `/finance/debts/${id}`]);
}

export async function createDebt(_: ActionResult | null, formData: FormData) {
  const party = text(formData, 'party');  // 'buyer:<id>', 'supplier:<id>' or '' for a typed name
  const [kind, id] = party.includes(':') ? party.split(':') : ['other', ''];
  const phone = text(formData, 'party_phone');
  const due = text(formData, 'due_on');
  const body = {
    direction: text(formData, 'direction'),
    party_kind: kind,
    ...(kind === 'buyer' ? { buyer_profile_id: id } : {}),
    ...(kind === 'supplier' ? { supplier_id: id } : {}),
    party_name: kind === 'other' ? text(formData, 'party_name') : '',
    party_phone: phone ? tanzanianMobile(phone) ?? phone : '',
    description: text(formData, 'description'),
    amount: text(formData, 'amount').replace(/,/g, ''),
    incurred_on: text(formData, 'incurred_on'),
    due_on: due || null,
  };
  return run(() => post('/ops/ledger/debts', body, key(formData)), [...FINANCE]);
}

export async function createExpense(_: ActionResult | null, formData: FormData) {
  const paidNow = text(formData, 'paid_now');  // 'full', 'part' or 'none'
  const amount = text(formData, 'amount').replace(/,/g, '');
  const paidAmount = paidNow === 'full' ? amount : paidNow === 'part' ? text(formData, 'paid_amount').replace(/,/g, '') : '';
  const phone = text(formData, 'paid_to_phone');
  const sale = text(formData, 'sale_id');
  const body = {
    spent_on: text(formData, 'spent_on'),
    category: text(formData, 'category'),
    description: text(formData, 'description'),
    amount,
    paid_to: text(formData, 'paid_to'),
    paid_to_phone: phone ? tanzanianMobile(phone) ?? phone : '',
    sale_id: sale || null,
    due_on: text(formData, 'due_on') || null,
    payment: paidAmount ? {
      amount: paidAmount, paid_on: text(formData, 'spent_on'), method: text(formData, 'method'),
      reference: text(formData, 'reference'), note: '',
    } : null,
  };
  return run(() => post('/ops/expenses', body, key(formData)),
    [...FINANCE, '/finance/expenses', '/finance/profit', ...(sale ? [`/sales/${sale}`] : [])]);
}

export async function sendPromotion(_: ActionResult | null, formData: FormData) {
  const channels = formData.getAll('channel').map(String);
  return run(() => post('/ops/promotions', {
    audience: text(formData, 'audience'),
    title: text(formData, 'title'),
    message: text(formData, 'message'),
    send_sms: channels.includes('sms'),
    send_in_app: channels.includes('in_app'),
  }, key(formData)), ['/promotions']);
}

export async function retryPromotion(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'promotion_id');
  return run(() => post(`/ops/promotions/${id}/retry`, {}), ['/promotions', `/promotions/${id}`]);
}

export async function addOptOut(_: ActionResult | null, formData: FormData) {
  const phone = text(formData, 'phone');
  return run(() => post('/ops/promotions/opt-outs', { phone: tanzanianMobile(phone) ?? phone, note: text(formData, 'note') }),
    ['/promotions']);
}

export async function removeOptOut(_: ActionResult | null, formData: FormData) {
  return run(() => del(`/ops/promotions/opt-outs/${encodeURIComponent(text(formData, 'phone'))}`), ['/promotions']);
}
