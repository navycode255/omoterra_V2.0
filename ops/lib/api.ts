import 'server-only';

// The operations token is a shared backend secret. It is read from the server
// environment and attached here, so it never reaches the browser bundle.
const base = process.env.OMOTERRA_API_URL ?? 'http://127.0.0.1:8010/api/v1';
const token = process.env.OMOTERRA_OPS_TOKEN ?? '';

export class ApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  if (!token) {
    throw new ApiError(500, 'OMOTERRA_OPS_TOKEN is not configured on the server.');
  }
  let response: Response;
  try {
    response = await fetch(base + path, {
      ...init,
      headers: { 'X-Ops-Token': token, ...(init.headers ?? {}) },
      cache: 'no-store',
    });
  } catch {
    throw new ApiError(503, 'The Omoterra backend is unreachable. Check it is running.');
  }
  const body = await response.text();
  const parsed = body ? JSON.parse(body) : null;
  if (!response.ok) {
    const detail = parsed?.detail ?? parsed?.message;
    throw new ApiError(response.status, typeof detail === 'string' ? detail : 'The request failed.');
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
