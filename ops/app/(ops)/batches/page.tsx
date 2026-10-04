import Link from 'next/link';
import { DesktopBatches } from '@/components/production/desktop-batches';
import { BatchSummary } from '@/components/production/batch-summary';
import { SearchBox, FilterMenu } from '@/components/list-toolbar';
import { Icons } from '@/components/icons';
import { Empty, Notice } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { batchStatus, batchTitle, type Batch } from '@/lib/production';
import { param, type ListParams } from '@/lib/paging';
import { titleCase } from '@/lib/format';
import styles from '@/components/production/production.module.css';

export const metadata = { title: 'Production batches · Omoterra Operations' };
export default async function Batches({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let batches: Batch[];
  try { batches = await get<Batch[]>('/ops/batches'); }
  catch (error) { return <main className={styles.page}><h1>Production batches</h1><Notice tone="error">{error instanceof ApiError ? error.message : 'Production batches could not be loaded.'}</Notice></main>; }
  const q = param(params, 'q').toLowerCase();
  const status = param(params, 'status');
  const category = param(params, 'category');
  const filtered = batches.filter((batch) => (!q || `${batchTitle(batch)} ${batch.supplier_name} ${batch.id}`.toLowerCase().includes(q)) && (!status || batchStatus(batch).tone === status || batch.status === status) && (!category || batch.category === category));
  const pages = Math.max(1, Math.ceil(filtered.length / 20));
  const page = Math.min(pages, Math.max(1, Math.floor(Number(param(params, 'page')) || 1)));
  const items = filtered.slice((page - 1) * 20, page * 20);
  const href = (next: number) => { const query = new URLSearchParams(); for (const key of ['q', 'status', 'category']) if (param(params, key)) query.set(key, param(params, key)); query.set('page', String(next)); return `/batches?${query}`; };
  return <>
    <div className={styles.desktop}><DesktopBatches batches={items}/></div>
    <main className={`${styles.page} ${styles.mobile}`} data-production-list>
      <h1>Production batches</h1>
      <div className={styles.controls}>
        <SearchBox placeholder="Search batches..."/>
        <FilterMenu label={<span className="sr-only">Filter batches</span>}><label>Status<select name="status" defaultValue={status}><option value="">All</option>{[['reviewed','Reviewed'],['review','Needs review'],['pending','Pending'],['rejected','Rejected'],['draft','Draft']].map(([key,label]) => <option key={key} value={key}>{label}</option>)}</select></label><label>Product<select name="category" defaultValue={category}><option value="">All</option>{[...new Set(batches.map(b => b.category))].map(value => <option key={value} value={value}>{titleCase(value)}</option>)}</select></label></FilterMenu>
        <Link href="/batches/new" className={styles.primary}><Icons.plus size={20}/>New batch</Link>
      </div>
      {items.length ? <div className={styles.list}>{items.map(batch => <Link key={batch.id} href={`/batches/${batch.id}`} className={styles.batchCard}><BatchSummary batch={batch}/></Link>)}</div> : <Empty>No production batches found.</Empty>}
    </main>
    {pages > 1 && <nav className={styles.pagination} aria-label="Batch pages">{page > 1 && <Link href={href(page - 1)}>Previous</Link>}<span>{page} / {pages}</span>{page < pages && <Link href={href(page + 1)}>Next</Link>}</nav>}
  </>;
}
