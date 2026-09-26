'use server';

import { cookies } from 'next/headers';
import { MEMBER_COOKIE } from '@/lib/member-cookie';
import { tanzanianMobile } from '@/lib/phone';
import { call, PublicApiError } from '@/lib/public-api';

export type Contact = { alternate_phone: string; preferred_contact_method: string; internal_pickup_address: string; pickup_instructions: string };

// Contact and pickup details: saved without a new review (PUT /supplier/contact).
export async function saveSupplierContact(values: Contact): Promise<{ ok: true } | { ok: false; error: string; field?: string }> {
  const token = (await cookies()).get(MEMBER_COOKIE)?.value;
  if (!token) return { ok: false, error: 'Your session has ended. Log in again.' };
  const alternate = values.alternate_phone.trim();
  const phone = alternate ? tanzanianMobile(alternate) : '';
  if (phone === null) return { ok: false, error: 'Enter a Tanzanian mobile number, e.g. 0712 345 678.', field: 'alternate_phone' };
  const address = values.internal_pickup_address.trim();
  if (address.length < 3) return { ok: false, error: 'Enter the exact pickup location.', field: 'internal_pickup_address' };
  try {
    await call('/supplier/contact', { method: 'PUT', token, body: {
      alternate_phone: phone, preferred_contact_method: values.preferred_contact_method,
      internal_pickup_address: address, pickup_instructions: values.pickup_instructions.trim() } });
    return { ok: true };
  } catch (error) {
    if (error instanceof PublicApiError) return { ok: false, error: error.message, field: error.field };
    return { ok: false, error: 'We could not save that just now. Please try again.' };
  }
}
