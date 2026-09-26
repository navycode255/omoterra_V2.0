// The one paging contract every /ops list speaks (backend/app/paging.py).
// Rows that need action are never paged: all of them come first on page 1.
// Paging applies only to the history behind them.

export interface Page<T> {
  items: T[];
  total: number;
  page: number;
  page_size: number;
  /** How many of `total` need action; all of them are on page 1. */
  actionable: number;
  /** Rows per status tab under the same search, counted by the database. */
  counts?: Record<string, number>;
}

export type ListParams = Record<string, string | string[] | undefined>;

/** The first value of a query-string parameter. */
export function param(params: ListParams, key: string): string {
  const value = params[key];
  return (Array.isArray(value) ? value[0] : value) ?? '';
}

/**
 * Backend path for a list, carrying the dashboard URL's filters. `keys` are
 * the list's own extra filters on top of status, q, page and page_size.
 */
export function listPath(path: string, params: ListParams, keys: string[] = [], defaults: Record<string, string> = {}) {
  const query = new URLSearchParams();
  for (const key of ['status', 'q', 'page', 'page_size', ...keys]) {
    const value = param(params, key) || defaults[key] || '';
    if (value) query.set(key, value);
  }
  return query.size ? `${path}?${query}` : path;
}

/** Pages of history behind the rows that need action. */
export function pageCount(page: Page<unknown>) {
  return Math.max(1, Math.ceil((page.total - page.actionable) / page.page_size));
}
