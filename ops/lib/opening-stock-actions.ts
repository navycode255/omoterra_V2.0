'use server';

import { randomUUID } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { ApiError, post } from './api';
import type { ActionResult } from './actions';
import { requireSession } from './session';

// Opening stock and unknown buying costs (build plan M1.3). Admins only on
// the server; the backend owns every rule (no payable, never below zero,
// a reason for every change).
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
const PATHS = ['/finance', '/sales'];

/** Record stock held before the system at the finance owner's value (no payable). */
export async function recordOpeningStock(_: ActionResult | null, formData: FormData) {
  const value = text(formData, 'value_kind') === 'total' ? { total_value: money(formData, 'value') } : { unit_cost: money(formData, 'value') };
  return run(() => post('/ops/opening-stock', {
    category: text(formData, 'category') || null,
    description: text(formData, 'description'),
    unit: text(formData, 'unit'),
    quantity: money(formData, 'quantity'),
    ...value,
    as_of: text(formData, 'as_of'),
    evidence: text(formData, 'evidence'),
    valued_by: text(formData, 'valued_by'),
  }, key(formData)), PATHS);
}

/** Cancel an opening stock entry made by mistake (nothing sold from it). */
export async function cancelOpeningStock(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'opening_stock_id');
  return run(() => post(`/ops/opening-stock/${id}/cancel`, { reason: text(formData, 'reason') }, key(formData)), PATHS);
}

/** Give an unknown-cost sale line its cost: opening stock, an evidenced cost, or free. */
export async function resolveCost(_: ActionResult | null, formData: FormData) {
  const sale = text(formData, 'sale_id');
  const how = text(formData, 'how');
  return run(() => post(`/ops/sales/${sale}/items/${text(formData, 'item_id')}/cost`, {
    how,
    reason: text(formData, 'reason'),
    ...(how === 'opening_stock' ? { opening_stock_id: text(formData, 'opening_stock_id') } : {}),
    ...(how === 'cost' ? { unit_cost: money(formData, 'unit_cost'), evidence: text(formData, 'evidence') } : {}),
  }, key(formData)), [...PATHS, `/sales/${sale}`]);
}
