'use server';

import { randomUUID } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { ApiError, post, put } from './api';
import type { ActionResult } from './actions';
import type { BuyerOrderDetail } from './buyer-orders';
import type { SaleDetail } from './finance';
import { requireSession } from './session';

// Orders staff take for a buyer (build plan M2.5). Same contract as
// finance-actions.ts: the session is re-checked and the backend owns the
// rules; every write that moves money or creates a record sends the form's
// retry key so a double click records it once.

const text = (formData: FormData, key: string) => String(formData.get(key) ?? '').trim();
const key = (formData: FormData) => text(formData, 'idempotency_key') || randomUUID();
const PATHS = ['/sales', '/finance'];

function refresh(id?: string) {
  for (const path of [...PATHS, ...(id ? [`/sales/orders/${id}`] : [])]) revalidatePath(path, 'layout');
}

async function attempt<T>(work: () => Promise<T>): Promise<{ ok: true; value: T } | { ok: false; error: string }> {
  await requireSession();
  try {
    return { ok: true, value: await work() };
  } catch (error) {
    if (error instanceof ApiError) return { ok: false, error: error.message };
    if (error instanceof SyntaxError) return { ok: false, error: 'The order could not be read. Reload the page and try again.' };
    throw error;
  }
}

/** The order form posts the whole order as JSON; on success, open it. */
export async function createBuyerOrder(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  const done = await attempt(() => post<BuyerOrderDetail>('/ops/buyer-orders', JSON.parse(text(formData, 'payload')), key(formData)));
  if (!done.ok) return done;
  refresh();
  redirect(`/sales/orders/${done.value.id}?created=1`);
}

export async function updateBuyerOrder(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  const id = text(formData, 'order_id');
  const done = await attempt(() => put<BuyerOrderDetail>(`/ops/buyer-orders/${encodeURIComponent(id)}`, JSON.parse(text(formData, 'payload'))));
  if (!done.ok) return done;
  refresh(id);
  redirect(`/sales/orders/${id}?updated=1`);
}

export async function cancelBuyerOrder(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  const id = text(formData, 'order_id');
  const done = await attempt(() => post(`/ops/buyer-orders/${encodeURIComponent(id)}/cancel`, { reason: text(formData, 'reason') }, key(formData)));
  if (!done.ok) return done;
  refresh(id);
  return { ok: true };
}

function overrideBody(formData: FormData) {
  return text(formData, 'duplicate_override') === 'true'
    ? { duplicate_override: true, duplicate_reason: text(formData, 'duplicate_reason') } : {};
}

export async function recordOrderDeposit(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  const id = text(formData, 'order_id');
  const done = await attempt(() => post(`/ops/buyer-orders/${encodeURIComponent(id)}/deposits`, {
    amount: text(formData, 'amount').replace(/,/g, ''), paid_on: text(formData, 'paid_on'), method: text(formData, 'method'),
    reference: text(formData, 'reference'), note: text(formData, 'note'),
    money_account_id: text(formData, 'money_account_id') || null, ...overrideBody(formData),
  }, key(formData)));
  if (!done.ok) return done;
  refresh(id);
  return { ok: true };
}

/** A deposit given back to the buyer, whole or in part: its own dated money out. */
export async function refundOrderDeposit(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  const id = text(formData, 'order_id');
  const payment = text(formData, 'payment_id');
  const amount = text(formData, 'amount').replace(/,/g, '');
  const done = await attempt(() => post(`/ops/buyer-orders/${encodeURIComponent(id)}/deposits/${encodeURIComponent(payment)}/refund`, {
    ...(amount ? { amount } : {}),
    paid_on: text(formData, 'paid_on'), method: text(formData, 'method'), reference: text(formData, 'reference'),
    note: text(formData, 'note'), money_account_id: text(formData, 'money_account_id') || null, ...overrideBody(formData),
  }, key(formData)));
  if (!done.ok) return done;
  refresh(id);
  return { ok: true };
}

/** Move a held deposit (all or part) to another open order of the same buyer. No money moves. */
export async function moveOrderDeposit(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  const id = text(formData, 'order_id');
  const payment = text(formData, 'payment_id');
  const target = text(formData, 'to_order_id');
  const amount = text(formData, 'amount').replace(/,/g, '');
  const done = await attempt(() => post(`/ops/buyer-orders/${encodeURIComponent(id)}/deposits/${encodeURIComponent(payment)}/move`, {
    to_order_id: target, reason: text(formData, 'reason'), ...(amount ? { amount } : {}),
  }, key(formData)));
  if (!done.ok) return done;
  refresh(id);
  if (target) revalidatePath(`/sales/orders/${target}`, 'layout');
  return { ok: true };
}

/** A deposit entered by mistake (admins only, with a reason). */
export async function voidOrderDeposit(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  const id = text(formData, 'order_id');
  const payment = text(formData, 'payment_id');
  const done = await attempt(() => post(`/ops/buyer-orders/${encodeURIComponent(id)}/deposits/${encodeURIComponent(payment)}/void`,
    { reason: text(formData, 'reason') }));
  if (!done.ok) return done;
  refresh(id);
  return { ok: true };
}

/** "Mark delivered": the sale form's order becomes the sale, dated the delivery day. */
export async function deliverBuyerOrder(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  const id = text(formData, 'buyer_order_id');
  const done = await attempt(() => post<SaleDetail>(`/ops/buyer-orders/${encodeURIComponent(id)}/deliver`, JSON.parse(text(formData, 'payload')), key(formData)));
  if (!done.ok) return done;
  refresh(id);
  revalidatePath('/buyers', 'layout');
  redirect(`/sales/${done.value.id}?created=1`);
}

/** Take back a delivered app order (admins): reopened or returned (M2.5). */
export async function reverseOrderDelivery(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  const id = text(formData, 'id');
  const done = await attempt(() => post(`/ops/orders/${encodeURIComponent(id)}/reverse-delivery`, {
    kind: text(formData, 'kind'), reversed_on: text(formData, 'reversed_on'), reason: text(formData, 'reason'),
  }, key(formData)));
  if (!done.ok) return done;
  for (const path of ['/orders', `/orders/${id}`, '/finance', '/sales', '/settlements']) revalidatePath(path, 'layout');
  return { ok: true };
}
