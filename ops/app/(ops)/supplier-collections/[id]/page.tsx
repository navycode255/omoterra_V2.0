import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { PrintButton } from '@/components/lpo/print-button';
import { Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { cancelDeliveryLoss, correctReceipt, recordDeliveryLoss, recordSupplierCreditNote, returnToSupplier } from '@/lib/batch-stock-actions';
import { LOSS_REASONS } from '@/lib/lpo';
import { today, type CollectionMovement, type DeliveryNoteDetail } from '@/lib/finance';
import { category, date, quantity, tzs } from '@/lib/format';
import { requireSession } from '@/lib/session';
import styles from './delivery-note.module.css';

export const metadata = { title: 'Supplier delivery note · Omoterra Operations' };

const EVENT_LABELS: Record<CollectionMovement['kind'], string> = {
  never_left: 'Sale cancelled or reduced: goods never left (back on hand)',
  buyer_return_accepted: 'Returned by the buyer and accepted back',
  not_recovered: 'Not recovered: loss pending investigation',
  returned_to_supplier: 'Returned to the supplier',
  receipt_correction: 'Receipt corrected: never delivered',
  lost: 'Lost before sale',
};
const LOSS_LABELS = Object.fromEntries(LOSS_REASONS);

const ORIGIN_LABELS = { delivery: 'Received on collection', sale: 'Collected and sold the same day', historical: 'Linked from an earlier sale' };

export default async function SupplierDeliveryNote({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const operator = await requireSession();
  const admin = operator.role === 'admin';
  let note: DeliveryNoteDetail;
  try { note = await get<DeliveryNoteDetail>('/ops/supplier-collections/' + id); }
  catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    return <><div className="topbar"><PageHeader title="Delivery note" /></div><div className="workspace"><Notice tone="error">The delivery note could not be loaded.</Notice></div></>;
  }
  const onHand = Number(note.on_hand);
  const unit = `${note.unit}s`;
  const paid = note.payable ? Number(note.payable.paid_amount) : 0;
  const hidden = { collection_id: note.id, supplier_id: note.supplier_id };
  const awaiting = note.movements.filter((row) => row.awaiting_credit);
  return <>
    <div className="topbar delivery-note-actions"><PageHeader title={note.collection_number} subtitle="Supplier stock collection and acceptance record" /><PrintButton /></div>
    <div className="workspace">
      <article className="delivery-note">
        <header><div><strong>Omoterra</strong><span>SUPPLIER DELIVERY NOTE</span></div><Status tone={note.cancelled_at ? 'warning' : 'positive'}>{note.cancelled_at ? 'Cancelled' : 'Received'}</Status></header>
        <div className="delivery-note-grid">
          <dl><div><dt>Supplier</dt><dd>{note.supplier_name}</dd></div><div><dt>Phone</dt><dd>{note.supplier_phone}</dd></div><div><dt>Batch</dt><dd>{note.batch_id.slice(0, 8)} · {category(note.category)}{note.subtype ? ' · ' + note.subtype : ''}</dd></div></dl>
          <dl><div><dt>Delivery note</dt><dd>{note.collection_number}</dd></div><div><dt>Collection date</dt><dd>{date(note.received_on)}</dd></div>
            <div><dt>Receipt confirmed by</dt><dd>{note.confirmed_by ?? note.recorded_by ?? '—'}</dd></div>
            {note.origin && note.origin !== 'delivery' && <div><dt>How</dt><dd>{ORIGIN_LABELS[note.origin]}{note.sale_id && note.sale_number ? <> · <Link href={`/sales/${note.sale_id}`}>{note.sale_number}</Link></> : null}</dd></div>}
            <div><dt>Recorded</dt><dd>{date(note.created_at)}</dd></div></dl>
        </div>
        <table><thead><tr><th>Product</th><th>Delivered</th><th>Accepted</th><th>Rejected</th><th>Avg. weight</th><th>Unit cost</th><th>Accepted value</th></tr></thead>
          <tbody><tr><td>{category(note.category)}</td><td>{quantity(note.delivered_quantity)} {unit}</td><td>{quantity(note.accepted_quantity)} {unit}</td><td>{quantity(note.rejected_quantity)} {unit}</td><td>{note.average_weight_kg ? note.average_weight_kg + ' kg' : '—'}</td><td>{tzs(note.unit_cost)}</td><td>{tzs(note.amount)}</td></tr></tbody></table>
        <section><h3>Stock movement</h3><dl className="delivery-note-stock">
          <div><dt>Accepted into Omoterra stock</dt><dd>{quantity(note.accepted_quantity)}</dd></div>
          <div><dt>Sold</dt><dd>{quantity(note.sold)}</dd></div>
          {Number(note.not_recovered ?? 0) > 0 && <div><dt>Not recovered</dt><dd>{quantity(note.not_recovered ?? '0')}</dd></div>}
          {Number(note.returned ?? 0) > 0 && <div><dt>Returned to supplier</dt><dd>{quantity(note.returned ?? '0')}</dd></div>}
          {Number(note.lost ?? 0) > 0 && <div><dt>Lost (died, culled, stolen, spoiled)</dt><dd>{quantity(note.lost ?? '0')}</dd></div>}
          <div><dt>Currently on hand</dt><dd>{quantity(note.on_hand)}</dd></div></dl></section>
        {note.notes && <section><h3>Comments</h3><p>{note.notes}</p></section>}
        {note.cancelled_at && <section><h3>Cancelled</h3><p>{note.cancel_reason}</p></section>}
        <footer><span>Recorded by Omoterra operations</span><span>Supplier acknowledgement: ____________________</span></footer>
      </article>

      <section className={styles.panel} aria-labelledby="after-receipt">
        <h2 id="after-receipt">After receipt</h2>
        <p className="meta">Stock moves only with a physical event. Cancelling a sale never changes this note or what is owed to the supplier.
          {note.payable && <> Payable: {tzs(note.payable.amount)}, paid {tzs(note.payable.paid_amount)}, {note.payable.status === 'cancelled' ? 'cancelled' : `owed ${tzs(note.payable.balance)}`}.</>}
          {Number(note.credited) > 0 && <> Supplier credit notes: {tzs(note.credited)}.</>}</p>
        {awaiting.length > 0 && <p className={styles.awaiting}>{quantity(note.awaiting_credit_quantity)} {unit} returned ({tzs(note.awaiting_credit_value)}) awaiting supplier credit. The payable stays until their credit note is recorded.</p>}
        {note.movements.length === 0 ? <p className="meta">No events since the goods were received.</p>
          : <table className={styles.events}><thead><tr><th>Date</th><th>Event</th><th className={styles.numeric}>Quantity</th><th className={styles.numeric}>Value</th><th>Details</th></tr></thead>
            <tbody>{note.movements.map((row) => <tr key={row.id}>
              <td data-label="Date">{date(row.occurred_on)}</td>
              <td data-label="Event" className={row.cancelled_at ? styles.cancelled : undefined}>{EVENT_LABELS[row.kind]}{row.loss_reason && `: ${(LOSS_LABELS[row.loss_reason] ?? row.loss_reason).toLowerCase()}`}
                {row.cancelled_at && <small className={styles.cancelNote}>Cancelled{row.cancelled_by ? ` by ${row.cancelled_by}` : ''}: {row.cancel_reason}</small>}{row.awaiting_credit && <small className={styles.awaiting}>Awaiting supplier credit</small>}
                {row.credit_note && <small>Credit note {row.credit_note.reference}: {tzs(row.credit_note.amount)} on {date(row.credit_note.issued_on)}</small>}</td>
              <td data-label="Quantity" className={styles.numeric}>{quantity(row.quantity)} {unit}</td>
              <td data-label="Value" className={styles.numeric}>{tzs(row.value)}</td>
              <td data-label="Details">{row.sale_id && row.sale_number && <Link href={`/sales/${row.sale_id}`}>{row.sale_number}</Link>}
                {row.reason && <small>{row.reason}</small>}{row.note && <small>{row.kind === 'lost' ? 'Note' : 'Condition'}: {row.note}</small>}
                {row.evidence && <small>Evidence: {row.evidence}</small>}<small>by {row.recorded_by ?? '—'}</small>
                {admin && row.kind === 'lost' && !row.cancelled_at && <details className={styles.cancelLoss}><summary>Cancel this loss</summary>
                  <ActionForm action={cancelDeliveryLoss} label="Cancel loss" variant="danger" hidden={{ ...hidden, movement_id: row.id }}>
                    <div className="field"><label htmlFor={`cancel-loss-${row.id}`}>Why was it recorded by mistake?</label><input id={`cancel-loss-${row.id}`} name="reason" className="input" required minLength={3} /></div>
                  </ActionForm></details>}</td>
            </tr>)}</tbody></table>}

        {!note.cancelled_at && <div className={styles.loss}>
          <div>
            <h3>Record a loss</h3>
            <p className="meta">Birds or animals that died, were culled, stolen or spoiled after Omoterra received them. They leave stock on hand and their cost ({tzs(note.unit_cost)} each) counts as a loss in Profit. What is owed to the supplier does not change.</p>
          </div>
          {onHand > 0 ? <ActionForm action={recordDeliveryLoss} label="Record loss" layout="row" hidden={{ ...hidden, idempotency_key: randomUUID() }}>
            <div className="field"><label htmlFor="loss-qty">How many?</label><input id="loss-qty" name="quantity" type="number" min={note.unit === 'kg' ? '0.001' : '1'} max={onHand} step={note.unit === 'kg' ? '0.001' : '1'} className="input" required /></div>
            <div className="field"><label htmlFor="loss-reason">What happened?</label><select id="loss-reason" name="reason" className="input" defaultValue="died">
              {LOSS_REASONS.map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></div>
            <div className="field"><label htmlFor="loss-date">Date</label><input id="loss-date" name="lost_on" type="date" min={note.received_on} max={today()} defaultValue={today()} className="input" required /></div>
            <div className="field"><label htmlFor="loss-note">Note (optional)</label><input id="loss-note" name="note" className="input" maxLength={500} placeholder="e.g. Died on the way from the farm" /></div>
          </ActionForm> : <p className="meta">Nothing on hand on this note.</p>}
        </div>}

        {admin && !note.cancelled_at && <div className={styles.actions}>
          <div className={styles.action}>
            <h3>Correct receipt</h3>
            <p className="meta">The supplier never delivered some of these. Removes them from this note and its payable; they go back to the supplier&apos;s batch. Only stock on hand ({quantity(note.on_hand)}) can be corrected.</p>
            {onHand > 0 ? <ActionForm action={correctReceipt} label="Correct receipt" variant="danger"
              confirm="Reduce this delivery note and its payable? This is recorded with your reason and evidence."
              hidden={{ ...hidden, idempotency_key: randomUUID() }}>
              <div className="field"><label htmlFor="correct-qty">How many were never delivered?</label><input id="correct-qty" name="quantity" type="number" min="0.001" max={onHand} step={note.unit === 'kg' ? '0.001' : '1'} className="input" required /></div>
              <div className="field"><label htmlFor="correct-reason">Reason</label><input id="correct-reason" name="reason" className="input" required minLength={3} /></div>
              <div className="field"><label htmlFor="correct-evidence">Evidence</label><input id="correct-evidence" name="evidence" className="input" required minLength={3} placeholder="e.g. Gate log, supplier confirmation" /></div>
              {paid > 0 && <div className="field"><label htmlFor="correct-payments">Money already paid above the new payable</label>
                <select id="correct-payments" name="payments" className="input" defaultValue="credit">
                  <option value="credit">The supplier keeps it as credit</option>
                  <option value="unresolved">Not yet known (unresolved)</option>
                </select></div>}
            </ActionForm> : <p className="meta">Nothing on hand to correct.</p>}
          </div>
          <div className={styles.action}>
            <h3>Return to supplier</h3>
            <p className="meta">Goods sent back to the supplier leave stock now. The payable stays until the supplier agrees a credit note.</p>
            {onHand > 0 ? <ActionForm action={returnToSupplier} label="Record return" hidden={{ ...hidden, idempotency_key: randomUUID() }}>
              <div className="field"><label htmlFor="return-qty">How many went back?</label><input id="return-qty" name="quantity" type="number" min="0.001" max={onHand} step={note.unit === 'kg' ? '0.001' : '1'} className="input" required /></div>
              <div className="field"><label htmlFor="return-date">Date returned</label><input id="return-date" name="returned_on" type="date" min={note.received_on} max={today()} defaultValue={today()} className="input" required /></div>
              <div className="field"><label htmlFor="return-reason">Reason</label><input id="return-reason" name="reason" className="input" required minLength={3} placeholder="e.g. Underweight" /></div>
            </ActionForm> : <p className="meta">Nothing on hand to return.</p>}
          </div>
          <div className={styles.action}>
            <h3>Record supplier credit note</h3>
            <p className="meta">The supplier agreed a credit for returned goods. It lowers the payable; money already paid above it stays with them as credit.</p>
            {awaiting.length === 0 ? <p className="meta">No return is awaiting supplier credit.</p> : awaiting.map((row) =>
              <div key={row.id} className={styles.credit}>
                <ActionForm action={recordSupplierCreditNote} label="Record credit note" hidden={{ ...hidden, movement_id: row.id, idempotency_key: randomUUID() }}>
                  <p className="meta">{quantity(row.quantity)} {unit} returned {date(row.occurred_on)}, worth {tzs(row.value)}</p>
                  <div className="field"><label htmlFor={`credit-amount-${row.id}`}>Agreed credit (TZS)</label><input id={`credit-amount-${row.id}`} name="amount" type="number" min="1" max={Number(row.value)} step="0.01" defaultValue={Number(row.value)} className="input" required /></div>
                  <div className="field"><label htmlFor={`credit-date-${row.id}`}>Credit note date</label><input id={`credit-date-${row.id}`} name="issued_on" type="date" min={row.occurred_on} max={today()} defaultValue={today()} className="input" required /></div>
                  <div className="field"><label htmlFor={`credit-ref-${row.id}`}>Credit note reference</label><input id={`credit-ref-${row.id}`} name="reference" className="input" required /></div>
                  <div className="field"><label htmlFor={`credit-note-${row.id}`}>Note (optional)</label><input id={`credit-note-${row.id}`} name="note" className="input" /></div>
                </ActionForm>
              </div>)}
          </div>
        </div>}
        {!admin && <p className="meta">Corrections, returns and credit notes are recorded by an admin.</p>}
      </section>
      <p className="meta"><Link href={'/suppliers/' + note.supplier_id}>← Back to supplier</Link>{note.debt_id && <> · <Link href={'/finance/debts/' + note.debt_id}>Open supplier invoice</Link></>}</p>
    </div>
  </>;
}
