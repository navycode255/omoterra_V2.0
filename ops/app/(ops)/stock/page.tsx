import Link from 'next/link';
import { Notice, PageHeader } from '@/components/ui';
import { SearchBox } from '@/components/list-toolbar';
import { ListFooter } from '@/components/finance/list-footer';
import list from '@/components/finance/finance-list.module.css';
import styles from '@/components/finance/cost-states.module.css';
import { ApiError, get } from '@/lib/api';
import { day, today } from '@/lib/finance';
import { quantity, tzs } from '@/lib/format';
import { LOT_KINDS, lotHref, type LotPage } from '@/lib/lots';
import { param, type ListParams } from '@/lib/paging';
import { requireSession } from '@/lib/session';

export const metadata = { title: 'Stock · Omoterra Operations' };

const label = (value: string) => value.replaceAll('_', ' ');

/**
 * Stock on hand per received lot (build plan M2.1): delivery notes, LPO lines
 * and opening stock, as of any date. Each lot's figure is the sum of its dated
 * movements; a supplier's registered batch is their declaration, not stock.
 */
export default async function StockPage({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  await requireSession();
  const asOf = param(params, 'as_of') || today();
  const show = param(params, 'show') === 'all' ? 'all' : 'on_hand';
  const query = new URLSearchParams({ as_of: asOf, show, page: param(params, 'page') || '1', page_size: param(params, 'page_size') || '10' });
  const q = param(params, 'q');
  if (q) query.set('q', q);
  let data: LotPage;
  try {
    data = await get<LotPage>(`/ops/lots?${query}`);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Stock" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Stock could not be loaded.'}</Notice></div></>;
  }
  function href(change: Record<string, string>) {
    const next = new URLSearchParams();
    for (const key of ['as_of', 'show', 'q', 'page', 'page_size']) { const value = param(params, key); if (value) next.set(key, value); }
    for (const [key, value] of Object.entries(change)) { if (value) next.set(key, value); else next.delete(key); }
    return `/stock${next.size ? `?${next}` : ''}`;
  }
  const units = Object.entries(data.summary.on_hand);

  return <div className={`workspace ${styles.page}`}>
    <div className={styles.heading}>
      <div><h1>Stock</h1><p>What is on hand from each delivery note, LPO and opening stock entry, on any date.</p></div>
      <div className={styles.search}>
        <Link href="/finance/opening-stock" className="button" data-variant="secondary">Opening stock</Link>
        <Link href="/finance" className="button" data-variant="secondary">Finance</Link>
      </div>
    </div>

    <form className={styles.search} method="get" aria-label="Stock date">
      <label htmlFor="as_of" className="meta">On hand at the end of</label>
      <input id="as_of" name="as_of" type="date" className="input" defaultValue={asOf} max={today()} />
      <input type="hidden" name="show" value={show} />
      <button className="button" data-variant="secondary" type="submit">Show</button>
      {asOf !== today() && <Link className="meta" href={href({ as_of: '', page: '' })}>Today</Link>}
    </form>

    <section className={styles.stats} aria-label="Stock summary">
      <article className={styles.stat}><span>Value on hand</span><strong>{tzs(data.summary.on_hand_value)}</strong><small>At each lot&apos;s cost, {day(asOf)}</small></article>
      <article className={styles.stat}><span>Lots with stock</span><strong>{data.summary.lots_with_stock}</strong><small>Delivery notes, LPO lines, opening stock</small></article>
      {units.slice(0, 2).map(([unit, value]) => <article key={unit} className={styles.stat}><span>On hand ({unit}s)</span>
        <strong>{quantity(value)}</strong><small>All lots</small></article>)}
    </section>

    <section className={styles.panel}>
      <h2>Lots {show === 'all' ? '' : 'with stock '}on {day(asOf)}</h2>
      <div className={styles.search} role="search">
        <SearchBox placeholder="Search number, product or supplier…" />
        <Link className="meta" href={href({ show: show === 'all' ? '' : 'all', page: '' })}>{show === 'all' ? 'Only lots with stock' : 'Include empty lots'}</Link>
      </div>
      <div className={list.tableWrap}>
        <table className={list.table}>
          <thead><tr><th data-phone-first>Lot</th><th>On hand</th><th>Value (TZS)</th><th>Received</th><th>Sold</th><th>Died or lost</th><th>Returned to supplier</th><th>Supplier</th></tr></thead>
          <tbody>{data.items.map((row) => <tr key={`${row.lot_table}:${row.lot_id}`}>
            <td data-label="Lot"><div><Link className={list.name} href={lotHref(row.lot_table, row.lot_id)}>{row.number}</Link>
              <small><span className={styles.label}>{LOT_KINDS[row.lot_table]}</span> {row.category ? label(row.category) : row.description}</small></div></td>
            <td data-label="On hand">{quantity(row.on_hand)} {row.unit}</td>
            <td data-label="Value" className={list.money}>{Number(row.value_on_hand).toLocaleString('en-US')}</td>
            <td data-label="Received">{quantity(row.received)}<small> on {day(row.received_on)}</small></td>
            <td data-label="Sold">{quantity(row.sold)}</td>
            <td data-label="Died or lost">{quantity(String(Number(row.died) + Number(row.lost) + Number(row.not_recovered)))}</td>
            <td data-label="Returned to supplier">{quantity(row.returned_to_supplier)}</td>
            <td data-label="Supplier">{row.supplier_name}</td>
          </tr>)}</tbody>
        </table>
        {!data.items.length && <p className="meta">No {show === 'all' ? '' : 'stock on hand in '}lots on {day(asOf)}{q ? ' matching this search' : ''}.</p>}
      </div>
      <ListFooter data={data} label="Lots" href={(n) => href({ page: String(n) })} />
    </section>
  </div>;
}
