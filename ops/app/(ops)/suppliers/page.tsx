import Link from 'next/link';
import { ListControls } from '@/components/list-controls';
import { SupplierTable } from '@/components/supplier-directory';
import { Icons } from '@/components/icons';
import { Notice, PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { listPath, type ListParams, type Page } from '@/lib/paging';
import type { SupplierRow } from '@/lib/types';

export const metadata = { title: 'Suppliers · Omoterra Operations' };

const TABS = [
  { key: '', label: 'All' },
  { key: 'under_review', label: 'Under review' },
  { key: 'approved', label: 'Approved' },
  { key: 'suspended', label: 'Suspended' },
  { key: 'rejected', label: 'Rejected' },
];

export default async function Suppliers({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let data: Page<SupplierRow>;
  try { data = await get<Page<SupplierRow>>(listPath('/ops/suppliers', params)); }
  catch (error) {
    return <><div className="topbar"><PageHeader title="Suppliers" /></div><div className="workspace"><Notice tone="error">{error instanceof ApiError ? error.message : 'Suppliers could not be loaded.'}</Notice></div></>;
  }
  const counts = data.counts ?? {};
  return <>
    <div className="topbar supplier-page-header"><PageHeader title="Suppliers"/><Link className="button add-supplier" href="/suppliers/new"><Icons.plus size={22}/>Add supplier</Link></div>
    <main className="workspace supplier-list-workspace"><div className="supplier-directory">
      <section className="supplier-summary" aria-label="Supplier summary">
        <div className="summary-item"><Icons.users size={42}/><span><strong>{counts.all ?? data.total}</strong><small>Total suppliers</small></span></div>
        <div className="summary-item"><Icons.checkCircle size={42}/><span><strong>{counts.approved ?? 0}</strong><small>Approved</small></span></div>
        <div className="summary-item"><Icons.clock size={42}/><span><strong>{counts.under_review ?? 0}</strong><small>Under review</small></span></div>
      </section>
      <ListControls path="/suppliers" params={params} data={data} tabs={TABS} noun={['supplier', 'suppliers']}
        actionLabel="awaiting review" placeholder="Search suppliers by name, phone, location or category">
        <SupplierTable suppliers={data.items}/>
      </ListControls>
    </div></main>
  </>;
}
