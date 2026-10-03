'use server';

import { randomUUID } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { ApiError, post } from './api';
import type { ActionResult } from './actions';
import { requireSession } from './session';

const read = (form: FormData, key: string) => String(form.get(key) ?? '').trim();
const optional = (text: unknown) => String(text ?? '').trim() || null;

// The editor sends its bands as JSON; the form key makes a double submit a replay.
export async function publishMarketPrices(_: ActionResult | null, form: FormData): Promise<ActionResult> {
  await requireSession();
  const category = read(form, 'category');
  let bands: { label?: string; min?: string; max?: string; price?: string }[];
  try { bands = JSON.parse(read(form, 'bands') || '[]'); } catch { return { ok: false, error: 'The price bands could not be read. Please try again.' }; }
  try {
    await post('/ops/market-prices', {
      category, effective_from: read(form, 'effective_from'), note: read(form, 'note'),
      bands: bands.map((band) => ({ label: String(band.label ?? '').trim(), min_weight_kg: optional(band.min),
        max_weight_kg: optional(band.max), price_per_unit: optional(band.price) })),
    }, read(form, 'key') || randomUUID());
  } catch (error) {
    if (error instanceof ApiError) return { ok: false, error: error.message };
    throw error;
  }
  revalidatePath('/market-prices', 'layout');
  redirect(`/market-prices?published=${category}`);
}

export async function withdrawMarketPrices(_: ActionResult | null, form: FormData): Promise<ActionResult> {
  await requireSession();
  try {
    await post(`/ops/market-prices/${read(form, 'id')}/withdraw`, { reason: read(form, 'reason') }, randomUUID());
  } catch (error) {
    if (error instanceof ApiError) return { ok: false, error: error.message };
    throw error;
  }
  revalidatePath('/market-prices', 'layout');
  return { ok: true };
}
