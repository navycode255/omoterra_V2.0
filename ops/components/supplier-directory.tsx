'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';
import { Icons } from '@/components/icons';
import { date, quantity, tzs } from '@/lib/format';
import type { SupplierRow } from '@/lib/types';

type SortKey = 'public_alias' | 'status' | 'birds_bought' | 'owed_total' | 'last_activity';

function statusLabel(status: SupplierRow['status']) {
  const label = status.replace(/_/g, ' ');
  return label[0].toUpperCase() + label.slice(1);
}

function compare(a: SupplierRow, b: SupplierRow, key: SortKey) {
  if (key === 'birds_bought' || key === 'owed_total') return Number(a[key]) - Number(b[key]);
  return (a[key] ?? '').localeCompare(b[key] ?? '', undefined, { sensitivity: 'base' });
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
      <table className="supplier-table" data-phone-show="1 7">
        <thead><tr>{sortHeader('Supplier', 'public_alias')}{sortHeader('Status', 'status')}<th>Region / district</th><th>Batches</th>{sortHeader('Birds bought', 'birds_bought')}<th>Paid</th>{sortHeader('Owed', 'owed_total')}{sortHeader('Last activity', 'last_activity')}<th>Actions</th></tr></thead>
        <tbody>{shown.length ? shown.map((supplier) => <tr key={supplier.id}>
          <td><Link href={`/suppliers/${supplier.id}`} className="supplier-name">{supplier.public_alias || supplier.legal_name}</Link><small>{supplier.legal_name && supplier.legal_name !== supplier.public_alias ? supplier.legal_name : supplier.phone}</small></td>
          <td><span className="directory-status" data-status={supplier.status}>{statusLabel(supplier.status)}</span></td>
          <td>{[supplier.region, supplier.district].filter(Boolean).join(' · ') || '—'}</td>
          <td>{supplier.batches_total ? <><b>{supplier.batches_open} open</b><small>{quantity(supplier.birds_left)} birds left · {supplier.batches_total} total</small></> : <span className="muted">None</span>}</td>
          <td className="center">{quantity(supplier.birds_bought)}</td>
          <td className="money">{tzs(supplier.paid_total)}</td>
          <td className="money" data-owed={Number(supplier.owed_total) > 0 || undefined}>{tzs(supplier.owed_total)}</td>
          <td>{supplier.last_activity ? date(supplier.last_activity) : <span className="muted">—</span>}</td>
          <td className="center"><Link href={`/suppliers/${supplier.id}`} className="icon-button" aria-label={`View ${supplier.public_alias}`}><Icons.more size={22}/></Link></td>
        </tr>) : <tr><td colSpan={9} className="table-empty">No suppliers match this search.</td></tr>}</tbody>
      </table>
    </div>
  </>;
}
