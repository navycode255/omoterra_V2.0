'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';
import { Icons } from '@/components/icons';
import { tzs } from '@/lib/format';
import type { SupplierRow } from '@/lib/types';

type SortKey = 'public_alias' | 'status' | 'legal_name' | 'pending_settlement_total';

function statusLabel(status: SupplierRow['status']) {
  const label = status.replace(/_/g, ' ');
  return label[0].toUpperCase() + label.slice(1);
}

function compare(a: SupplierRow, b: SupplierRow, key: SortKey) {
  if (key === 'pending_settlement_total') return Number(a[key]) - Number(b[key]);
  return a[key].localeCompare(b[key], undefined, { sensitivity: 'base' });
}

// One page of suppliers from /ops/suppliers. Search, status tabs and paging
// happen on the server (ListControls); sorting here reorders this page only.
export function SupplierTable({ suppliers }: { suppliers: SupplierRow[] }) {
  const [sort, setSort] = useState<{ key: SortKey; direction: 1 | -1 } | null>(null);
  const shown = useMemo(
    () => (sort ? [...suppliers].sort((a, b) => compare(a, b, sort.key) * sort.direction) : suppliers),
    [sort, suppliers],
  );

  function sortHeader(label: string, sortKey: SortKey) {
    const active = sort?.key === sortKey;
    const ariaSort = active ? (sort.direction === 1 ? 'ascending' : 'descending') : 'none';
    return <th key={sortKey} aria-sort={ariaSort}><button type="button" className="sort-header" data-active={active} onClick={() => setSort({ key: sortKey, direction: active && sort.direction === 1 ? -1 : 1 })}>{label}<Icons.sort size={14}/></button></th>;
  }

  return <>
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
    </div>
  </>;
}
