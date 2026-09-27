import { NextResponse } from 'next/server';
import { signedFile } from '@/lib/api';
import { signedIn } from '@/lib/session';

// The stamp or signature printed on one issued LPO. The backend serves it only
// for issued LPOs, never as plain media, and only to signed-in operators.
export async function GET(_: Request, { params }: { params: Promise<{ id: string; kind: string }> }) {
  if (!(await signedIn())) return new NextResponse('Not authorised', { status: 403 });
  const { id, kind } = await params;
  if (kind !== 'stamp' && kind !== 'signature') return new NextResponse('Not found', { status: 404 });
  const file = await signedFile(`/ops/lpos/${encodeURIComponent(id)}/marks/${kind}`);
  if (!file) return new NextResponse('Not found', { status: 404 });
  return new NextResponse(file.body, {
    headers: {
      'Content-Type': 'image/jpeg',
      'Content-Disposition': 'inline',
      'Content-Security-Policy': "default-src 'none'; sandbox",
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': 'private, no-store',
    },
  });
}
