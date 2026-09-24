import Link from 'next/link';
import { SupplierDirectory } from '@/components/supplier-directory';
import { Icons } from '@/components/icons';
import { Notice, PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import type { SupplierRow } from '@/lib/types';

export const metadata = { title: 'Suppliers · Omoterra Operations' };

export default async function Suppliers() {
  let suppliers: SupplierRow[];
  try { suppliers = await get<SupplierRow[]>('/ops/suppliers'); }
  catch (error) {
    return <><div className="topbar"><PageHeader title="Suppliers" /></div><div className="workspace"><Notice tone="error">{error instanceof ApiError ? error.message : 'Suppliers could not be loaded.'}</Notice></div></>;
  }
  return <>
    <div className="topbar supplier-page-header"><PageHeader title="Suppliers"/><Link className="button add-supplier" href="/suppliers/new"><Icons.plus size={22}/>Add supplier</Link></div>
    <main className="workspace supplier-list-workspace"><SupplierDirectory suppliers={suppliers}/></main>
  </>;
}
