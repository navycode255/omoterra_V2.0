import Link from 'next/link';
import type { ReactNode } from 'react';
import { pageCount, param, type ListParams, type Page } from '@/lib/paging';

export type ListTab = { key: string; label: string };

// Search box, status tabs, page buttons and total count around every
// operations list (the table goes in as children). Every filter lives in the
// URL, so a filtered view can be shared or bookmarked, and the controls work
// without client JavaScript.
export function ListControls({
  path,
  params,
  data,
  tabs = [],
  placeholder = 'Search',
  noun = ['row', 'rows'],
  actionLabel = 'need action',
  keep = [],
  children,
}: {
  path: string;
  params: ListParams;
  data: Page<unknown>;
  tabs?: ListTab[];
  placeholder?: string;
  noun?: [string, string];
  actionLabel?: string;
  /** The list's own extra filters, carried along with search and tabs. */
  keep?: string[];
  children: ReactNode;
}) {
  const status = param(params, 'status');
  const q = param(params, 'q');

  function href(change: Record<string, string>) {
    const query = new URLSearchParams();
    for (const key of ['status', 'q', 'page_size', ...keep]) {
      const value = param(params, key);
      if (value) query.set(key, value);
    }
    for (const [key, value] of Object.entries(change)) {
      if (value) query.set(key, value);
      else query.delete(key);
    }
    return query.size ? `${path}?${query}` : path;
  }

  return (
    <div className="list-controls">
      {tabs.length > 0 && (
        <nav className="tabs" aria-label="Filter">
          {tabs.map((tab) => {
            const count = data.counts?.[tab.key || 'all'];
            return (
              <Link key={tab.key} href={href({ status: tab.key, page: '' })} className="tab" data-active={status === tab.key}>
                {tab.label}
                {count !== undefined && <span className="meta"> {count}</span>}
              </Link>
            );
          })}
        </nav>
      )}
      <form className="row list-search" action={path} role="search">
        {['status', 'page_size', ...keep].map((key) => {
          const value = param(params, key);
          return value ? <input key={key} type="hidden" name={key} value={value} /> : null;
        })}
        <input className="input" name="q" type="search" defaultValue={q} placeholder={placeholder} aria-label={placeholder} />
        <button className="button" data-variant="secondary" type="submit">Search</button>
        {q && <Link className="small" href={href({ q: '', page: '' })}>Clear</Link>}
      </form>
      {children}
      <ListFooter path={path} params={params} data={data} noun={noun} actionLabel={actionLabel} keep={keep} />
    </div>
  );
}

function ListFooter({
  path,
  params,
  data,
  noun = ['row', 'rows'],
  actionLabel = 'need action',
  keep = [],
}: {
  path: string;
  params: ListParams;
  data: Page<unknown>;
  noun?: [string, string];
  actionLabel?: string;
  keep?: string[];
}) {
  const pages = pageCount(data);
  const page = Math.min(data.page, pages);

  function href(target: number) {
    const query = new URLSearchParams();
    for (const key of ['status', 'q', 'page_size', ...keep]) {
      const value = param(params, key);
      if (value) query.set(key, value);
    }
    if (target > 1) query.set('page', String(target));
    return query.size ? `${path}?${query}` : path;
  }

  const numbers = [...new Set([1, page - 1, page, page + 1, pages])].filter((n) => n >= 1 && n <= pages).sort((a, b) => a - b);

  return (
    <footer className="list-footer">
      <span className="small muted">
        {data.total} {data.total === 1 ? noun[0] : noun[1]}
        {data.actionable > 0 && <> · <strong>{data.actionable} {actionLabel}</strong>, all shown on page 1</>}
      </span>
      {pages > 1 && (
        <nav className="list-pages" aria-label="Pages">
          {page > 1 ? <Link href={href(page - 1)} aria-label="Previous page">‹</Link> : <span aria-hidden>‹</span>}
          {numbers.map((n, index) => (
            <span key={n} className="list-page-group">
              {index > 0 && n - numbers[index - 1] > 1 && <span className="meta">…</span>}
              <Link href={href(n)} data-active={n === page} aria-current={n === page ? 'page' : undefined}>{n}</Link>
            </span>
          ))}
          {page < pages ? <Link href={href(page + 1)} aria-label="Next page">›</Link> : <span aria-hidden>›</span>}
        </nav>
      )}
    </footer>
  );
}
