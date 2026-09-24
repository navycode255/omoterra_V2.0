'use server';

import { randomUUID } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { ApiError, patch, post, postFile, put } from './api';
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
    ['/supply', `/supply/${id}`, '/manage'],
  );
}

export async function reviewListing(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  return run(
    () => patch(`/ops/listings/${id}/status`, { status: String(formData.get('status')) }, randomUUID()),
    ['/supply', `/supply/${id}`, '/manage'],
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
  for (const key of ['expected_collection_date', 'actual_quantity', 'rejected_quantity', 'actual_weight']) {
    const value = optional(key);
    if (value !== undefined) body[key] = value;
  }
  const itemIds = formData.getAll('collection_item_id').map(String);
  if (itemIds.length) body.collection_results = itemIds.map((itemId) => ({
    order_item_id: itemId,
    actual_quantity: String(formData.get(`actual_${itemId}`) ?? ''),
    rejected_quantity: String(formData.get(`rejected_${itemId}`) ?? ''),
  }));
  return run(() => post(`/ops/orders/${id}/progress`, body, randomUUID()), [
    '/orders',
    `/orders/${id}`,
    '/payments',
    '/settlements',
    '/manage',
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
    ['/payments', '/orders', `/orders/${id}`, '/manage'],
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
    ['/settlements', '/suppliers', '/manage'],
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
    ['/sourcing', `/sourcing/${id}`, '/manage'],
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
    ['/sourcing', `/sourcing/${id}`, '/orders', '/manage'],
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

export async function createRequirement(_: ActionResult | null, formData: FormData) {
  const read = (key: string) => String(formData.get(key) ?? '').trim();
  const quantityUnit: Record<string, string> = {
    broilers: 'bird', local_chicken: 'bird', goats: 'animal', cattle: 'animal',
    chicken_meat: 'kg', beef: 'kg', goat_meat: 'kg', eggs: 'tray',
  };
  const category = read('category');
  const weekdays = formData.getAll('preferred_weekdays').map(String);
  const buyerName = read('business_name');
  const body: Record<string, unknown> = {
    category, unit_type: quantityUnit[category], quantity: read('quantity'),
    product_subtype: read('product_subtype'), weight_or_size_requirement: read('weight_or_size_requirement'),
    minimum_weight_kg: read('minimum_weight_kg') || null,
    maximum_weight_kg: read('maximum_weight_kg') || null,
    live_dressed_or_cut: read('form'), needed_by_date: read('needed_by_date'),
    delivery_region: read('delivery_region'), delivery_area: read('delivery_area'),
    delivery_notes: read('delivery_notes'), requirement_type: read('requirement_type'),
    recurrence_frequency: read('recurrence_frequency'), preferred_weekdays: weekdays,
    notes: read('notes'), internal_notes: read('internal_notes'),
  };
  if (buyerName) body.buyer = {
    business_name: buyerName, buyer_type: read('buyer_type') || 'other',
    contact_person: read('contact_person'), phone: read('phone'),
    region: read('delivery_region'), area: read('delivery_area'), internal_notes: read('internal_notes'),
  };
  return run(() => post('/ops/requirements', body, randomUUID()), ['/sourcing', '/buyers', '/manage']);
}

export async function setRequirementProgress(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  return run(() => patch(`/ops/requirements/${id}/progress`, {
    status: String(formData.get('status')),
    internal_notes: String(formData.get('internal_notes') ?? ''),
  }, randomUUID()), ['/sourcing', `/sourcing/${id}`, '/manage']);
}

export async function createAllocationPlan(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  const batches = formData.getAll('batch_id').map(String);
  const allocations = batches.map((supplier_batch_id) => ({
    supplier_batch_id,
    allocated_quantity: String(formData.get(`quantity_${supplier_batch_id}`) ?? '').trim(),
    ...(String(formData.get(`offer_${supplier_batch_id}`) ?? '').trim()
      ? { supply_offer_id: String(formData.get(`offer_${supplier_batch_id}`)) }
      : {}),
  })).filter((row) => row.allocated_quantity !== '');
  if (allocations.length === 0) return { ok: false as const, error: 'Enter an allocation quantity for at least one batch.' };
  return run(() => post(`/ops/requirements/${id}/allocations`, { allocations }, randomUUID()), [
    '/sourcing', `/sourcing/${id}`, '/batches', '/manage',
  ]);
}

export async function reviewSupplyOffer(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  const accepted = String(formData.get('accepted_quantity') ?? '').trim();
  return run(() => post(`/ops/offers/${id}/review`, {
    status: String(formData.get('status')),
    ...(accepted ? { accepted_quantity: accepted } : {}),
    notes: String(formData.get('notes') ?? ''),
  }, randomUUID()), ['/sourcing', `/sourcing/${String(formData.get('demand_id'))}`]);
}

export async function updateAllocation(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  return run(() => patch(`/ops/allocations/${id}`, {
    ...(String(formData.get('allocated_quantity') ?? '').trim()
      ? { allocated_quantity: String(formData.get('allocated_quantity')) }
      : { status: 'cancelled' }),
  }, randomUUID()), ['/sourcing', `/sourcing/${String(formData.get('demand_id'))}`, '/batches']);
}

export async function verifyBatch(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  return run(() => post(`/ops/batches/${id}/verify`, {
    verified_quantity: String(formData.get('verified_quantity')),
    rejected_quantity: String(formData.get('rejected_quantity') || '0'),
    sampled_average_weight_kg: String(formData.get('sampled_average_weight_kg') || '') || null,
    readiness_confirmed: formData.get('readiness_confirmed') === 'on',
    location_confirmed: formData.get('location_confirmed') === 'on',
    notes: String(formData.get('notes') ?? ''), photos: [],
    buyer_price_per_unit: String(formData.get('buyer_price_per_unit')),
    supplier_asking_price_per_unit: String(formData.get('supplier_asking_price_per_unit') || '') || null,
    supplier_payout_price_per_unit: String(formData.get('supplier_payout_price_per_unit') || '') || null,
  }, randomUUID()), ['/batches', '/sourcing', '/manage']);
}

function buyerPreferences(formData: FormData) {
  const csv = (name: string) => String(formData.get(name) ?? '').split(',').map((item) => item.trim()).filter(Boolean);
  return {
    preferred_products: csv('preferred_products'),
    live_dressed_preference: String(formData.get('live_dressed_preference') ?? ''),
    minimum_weight_kg: String(formData.get('preference_minimum_weight_kg') ?? '').trim() || null,
    maximum_weight_kg: String(formData.get('preference_maximum_weight_kg') ?? '').trim() || null,
    typical_quantity: String(formData.get('typical_quantity') ?? '').trim() || null,
    purchase_frequency: String(formData.get('purchase_frequency') ?? ''),
    preferred_days: csv('preferred_days'),
    pickup_delivery_preference: String(formData.get('pickup_delivery_preference') ?? ''),
  };
}

export async function createBuyerCRM(_: ActionResult | null, formData: FormData) {
  const optionalNumber = (key: string) => String(formData.get(key) ?? '').trim();
  return run(() => post('/ops/buyer-crm', {
    user_id: String(formData.get('user_id') ?? '') || null,
    business_name: String(formData.get('business_name') ?? ''),
    buyer_type: String(formData.get('buyer_type') ?? 'other'),
    contact_person: String(formData.get('contact_person') ?? ''),
    phone: String(formData.get('phone') ?? ''),
    region: String(formData.get('region') ?? ''),
    area: String(formData.get('area') ?? ''),
    internal_notes: String(formData.get('internal_notes') ?? ''),
    last_known_buying_price: optionalNumber('last_known_buying_price') || null,
    minimum_order: optionalNumber('minimum_order') || null,
    payment_terms: String(formData.get('payment_terms') ?? ''),
    preferences: buyerPreferences(formData),
  }, randomUUID()), ['/buyers', '/sourcing']);
}


export async function updateBuyerCRM(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  const optionalNumber = (key: string) => String(formData.get(key) ?? '').trim();
  return run(() => patch(`/ops/buyer-crm/${id}`, {
    user_id: String(formData.get('user_id') ?? '') || null,
    business_name: String(formData.get('business_name') ?? ''),
    buyer_type: String(formData.get('buyer_type') ?? 'other'),
    contact_person: String(formData.get('contact_person') ?? ''),
    phone: String(formData.get('phone') ?? ''), region: String(formData.get('region') ?? ''),
    area: String(formData.get('area') ?? ''), internal_notes: String(formData.get('internal_notes') ?? ''),
    preferences: buyerPreferences(formData), last_known_buying_price: optionalNumber('last_known_buying_price') || null,
    minimum_order: optionalNumber('minimum_order') || null,
    payment_terms: String(formData.get('payment_terms') ?? ''),
  }, randomUUID()), ['/buyers', `/buyers/${id}`, '/sourcing']);
}

export async function convertRequirementToOrder(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  const address = String(formData.get('delivery_address_id') ?? '').trim();
  return run(() => post(`/ops/requirements/${id}/convert`, {
    delivery_address_id: address || null, payment_method: 'pay_on_delivery',
  }, randomUUID()), [`/sourcing/${id}`, '/orders', '/payments', '/manage']);
}


export async function createSupplier(_: ActionResult | null, formData: FormData) {
  const read = (key: string) => String(formData.get(key) ?? '').trim();
  const categories = formData.getAll('categories').map(String);
  const units: Record<string, string> = {
    broilers: 'bird', local_chicken: 'bird', layers: 'bird', goats: 'animal', cattle: 'animal',
    chicken_meat: 'kg', beef: 'kg', goat_meat: 'kg', eggs: 'tray',
  };
  const production_profile: Record<string, { capacity: string; unit: string; frequency: string }> = {};
  for (const category of categories) {
    const capacity = read(`capacity_${category}`);
    if (capacity) production_profile[category] = { capacity, unit: units[category], frequency: read('production_frequency') };
  }
  const batch = (prefix: string) => {
    const quantity = read(`${prefix}_quantity`);
    if (!quantity) return null;
    return {
      category: read(`${prefix}_category`), subtype: read(`${prefix}_subtype`), initial_quantity: quantity,
      current_age: read(`${prefix}_age`) || null, age_unit: read(`${prefix}_age_unit`) || 'weeks',
      expected_ready_date: read(`${prefix}_ready_date`),
      expected_min_weight_kg: read(`${prefix}_min_weight`) || null,
      expected_max_weight_kg: read(`${prefix}_max_weight`) || null,
      form: read(`${prefix}_form`) || 'live', asking_price_per_unit: read(`${prefix}_asking_price`) || null,
      region: read('region'), private_pickup_location: read('internal_pickup_address'), photos: [] as string[],
    };
  };
  const current = batch('current');
  const future = batch('future');
  const upload = async (key: string) => Promise.all(formData.getAll(key)
    .filter((file): file is File => file instanceof File && file.size > 0)
    .map((file) => postFile<{ url: string }>('/ops/suppliers/photos', file, randomUUID()).then((photo) => photo.url)));
  if (!categories.length) return { ok: false as const, error: 'Choose at least one supply category.' };
  return run(async () => {
    const photoFiles = ['evidence_photos', 'current_photos', 'future_photos']
      .flatMap((key) => formData.getAll(key))
      .filter((file): file is File => file instanceof File && file.size > 0);
    if (photoFiles.length > 8 || photoFiles.some((file) => file.size > 8 * 1024 * 1024)) {
      throw new ApiError(422, 'Choose up to 8 photos, each smaller than 8 MB.');
    }
    const [evidence_photos, currentPhotos, futurePhotos] = await Promise.all([
      upload('evidence_photos'), upload('current_photos'), upload('future_photos'),
    ]);
    if (current) current.photos = currentPhotos;
    if (future) future.photos = futurePhotos;
    return post('/ops/suppliers', {
      phone: read('phone'), name: read('legal_name'), public_alias: read('public_alias'), legal_name: read('legal_name'),
      alternate_phone: read('alternate_phone'), region: read('region'), district: read('district'), general_area: read('general_area'),
      categories, primary_category: read('primary_category'), production_profile, evidence_photos,
      production_frequency: read('production_frequency'), internal_pickup_address: read('internal_pickup_address'),
      pickup_instructions: read('pickup_instructions'), omoterra_pickup: formData.get('omoterra_pickup') === 'on',
      supplier_transport: formData.get('supplier_transport') === 'on',
      supply_forms: formData.getAll('supply_forms').map(String), preferred_contact_method: read('preferred_contact_method') || 'phone',
      operating_notes: read('operating_notes'), internal_notes: read('internal_notes'), verification: {},
      current_batch: current, future_batches: future ? [future] : [],
    }, randomUUID());
  }, ['/suppliers', '/manage']);
}

export async function updateSupplierStatus(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  const status = String(formData.get('status'));
  return run(() => patch(`/ops/suppliers/${id}/status`, {
    status, notes: String(formData.get('notes') ?? ''),
  }), ['/suppliers', `/suppliers/${id}`, '/manage']);
}

export async function updateSupplierVerification(_: ActionResult | null, formData: FormData) {
  const id = String(formData.get('id'));
  const names = ['phone_confirmed', 'identity_reviewed', 'location_confirmed', 'location_visited', 'production_seen', 'pickup_access_checked', 'photos_reviewed'];
  const checks = Object.fromEntries(names.map((name) => [name, formData.get(name) === 'on']));
  return run(() => patch(`/ops/suppliers/${id}/verification`, {
    checks, notes: String(formData.get('notes') ?? ''),
  }), ['/suppliers', `/suppliers/${id}`]);
}


export async function editSupplierProfile(_: ActionResult | null, formData: FormData) {
  const read = (key: string) => String(formData.get(key) ?? '').trim();
  const categories = formData.getAll('categories').map(String);
  const units: Record<string, string> = { broilers:'bird', local_chicken:'bird', layers:'bird', eggs:'tray', goats:'animal', cattle:'animal', chicken_meat:'kg', beef:'kg', goat_meat:'kg' };
  const production_profile: Record<string, { capacity: string; unit: string; frequency: string }> = {};
  for (const category of categories) {
    const capacity = read(`capacity_${category}`);
    if (capacity) production_profile[category] = { capacity, unit: units[category], frequency: read('production_frequency') };
  }
  const id = String(formData.get('id'));
  return run(() => put(`/ops/suppliers/${id}`, {
    public_alias: read('public_alias'), legal_name: read('legal_name'), alternate_phone: read('alternate_phone'),
    region: read('region'), district: read('district'), general_area: read('general_area'), categories,
    primary_category: read('primary_category'), production_profile, evidence_photos: formData.getAll('evidence_photo_url').map(String),
    production_frequency: read('production_frequency'), internal_pickup_address: read('internal_pickup_address'),
    pickup_instructions: read('pickup_instructions'), omoterra_pickup: formData.get('omoterra_pickup') === 'on',
    supplier_transport: formData.get('supplier_transport') === 'on', supply_forms: formData.getAll('supply_forms').map(String),
    preferred_contact_method: read('preferred_contact_method') || 'phone', operating_notes: read('operating_notes'),
  }), ['/suppliers', `/suppliers/${id}`]);
}
