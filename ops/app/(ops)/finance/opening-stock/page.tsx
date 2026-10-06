import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Notice, PageHeader } from '@/components/ui';
import { SearchBox } from '@/components/list-toolbar';
import { ListFooter } from '@/components/finance/list-footer';
import { OpeningStockForm } from '@/components/finance/opening-stock-form';
import list from '@/components/finance/finance-list.module.css';
import styles from '@/components/finance/cost-states.module.css';
import { ApiError, get } from '@/lib/api';
import { PROVISIONAL, day, today, type OpeningStock, type UnknownCostLine, type UnknownCost } from '@/lib/finance';
import { quantity, tzs } from '@/lib/format';
import { cancelOpeningStock } from '@/lib/opening-stock-actions';
import { param, type ListParams, type Page } from '@/lib/paging';
import { requireSession } from '@/lib/session';

export const metadata = { title: 'Opening stock · Omoterra Operations' };

type OpeningPage = Page<OpeningStock> & { summary: { entries: number; value: string; value_on_hand: string; with_stock: number } };
type UnknownPage = Page<UnknownCostLine> & { summary: UnknownCost };

const label = (value: string) => value.replaceAll('_', ' ');

/**
 * Opening stock (build plan M1.3, decision D3): stock held before the system,
 * at the value the finance owner gives it, with no payable. Below it, the
 * sale lines whose buying cost is still unknown, which keep profit
 * "Provisional: buying costs incomplete" until an admin gives them a cost.
 */
export default async function OpeningStockPage({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  const operator = await requireSession();
  const admin = operator.role === 'admin';
  const start = param(params, 'start');
  const end = param(params, 'end');
  const stockQuery = new URLSearchParams({ page: param(params, 'page') || '1', page_size: param(params, 'page_size') || '10' });
  const q = param(params, 'q');
  if (q) stockQuery.set('q', q);
  const unknownQuery = new URLSearchParams({ page: param(params, 'upage') || '1', page_size: '10' });
  if (start) unknownQuery.set('start', start);
  if (end) unknownQuery.set('end', end);
  let stock: OpeningPage;
  let unknown: UnknownPage;
  try {
    [stock, unknown] = await Promise.all([
      get<OpeningPage>(`/ops/opening-stock?${stockQuery}`),
      get<UnknownPage>(`/ops/finance/unknown-costs?${unknownQuery}`),
    ]);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Opening stock" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Opening stock could not be loaded.'}</Notice></div></>;
  }
  function href(change: Record<string, string>) {
    const query = new URLSearchParams();
    for (const key of ['q', 'page', 'page_size', 'upage', 'start', 'end']) { const value = param(params, key); if (value) query.set(key, value); }
    for (const [key, value] of Object.entries(change)) { if (value) query.set(key, value); else query.delete(key); }
    return `/finance/opening-stock${query.size ? `?${query}` : ''}`;
  }

  return <div className={`workspace ${styles.page}`}>
    <div className={styles.heading}>
      <div><h1>Opening stock</h1><p>Stock held before the system, valued by the finance owner. It opens no supplier debt.</p></div>
      <Link href="/finance/profit" className="button" data-variant="secondary">Profit</Link>
    </div>

    <section className={styles.stats} aria-label="Opening stock summary">
      <article className={styles.stat}><span>Entries</span><strong>{stock.summary.entries}</strong><small>{stock.summary.with_stock} with stock on hand</small></article>
      <article className={styles.stat}><span>Value recorded</span><strong>{tzs(stock.summary.value)}</strong><small>No payable: paid before the system</small></article>
      <article className={styles.stat}><span>Value on hand</span><strong>{tzs(stock.summary.value_on_hand)}</strong><small>At opening cost</small></article>
      <article className={styles.stat}><span>Lines with unknown cost</span><strong>{unknown.summary.lines}</strong>
        <small>{unknown.summary.sales} {unknown.summary.sales === 1 ? 'sale' : 'sales'} · {tzs(unknown.summary.revenue)} revenue</small></article>
    </section>

    {admin ? <section className={styles.panel}>
      <h2>Record opening stock</h2>
      <OpeningStockForm today={today()} valuedBy="Maternus Joshua" />
    </section> : <Notice>Only an admin records opening stock, at the value the finance owner gives.</Notice>}

    <section className={styles.panel}>
      <h2>Opening stock entries</h2>
      <div className={styles.search} role="search"><SearchBox placeholder="Search number, product, evidence or who valued it…" /></div>
      <div className={list.tableWrap}>
        <table className={list.table}>
          <thead><tr><th data-phone-first>Entry</th><th>On hand</th><th>Quantity</th><th>Cost each (TZS)</th><th>Value (TZS)</th><th>Valued as of</th><th>Evidence</th><th>Sold</th>{admin && <th>Correct</th>}</tr></thead>
          <tbody>{stock.items.map((row) => <tr key={row.id}>
            <td data-label="Entry"><div>{row.cancelled_at ? <b className={styles.cancelled}>{row.receipt_number}</b>
              : <Link className={list.name} href={`/stock/opening_stock/${row.id}`}>{row.receipt_number}</Link>}
              <small><span className={styles.label}>{row.label}</span> {row.category ? label(row.category) : row.description}</small></div></td>
            <td data-label="On hand">{row.cancelled_at ? 'Cancelled' : `${quantity(row.on_hand)} ${row.unit}`}</td>
            <td data-label="Quantity">{quantity(row.quantity)} {row.unit}</td>
            <td data-label="Cost each" className={list.money}>{Number(row.unit_cost).toLocaleString('en-US')}</td>
            <td data-label="Value" className={list.money}>{Number(row.amount).toLocaleString('en-US')}</td>
            <td data-label="Valued as of">{day(row.as_of)}<small> by {row.valued_by}</small></td>
            <td data-label="Evidence">{row.evidence}<small> · entered by {row.recorded_by ?? '—'}</small></td>
            <td data-label="Sold">{quantity(row.sold)}{Number(row.not_recovered) > 0 ? ` · ${quantity(row.not_recovered)} not recovered` : ''}</td>
            {admin && <td data-label="Correct">{row.cancelled_at ? row.cancel_reason
              : Number(row.sold) > 0 || Number(row.not_recovered) > 0 ? 'Sold from: correct the sales first'
              : <details><summary>Cancel entry</summary>
                <ActionForm action={cancelOpeningStock} label="Cancel entry" variant="danger" hidden={{ opening_stock_id: row.id, idempotency_key: randomUUID() }}>
                  <div className="field"><label htmlFor={`cancel-${row.id}`}>Reason</label><input id={`cancel-${row.id}`} name="reason" className="input" required minLength={3} /></div>
                </ActionForm></details>}</td>}
          </tr>)}</tbody>
        </table>
        {!stock.items.length && <p className="meta">No opening stock recorded{q ? ' matching this search' : ''}.</p>}
      </div>
      <ListFooter data={stock} label="Opening stock" href={(n) => href({ page: String(n) })} />
    </section>

    <section className={styles.panel} id="unknown-costs">
      <h2>Sale lines with an unknown buying cost</h2>
      {unknown.summary.lines > 0
        ? <p className={styles.provisionalNote}>{PROVISIONAL}: profit for any period with these lines is not final. {admin
          ? 'Open each sale to give its line a cost: sold from opening stock, an evidenced cost, or free.'
          : 'An admin gives each line its cost on its sale page.'}{start ? ` Showing ${day(start)} – ${day(end || today())}.` : ''}</p>
        : <p className="meta">Every active sale line{start ? ' in these dates' : ''} has a known or free buying cost.</p>}
      {unknown.items.length > 0 && <div className={list.tableWrap}>
        <table className={list.table}>
          <thead><tr><th data-phone-first>Sale</th><th>Item</th><th>Quantity</th><th>Revenue (TZS)</th><th>Buyer</th><th>Date sold</th></tr></thead>
          <tbody>{unknown.items.map((row) => <tr key={row.sale_item_id}>
            <td data-label="Sale"><Link className={list.name} href={row.href}>{row.sale_number}</Link></td>
            <td data-label="Item">{row.category ? label(row.category) : row.description}<small className={styles.unknown}> · cost unknown</small></td>
            <td data-label="Quantity">{quantity(row.quantity)} {row.unit}</td>
            <td data-label="Revenue" className={list.money}>{Number(row.revenue).toLocaleString('en-US')}</td>
            <td data-label="Buyer">{row.buyer_name}</td>
            <td data-label="Date sold">{day(row.sold_on)}</td>
          </tr>)}</tbody>
        </table>
      </div>}
      {unknown.total > 0 && <ListFooter data={unknown} label="Unknown-cost lines" perPage={false} href={(n) => href({ upage: String(n) })} />}
    </section>
  </div>;
}
