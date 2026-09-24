import { NextRequest, NextResponse } from 'next/server';
import { startSession, verifyPassphrase } from '@/lib/session';

function signInRedirect(request: NextRequest, error?: string) {
  const url = new URL('/sign-in', request.url);
  if (error) url.searchParams.set('error', error);
  return NextResponse.redirect(url, 303);
}

export async function POST(request: NextRequest) {
  const formData = await request.formData();
  const passphrase = String(formData.get('passphrase') ?? '');

  let valid = false;
  try {
    valid = verifyPassphrase(passphrase);
  } catch (error) {
    console.error('Omoterra dashboard passphrase is not configured.', error);
    return signInRedirect(request, 'config');
  }

  if (!valid) return signInRedirect(request, '1');

  try {
    await startSession();
  } catch (error) {
    console.error('Could not create the Omoterra dashboard session.', error);
    return signInRedirect(request, 'session');
  }

  return NextResponse.redirect(new URL('/manage', request.url), 303);
}
