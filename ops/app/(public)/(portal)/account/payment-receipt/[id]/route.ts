import { cookies } from 'next/headers';
import { MEMBER_COOKIE } from '@/lib/member-cookie';
import { memberSignedFile } from '@/lib/public-api';

const PHOTO_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);

export async function GET(_: Request, { params }: { params: Promise<{ id: string }> }) {
  const token = (await cookies()).get(MEMBER_COOKIE)?.value;
  const id = (await params).id;
  const photo = token && /^[0-9a-f-]{36}$/.test(id)
    ? await memberSignedFile(`/supplier/payments/${id}/receipt`, token) : null;
  if (!photo || !PHOTO_TYPES.has(photo.type.split(';')[0].trim().toLowerCase())) return new Response(null, { status: 404 });
  return new Response(photo.body, { headers: {
    'Content-Type': photo.type, 'Cache-Control': 'private, max-age=600', 'X-Content-Type-Options': 'nosniff',
    'Content-Security-Policy': "default-src 'none'; sandbox",
  } });
}
