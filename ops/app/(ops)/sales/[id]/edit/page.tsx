import Link from 'next/link';
import { notFound } from 'next/navigation';
import { SaleForm } from '@/components/finance/sale-form';
import { Notice, PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { today, type Parties, type SaleDetail } from '@/lib/finance';
import type { LpoStockRow } from '@/lib/lpo';
import styles from '@/components/finance/finance.module.css';

export const metadata = { title: 'Edit sale · Omoterra Operations' };

export default async function EditSale({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let sale: SaleDetail;
  let parties: Parties;
  let stock: LpoStockRow[];
  try {
    [sale, parties, stock] = await Promise.all([
      get<SaleDetail>(`/ops/sales/${id}`),
      get<Parties>('/ops/finance/parties'),
      get<LpoStockRow[]>('/ops/lpos/stock'),
    ]);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    return <><div className="topbar"><PageHeader title="Edit sale" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'The sale could not be loaded.'}</Notice></div></>;
  }
  if (sale.status !== 'active') notFound();

  // Sold-out LPO lines disappear from the general stock picker. Keep the
  // current line selectable; the backend adds this sale's quantity back while
  // checking an edit, so increasing it still requires real stock on hand.
  const present = new Set(stock.map((row) => row.lpo_line_id));
  for (const item of sale.items) {
    if (!item.lpo_line_id || present.has(item.lpo_line_id)) continue;
    stock.push({
      lpo_line_id: item.lpo_line_id, lpo_id: '', lpo_number: 'Current LPO', item: item.description || item.category,
      category: item.category, unit: item.unit, unit_price: item.unit_cost ?? '0', supplier_name: item.supplier_name || 'Supplier',
      accepted: item.quantity, rejected: '0', sold: item.quantity, lost: '0', on_hand: '0',
    });
  }

  return <div className={styles.salePage}>
    <div className={styles.saleHeader}><div className={styles.saleFrame}>
      <PageHeader title={`Edit ${sale.sale_number}`} subtitle="Correct the buyer, items, prices, buying costs, or notes." />
    </div></div>
    <div className={styles.saleFrame}><div className={styles.saleWorkspace}>
      <SaleForm parties={parties} today={today()} stock={stock} sale={sale} />
      <Link href={`/sales/${sale.id}`} className={styles.backLink}>← <span>Back to sale</span></Link>
    </div></div>
  </div>;
}
