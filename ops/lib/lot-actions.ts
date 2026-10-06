'use server';

import { randomUUID } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { ApiError, post } from './api';
import type { ActionResult } from './actions';
import { requireSession } from './session';

// Counts and opening stock losses on received lots (build plan M2.1). The
// backend owns every rule: admins only for counts and cancelling, a reason
// and evidence, and never below zero on any later day (R8).
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
const number = (formData: FormData, key: string) => text(formData, key).replace(/,/g, '');
const key = (formData: FormData) => text(formData, 'idempotency_key') || randomUUID();
const PATHS = ['/stock', '/finance', '/supplier-collections', '/lpos', '/sales/new'];

/** A physical count: its difference from the records becomes a count adjustment. */
export async function recordStockCount(_: ActionResult | null, formData: FormData) {
  return run(() => post(`/ops/lots/${text(formData, 'lot_table')}/${text(formData, 'lot_id')}/counts`, {
    counted_quantity: number(formData, 'counted_quantity'),
    counted_on: text(formData, 'counted_on'),
    reason: text(formData, 'reason'),
    evidence: text(formData, 'evidence'),
  }, key(formData)), PATHS);
}

/** Opening stock that died or was lost. */
export async function recordOpeningLoss(_: ActionResult | null, formData: FormData) {
  return run(() => post(`/ops/lots/opening_stock/${text(formData, 'lot_id')}/losses`, {
    quantity: number(formData, 'quantity'),
    lost_on: text(formData, 'lost_on'),
    reason: text(formData, 'reason'),
    note: text(formData, 'note'),
    late_reason: text(formData, 'late_reason'),
  }, key(formData)), PATHS);
}

/** Cancel a count or loss recorded by mistake (admin, with a reason). */
export async function cancelLotAdjustment(_: ActionResult | null, formData: FormData) {
  return run(() => post(`/ops/lot-adjustments/${text(formData, 'adjustment_id')}/cancel`, {
    reason: text(formData, 'reason'),
  }, key(formData)), PATHS);
}
