'use server';

import { randomUUID } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { ApiError, patch, post } from './api';
import type { ActionResult } from './actions';
import type { MarketSlot } from './market';
import { requireSession } from './session';

const read = (form: FormData, key: string) => String(form.get(key) ?? '').trim();
const optional = (form: FormData, key: string) => read(form, key) || null;
function body(form: FormData) {
  return {
    category: read(form, 'category'), delivery_date: read(form, 'delivery_date'),
    reservation_deadline: read(form, 'reservation_deadline'), quantity_required: read(form, 'quantity_required'),
    unit_type: read(form, 'unit_type'), region: read(form, 'region'), collection_point: read(form, 'collection_point'),
    minimum_weight_kg: optional(form, 'minimum_weight_kg'), maximum_weight_kg: optional(form, 'maximum_weight_kg'),
    supply_type: read(form, 'supply_type'), price_per_unit: optional(form, 'price_per_unit'),
    collection_method: read(form, 'collection_method'), status: read(form, 'status') || 'open',
    internal_note: read(form, 'internal_note'),
  };
}
async function errorResult(work: () => Promise<unknown>): Promise<ActionResult> {
  await requireSession();
  try { await work(); return { ok: true }; }
  catch (error) { if (error instanceof ApiError) return { ok: false, error: error.message }; throw error; }
}
export async function createMarketSlot(_: ActionResult | null, form: FormData): Promise<ActionResult> {
  let slot: MarketSlot;
  await requireSession();
  try { slot = await post<MarketSlot>('/ops/market-slots', body(form), randomUUID()); }
  catch (error) { if (error instanceof ApiError) return { ok: false, error: error.message }; throw error; }
  revalidatePath('/market-schedule'); redirect(`/market-schedule/${slot.id}`);
}
export async function editMarketSlot(_: ActionResult | null, form: FormData): Promise<ActionResult> {
  const id = read(form, 'id');
  const result = await errorResult(() => patch(`/ops/market-slots/${id}`, body(form)));
  if (!result.ok) return result;
  revalidatePath('/market-schedule', 'layout'); redirect(`/market-schedule/${id}?updated=1`);
}
export async function setMarketSlotStatus(_: ActionResult | null, form: FormData): Promise<ActionResult> {
  const id = read(form, 'id');
  const result = await errorResult(() => post(`/ops/market-slots/${id}/status`, { status: read(form, 'status') }, randomUUID()));
  if (result.ok) revalidatePath('/market-schedule', 'layout');
  return result;
}
export async function reviewMarketReservation(_: ActionResult | null, form: FormData): Promise<ActionResult> {
  const id = read(form, 'id');
  const result = await errorResult(() => post(`/ops/market-reservations/${id}/review`, {
    action: read(form, 'action'), approved_quantity: optional(form, 'approved_quantity'), reason: read(form, 'reason'),
  }, randomUUID()));
  if (result.ok) revalidatePath('/market-schedule', 'layout');
  return result;
}
