'use client';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import styles from './finance-list.module.css';

// "Rows per page" in a list footer: reloads the list from page 1.
export function RowsPerPage({ value }: { value: number }) {
  const router = useRouter();
  const pathname = usePathname();
  const search = useSearchParams();
  return <label className={styles.rows}>Rows per page
    <select value={String(value)} onChange={(event) => {
      const query = new URLSearchParams(search.toString());
      query.set('page_size', event.target.value); query.delete('page');
      router.push(`${pathname}?${query}`);
    }}>{[10, 20, 50, 100].map((n) => <option key={n} value={n}>{n}</option>)}</select>
  </label>;
}
