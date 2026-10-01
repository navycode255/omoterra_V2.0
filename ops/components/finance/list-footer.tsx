import Link from 'next/link';
import { pageCount, type Page } from '@/lib/paging';
import { RowsPerPage } from './rows-per-page';
import styles from './finance-list.module.css';

// "Showing 1 – 10 of 54", the page numbers and rows per page under a list.
// `href(page)` builds the link to a page with the list's current filters.
export function ListFooter({ data, href, label }: { data: Page<unknown>; href: (page: number) => string; label: string }) {
  const pages = pageCount(data);
  const current = Math.min(data.page, pages);
  const first = data.total ? (current - 1) * data.page_size + 1 : 0;
  const last = Math.min(data.total, (current - 1) * data.page_size + data.items.length);
  const numbers = [...new Set([1, current - 1, current, current + 1, pages])].filter((n) => n >= 1 && n <= pages).sort((a, b) => a - b);
  return <footer className={styles.footer}>
    <span className={styles.showing}>Showing {first} – {last} of {data.total}</span>
    {pages > 1 && <nav className={styles.pages} aria-label={`${label} pages`}>
      {current > 1 ? <Link href={href(current - 1)} className={styles.step}>‹ Previous</Link> : <span className={styles.step} aria-disabled="true">‹ Previous</span>}
      {numbers.map((n, index) => <span key={n} className={styles.pageGroup}>
        {index > 0 && n - numbers[index - 1] > 1 && <span className={styles.ellipsis}>…</span>}
        <Link href={href(n)} data-active={n === current} aria-current={n === current ? 'page' : undefined}>{n}</Link>
      </span>)}
      {current < pages ? <Link href={href(current + 1)} className={styles.step}>Next ›</Link> : <span className={styles.step} aria-disabled="true">Next ›</span>}
    </nav>}
    <RowsPerPage value={data.page_size} />
  </footer>;
}
