import Link from 'next/link';
import type { ReactNode } from 'react';
import { SearchBox } from '@/components/list-toolbar';
import { ListFooter } from '@/components/finance/list-footer';
import styles from '@/components/finance/finance-list.module.css';
import { param, type ListParams, type Page } from '@/lib/paging';

export type ListTab = { key: string; label: string };

// Status tabs, search box (results as you type), extra filter menus and the
// page footer around every operations list (the table goes in as children),
// in the same design as the finance lists. Every filter lives in the URL, so
// a filtered view can be shared or bookmarked.
export function ListControls({
  path,
  params,
  data,
  tabs = [],
  placeholder = 'Search',
  noun = ['row', 'rows'],
  keep = [],
  filters,
  children,
}: {
  path: string;
  params: ListParams;
  data: Page<unknown>;
  tabs?: ListTab[];
  placeholder?: string;
  noun?: [string, string];
  /** Kept for callers; "need action" rows are simply listed first. */
  actionLabel?: string;
  /** The list's own extra filters, carried along with search and tabs. */
  keep?: string[];
  /** Extra filter menus (components/list-toolbar FilterMenu) beside search. */
  filters?: ReactNode;
  children: ReactNode;
}) {
  const status = param(params, 'status');

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
    <div className={styles.listControls}>
      {tabs.length > 0 && (
        <nav className={styles.tabs} aria-label="Filter">
          {tabs.map((tab) => (
            <Link key={tab.key} href={href({ status: tab.key, page: '' })} data-active={status === tab.key} aria-current={status === tab.key ? 'page' : undefined}>
              {tab.label}<span>{data.counts?.[tab.key || 'all'] ?? ''}</span>
            </Link>
          ))}
        </nav>
      )}
      <div className={styles.toolbar} role="search">
        <SearchBox placeholder={`${placeholder.replace(/…$/, '')}…`} />
        {filters && <div className={styles.toolbarEnd}>{filters}</div>}
      </div>
      {children}
      <ListFooter data={data} label={noun[1][0].toUpperCase() + noun[1].slice(1)} href={(page) => href({ page: page > 1 ? String(page) : '' })} />
    </div>
  );
}
