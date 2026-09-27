import { NextResponse } from 'next/server';
import { signedFile } from '@/lib/api';
import { signedIn } from '@/lib/session';

// An admin's own view of the current stamp or their signature (the backend
// refuses anyone else).
export async function GET(_: Request, { params }: { params: Promise<{ kind: string }> }) {
  if (!(await signedIn())) return new NextResponse('Not authorised', { status: 403 });
  const { kind } = await params;
  if (kind !== 'stamp' && kind !== 'signature') return new NextResponse('Not found', { status: 404 });
  const file = await signedFile(`/ops/marks/${kind}/preview`);
  if (!file) return new NextResponse('Not found', { status: 404 });
  return new NextResponse(file.body, {
    headers: { 'Content-Type': 'image/jpeg', 'Content-Security-Policy': "default-src 'none'; sandbox",
      'X-Content-Type-Options': 'nosniff', 'Cache-Control': 'private, no-store' },
  });
}
