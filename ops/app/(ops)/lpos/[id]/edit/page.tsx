import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { LpoForm } from '@/components/lpo/lpo-form';
import { PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { today } from '@/lib/finance';
import type { LpoDetail, SupplierSuggestion } from '@/lib/lpo';

export const metadata = { title: 'Edit LPO · Omoterra Operations' };

export default async function EditLpo({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let lpo: LpoDetail;
  try {
    lpo = await get<LpoDetail>(`/ops/lpos/${id}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }
  if (lpo.status !== 'draft') redirect(`/lpos/${id}`);
  const category = lpo.lines[0]?.category || 'broilers';
  const suppliers = await get<{ suggested: SupplierSuggestion[]; others: SupplierSuggestion[] }>(`/ops/lpos/suppliers?category=${category}`);
  return (
    <>
      <div className="topbar"><PageHeader title="Edit draft LPO" subtitle={lpo.supplier_snapshot.name} /></div>
      <div className="workspace">
        <LpoForm suggested={suppliers.suggested} others={suppliers.others} today={today()} demand={null} lpo={lpo} />
        <p className="meta"><Link href={`/lpos/${id}`}>Back to the LPO</Link></p>
      </div>
    </>
  );
}
