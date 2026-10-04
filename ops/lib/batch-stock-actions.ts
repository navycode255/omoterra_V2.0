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

const NOTE_PATHS = (note: string, supplier: string) => [`/supplier-collections/${note}`, '/suppliers/' + supplier, '/sales/new',
  '/finance', '/finance/debts', '/finance/supplier-payments', '/batches'];

// The supplier never delivered some of this delivery note (admin, with a reason and evidence).
export async function correctReceipt(_: ActionResult | null, form: FormData) {
  const note = text(form, 'collection_id');
  const payments = text(form, 'payments');
  return run(() => post(`/ops/supplier-collections/${encodeURIComponent(note)}/corrections`, {
    quantity: text(form, 'quantity'), reason: text(form, 'reason'), evidence: text(form, 'evidence'),
    ...(payments ? { payments } : {}),
  }, text(form, 'idempotency_key') || randomUUID()), NOTE_PATHS(note, text(form, 'supplier_id')));
}

// Goods from this delivery note went back to the supplier; the payable waits for their credit note.
export async function returnToSupplier(_: ActionResult | null, form: FormData) {
  const note = text(form, 'collection_id');
  return run(() => post(`/ops/supplier-collections/${encodeURIComponent(note)}/returns`, {
    quantity: text(form, 'quantity'), returned_on: text(form, 'returned_on'), reason: text(form, 'reason'),
  }, text(form, 'idempotency_key') || randomUUID()), NOTE_PATHS(note, text(form, 'supplier_id')));
}

// The supplier agreed a credit for a return: it lowers the payable.
export async function recordSupplierCreditNote(_: ActionResult | null, form: FormData) {
  const note = text(form, 'collection_id');
  const movement = text(form, 'movement_id');
  return run(() => post(`/ops/supplier-collections/${encodeURIComponent(note)}/returns/${encodeURIComponent(movement)}/credit-note`, {
    amount: text(form, 'amount').replace(/,/g, ''), issued_on: text(form, 'issued_on'), reference: text(form, 'reference'),
    note: text(form, 'note'),
  }, text(form, 'idempotency_key') || randomUUID()), NOTE_PATHS(note, text(form, 'supplier_id')));
}

// Goods from this delivery note died, were culled, stolen or spoiled before they were sold.
// Stock drops and the cost counts as a loss; what is owed to the supplier does not change.
export async function recordDeliveryLoss(_: ActionResult | null, form: FormData) {
  const note = text(form, 'collection_id');
  return run(() => post(`/ops/supplier-collections/${encodeURIComponent(note)}/losses`, {
    quantity: text(form, 'quantity'), lost_on: text(form, 'lost_on'), reason: text(form, 'reason'), note: text(form, 'note'),
  }, text(form, 'idempotency_key') || randomUUID()), [...NOTE_PATHS(note, text(form, 'supplier_id')), '/finance/profit', '/finance/reports']);
}

// A loss recorded by mistake (admin, with a reason): the goods count as on hand again.
export async function cancelDeliveryLoss(_: ActionResult | null, form: FormData) {
  const note = text(form, 'collection_id');
  return run(() => post(`/ops/supplier-collections/${encodeURIComponent(note)}/losses/${encodeURIComponent(text(form, 'movement_id'))}/cancel`, {
    reason: text(form, 'reason'),
  }), [...NOTE_PATHS(note, text(form, 'supplier_id')), '/finance/profit', '/finance/reports']);
}
