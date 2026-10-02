'use server';

import { randomUUID } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { ApiError, post } from './api';
import type { ActionResult } from './actions';
import { requireSession } from './session';

const text = (form: FormData, name: string) => String(form.get(name) ?? '').trim();

async function run(work: () => Promise<unknown>, paths: string[]): Promise<ActionResult> {
  await requireSession();
  try { await work(); }
  catch (error) {
    if (error instanceof ApiError) return { ok: false, error: error.message };
    throw error;
  }
  for (const path of paths) revalidatePath(path, 'layout');
  return { ok: true };
}

export async function registerSupplierBatch(_: ActionResult | null, form: FormData) {
  const supplier = text(form, 'supplier_id');
  return run(() => post('/ops/suppliers/' + supplier + '/batches', {
    category: text(form, 'category'), subtype: text(form, 'subtype'),
    initial_quantity: text(form, 'initial_quantity'), current_age: text(form, 'current_age') || null,
    age_unit: text(form, 'age_unit') || 'weeks', expected_ready_date: text(form, 'expected_ready_date'),
    expected_min_weight_kg: text(form, 'expected_min_weight_kg') || null,
    expected_max_weight_kg: text(form, 'expected_max_weight_kg') || null,
    form: text(form, 'form') || 'live', asking_price_per_unit: text(form, 'asking_price_per_unit') || null,
    region: text(form, 'region'), private_pickup_location: text(form, 'private_pickup_location'), photos: [],
  }, randomUUID()), ['/suppliers/' + supplier, '/batches', '/sales/new']);
}

export async function receiveSupplierBatch(_: ActionResult | null, form: FormData) {
  const supplier = text(form, 'supplier_id');
  return run(() => post('/ops/suppliers/' + supplier + '/collections', {
    batch_id: text(form, 'batch_id'), received_on: text(form, 'received_on'),
    delivered_quantity: text(form, 'delivered_quantity'), accepted_quantity: text(form, 'accepted_quantity'),
    average_weight_kg: text(form, 'average_weight_kg') || null,
    unit_cost: text(form, 'unit_cost'), payment_terms_days: Number(text(form, 'payment_terms_days') || '0'),
    notes: text(form, 'notes'),
  }, randomUUID()), ['/suppliers/' + supplier, '/sales/new', '/finance', '/finance/debts', '/finance/supplier-payments']);
}

// The supplier sold some of this batch to someone else.
export async function recordSoldElsewhere(_: ActionResult | null, form: FormData) {
  const supplier = text(form, 'supplier_id');
  return run(() => post('/ops/batches/' + text(form, 'batch_id') + '/sold-elsewhere', {
    quantity: text(form, 'quantity'), notes: text(form, 'notes'),
  }, randomUUID()), ['/suppliers/' + supplier, '/sales/new', '/batches']);
}

// Everything still left in this batch was sold elsewhere: finish it.
export async function closeSupplierBatch(_: ActionResult | null, form: FormData) {
  const supplier = text(form, 'supplier_id');
  return run(() => post('/ops/batches/' + text(form, 'batch_id') + '/close', { notes: text(form, 'notes') }, randomUUID()),
    ['/suppliers/' + supplier, '/sales/new', '/batches']);
}
