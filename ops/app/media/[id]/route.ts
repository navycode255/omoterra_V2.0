import { NextResponse } from 'next/server';
import { media } from '@/lib/api';
import { signedIn } from '@/lib/session';

// Backend media is operator-authenticated, so images are proxied through this
// route. Without a dashboard session nothing is served.
export async function GET(_: Request, { params }: { params: Promise<{ id: string }> }) {
  if (!(await signedIn())) return new NextResponse('Not authorised', { status: 403 });
  const { id } = await params;
  const file = await media(id);
  if (!file) return new NextResponse('Not found', { status: 404 });
  return new NextResponse(file.body, {
    headers: { 'Content-Type': file.type, 'Cache-Control': 'private, max-age=300' },
  });
}
