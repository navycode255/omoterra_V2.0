import Link from 'next/link';
import { BuyerOrderForm } from '@/components/finance/buyer-order-form';
import { Notice, PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { today, type Parties } from '@/lib/finance';
import styles from '@/components/finance/finance.module.css';

export const metadata = { title: 'New buyer order · Omoterra Operations' };

// An order a buyer placed by phone or in person (build plan M2.5).
export default async function NewBuyerOrder() {
  let parties: Parties;
  try {
    parties = await get<Parties>('/ops/finance/parties');
  } catch (error) {
    return <><div className="topbar"><PageHeader title="New buyer order" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Buyers could not be loaded.'}</Notice></div></>;
  }
  return (
    <div className={styles.salePage}>
      <div className={styles.saleHeader}>
        <div className={styles.saleFrame}><PageHeader title="New buyer order" /></div>
      </div>
      <div className={styles.saleFrame}>
        <div className={styles.saleWorkspace}>
          <BuyerOrderForm parties={parties} today={today()} />
          <Link href="/sales/orders" className={styles.backLink}>← <span>Back to buyer orders</span></Link>
        </div>
      </div>
    </div>
  );
}
