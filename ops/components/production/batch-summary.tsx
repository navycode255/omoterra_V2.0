import { Icons } from '@/components/icons';
import { date, quantity, tzs } from '@/lib/format';
import { batchStatus, batchTitle, type Batch } from '@/lib/production';
import styles from './production.module.css';

export function BatchSummary({ batch, detail = false }: { batch: Batch; detail?: boolean }) {
  const status = batchStatus(batch);
  const facts = [
    { icon: Icons.box, value: quantity(batch.current_quantity), label: 'Total quantity' },
    { icon: Icons.calendar, value: date(batch.expected_ready_date), label: 'Expected ready' },
    { icon: Icons.tag, value: batch.asking_price_per_unit ? tzs(batch.asking_price_per_unit) : '—', label: 'Asking price' },
    ...(detail ? [{ icon: Icons.weight, value: `${quantity(batch.expected_min_weight_kg)} – ${quantity(batch.expected_max_weight_kg)} kg`, label: 'Weight' }] : []),
  ];
  return <>
    <div className={styles.cardHeading}><h2>{batchTitle(batch)}</h2><span className={styles.status} data-tone={status.tone}>{status.label}</span>{!detail && <Icons.chevron size={18}/>}</div>
    <p className={styles.supplier}>Supplier: <span>{batch.supplier_name || 'Not registered'}</span></p>
    <dl className={`${styles.facts} ${detail ? styles.detailFacts : ''}`}>{facts.map(({ icon: Icon, value, label }) => <div key={label}><Icon size={20}/><div><dd>{value}</dd><dt>{label}</dt></div></div>)}</dl>
  </>;
}
