import 'server-only';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

const COOKIE = 'omoterra_ops';
const MAX_AGE = 60 * 60 * 12;

function secret() {
  const value = process.env.OMOTERRA_DASHBOARD_SECRET;
  if (!value) throw new Error('OMOTERRA_DASHBOARD_SECRET is not configured on the server.');
  return value;
}

function sign(expiry: number) {
  return createHmac('sha256', secret()).update(String(expiry)).digest('hex');
}

function equal(a: string, b: string) {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

export function verifyPassphrase(candidate: string) {
  const expected = process.env.OMOTERRA_DASHBOARD_PASSPHRASE;
  if (!expected) throw new Error('OMOTERRA_DASHBOARD_PASSPHRASE is not configured on the server.');
  return equal(candidate, expected);
}

export async function startSession() {
  const expiry = Date.now() + MAX_AGE * 1000;
  (await cookies()).set(COOKIE, `${expiry}.${sign(expiry)}`, {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production',
    path: '/',
    maxAge: MAX_AGE,
  });
}

export async function endSession() {
  (await cookies()).delete(COOKIE);
}

export async function signedIn() {
  const raw = (await cookies()).get(COOKIE)?.value;
  if (!raw) return false;
  const [expiry, signature] = raw.split('.');
  if (!expiry || !signature) return false;
  if (Number(expiry) < Date.now()) return false;
  return equal(signature, sign(Number(expiry)));
}

// Called at the top of every operator page and Server Action. Server Actions are
// reachable by direct POST, so authorization is checked inside each one rather
// than relying on the page that rendered the form.
export async function requireSession() {
  if (!(await signedIn())) redirect('/sign-in');
}
