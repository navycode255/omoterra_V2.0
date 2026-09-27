import 'server-only';
import { cookies } from 'next/headers';

// The operations token is the dashboard server's own backend credential. It is
// read from the server environment and attached here, so it never reaches the
// browser bundle. The signed-in operator's session (an httpOnly cookie) goes
// with it, so the backend knows which person made each change.
const base = process.env.OMOTERRA_API_URL ?? 'https://omoterra.jopex.co.tz/api/v1';
const token = process.env.OMOTERRA_OPS_TOKEN ?? '';

export class ApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
    // The backend's own reason, kept even where `message` is replaced by a
    // friendlier line (403s become "You do not have access…").
    readonly detail: string | null = null,
  ) {
    super(message);
  }
}

// Staff (/ops) answers are always English, so their reasons can be told apart.
// A mismatched dashboard token or switched-off setup must not read as a wrong
// passphrase or an unknown number.
export function opsCause(error: unknown): 'connection' | 'setup-off' | null {
  const detail = error instanceof ApiError ? error.detail ?? '' : '';
  if (detail.startsWith('Operations authentication required')) return 'connection';
  if (detail.startsWith('Admin setup is turned off')) return 'setup-off';
  return null;
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
  const operator = (await cookies()).get('omoterra_operator')?.value ?? '';
  let response: Response;
  try {
    response = await fetch(base + path, {
      ...init,
      headers: {
        'X-Ops-Token': token,
        ...(operator ? { 'X-Operator-Session': operator } : {}),
        ...(init.headers ?? {}),
      },
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
    throw new ApiError(response.status, message, detail);
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

export async function postFiles<T>(path: string, field: string, files: File[]): Promise<T> {
  const form = new FormData();
  for (const file of files) form.append(field, file);
  return request<T>(path, { method: 'POST', body: form });
}

export function del<T>(path: string) {
  return request<T>(path, { method: 'DELETE' });
}

// Photos are fetched server-side and streamed through this app, because the
// backend media route is ops-authenticated and the browser has no token. The
// backend answers with a short-lived signed URL: an R2 link, or a path under
// the API when media is on the server's disk.
export async function media(id: string): Promise<{ body: ArrayBuffer; type: string } | null> {
  return signedFile(`/ops/media/${id}`);
}

/** Any ops endpoint that answers with a signed link (e.g. an LPO's stamp). */
export async function signedFile(path: string): Promise<{ body: ArrayBuffer; type: string } | null> {
  if (!token) return null;
  const operator = (await cookies()).get('omoterra_operator')?.value ?? '';
  const signed = await fetch(`${base}${path}`, {
    headers: { 'X-Ops-Token': token, 'X-Operator-Session': operator },
    cache: 'no-store',
  });
  if (!signed.ok) return null;
  const { url } = (await signed.json()) as { url: string };
  const response = await fetch(/^https:\/\//.test(url) ? url : `${base}${url}`, { cache: 'no-store' });
  if (!response.ok) return null;
  return {
    body: await response.arrayBuffer(),
    type: response.headers.get('content-type') ?? 'application/octet-stream',
  };
}

export function put<T>(path: string, body: unknown) {
  return request<T>(path, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
}
