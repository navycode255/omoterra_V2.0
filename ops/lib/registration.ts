'use server';

import { randomUUID } from 'node:crypto';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { MEMBER_COOKIE, MEMBER_MAX_AGE } from '@/lib/member-cookie';
import { tanzanianMobile } from '@/lib/phone';
import { call, PublicApiError } from '@/lib/public-api';

// Public registration reuses the app's own member flow rather than a parallel
// one: a phone code signs the visitor in (/auth/otp, /auth/verify), buyers then
// save their profile (PUT /me) and suppliers submit the same onboarding the app
// sends (POST /supplier/onboarding), which validates with the same
// SupplierProfileInput as admin registration and leaves the supplier
// under_review until staff approve them.
//
// Afterwards members sign in with phone + PIN (POST /auth/pin/sign-in), so
// only registration and a forgotten PIN cost an SMS.

const CHALLENGE = 'omoterra_join_challenge';

type Member = { id: string; phone: string; name: string | null; region: string | null; language: 'en' | 'sw' | null; roles: string[]; has_pin: boolean };
export type Role = 'buyer' | 'supplier';
export type Failure = { ok: false; error: string; field?: string };
export type Verified = { ok: true; registered: boolean; hasPin: boolean; phone: string; name: string; region: string };

function options(maxAge: number) {
  return { httpOnly: true, sameSite: 'lax' as const, secure: process.env.NODE_ENV === 'production', path: '/', maxAge };
}

function failed(error: unknown, fallbackField?: string): Failure {
  if (error instanceof PublicApiError) return { ok: false, error: error.message, field: error.field ?? fallbackField };
  return { ok: false, error: 'We could not complete that just now. Please try again.' };
}

export async function sendCode(rawPhone: string): Promise<{ ok: true; phone: string; developmentCode?: string } | Failure> {
  const phone = tanzanianMobile(rawPhone);
  if (!phone) return { ok: false, error: 'Enter a Tanzanian mobile number, e.g. 0712 345 678.', field: 'phone' };
  try {
    const challenge = await call<{ challenge_id: string; development_code?: string }>('/auth/otp', { method: 'POST', body: { phone } });
    (await cookies()).set(CHALLENGE, JSON.stringify({ id: challenge.challenge_id, phone }), options(60 * 10));
    // The backend only includes the code while no SMS provider is wired up, as on the dashboard sign-in.
    return { ok: true, phone, developmentCode: challenge.development_code };
  } catch (error) {
    return failed(error, 'phone');
  }
}

// `role` is the registration being started; without one (a PIN reset) the
// visitor is only signed in.
export async function verifyCode(code: string, role?: Role): Promise<Verified | Failure> {
  const store = await cookies();
  let challenge: { id: string; phone: string } | null = null;
  try { challenge = JSON.parse(store.get(CHALLENGE)?.value ?? 'null'); }
  catch { challenge = null; }
  if (!challenge) return { ok: false, error: 'Your code has expired. Request a new one.', field: 'code' };
  if (!/^\d{4,8}$/.test(code.trim())) return { ok: false, error: 'Enter the code we sent by SMS.', field: 'code' };
  try {
    const session = await call<{ access_token: string; user: Member }>('/auth/verify', { method: 'POST', body: { challenge_id: challenge.id, code: code.trim() } });
    store.delete(CHALLENGE);
    store.set(MEMBER_COOKIE, session.access_token, options(MEMBER_MAX_AGE));
    const user = session.user;
    let registered = !!role && user.roles.includes(role);
    if (role === 'supplier' && registered) {
      // A profile the app created when the role was added but never submitted
      // ('new') may still be completed here. Anything past that is in the
      // approval workflow already and must not be resubmitted, which would
      // send an approved supplier back to review.
      const profile = await call<{ status: string } | null>('/supplier/profile', { token: session.access_token });
      registered = !!profile && profile.status !== 'new';
    }
    return { ok: true, registered, hasPin: user.has_pin, phone: user.phone, name: user.name ?? '', region: user.region ?? '' };
  } catch (error) {
    return failed(error, 'code');
  }
}

async function token() {
  return (await cookies()).get(MEMBER_COOKIE)?.value ?? '';
}

function guessable(pin: string) {
  const steps = new Set([...pin].slice(1).map((digit, at) => Number(digit) - Number(pin[at])));
  return new Set(pin).size === 1 || (steps.size === 1 && (steps.has(1) || steps.has(-1)));
}

export async function setPin(pin: string): Promise<{ ok: true } | Failure> {
  if (!/^\d{4,6}$/.test(pin)) return { ok: false, error: 'Use 4 to 6 digits.', field: 'pin' };
  if (guessable(pin)) return { ok: false, error: 'Choose a PIN that is harder to guess, not 1234 or 0000.', field: 'pin' };
  const access = await token();
  if (!access) return { ok: false, error: 'Your verification has expired. Confirm your phone number again.', field: 'phone' };
  try {
    await call('/auth/pin', { method: 'PUT', token: access, body: { pin } });
    return { ok: true };
  } catch (error) {
    return failed(error, 'pin');
  }
}

export async function signInWithPin(rawPhone: string, pin: string): Promise<{ ok: true } | Failure> {
  const phone = tanzanianMobile(rawPhone);
  if (!phone) return { ok: false, error: 'Enter a Tanzanian mobile number, e.g. 0712 345 678.', field: 'phone' };
  if (!/^\d{4,6}$/.test(pin)) return { ok: false, error: 'Enter your 4 to 6 digit PIN.', field: 'pin' };
  try {
    const session = await call<{ access_token: string }>('/auth/pin/sign-in', { method: 'POST', body: { phone, pin } });
    (await cookies()).set(MEMBER_COOKIE, session.access_token, options(MEMBER_MAX_AGE));
    return { ok: true };
  } catch (error) {
    return failed(error, 'pin');
  }
}

export async function signOut() {
  const store = await cookies();
  const access = store.get(MEMBER_COOKIE)?.value;
  if (access) {
    try { await call('/auth/logout', { method: 'POST', token: access }); }
    catch { /* Already expired; the cookie goes either way. */ }
  }
  store.delete(MEMBER_COOKIE);
  redirect('/login');
}

export async function registerBuyer(profile: { name: string; region: string; language: 'en' | 'sw'; buyer_type: string }): Promise<{ ok: true } | Failure> {
  const access = await token();
  if (!access) return { ok: false, error: 'Your verification has expired. Confirm your phone number again.', field: 'phone' };
  try {
    await call('/me', { method: 'PUT', token: access, body: { ...profile, roles: ['buyer'] } });
    return { ok: true };
  } catch (error) {
    return failed(error);
  }
}

const PHOTO_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

export async function registerSupplier(form: FormData): Promise<{ ok: true } | Failure> {
  const access = await token();
  if (!access) return { ok: false, error: 'Your verification has expired. Confirm your phone number again.', field: 'phone' };
  let payload: Record<string, unknown> & { current_batch: { photos: string[] } | null; future_batches: { photos: string[] }[] };
  try { payload = JSON.parse(String(form.get('payload') ?? '')); }
  catch { return { ok: false, error: 'Please check the information and try again.' }; }
  const files = (key: string) => form.getAll(key).filter((file): file is File => file instanceof File && file.size > 0);
  const groups = { evidence_photos: files('evidence_photos'), current_photos: files('current_photos'), future_photos: files('future_photos') };
  const all = Object.values(groups).flat();
  // Same limit as admin registration: up to 8 photos, 8 MB each.
  if (all.length > 8 || all.some((file) => file.size > 8 * 1024 * 1024 || !PHOTO_TYPES.includes(file.type))) {
    return { ok: false, error: 'Choose up to 8 JPEG, PNG or WebP photos, each smaller than 8 MB.', field: 'evidence_photos' };
  }
  try {
    if (all.length) {
      // Uploading needs a member role, as in the app, where setup saves the
      // profile before the supplier wizard. New accounts get theirs here.
      const me = await call<Member>('/me', { token: access });
      if (!me.roles.includes('supplier') && !me.roles.includes('buyer')) {
        await call('/me', { method: 'PUT', token: access, body: {
          name: payload.legal_name, region: payload.region, language: me.language ?? 'en', roles: ['supplier'] } });
      }
    }
    const upload = (group: File[]) => Promise.all(group.map((file) => {
      const body = new FormData();
      body.append('file', file);
      return call<{ url: string }>('/media', { method: 'POST', token: access, form: body }).then((photo) => photo.url);
    }));
    const [evidence, current, future] = await Promise.all([upload(groups.evidence_photos), upload(groups.current_photos), upload(groups.future_photos)]);
    payload.evidence_photos = evidence;
    if (payload.current_batch) payload.current_batch.photos = current;
    if (payload.future_batches[0]) payload.future_batches[0].photos = future;
    await call('/supplier/onboarding', { method: 'POST', token: access, body: payload, key: randomUUID() });
    return { ok: true };
  } catch (error) {
    return failed(error);
  }
}
