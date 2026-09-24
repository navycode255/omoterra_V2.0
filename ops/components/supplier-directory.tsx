'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';
import { Icons } from '@/components/icons';
import { tzs } from '@/lib/format';
import type { SupplierRow } from '@/lib/types';

type Filter = 'all' | 'approved' | 'under_review';
type SortKey = 'public_alias' | 'status' | 'legal_name' | 'pending_settlement_total';

function statusLabel(status: SupplierRow['status']) {
  const label = status.replace(/_/g, ' ');
  return label[0].toUpperCase() + label.slice(1);
}

function compare(a: SupplierRow, b: SupplierRow, key: SortKey) {
  if (key === 'pending_settlement_total') return Number(a[key]) - Number(b[key]);
  return a[key].localeCompare(b[key], undefined, { sensitivity: 'base' });
}

export function SupplierDirectory({ suppliers }: { suppliers: SupplierRow[] }) {
  const [filter, setFilter] = useState<Filter>('all');
  const [query, setQuery] = useState('');
  const [sort, setSort] = useState<{ key: SortKey; direction: 1 | -1 } | null>(null);
  const approved = suppliers.filter((supplier) => supplier.status === 'approved').length;
  const review = suppliers.filter((supplier) => supplier.status === 'under_review' || supplier.status === 'new').length;
  const shown = useMemo(() => {
    const search = query.trim().toLowerCase();
    const rows = suppliers.filter((supplier) => {
      const matchesFilter = filter === 'all' || supplier.status === filter || (filter === 'under_review' && supplier.status === 'new');
      const haystack = [supplier.public_alias, supplier.legal_name, supplier.phone, supplier.region, supplier.district].join(' ').toLowerCase();
      return matchesFilter && (!search || haystack.includes(search));
    });
    return sort ? rows.sort((a, b) => compare(a, b, sort.key) * sort.direction) : rows;
  }, [filter, query, sort, suppliers]);

  function sortHeader(label: string, sortKey: SortKey) {
    const active = sort?.key === sortKey;
    const ariaSort = active ? (sort.direction === 1 ? 'ascending' : 'descending') : 'none';
    return <th key={sortKey} aria-sort={ariaSort}><button type="button" className="sort-header" data-active={active} onClick={() => setSort({ key: sortKey, direction: active && sort.direction === 1 ? -1 : 1 })}>{label}<Icons.sort size={14}/></button></th>;
  }

  return <div className="supplier-directory">
    <section className="supplier-summary" aria-label="Supplier summary">
      <div className="summary-item"><Icons.users size={42}/><span><strong>{suppliers.length}</strong><small>Total suppliers</small></span></div>
      <div className="summary-item"><Icons.checkCircle size={42}/><span><strong>{approved}</strong><small>Approved</small></span></div>
      <div className="summary-item"><Icons.clock size={42}/><span><strong>{review}</strong><small>Under review</small></span></div>
    </section>
    <div className="supplier-toolbar">
      <div className="filter-tabs" role="tablist" aria-label="Filter suppliers">
        <button type="button" data-active={filter === 'all'} onClick={() => setFilter('all')}>All ({suppliers.length})</button>
        <button type="button" data-active={filter === 'approved'} onClick={() => setFilter('approved')}>Approved ({approved})</button>
        <button type="button" data-active={filter === 'under_review'} onClick={() => setFilter('under_review')}>Under review ({review})</button>
      </div>
      <label className="supplier-search"><Icons.search size={24}/><span className="sr-only">Search suppliers</span><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search suppliers by name, location or contact..." /></label>
    </div>
    <div className="supplier-table-wrap">
      <table className="supplier-table">
        <thead><tr>{sortHeader('Supplier', 'public_alias')}{sortHeader('Status', 'status')}{sortHeader('Legal name (internal)', 'legal_name')}<th>Region / district</th><th>Live</th><th>Pending</th><th>Completed</th>{sortHeader('Owed', 'pending_settlement_total')}<th>Actions</th></tr></thead>
        <tbody>{shown.length ? shown.map((supplier) => <tr key={supplier.id}>
          <td><Link href={`/suppliers/${supplier.id}`} className="supplier-name">{supplier.public_alias}</Link>{!supplier.alias_approved && <small>Alias not approved</small>}</td>
          <td><span className="directory-status" data-status={supplier.status}>{statusLabel(supplier.status)}</span></td>
          <td>{supplier.legal_name}</td><td>{[supplier.region, supplier.district].filter(Boolean).join(' · ') || '—'}</td>
          <td className="center">{supplier.live_listings}</td><td className="center">{supplier.pending_listings}</td><td className="center">{supplier.completed_supplies_count}</td>
          <td className="money">{tzs(supplier.pending_settlement_total)}</td>
          <td className="center"><Link href={`/suppliers/${supplier.id}`} className="icon-button" aria-label={`View ${supplier.public_alias}`}><Icons.more size={22}/></Link></td>
        </tr>) : <tr><td colSpan={9} className="table-empty">No suppliers match this search.</td></tr>}</tbody>
      </table>
      <footer className="table-footer"><span>Showing {shown.length} of {suppliers.length} {suppliers.length === 1 ? 'supplier' : 'suppliers'}</span><span className="pagination"><button disabled aria-label="Previous page">‹</button><button className="current">1</button><button disabled aria-label="Next page">›</button></span></footer>
    </div>
  </div>;
}
