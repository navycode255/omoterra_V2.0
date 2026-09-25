import { NextRequest, NextResponse } from 'next/server';
import { ApiError, post } from '@/lib/api';
import { endSetup, setSetup, setupState, startSession } from '@/lib/session';
import type { Operator } from '@/lib/types';

// Admin setup from the sign-in screen, one step per POST:
//   passphrase → (existing admin's phone → their code, when an admin exists)
//   → new admin's name and phone → the code sent to that phone → signed in.
// Every check happens on the backend; this only carries the state between steps.

function to(request: NextRequest, params: Record<string, string>) {
  const url = new URL('/sign-in', request.url);
  url.searchParams.set('mode', 'setup');
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

function failure(error: unknown) {
  if (!(error instanceof ApiError)) return 'server';
  return ({ 400: 'code', 401: 'expired', 403: 'denied', 409: 'taken', 429: 'locked' } as Record<number, string>)[error.status] ?? 'server';
}

type Start = { setup_token: string; needs_approval: boolean; expires_in: number };
type Challenge = { challenge_id: string; development_code?: string };
type Session = { session_token: string; expires_in: number; operator: Operator };

// "Back to sign in": forget the setup in progress.
export async function GET(request: NextRequest) {
  await endSetup();
  return NextResponse.redirect(new URL('/sign-in', request.url), 303);
}

export async function POST(request: NextRequest) {
  const form = await request.formData();
  const step = String(form.get('step') ?? '');
  const field = (name: string) => String(form.get(name) ?? '').trim();

  if (step === 'passphrase') {
    try {
      const started = await post<Start>('/ops/setup/start', { passphrase: String(form.get('passphrase') ?? '') });
      await setSetup({ token: started.setup_token, stage: started.needs_approval ? 'approve-phone' : 'details' },
        started.expires_in);
      return to(request, {});
    } catch (error) {
      const reason = failure(error);
      return to(request, { error: reason === 'denied' ? 'passphrase' : reason });
    }
  }

  const state = await setupState();
  if (!state) return to(request, { error: 'expired' });

  try {
    if (step === 'approve-phone') {
      const phone = phoneNumber(field('phone'));
      if (!phone) return to(request, { error: 'phone' });
      const challenge = await post<Challenge>('/ops/setup/approve/otp', { setup_token: state.token, phone });
      await setSetup({ ...state, stage: 'approve-code', phone, challengeId: challenge.challenge_id,
        developmentCode: challenge.development_code });
      return to(request, {});
    }
    if (step === 'approve-code') {
      const approved = await post<{ approved_by: string }>('/ops/setup/approve/verify',
        { setup_token: state.token, challenge_id: state.challengeId, code: field('code') });
      await setSetup({ token: state.token, stage: 'details', approvedBy: approved.approved_by });
      return to(request, {});
    }
    if (step === 'details') {
      const phone = phoneNumber(field('phone'));
      if (!phone) return to(request, { error: 'phone' });
      const challenge = await post<Challenge>('/ops/setup/admin/otp',
        { setup_token: state.token, name: field('name'), phone });
      await setSetup({ ...state, stage: 'new-code', phone, challengeId: challenge.challenge_id,
        developmentCode: challenge.development_code });
      return to(request, {});
    }
    if (step === 'new-code') {
      const session = await post<Session>('/ops/setup/admin/verify',
        { setup_token: state.token, challenge_id: state.challengeId, code: field('code') });
      await endSetup();
      await startSession(session.session_token, session.expires_in);
      return NextResponse.redirect(new URL('/staff', request.url), 303);
    }
  } catch (error) {
    const reason = failure(error);
    if (reason === 'expired') await endSetup();
    return to(request, { error: reason });
  }
  return to(request, { error: 'server' });
}
