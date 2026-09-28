'use server';

import { randomUUID } from 'node:crypto';
import { cookies } from 'next/headers';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import type { ActionResult } from './actions';
import { MEMBER_COOKIE } from './member-cookie';
import { call, PublicApiError } from './public-api';

const read = (form: FormData, key: string) => String(form.get(key) ?? '').trim();
export async function requestMarketReservation(_: ActionResult | null, form: FormData): Promise<ActionResult> {
  const token = (await cookies()).get(MEMBER_COOKIE)?.value;
  if (!token) return { ok: false, error: 'Your session has ended. Log in again.' };
  const slot = read(form, 'slot_id');
  try { await call(`/market-schedule/${encodeURIComponent(slot)}/reservations`, { method: 'POST', token, key: randomUUID(), body: {
    quantity: read(form, 'quantity'), production_choice: read(form, 'production_choice'),
    supplier_batch_id: read(form, 'production_choice') === 'existing' ? read(form, 'supplier_batch_id') : null,
  } }); }
  catch (error) { if (error instanceof PublicApiError) return { ok: false, error: error.message }; throw error; }
  revalidatePath('/account', 'layout'); redirect('/account/market-schedule?requested=1');
}
export async function cancelMarketReservation(_: ActionResult | null, form: FormData): Promise<ActionResult> {
  const token = (await cookies()).get(MEMBER_COOKIE)?.value;
  if (!token) return { ok: false, error: 'Your session has ended. Log in again.' };
  try { await call(`/supplier/market-reservations/${encodeURIComponent(read(form, 'id'))}/cancel`, { method: 'POST', token, key: randomUUID() }); }
  catch (error) { if (error instanceof PublicApiError) return { ok: false, error: error.message }; throw error; }
  revalidatePath('/account', 'layout'); redirect('/account/market-schedule?cancelled=1');
}
