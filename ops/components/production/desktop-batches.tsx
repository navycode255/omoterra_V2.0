import Link from 'next/link';
import { date, quantity, titleCase, tzs } from '@/lib/format';
import { batchStatus, batchTitle, type Batch } from '@/lib/production';
import styles from './production.module.css';

export function DesktopBatches({ batches }: { batches: Batch[] }) {
  return <div className={styles.tableWrap}><table className={styles.table}><thead><tr>{['Supplier', 'Product', 'Quantity', 'Expected ready', 'Region / pickup', 'Price (TZS)', 'Status', 'Actions'].map(label => <th key={label} scope="col">{label}</th>)}</tr></thead><tbody>{batches.map(batch => {
    const status = batchStatus(batch);
    return <tr key={batch.id}>
      <td><strong>{batch.supplier_name || 'Not registered'}</strong></td>
      <td><strong>{batchTitle(batch)}</strong><span className={styles.secondary}>{titleCase(batch.form)} · {batch.expected_min_weight_kg ?? '—'}–{batch.expected_max_weight_kg ?? '—'} kg</span></td>
      <td>{quantity(batch.current_quantity)}<span className={styles.secondary}>Avail. {quantity(batch.available_to_commit)}</span></td>
      <td>{date(batch.expected_ready_date)}</td>
      <td>{batch.region || '—'}<span className={styles.secondary}>{batch.private_pickup_location || 'Not recorded'}</span></td>
      <td>{batch.asking_price_per_unit ? tzs(batch.asking_price_per_unit).replace(/^TZS\s*/, '') : '—'}</td>
      <td><span className={styles.status} data-tone={status.tone}>{status.label}</span></td>
      <td><Link className={styles.viewButton} href={`/batches/${batch.id}`} aria-label={`View ${batchTitle(batch)} from ${batch.supplier_name || 'unregistered supplier'}`}>View</Link></td>
    </tr>;
  })}</tbody></table></div>;
}
