'use server';

import { randomUUID } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { ApiError, post, postFile, put } from './api';
import type { ActionResult } from './actions';
import type { LpoDetail } from './lpo';
import { requireSession } from './session';

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
const key = (formData: FormData) => text(formData, 'idempotency_key') || randomUUID();
const PATHS = ['/lpos', '/finance', '/sales'];

/** The LPO form posts the whole order as JSON: create, or save a draft. */
export async function saveLpo(_: ActionResult | null, formData: FormData): Promise<ActionResult> {
  await requireSession();
  const id = text(formData, 'id');
  let lpo: LpoDetail;
  try {
    const body = JSON.parse(text(formData, 'payload'));
    lpo = id ? await put<LpoDetail>(`/ops/lpos/${id}`, body) : await post<LpoDetail>('/ops/lpos', body, key(formData));
  } catch (error) {
    if (error instanceof ApiError) return { ok: false, error: error.message };
    if (error instanceof SyntaxError) return { ok: false, error: 'The LPO could not be read. Reload the page and try again.' };
    throw error;
  }
  for (const path of PATHS) revalidatePath(path, 'layout');
  redirect(`/lpos/${lpo.id}`);
}

export async function issueLpo(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'lpo_id');
  const number = text(formData, 'lpo_number');
  return run(() => post(`/ops/lpos/${id}/issue`, {
    issuer_position: text(formData, 'issuer_position') || 'Authorized Signatory',
    ...(number ? { lpo_number: number.toUpperCase() } : {}),
  }, key(formData)), [...PATHS, `/lpos/${id}`]);
}

export async function recordLpoAcceptance(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'lpo_id');
  return run(() => post(`/ops/lpos/${id}/acceptance`, {
    accepted_on: text(formData, 'accepted_on'), name: text(formData, 'name'), position: text(formData, 'position'),
  }), [`/lpos/${id}`, '/lpos']);
}

export async function uploadSignedCopy(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'lpo_id');
  const file = formData.get('file');
  if (!(file instanceof File) || file.size === 0) return { ok: false, error: 'Choose a photo of the signed LPO.' } as ActionResult;
  return run(() => postFile(`/ops/lpos/${id}/signed-copy`, file, randomUUID()), [`/lpos/${id}`]);
}

export async function receiveBatch(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'lpo_id');
  const lines = formData.getAll('line_id').map(String).map((line) => ({
    lpo_line_id: line,
    delivered_quantity: text(formData, `delivered_${line}`) || '0',
    accepted_quantity: text(formData, `accepted_${line}`) || '0',
    average_weight_kg: text(formData, `weight_${line}`) || null,
  })).filter((line) => line.delivered_quantity !== '0' || line.accepted_quantity !== '0');
  if (!lines.length) return { ok: false, error: 'Enter how many were delivered.' } as ActionResult;
  return run(() => post(`/ops/lpos/${id}/receipts`, {
    received_on: text(formData, 'received_on'), notes: text(formData, 'notes'), lines,
  }, key(formData)), [...PATHS, `/lpos/${id}`, '/finance/debts', '/finance/profit']);
}

export async function cancelReceipt(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'lpo_id');
  return run(() => post(`/ops/lpos/receipts/${text(formData, 'receipt_id')}/cancel`, { reason: text(formData, 'reason') }),
    [...PATHS, `/lpos/${id}`, '/finance/debts']);
}

export async function recordLoss(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'lpo_id');
  return run(() => post('/ops/lpos/losses', {
    lpo_line_id: text(formData, 'lpo_line_id'), lost_on: text(formData, 'lost_on'),
    quantity: text(formData, 'quantity'), reason: text(formData, 'reason'), note: text(formData, 'note'),
    late_reason: text(formData, 'late_reason'),
  }, key(formData)), [`/lpos/${id}`, '/finance/profit', '/finance', '/stock']);
}

export async function cancelLoss(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'lpo_id');
  return run(() => post(`/ops/lpos/losses/${text(formData, 'loss_id')}/cancel`, {}), [`/lpos/${id}`, '/finance/profit']);
}

export async function extendLpo(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'lpo_id');
  return run(() => post(`/ops/lpos/${id}/extend`, { delivery_end: text(formData, 'delivery_end'), reason: text(formData, 'reason') }),
    [`/lpos/${id}`, '/lpos']);
}

export async function closeLpo(_: ActionResult | null, formData: FormData) {
  const id = text(formData, 'lpo_id');
  const action = text(formData, 'action') === 'cancel' ? 'cancel' : 'close';
  return run(() => post(`/ops/lpos/${id}/${action}`, { reason: text(formData, 'reason') }), [`/lpos/${id}`, '/lpos']);
}

export async function uploadMark(_: ActionResult | null, formData: FormData) {
  const kind = text(formData, 'kind') === 'stamp' ? 'stamp' : 'signature';
  const file = formData.get('file');
  if (!(file instanceof File) || file.size === 0) return { ok: false, error: 'Choose an image to upload.' } as ActionResult;
  return run(() => postFile(`/ops/marks/${kind}`, file, randomUUID()), ['/lpos/marks']);
}
