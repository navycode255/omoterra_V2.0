import Link from 'next/link';
import { notFound } from 'next/navigation';
import { SaleForm } from '@/components/finance/sale-form';
import { Notice, PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import type { BuyerOrderDetail } from '@/lib/buyer-orders';
import { today, type OpenBatch, type OpeningStock, type Parties, type SupplierCollectionStock } from '@/lib/finance';
import type { LpoStockRow } from '@/lib/lpo';
import styles from '@/components/finance/finance.module.css';

export const metadata = { title: 'Mark order delivered · Omoterra Operations' };

// "Mark delivered" (build plan M2.5): the sale form, filled in from the
// order. Saving records the sale on the delivery day, takes the stock and
// its cost then, and puts any deposit on it.
export default async function DeliverBuyerOrder({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let order: BuyerOrderDetail;
  let parties: Parties;
  let stock: LpoStockRow[];
  let supplierStock: SupplierCollectionStock[];
  let batches: OpenBatch[];
  let openingStock: OpeningStock[];
  try {
    [order, parties, stock, supplierStock, batches, openingStock] = await Promise.all([
      get<BuyerOrderDetail>(`/ops/buyer-orders/${encodeURIComponent(id)}`),
      get<Parties>('/ops/finance/parties'), get<LpoStockRow[]>('/ops/lpos/stock'),
      get<SupplierCollectionStock[]>('/ops/supplier-collections/stock'),
      get<OpenBatch[]>('/ops/supplier-batches/open'),
      get<OpeningStock[]>('/ops/opening-stock/available'),
    ]);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    return <><div className="topbar"><PageHeader title="Mark delivered" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'The order could not be loaded.'}</Notice></div></>;
  }
  return (
    <div className={styles.salePage}>
      <div className={styles.saleHeader}>
        <div className={styles.saleFrame}><PageHeader title={`Mark ${order.order_number} delivered`} /></div>
      </div>
      <div className={styles.saleFrame}>
        <div className={styles.saleWorkspace}>
          {order.status === 'open'
            ? <SaleForm parties={parties} today={today()} stock={stock} supplierStock={supplierStock} batches={batches} openingStock={openingStock} order={order} />
            : <Notice>This order is already {order.status}.</Notice>}
          <Link href={`/sales/orders/${order.id}`} className={styles.backLink}>← <span>Back to the order</span></Link>
        </div>
      </div>
    </div>
  );
}
