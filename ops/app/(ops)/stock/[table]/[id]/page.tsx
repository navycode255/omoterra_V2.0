import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { Notice, PageHeader } from '@/components/ui';
import list from '@/components/finance/finance-list.module.css';
import styles from '@/components/finance/cost-states.module.css';
import { ApiError, get } from '@/lib/api';
import { day, today } from '@/lib/finance';
import { quantity, tzs } from '@/lib/format';
import { cancelLotAdjustment, recordOpeningLoss, recordStockCount } from '@/lib/lot-actions';
import { LOT_KINDS, MOVEMENT_LABELS, type LotDetail, type LotTable } from '@/lib/lots';
import { requireSession } from '@/lib/session';

export const metadata = { title: 'Stock lot · Omoterra Operations' };

const TABLES: LotTable[] = ['supplier_collections', 'lpo_lines', 'opening_stock'];

/**
 * One received lot (build plan M2.1): what it is, its figures on any date, and
 * every dated movement with the on-hand balance after it. Admins record a
 * physical count; staff record opening stock that died or was lost.
 */
export default async function LotPage({ params, searchParams }: {
  params: Promise<{ table: string; id: string }>; searchParams: Promise<{ as_of?: string }>;
}) {
  const { table, id } = await params;
  const { as_of: asOf } = await searchParams;
  if (!TABLES.includes(table as LotTable)) notFound();
  const operator = await requireSession();
  const admin = operator.role === 'admin';
  let lot: LotDetail;
  try {
    lot = await get<LotDetail>(`/ops/lots/${table}/${id}${asOf ? `?as_of=${asOf}` : ''}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    return <><div className="topbar"><PageHeader title="Stock lot" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'This lot could not be loaded.'}</Notice></div></>;
  }
  const unit = lot.unit;
  const lostTotal = Number(lot.died) + Number(lot.lost) + Number(lot.not_recovered);

  return <div className={`workspace ${styles.page}`}>
    <div className={styles.heading}>
      <div><h1>{lot.number}</h1><p><span className={styles.label}>{LOT_KINDS[lot.lot_table]}</span> {lot.description} · {lot.supplier_name} · {tzs(lot.unit_cost)} per {unit}</p></div>
      <div className={styles.search}>
        <Link href={lot.href} className="button" data-variant="secondary">Open {LOT_KINDS[lot.lot_table].toLowerCase()}</Link>
        <Link href="/stock" className="button" data-variant="secondary">All stock</Link>
      </div>
    </div>

    <form className={styles.search} method="get" aria-label="Figures as of">
      <label htmlFor="as_of" className="meta">Figures at the end of</label>
      <input id="as_of" name="as_of" type="date" className="input" defaultValue={asOf || today()} max={today()} />
      <button className="button" data-variant="secondary" type="submit">Show</button>
      {asOf && <Link className="meta" href={`/stock/${table}/${id}`}>Today</Link>}
    </form>

    <section className={styles.stats} aria-label="Lot figures">
      <article className={styles.stat}><span>On hand{asOf ? ` on ${day(asOf)}` : ''}</span><strong>{quantity(lot.on_hand)} {unit}</strong><small>{tzs(String(Number(lot.on_hand) * Number(lot.unit_cost)))} at cost</small></article>
      <article className={styles.stat}><span>Received</span><strong>{quantity(lot.received)}</strong><small>{Number(lot.corrected) > 0 ? `${quantity(lot.corrected)} corrected as never delivered` : `on ${day(lot.received_on)}`}</small></article>
      <article className={styles.stat}><span>Sold</span><strong>{quantity(lot.sold)}</strong><small>{Number(lot.returned_by_buyers) > 0 ? `${quantity(lot.returned_by_buyers)} returned by buyers` : 'Net of buyer returns'}</small></article>
      <article className={styles.stat}><span>Died, lost or returned</span><strong>{quantity(String(lostTotal + Number(lot.returned_to_supplier)))}</strong>
        <small>{quantity(lot.died)} died · {quantity(String(Number(lot.lost) + Number(lot.not_recovered)))} lost · {quantity(lot.returned_to_supplier)} to supplier{Number(lot.counted) !== 0 ? ` · count ${Number(lot.counted) > 0 ? '+' : ''}${quantity(lot.counted)}` : ''}</small></article>
    </section>

    <section className={styles.panel}>
      <h2>Movements</h2>
      <div className={list.tableWrap}>
        <table className={list.table}>
          <thead><tr><th data-phone-first>Date</th><th>What happened</th><th>Change</th><th>On hand after</th><th>Details</th><th>Recorded by</th>{admin && <th>Correct</th>}</tr></thead>
          <tbody>{lot.movements.map((row) => <tr key={`${row.source_table}:${row.source_id}:${row.kind}`}>
            <td data-label="Date">{day(row.date)}</td>
            <td data-label="What happened">{MOVEMENT_LABELS[row.kind] ?? row.kind}</td>
            <td data-label="Change">{Number(row.delta) > 0 ? '+' : ''}{quantity(row.delta)}{Number(row.delta) === 0 ? ` (${quantity(row.quantity)}, no change)` : ''}</td>
            <td data-label="On hand after"><b>{quantity(row.on_hand)}</b></td>
            <td data-label="Details">{row.sale_id ? <Link href={`/sales/${row.sale_id}`}>{row.sale_number}</Link> : null}
              {row.kind === 'count_adjustment' ? `Counted ${quantity(row.counted_quantity)}. ${row.note} Evidence: ${row.evidence}` : row.sale_id ? '' : row.note}</td>
            <td data-label="Recorded by">{row.recorded_by || '—'}</td>
            {admin && <td data-label="Correct">{row.source_table === 'lot_adjustments'
              ? <details><summary>Cancel</summary>
                <ActionForm action={cancelLotAdjustment} label="Cancel this entry" variant="danger" hidden={{ adjustment_id: row.source_id, idempotency_key: randomUUID() }}>
                  <div className="field"><label htmlFor={`cancel-${row.source_id}`}>Reason</label><input id={`cancel-${row.source_id}`} name="reason" className="input" required minLength={3} /></div>
                </ActionForm></details> : null}</td>}
          </tr>)}</tbody>
        </table>
        {!lot.movements.length && <p className="meta">Nothing has been received on this lot.</p>}
      </div>
      {lot.cancelled_adjustments.length > 0 && <p className="meta">Cancelled: {lot.cancelled_adjustments.map((row) =>
        `${row.kind === 'count' ? 'count' : 'loss'} of ${quantity(row.quantity)} on ${day(row.occurred_on)} (${row.cancel_reason})`).join('; ')}.</p>}
    </section>

    {admin ? <section className={styles.panel}>
      <h2>Record a stock count</h2>
      <p className="meta">Enter what was physically counted. The difference from the records on that day is recorded, and a shortage counts as stock lost at {tzs(lot.unit_cost)} per {unit}.</p>
      <ActionForm action={recordStockCount} label="Record count" hidden={{ lot_table: lot.lot_table, lot_id: lot.lot_id, idempotency_key: randomUUID() }}>
        <div className="field"><label htmlFor="counted_quantity">Counted ({unit}s)</label><input id="counted_quantity" name="counted_quantity" className="input" inputMode="decimal" required /></div>
        <div className="field"><label htmlFor="counted_on">Counted on</label><input id="counted_on" name="counted_on" type="date" className="input" defaultValue={today()} max={today()} required /></div>
        <div className="field"><label htmlFor="reason">Why the records differ, if known</label><input id="reason" name="reason" className="input" required minLength={3} /></div>
        <div className="field"><label htmlFor="evidence">Evidence (count sheet, who counted)</label><input id="evidence" name="evidence" className="input" required minLength={3} /></div>
      </ActionForm>
    </section> : <Notice>Only an admin records a stock count.</Notice>}

    {lot.lot_table === 'opening_stock' && <section className={styles.panel}>
      <h2>Record died or lost</h2>
      <ActionForm action={recordOpeningLoss} label="Record loss" hidden={{ lot_id: lot.lot_id, idempotency_key: randomUUID() }}>
        <div className="field"><label htmlFor="loss_quantity">Quantity ({unit}s)</label><input id="loss_quantity" name="quantity" className="input" inputMode="decimal" required /></div>
        <div className="field"><label htmlFor="lost_on">Date</label><input id="lost_on" name="lost_on" type="date" className="input" defaultValue={today()} max={today()} required /></div>
        <div className="field"><label htmlFor="loss_reason">What happened</label><select id="loss_reason" name="reason" className="input" required>
          <option value="died">Died</option><option value="sick">Culled (sick)</option><option value="stolen">Stolen</option>
          <option value="spoiled">Spoiled</option><option value="other">Other</option></select></div>
        <div className="field"><label htmlFor="loss_note">Note</label><input id="loss_note" name="note" className="input" /></div>
        <div className="field"><label htmlFor="loss-late">If dated more than 3 days ago: why (admin only)</label><input id="loss-late" name="late_reason" className="input" /></div>
      </ActionForm>
    </section>}
  </div>;
}
