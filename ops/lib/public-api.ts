import 'server-only';

// Calls the backend as a member of the public, never with the dashboard's
// operations token: website registration uses the same member routes as the
// app (phone code sign-in, /me, /media, /supplier/onboarding).
const base = process.env.OMOTERRA_API_URL ?? 'https://omoterra.jopex.co.tz/api/v1';

// A member's private photo: the backend checks it is theirs and answers with a
// short-lived signed link (R2, or a path under the API on local storage).
export async function memberMedia(id: string, token: string): Promise<{ body: ArrayBuffer; type: string } | null> {
  if (!/^[0-9a-f-]{36}$/.test(id)) return null;
  try {
    const signed = await call<{ url: string }>(`/media/${id}`, { token });
    const url = /^https:\/\//.test(signed.url) ? signed.url : base + signed.url;
    const file = await fetch(url, { cache: 'no-store' });
    if (!file.ok) return null;
    return { body: await file.arrayBuffer(), type: file.headers.get('content-type') ?? 'application/octet-stream' };
  } catch {
    return null;
  }
}

export class PublicApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
    // Dotted path of the field the backend rejected, e.g. `current_batch.expected_ready_date`.
    readonly field?: string,
  ) {
    super(message);
  }
}

function failure(status: number, parsed: unknown): PublicApiError {
  const detail = parsed && typeof parsed === 'object' && 'detail' in parsed ? (parsed as { detail: unknown }).detail : null;
  if (typeof detail === 'string' && status < 500) return new PublicApiError(status, detail);
  if (Array.isArray(detail) && detail.length) {
    const first = detail[0] as { loc?: unknown[]; msg?: unknown };
    const field = Array.isArray(first.loc) ? first.loc.filter((part) => part !== 'body').join('.') : '';
    if (typeof first.msg === 'string') return new PublicApiError(status, first.msg.replace(/^Value error, /, ''), field || undefined);
  }
  if (status === 401) return new PublicApiError(status, 'Your verification has expired. Confirm your phone number again.', 'phone');
  return new PublicApiError(status, 'We could not complete that just now. Please try again.');
}

export async function call<T>(path: string, init: { method?: string; token?: string; body?: unknown; form?: FormData; key?: string } = {}): Promise<T> {
  const headers: Record<string, string> = {};
  if (init.token) headers.Authorization = `Bearer ${init.token}`;
  if (init.key) headers['Idempotency-Key'] = init.key;
  if (init.body !== undefined) headers['Content-Type'] = 'application/json';
  let response: Response;
  try {
    response = await fetch(base + path, {
      method: init.method ?? 'GET',
      headers,
      body: init.form ?? (init.body !== undefined ? JSON.stringify(init.body) : undefined),
      cache: 'no-store',
    });
  } catch {
    throw new PublicApiError(503, 'We could not reach Omoterra. Check your connection and try again.');
  }
  const text = await response.text();
  let parsed: unknown = null;
  try { parsed = text ? JSON.parse(text) : null; }
  catch { parsed = null; }
  if (!response.ok) throw failure(response.status, parsed);
  return parsed as T;
}
