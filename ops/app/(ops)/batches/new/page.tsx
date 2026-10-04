import Link from 'next/link';
import { SearchBox } from '@/components/list-toolbar';
import { Empty, Notice } from '@/components/ui';
import { Icons } from '@/components/icons';
import { get, ApiError } from '@/lib/api';
import { listPath, param, type ListParams, type Page } from '@/lib/paging';
import type { SupplierRow } from '@/lib/types';
import styles from '@/components/production/production.module.css';

export const metadata = { title: 'New batch · Omoterra Operations' };
export default async function NewBatch({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let data: Page<SupplierRow>;
  try { data = await get<Page<SupplierRow>>(listPath('/ops/suppliers', params)); }
  catch (error) { return <main className={styles.page}><h1>New batch</h1><Notice tone="error">{error instanceof ApiError ? error.message : 'Suppliers could not be loaded.'}</Notice></main>; }
  const href = (page: number) => `/batches/new?${new URLSearchParams({ q: param(params, 'q'), page: String(page) })}`;
  return <main className={styles.page}><h1>New batch</h1><SearchBox placeholder="Search suppliers..."/>
    {data.items.length ? <div className={styles.list}>{data.items.map(supplier => <Link className={styles.batchCard} key={supplier.id} href={`/suppliers/${supplier.id}?new_batch=1#production`}><div className={styles.cardHeading}><h2>{supplier.public_alias || supplier.legal_name || supplier.phone}</h2><Icons.chevron size={20}/></div></Link>)}</div> : <Empty>No suppliers found.</Empty>}
    <nav className={styles.pagination} aria-label="Supplier pages">{data.page > 1 && <Link href={href(data.page - 1)}>Previous</Link>}<span>{data.page}</span>{data.page * data.page_size < data.total && <Link href={href(data.page + 1)}>Next</Link>}</nav>
  </main>;
}
