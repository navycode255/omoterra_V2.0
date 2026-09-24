import Link from 'next/link';
import { Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { tzs } from '@/lib/format';
import type { SupplierRow } from '@/lib/types';

export const metadata = { title: 'Suppliers · Omoterra Operations' };

export default async function Suppliers() {
  let suppliers: SupplierRow[];
  try {
    suppliers = await get<SupplierRow[]>('/ops/suppliers');
  } catch (error) {
    return (
      <>
        <div className="topbar">
          <PageHeader title="Suppliers" />
        </div>
        <div className="workspace">
          <Notice tone="error">
            {error instanceof ApiError ? error.message : 'Suppliers could not be loaded.'}
          </Notice>
        </div>
      </>
    );
  }

  return (
    <>
      <div className="topbar">
        <PageHeader
          title="Suppliers"
          subtitle="Internal supplier records. Legal names and pickup addresses never reach buyers."
        />
        <Link className="button" href="/suppliers/new">Add supplier</Link>
      </div>
      <div className="workspace">
        <div className="table-wrap">
          {suppliers.length === 0 ? (
            <Empty>No suppliers registered yet.</Empty>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Farm / supplier</th>
                  <th>Status</th>
                  <th>Legal name (internal)</th>
                  <th>Region / district</th>
                  <th className="numeric">Live</th>
                  <th className="numeric">Pending</th>
                  <th className="numeric">Completed</th>
                  <th className="numeric">Owed</th>
                </tr>
              </thead>
              <tbody>
                {suppliers.map((supplier) => (
                  <tr key={supplier.id}>
                    <td>
                      <Link href={`/suppliers/${supplier.id}`} className="strong">
                        {supplier.public_alias}
                      </Link>
                      {!supplier.alias_approved && (
                        <div className="meta" style={{ color: 'var(--warning)' }}>
                          Alias not approved
                        </div>
                      )}
                    </td>
                    <td><Status tone={supplier.status === 'approved' ? 'positive' : supplier.status === 'rejected' || supplier.status === 'suspended' ? 'error' : 'warning'}>{supplier.status.replaceAll('_', ' ')}</Status></td>
                    <td className="small">{supplier.legal_name}</td>
                    <td className="small">{[supplier.region, supplier.district].filter(Boolean).join(' · ') || '—'}</td>
                    <td className="numeric">{supplier.live_listings}</td>
                    <td className="numeric">
                      {supplier.pending_listings > 0 ? (
                        <Status tone="warning">{supplier.pending_listings}</Status>
                      ) : (
                        '0'
                      )}
                    </td>
                    <td className="numeric">{supplier.completed_supplies_count}</td>
                    <td className="numeric money">{tzs(supplier.pending_settlement_total)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </>
  );
}
