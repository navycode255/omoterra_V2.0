import Link from 'next/link';
import { SaleForm } from '@/components/finance/sale-form';
import { Notice, PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { today, type Parties, type SupplierCollectionStock, type OpenBatch } from '@/lib/finance';
import type { LpoStockRow } from '@/lib/lpo';
import styles from '@/components/finance/finance.module.css';

export const metadata = { title: 'New sale · Omoterra Operations' };

export default async function NewSale() {
  let parties: Parties;
  let stock: LpoStockRow[];
  let supplierStock: SupplierCollectionStock[];
  let batches: OpenBatch[];
  try {
    [parties, stock, supplierStock, batches] = await Promise.all([
      get<Parties>('/ops/finance/parties'), get<LpoStockRow[]>('/ops/lpos/stock'),
      get<SupplierCollectionStock[]>('/ops/supplier-collections/stock'),
      get<OpenBatch[]>('/ops/supplier-batches/open'),
    ]);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="New sale" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Buyers and suppliers could not be loaded.'}</Notice></div></>;
  }
  return (
    <div className={styles.salePage}>
      <div className={styles.saleHeader}>
        <div className={styles.saleFrame}><PageHeader title="New sale" /></div>
      </div>
      <div className={styles.saleFrame}>
        <div className={styles.saleWorkspace}>
          <SaleForm parties={parties} today={today()} stock={stock} supplierStock={supplierStock} batches={batches} />
          <Link href="/sales" className={styles.backLink}>← <span>Back to sales</span></Link>
        </div>
      </div>
    </div>
  );
}
