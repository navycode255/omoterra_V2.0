import Link from 'next/link';
import { notFound } from 'next/navigation';
import { BuyerOrderForm } from '@/components/finance/buyer-order-form';
import { Notice, PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import type { BuyerOrderDetail } from '@/lib/buyer-orders';
import { today, type Parties } from '@/lib/finance';
import styles from '@/components/finance/finance.module.css';

export const metadata = { title: 'Edit buyer order · Omoterra Operations' };

export default async function EditBuyerOrder({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let order: BuyerOrderDetail;
  let parties: Parties;
  try {
    [order, parties] = await Promise.all([get<BuyerOrderDetail>(`/ops/buyer-orders/${encodeURIComponent(id)}`), get<Parties>('/ops/finance/parties')]);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    return <><div className="topbar"><PageHeader title="Edit buyer order" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'The order could not be loaded.'}</Notice></div></>;
  }
  return (
    <div className={styles.salePage}>
      <div className={styles.saleHeader}>
        <div className={styles.saleFrame}><PageHeader title={`Edit ${order.order_number}`} /></div>
      </div>
      <div className={styles.saleFrame}>
        <div className={styles.saleWorkspace}>
          {order.status === 'open' ? <BuyerOrderForm parties={parties} today={today()} order={order} />
            : <Notice>This order is {order.status} and can no longer be changed.</Notice>}
          <Link href={`/sales/orders/${order.id}`} className={styles.backLink}>← <span>Back to the order</span></Link>
        </div>
      </div>
    </div>
  );
}
