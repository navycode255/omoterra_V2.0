'use server';

import { randomUUID } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { ApiError, patch, post, postFile } from './api';
import { requireSession } from './session';

export type ActionResult = { ok: true } | { ok: false; error: string };

// Server Actions are reachable by direct POST, so each one re-checks the session
// rather than trusting the page that rendered its form. Every write goes through
// the backend's own endpoints, which own reservation release and idempotency.
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

export async function approveListing(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  const payout = String(formData.get('supplier_payout_price_per_unit') ?? '').trim();
  return run(
    () =>
      post(
        `/ops/listings/${id}/approve`,
        {
          buyer_price_per_unit: String(formData.get('buyer_price_per_unit')),
          public_alias: String(formData.get('public_alias')),
          ...(payout ? { supplier_payout_price_per_unit: payout } : {}),
        },
        randomUUID(),
      ),
    ['/supply', `/supply/${id}`, '/'],
  );
}

export async function reviewListing(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  return run(
    () => patch(`/ops/listings/${id}/status`, { status: String(formData.get('status')) }, randomUUID()),
    ['/supply', `/supply/${id}`, '/'],
  );
}

export async function progressOrder(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  const optional = (key: string) => {
    const value = String(formData.get(key) ?? '').trim();
    return value === '' ? undefined : value;
  };
  const body: Record<string, unknown> = {
    internal_status: String(formData.get('internal_status')),
    collection_notes: String(formData.get('collection_notes') ?? ''),
  };
  for (const key of [
    'expected_collection_date',
    'actual_quantity',
    'rejected_quantity',
    'actual_weight',
  ]) {
    const value = optional(key);
    if (value !== undefined) body[key] = value;
  }
  return run(() => post(`/ops/orders/${id}/progress`, body, randomUUID()), [
    '/orders',
    `/orders/${id}`,
    '/payments',
    '/settlements',
    '/',
  ]);
}

export async function uploadCollectionPhoto(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  const file = formData.get('file');
  if (!(file instanceof File) || file.size === 0) {
    return { ok: false as const, error: 'Choose a photo to upload.' };
  }
  return run(() => postFile(`/ops/orders/${id}/photos`, file, randomUUID()), [
    `/orders/${id}`,
  ]);
}

export async function reconcilePayment(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  return run(
    () =>
      post(
        `/ops/orders/${id}/reconcile`,
        {
          amount: String(formData.get('amount')),
          payment_reference: String(formData.get('payment_reference')),
        },
        randomUUID(),
      ),
    ['/payments', '/orders', `/orders/${id}`, '/'],
  );
}

export async function paySettlement(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  return run(
    () =>
      post(
        `/ops/settlements/${id}/pay`,
        {
          amount: String(formData.get('amount')),
          payment_reference: String(formData.get('payment_reference')),
        },
        randomUUID(),
      ),
    ['/settlements', '/suppliers', '/'],
  );
}

export async function updateSourcing(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  return run(
    () =>
      patch(`/ops/requests/${id}`, {
        status: String(formData.get('status')),
        quantity_secured: String(formData.get('quantity_secured') || '0'),
        admin_notes: String(formData.get('admin_notes') ?? ''),
      }),
    ['/sourcing', `/sourcing/${id}`, '/'],
  );
}

export async function reserveForSourcing(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  return run(
    () =>
      post(
        `/ops/requests/${id}/reserve`,
        {
          listing_id: String(formData.get('listing_id')),
          quantity: String(formData.get('quantity')),
        },
        randomUUID(),
      ),
    ['/sourcing', `/sourcing/${id}`],
  );
}

export async function convertSourcing(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  return run(
    () =>
      post(
        `/ops/requests/${id}/convert`,
        {
          reservation_id: String(formData.get('reservation_id')),
          delivery_address_id: String(formData.get('delivery_address_id')),
          preferred_delivery_date: String(formData.get('preferred_delivery_date')),
          payment_method: String(formData.get('payment_method')),
        },
        randomUUID(),
      ),
    ['/sourcing', `/sourcing/${id}`, '/orders', '/'],
  );
}

export async function updateOpportunity(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  return run(
    () =>
      patch(
        `/ops/business-opportunities/${id}`,
        {
          status: String(formData.get('status')),
          internal_notes: String(formData.get('internal_notes') ?? ''),
        },
        randomUUID(),
      ),
    ['/opportunities', `/opportunities/${id}`],
  );
}
