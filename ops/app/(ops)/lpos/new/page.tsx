import Link from 'next/link';
import { LpoForm } from '@/components/lpo/lpo-form';
import { Notice, PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { today } from '@/lib/finance';
import type { DemandRow, SupplierSuggestion } from '@/lib/lpo';
import { category, quantity } from '@/lib/format';
import { param, type ListParams } from '@/lib/paging';

export const metadata = { title: 'New LPO · Omoterra Operations' };

export default async function NewLpo({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  const demandId = param(params, 'demand');
  const supplierId = param(params, 'supplier');
  let demand: DemandRow | null = null;
  let suppliers: { suggested: SupplierSuggestion[]; others: SupplierSuggestion[] };
  try {
    if (demandId) demand = (await get<DemandRow[]>('/ops/lpos/demand')).find((row) => row.id === demandId) ?? null;
    const query = new URLSearchParams(demand ? { category: demand.category, region: demand.delivery_region, needed_by: demand.needed_by_date } : { category: 'broilers' });
    suppliers = await get<{ suggested: SupplierSuggestion[]; others: SupplierSuggestion[] }>(`/ops/lpos/suppliers?${query}`);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="New LPO" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Suppliers could not be loaded.'}</Notice></div></>;
  }
  // A supplier picked on the demand board comes first.
  const all = [...suppliers.suggested, ...suppliers.others];
  const picked = all.find((s) => s.supplier_id === supplierId);
  const suggested = picked ? [picked, ...suppliers.suggested.filter((s) => s !== picked)] : suppliers.suggested;
  const others = suppliers.others.filter((s) => s !== picked);
  return (
    <>
      <div className="topbar">
        <PageHeader title="New LPO" subtitle="Prepare a purchase order. It stays a draft until an admin issues it with signature and stamp." />
      </div>
      <div className="workspace">
        {demand && <Notice>For demand {demand.requirement_number}: {quantity(demand.short)} {category(demand.category)} short, needed by {demand.needed_by_date}
          {demand.delivery_region ? ` in ${demand.delivery_region}` : ''}.</Notice>}
        <LpoForm suggested={suggested} others={others} today={today()} demand={demand} lpo={null} />
        <p className="meta"><Link href="/lpos">Back to LPOs</Link></p>
      </div>
    </>
  );
}
