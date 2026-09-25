import 'server-only';
import { cache } from 'react';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { ApiError, get } from './api';
import type { Operator } from './types';

// The backend issues each operator their own session token after they sign in
// with a phone code. It lives only in this httpOnly cookie and is forwarded to
// the backend by lib/api.ts, which records every change under that operator.
export const SESSION_COOKIE = 'omoterra_operator';
// The pending sign-in code between the phone step and the code step.
export const CHALLENGE_COOKIE = 'omoterra_ops_challenge';
const MAX_AGE = 60 * 60 * 12;

const cookieOptions = (maxAge: number) => ({
  httpOnly: true,
  sameSite: 'lax' as const,
  secure: process.env.NODE_ENV === 'production',
  path: '/',
  maxAge,
});

export async function startSession(token: string, expiresIn = MAX_AGE) {
  const jar = await cookies();
  jar.set(SESSION_COOKIE, token, cookieOptions(Math.min(expiresIn, MAX_AGE)));
  jar.delete(CHALLENGE_COOKIE);
}

export async function endSession() {
  (await cookies()).delete(SESSION_COOKIE);
}

export async function sessionToken() {
  return (await cookies()).get(SESSION_COOKIE)?.value ?? '';
}

export type PendingChallenge = { id: string; phone: string; developmentCode?: string };

export async function setChallenge(challenge: PendingChallenge) {
  (await cookies()).set(CHALLENGE_COOKIE, JSON.stringify(challenge), cookieOptions(60 * 10));
}

export async function pendingChallenge(): Promise<PendingChallenge | null> {
  const raw = (await cookies()).get(CHALLENGE_COOKIE)?.value;
  if (!raw) return null;
  try { return JSON.parse(raw) as PendingChallenge; }
  catch { return null; }
}

// The signed-in operator, or null when there is no valid session. Cached for
// the request so the layout and the page share one lookup.
export const currentOperator = cache(async (): Promise<Operator | null> => {
  if (!(await sessionToken())) return null;
  try {
    return await get<Operator>('/ops/me');
  } catch (error) {
    if (error instanceof ApiError && (error.status === 401 || error.status === 403)) return null;
    throw error;
  }
});

export async function signedIn() {
  return (await currentOperator()) !== null;
}

// Called at the top of every operator page and Server Action. Server Actions are
// reachable by direct POST, so authorization is checked inside each one rather
// than relying on the page that rendered the form.
export async function requireSession() {
  const operator = await currentOperator();
  // Only say "expired" to someone who actually had a session.
  if (!operator) redirect((await sessionToken()) ? '/sign-in?error=expired' : '/sign-in');
  return operator;
}

export async function requireAdmin() {
  const operator = await requireSession();
  if (operator.role !== 'admin') redirect('/manage');
  return operator;
}

// "Admin setup" from the sign-in screen, between steps. The setup token is the
// backend's proof that the passphrase was right; the stage says which form
// comes next. httpOnly, so page scripts never see the token.
export const SETUP_COOKIE = 'omoterra_ops_setup';

export type SetupStage = 'approve-phone' | 'approve-code' | 'details' | 'new-code';
export type SetupState = {
  token: string;
  stage: SetupStage;
  approvedBy?: string;
  challengeId?: string;
  phone?: string;
  developmentCode?: string;
};

export async function setSetup(state: SetupState, maxAge = 60 * 15) {
  (await cookies()).set(SETUP_COOKIE, JSON.stringify(state), cookieOptions(maxAge));
}

export async function setupState(): Promise<SetupState | null> {
  const raw = (await cookies()).get(SETUP_COOKIE)?.value;
  if (!raw) return null;
  try { return JSON.parse(raw) as SetupState; }
  catch { return null; }
}

export async function endSetup() {
  (await cookies()).delete(SETUP_COOKIE);
}
