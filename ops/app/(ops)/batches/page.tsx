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
  const region = param(params, 'region');
  const readyFrom = param(params, 'ready_from');
  const readyTo = param(params, 'ready_to');
  const filtered = batches.filter((batch) => (!q || `${batchTitle(batch)} ${batch.supplier_name} ${batch.id}`.toLowerCase().includes(q)) && (!status || batchStatus(batch).tone === status || batch.status === status) && (!category || batch.category === category) && (!region || batch.region === region) && (!readyFrom || !!batch.expected_ready_date && batch.expected_ready_date >= readyFrom) && (!readyTo || !!batch.expected_ready_date && batch.expected_ready_date <= readyTo));
  const pages = Math.max(1, Math.ceil(filtered.length / 20));
  const page = Math.min(pages, Math.max(1, Math.floor(Number(param(params, 'page')) || 1)));
  const items = filtered.slice((page - 1) * 20, page * 20);
  const href = (next: number) => { const query = new URLSearchParams(); for (const key of ['q', 'status', 'category', 'region', 'ready_from', 'ready_to']) if (param(params, key)) query.set(key, param(params, key)); query.set('page', String(next)); return `/batches?${query}`; };
  return <main className={styles.page} data-production-list>
      <div className={styles.pageHeading}><h1>Production batches</h1><Link href="/batches/new" className={styles.primary}><Icons.plus size={20}/>Add batch</Link></div>
      <div className={styles.controls}>
        <SearchBox placeholder="Search by supplier, product or batch ID..."/>
        <FilterMenu label="Filters"><label>Status<select name="status" defaultValue={status}><option value="">All</option>{[['reviewed','Reviewed'],['review','Needs review'],['pending','Pending'],['rejected','Rejected'],['draft','Draft']].map(([key,label]) => <option key={key} value={key}>{label}</option>)}</select></label><label>Product<select name="category" defaultValue={category}><option value="">All</option>{[...new Set(batches.map(b => b.category))].map(value => <option key={value} value={value}>{titleCase(value)}</option>)}</select></label><label>Region<select name="region" defaultValue={region}><option value="">All regions</option>{[...new Set(batches.map(b => b.region).filter(Boolean))].sort().map(value => <option key={value} value={value}>{value}</option>)}</select></label><label>Ready from<input type="date" name="ready_from" defaultValue={readyFrom}/></label><label>Ready until<input type="date" name="ready_to" defaultValue={readyTo}/></label><Link href="/batches">Clear filters</Link></FilterMenu>

      </div>
      {items.length ? <><div className={styles.desktop}><DesktopBatches batches={items}/></div><div className={`${styles.list} ${styles.mobile}`}>{items.map(batch => <Link key={batch.id} href={`/batches/${batch.id}`} className={styles.batchCard}><BatchSummary batch={batch}/></Link>)}</div></> : <Empty>No production batches found.</Empty>}
    <div className={styles.tableFooter}><span>Showing {filtered.length ? (page - 1) * 20 + 1 : 0}–{Math.min(page * 20, filtered.length)} of {filtered.length} batches</span><nav className={styles.pagination} aria-label="Batch pages">{page > 1 && <Link href={href(page - 1)}>Previous</Link>}<span>{page} / {pages}</span>{page < pages && <Link href={href(page + 1)}>Next</Link>}</nav></div>
  </main>;
}
