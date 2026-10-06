import Link from 'next/link';
import type { StockSource } from '@/lib/finance';
import { tzs } from '@/lib/format';
import styles from './stock-source.module.css';

const STATE_LABEL: Record<StockSource['state'], string> = {
  no_invoice: 'No supplier invoice',
  unpaid: 'Supplier not paid',
  part_paid: 'Supplier part paid',
  paid: 'Supplier paid',
  cancelled: 'Invoice cancelled',
};

/**
 * Where a sale line's received stock came from and how far the supplier side
 * of that receipt is paid (build plan M2.4). Information only: the receipt's
 * payable belongs to the receipt and is never added to this sale (rule R1).
 */
export function StockSourceStatus({ source }: { source: StockSource }) {
  if (source.kind === 'opening_stock') {
    return <span className={styles.source} data-state="no_invoice">
      Opening stock {source.number ?? ''} (no supplier invoice)
    </span>;
  }
  const receipt = source.kind === 'delivery_note'
    ? <Link href={`/supplier-collections/${source.id}`}>{source.number ?? 'Delivery note'}</Link>
    : <Link href={`/lpos/${source.lpo_id ?? source.id}`}>{source.number ?? 'LPO'}</Link>;
  const credit = Number(source.supplier_credit);
  const fromCredit = source.invoices.reduce((sum, invoice) => sum + Number(invoice.paid_from_credit), 0);
  return <span className={styles.source} data-state={source.state} data-testid="stock-source">
    <span>Stock from {receipt}: <b className={styles.state}>{STATE_LABEL[source.state]}</b></span>
    {source.invoices.length === 0
      ? <span>No supplier invoice recorded for this receipt.</span>
      : <span>
        {source.invoices.length === 1 ? 'Supplier invoice' : `${source.invoices.length} supplier invoices`}{' '}
        {source.invoices.map((invoice, index) => <span key={invoice.debt_id}>
          {index > 0 && ', '}<Link href={`/finance/debts/${invoice.debt_id}`}>{tzs(invoice.amount)}</Link>
        </span>)}
        , paid {tzs(source.paid_amount)} (balance {tzs(source.balance)})
      </span>}
    {fromCredit > 0 && <span>{tzs(String(fromCredit))} of it paid from supplier credit.</span>}
    {credit > 0 && Number(source.balance) > 0 && <span>The supplier holds {tzs(source.supplier_credit)} credit that can be used on it.</span>}
  </span>;
}
