import { NextResponse } from 'next/server';
import { media } from '@/lib/api';
import { signedIn } from '@/lib/session';

// Only bitmap types the backend re-encodes to are served. Anything else (HTML,
// SVG) would execute in this dashboard's origin, where the session cookie lives,
// so the upstream content type is never echoed back unchecked.
const RENDERABLE = new Set(['image/jpeg', 'image/png', 'image/webp']);

// Backend media is operator-authenticated, so images are proxied through this
// route. Without a dashboard session nothing is served.
export async function GET(_: Request, { params }: { params: Promise<{ id: string }> }) {
  if (!(await signedIn())) return new NextResponse('Not authorised', { status: 403 });
  const { id } = await params;
  const file = await media(id);
  if (!file) return new NextResponse('Not found', { status: 404 });
  const type = file.type.split(';')[0].trim().toLowerCase();
  return new NextResponse(file.body, {
    headers: {
      'Content-Type': RENDERABLE.has(type) ? type : 'application/octet-stream',
      'Content-Disposition': 'inline',
      'Content-Security-Policy': "default-src 'none'; sandbox",
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': 'private, max-age=300',
    },
  });
}
