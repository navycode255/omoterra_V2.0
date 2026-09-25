import { NextRequest, NextResponse } from 'next/server';
import { ApiError, post } from '@/lib/api';
import { pendingChallenge, setChallenge, startSession } from '@/lib/session';
import type { Operator } from '@/lib/types';

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

type Challenge = { challenge_id: string; development_code?: string };
type Session = { session_token: string; expires_in: number; operator: Operator };

export async function POST(request: NextRequest) {
  const form = await request.formData();
  const step = String(form.get('step') ?? 'phone');

  if (step === 'phone') {
    const phone = phoneNumber(String(form.get('phone') ?? ''));
    if (!phone) return back(request, { error: 'phone' });
    try {
      const challenge = await post<Challenge>('/ops/auth/otp', { phone });
      await setChallenge({ id: challenge.challenge_id, phone, developmentCode: challenge.development_code });
    } catch (error) {
      const status = error instanceof ApiError ? error.status : 0;
      return back(request, { error: status === 403 ? 'unknown' : status === 429 ? 'wait' : 'server' });
    }
    return back(request, { step: 'code' });
  }

  const challenge = await pendingChallenge();
  if (!challenge) return back(request, { error: 'expired' });
  const code = String(form.get('code') ?? '').trim();
  try {
    const session = await post<Session>('/ops/auth/verify', { challenge_id: challenge.id, code });
    await startSession(session.session_token, session.expires_in);
  } catch (error) {
    const status = error instanceof ApiError ? error.status : 0;
    return back(request, status === 400 ? { step: 'code', error: 'code' } : { error: status === 403 ? 'unknown' : 'server' });
  }
  return NextResponse.redirect(new URL('/manage', request.url), 303);
}
