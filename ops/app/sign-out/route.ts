import { NextResponse } from 'next/server';
import { post } from '@/lib/api';
import { endSession } from '@/lib/session';

export async function POST(request: Request) {
  // End the session on the backend too, so the token is useless even if the
  // cookie was copied.
  try { await post('/ops/auth/logout', {}); } catch {}
  await endSession();
  return NextResponse.redirect(new URL('/sign-in', request.url), 303);
}
