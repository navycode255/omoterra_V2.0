import { NextRequest, NextResponse } from 'next/server';
import { ApiError, opsCause, post, put } from '@/lib/api';
import { endSignIn, pendingChallenge, pendingSignIn, setChallenge, setSignIn, startSession } from '@/lib/session';
import type { Operator } from '@/lib/types';

// Staff sign-in: passphrase + phone, then PIN (or creating a first PIN). A
// code is texted only for a forgotten PIN; the new PIN is then set signed in.

function back(request: NextRequest, params: Record<string, string>) {
  const url = new URL('/sign-in', request.url);
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value);
  return NextResponse.redirect(url, 303);
}

function phoneNumber(raw: string) {
  const digits = raw.replace(/[\s-]/g, '');
  if (/^\+255[67]\d{8}$/.test(digits)) return digits;
  if (/^0[67]\d{8}$/.test(digits)) return '+255' + digits.slice(1);
  if (/^255[67]\d{8}$/.test(digits)) return '+' + digits;
  return null;
}

function guessable(pin: string) {
  const steps = new Set([...pin].slice(1).map((digit, at) => Number(digit) - Number(pin[at])));
  return new Set(pin).size === 1 || (steps.size === 1 && (steps.has(1) || steps.has(-1)));
}

// Which message to show. Staff answers are always English, so PIN lockouts
// and the passphrase lockout (both 429) can be told apart by their reason.
function reason(error: unknown) {
  const cause = opsCause(error);
  if (cause) return cause;
  if (!(error instanceof ApiError)) return 'server';
  const detail = error.detail ?? '';
  if (detail.startsWith('That passphrase')) return 'passphrase';
  if (detail.startsWith('Staff sign-in is turned off')) return 'staff-off';
  if (detail.includes('blocked')) return 'pin-blocked';
  if (detail.startsWith('Too many wrong PINs')) return 'pin-paused';
  if (detail.startsWith('Choose a PIN')) return 'pin-easy';
  return ({ 400: 'pin', 403: 'unknown', 422: 'pin-easy', 429: 'wait' } as Record<number, string>)[error.status] ?? 'server';
}

type Challenge = { challenge_id: string; development_code?: string };
type Session = { session_token: string; expires_in: number; operator: Operator };

export async function POST(request: NextRequest) {
  const form = await request.formData();
  // "Forgot PIN?" is a second submit button on the PIN form.
  const step = form.get('action') === 'reset' ? 'reset' : String(form.get('step') ?? 'start');
  const pin = String(form.get('pin') ?? '').trim();
  const confirm = String(form.get('confirm') ?? '').trim();

  if (step === 'start') {
    const phone = phoneNumber(String(form.get('phone') ?? ''));
    const passphrase = String(form.get('passphrase') ?? '');
    if (!passphrase) return back(request, { error: 'passphrase' });
    if (!phone) return back(request, { error: 'phone' });
    try {
      const status = await post<{ has_pin: boolean }>('/ops/auth/pin/status', { passphrase, phone });
      await setSignIn({ passphrase, phone, hasPin: status.has_pin });
      return back(request, { step: status.has_pin ? 'pin' : 'create' });
    } catch (error) {
      return back(request, { error: reason(error) });
    }
  }

  if (step === 'new-pin') {
    // Signed in by a texted code: save the PIN used from now on.
    if (!/^\d{4,6}$/.test(pin)) return back(request, { step, error: 'pin-format' });
    if (pin !== confirm) return back(request, { step, error: 'pin-mismatch' });
    if (guessable(pin)) return back(request, { step, error: 'pin-easy' });
    try {
      await put('/ops/auth/pin', { pin });
    } catch (error) {
      return back(request, { step, error: reason(error) });
    }
    return NextResponse.redirect(new URL('/manage', request.url), 303);
  }

  if (step === 'code') {
    const challenge = await pendingChallenge();
    if (!challenge) return back(request, { error: 'expired' });
    try {
      const session = await post<Session>('/ops/auth/verify', { challenge_id: challenge.id, code: String(form.get('code') ?? '').trim() });
      await startSession(session.session_token, session.expires_in);
      await endSignIn();
    } catch (error) {
      const status = error instanceof ApiError ? error.status : 0;
      return back(request, status === 400 ? { step: 'code', error: 'code' } : { error: reason(error) });
    }
    return back(request, { step: 'new-pin' });
  }

  const pending = await pendingSignIn();
  if (!pending) return back(request, { error: 'expired' });

  if (step === 'reset') {
    // Forgot PIN: the one place staff sign-in texts a code.
    try {
      const challenge = await post<Challenge>('/ops/auth/otp', { passphrase: pending.passphrase, phone: pending.phone });
      await setChallenge({ id: challenge.challenge_id, phone: pending.phone, developmentCode: challenge.development_code });
    } catch (error) {
      return back(request, { step: 'pin', error: reason(error) });
    }
    return back(request, { step: 'code' });
  }

  // step 'pin' (sign in) or 'create' (first PIN, then sign in)
  const creating = step === 'create';
  if (!/^\d{4,6}$/.test(pin)) return back(request, { step, error: 'pin-format' });
  if (creating && pin !== confirm) return back(request, { step, error: 'pin-mismatch' });
  if (creating && guessable(pin)) return back(request, { step, error: 'pin-easy' });
  try {
    const session = await post<Session>('/ops/auth/pin/sign-in', { passphrase: pending.passphrase, phone: pending.phone, pin });
    await startSession(session.session_token, session.expires_in);
    await endSignIn();
  } catch (error) {
    return back(request, { step, error: reason(error) });
  }
  return NextResponse.redirect(new URL('/manage', request.url), 303);
}
