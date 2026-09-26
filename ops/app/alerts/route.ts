import { NextResponse } from 'next/server';
import { ApiError, get, post } from '@/lib/api';

// The header bell's feed. The backend checks the operator's session, so a
// signed-out browser just gets 401 here.
async function relay(work: () => Promise<unknown>) {
  try {
    return NextResponse.json(await work(), { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    return NextResponse.json({ error: 'unavailable' }, { status: error instanceof ApiError ? error.status : 503 });
  }
}

export async function GET() {
  return relay(() => get('/ops/alerts'));
}

export async function POST() {
  return relay(() => post('/ops/alerts/seen', {}));
}
