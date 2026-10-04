import Link from 'next/link';
import { Icons } from '@/components/icons';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { CurrencyInput } from '@/components/production/currency-input';
import { BatchSummary } from '@/components/production/batch-summary';
import { Notice } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { verifyBatch } from '@/lib/actions';
import { quantity } from '@/lib/format';
import type { Batch } from '@/lib/production';
import styles from '@/components/production/production.module.css';

export const metadata = { title: 'Batch details · Omoterra Operations' };
export default async function BatchDetails({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let batches: Batch[];
  try { batches = await get<Batch[]>('/ops/batches'); }
  catch (error) { return <main className={styles.page}><h1>Batch details</h1><Notice tone="error">{error instanceof ApiError ? error.message : 'Batch could not be loaded.'}</Notice></main>; }
  const batch = batches.find(row => row.id === id);
  if (!batch) notFound();
  const decimal = (value: string | null | undefined) => value == null ? '' : quantity(value);
  return <main className={styles.page} data-production-detail>
    <div className={styles.breadcrumb}><Link href="/batches">Production batches</Link><Icons.chevron size={16}/>Batch details</div>
    <div className={styles.pageHeading}><h1>Batch details</h1><Link href="/batches" className={styles.viewButton}>← Back to batches</Link></div>
    <div className={styles.detailGrid}><div className={styles.detailOverview}><section className={styles.batchCard}><BatchSummary batch={batch} detail/><div className={styles.batchId}>Batch ID <span>{batch.id.slice(0, 8)}</span></div></section><section className={styles.section}><h2>Availability</h2><dl className={styles.availability}>{[["Total", batch.current_quantity], ["Reserved", batch.reserved_quantity], ["Available to commit", batch.available_to_commit]].map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{quantity(value)}</dd></div>)}</dl></section></div>
    <div className={styles.verificationForm}>
      <ActionForm action={verifyBatch} label={batch.approved_at ? "Record new verification" : "Record verification"} hidden={{ id }}>
        <section className={styles.section}><h2>Verification</h2><div className={styles.fields}>
          <div className="field"><label htmlFor="verified">Verified quantity</label><input className="input" id="verified" name="verified_quantity" inputMode="decimal" defaultValue={decimal(batch.current_quantity)} required/></div>
          <div className="field"><label htmlFor="rejected">Rejected quantity</label><input className="input" id="rejected" name="rejected_quantity" inputMode="decimal" defaultValue="0"/></div>
          <div className={`field ${styles.full}`}><label htmlFor="weight">Sample average weight (kg)</label><input className="input" id="weight" name="sampled_average_weight_kg" inputMode="decimal" defaultValue={decimal(batch.actual_average_weight_kg)}/></div>
        </div></section>
        <section className={styles.section}><h2>Pricing</h2><div className={styles.fields}>
          <div className="field"><label htmlFor="buyer">Buyer price per unit (TZS)</label><CurrencyInput id="buyer" name="buyer_price_per_unit" defaultValue={decimal(batch.buyer_price_per_unit)} required/></div>
          <div className="field"><label htmlFor="payout">Supplier payout per unit (TZS)</label><CurrencyInput id="payout" name="supplier_payout_price_per_unit" defaultValue={decimal(batch.supplier_payout_price_per_unit)}/></div>
          <div className={`field ${styles.full}`}><label htmlFor="asking">Agreed supplier asking price (TZS)</label><CurrencyInput id="asking" name="supplier_asking_price_per_unit" defaultValue={decimal(batch.asking_price_per_unit)} required/></div>
        </div></section>
        <section className={`${styles.section} ${styles.confirmations}`}><h2>Confirmations</h2>
          <label><input type="checkbox" name="readiness_confirmed"/>Readiness confirmed</label>
          <label><input type="checkbox" name="location_confirmed"/>Location confirmed</label>
        </section>
        <section className={styles.section}><div className="field"><label className={styles.notesTitle} htmlFor="notes">Inspection notes</label><textarea className="input" id="notes" name="notes" placeholder="Add notes..."/></div></section>
      </ActionForm>
    </div></div>
  </main>;
}
