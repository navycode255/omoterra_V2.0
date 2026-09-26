import { cookies } from 'next/headers';
import { MEMBER_COOKIE } from '@/lib/member-cookie';
import { memberMedia } from '@/lib/public-api';

// The signed-in member's own photos (farm and stock), fetched server-side with
// their session so the browser never needs a backend token.
export async function GET(_: Request, { params }: { params: Promise<{ id: string }> }) {
  const token = (await cookies()).get(MEMBER_COOKIE)?.value;
  const photo = token ? await memberMedia((await params).id, token) : null;
  if (!photo || !photo.type.startsWith('image/')) return new Response(null, { status: 404 });
  return new Response(photo.body, {
    headers: { 'Content-Type': photo.type, 'Cache-Control': 'private, max-age=600', 'X-Content-Type-Options': 'nosniff' },
  });
}
