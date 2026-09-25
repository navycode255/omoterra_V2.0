import 'server-only';

// The operations token is a shared backend secret. It is read from the server
// environment and attached here, so it never reaches the browser bundle.
const base = process.env.OMOTERRA_API_URL ?? 'https://omoterra.jopex.co.tz/api/v1';
const token = process.env.OMOTERRA_OPS_TOKEN ?? '';

export class ApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

// FastAPI sends either a message string or, for field validation, a list of
// { loc, msg } entries. The first field error is shown with its field name.
function errorDetail(parsed: unknown): string | null {
  if (!parsed || typeof parsed !== 'object' || !('detail' in parsed)) return null;
  const { detail } = parsed;
  if (typeof detail === 'string') return detail;
  if (!Array.isArray(detail) || !detail.length) return null;
  const first = detail[0] as { loc?: unknown[]; msg?: unknown };
  if (typeof first?.msg !== 'string') return null;
  const message = first.msg.replace(/^Value error, /, '');
  const field = Array.isArray(first.loc) ? first.loc.filter((part) => part !== 'body' && typeof part === 'string').pop() : undefined;
  return field ? `${String(field).replace(/_/g, ' ').replace(/^\w/, (c) => c.toUpperCase())}: ${message}` : message;
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  if (!token) {
    throw new ApiError(500, 'We could not load this information just now. Please try again later.');
  }
  let response: Response;
  try {
    response = await fetch(base + path, {
      ...init,
      headers: { 'X-Ops-Token': token, ...(init.headers ?? {}) },
      cache: 'no-store',
    });
  } catch {
    throw new ApiError(503, 'We could not load this information just now. Check your connection and try again.');
  }
  const body = await response.text();
  let parsed: unknown = null;
  try { parsed = body ? JSON.parse(body) : null; }
  catch { parsed = null; }
  if (!response.ok) {
    const detail = errorDetail(parsed);
    const message = response.status === 401
      ? 'Your sign-in has expired. Please sign in again.'
      : response.status === 403
        ? 'You do not have access to this information.'
        : response.status === 404
          ? 'We could not find that information.'
          : response.status === 400 || response.status === 409 || response.status === 422
            ? detail ?? 'Please check the information and try again.'
            : 'We could not complete that just now. Please try again.';
    throw new ApiError(response.status, message);
  }
  return parsed as T;
}

export function get<T>(path: string) {
  return request<T>(path);
}

// Every write the backend treats as idempotent requires a caller-supplied key.
export function post<T>(path: string, body: unknown, idempotencyKey?: string) {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (idempotencyKey) headers['Idempotency-Key'] = idempotencyKey;
  return request<T>(path, { method: 'POST', headers, body: JSON.stringify(body) });
}

export function patch<T>(path: string, body: unknown, idempotencyKey?: string) {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (idempotencyKey) headers['Idempotency-Key'] = idempotencyKey;
  return request<T>(path, { method: 'PATCH', headers, body: JSON.stringify(body) });
}

export async function postFile<T>(path: string, file: File, idempotencyKey: string): Promise<T> {
  const form = new FormData();
  form.append('file', file);
  return request<T>(path, {
    method: 'POST',
    headers: { 'Idempotency-Key': idempotencyKey },
    body: form,
  });
}

// Photos are fetched server-side and streamed through this app, because the
// backend media route is ops-authenticated and the browser has no token.
export async function media(id: string): Promise<{ body: ArrayBuffer; type: string } | null> {
  if (!token) return null;
  const response = await fetch(`${base}/ops/media/${id}`, {
    headers: { 'X-Ops-Token': token },
    cache: 'no-store',
  });
  if (!response.ok) return null;
  return {
    body: await response.arrayBuffer(),
    type: response.headers.get('content-type') ?? 'application/octet-stream',
  };
}

export function put<T>(path: string, body: unknown) {
  return request<T>(path, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
}
