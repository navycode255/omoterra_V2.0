import Link from 'next/link';
import { SaleForm } from '@/components/finance/sale-form';
import { Notice, PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { today, type Parties } from '@/lib/finance';

export const metadata = { title: 'New sale · Omoterra Operations' };

export default async function NewSale() {
  let parties: Parties;
  try {
    parties = await get<Parties>('/ops/finance/parties');
  } catch (error) {
    return <><div className="topbar"><PageHeader title="New sale" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Buyers and suppliers could not be loaded.'}</Notice></div></>;
  }
  return (
    <>
      <div className="topbar">
        <PageHeader title="New sale" subtitle="Record an order for an existing or a new buyer. New buyers are saved for later sales and promotions." />
      </div>
      <div className="workspace">
        <SaleForm parties={parties} today={today()} />
        <p className="meta"><Link href="/sales">Back to sales</Link></p>
      </div>
    </>
  );
}
