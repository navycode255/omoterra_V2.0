import Link from 'next/link';
import { Notice, PageHeader } from '@/components/ui';
import { Icons } from '@/components/icons';
import { FilterMenu, SearchBox } from '@/components/list-toolbar';
import { ListFooter } from '@/components/finance/list-footer';
import ui from '@/components/finance/expenses.module.css';
import styles from '@/components/finance/finance-list.module.css';
import { ApiError, get } from '@/lib/api';
import { METHODS, day, methodLabel, thisMonth, type CashMovement } from '@/lib/finance';
import { dateTime, tzs } from '@/lib/format';
import { listPath, param, type ListParams, type Page } from '@/lib/paging';

export const metadata = { title: 'Cash book · Omoterra Operations' };
type CashBook = Page<CashMovement> & { summary: { money_in: string; money_out: string; net: string; recorded_net_cash: string;
  disputed_out: string; disputed_out_count: number } };
const tabs = [['', 'All'], ['in', 'Money in'], ['out', 'Money out'], ['reversed', 'Reversed']];
const plain = (value: string) => Number(value).toLocaleString('en-US', { maximumFractionDigits: 2 });
const signed = (value: string) => `${Number(value) < 0 ? '-' : ''}${tzs(String(Math.abs(Number(value))))}`;

export default async function CashBookPage({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  // This calendar month unless other dates (or "all") were chosen.
  const all = param(params, 'dates') === 'all';
  const month = thisMonth();
  const start = all ? '' : param(params, 'start') || month.start;
  const end = all ? '' : param(params, 'end') || month.end;
  let data: CashBook;
  try {
    data = await get<CashBook>(listPath('/ops/ledger/payments', params, ['start', 'end', 'method'], { start, end }));
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Cash book" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'The cash book could not be loaded.'}</Notice></div></>;
  }
  const status = param(params, 'status');
  const method = param(params, 'method');
  const total = data.summary;
  function href(change: Record<string, string>) {
    const query = new URLSearchParams();
    for (const key of ['q', 'status', 'page_size', 'start', 'end', 'dates', 'method']) { const value = param(params, key); if (value) query.set(key, value); }
    for (const [key, value] of Object.entries(change)) { if (value) query.set(key, value); else query.delete(key); }
    return `/finance/cash-book${query.size ? `?${query}` : ''}`;
  }

  return <div className={`${ui.workspace} ${styles.page}`}>
    <div className={ui.heading}>
      <div className={styles.titleGroup}>
        <h1>Cash book</h1>
        <FilterMenu icon="calendar" align="start" label={start ? `${day(start)} – ${day(end)}` : 'All dates'}>
          <label>From<input type="date" name="start" defaultValue={start} /></label>
          <label>To<input type="date" name="end" defaultValue={end} /></label>
          <Link className={styles.filterReset} href={href({ dates: 'all', start: '', end: '', page: '' })}>Show all dates</Link>
          <Link className={styles.filterReset} href="/finance/cash-book">This month</Link>
        </FilterMenu>
      </div>
      <details className={styles.menu} data-wide="true">
        <summary className={ui.primary}><Icons.plus size={19} />Record transaction</summary>
        <div>
          <Link href="/sales">Money received for a sale</Link>
          <Link href="/finance/expenses">Record an expense</Link>
          <Link href="/finance/supplier-payments">Pay a supplier</Link>
          <Link href="/finance/debts">Other debt or payment</Link>
        </div>
      </details>
    </div>

    <section className={styles.stats} data-count="4" aria-label="Cash summary">
      {/* Not a verified balance until money accounts and counts (M2.3). */}
      <Link href={href({ method: 'cash', dates: 'all', start: '', end: '', status: '', page: '' })} className={styles.stat} data-tone="in"><span className={styles.statIcon}><Icons.cash size={26} /></span>
        <div><span><span className={styles.wideLabel}>Recorded net cash movement (unverified)</span><span className={styles.phoneLabel}>Net cash (unverified)</span></span>
          <strong>{signed(total.recorded_net_cash)}</strong><small>Cash entries since records began; excludes app orders</small></div></Link>
      <Link href={href({ status: 'in', page: '' })} className={styles.stat} data-tone="in"><span className={styles.statIcon}><Icons.arrowUp size={26} /></span>
        <div><span>Money in</span><strong>{tzs(total.money_in)}</strong></div></Link>
      <Link href={href({ status: 'out', page: '' })} className={styles.stat} data-tone="red"><span className={styles.statIcon}><Icons.arrowDown size={26} /></span>
        <div><span>Money out</span><strong>{tzs(total.money_out)}</strong>
          {/* Still money out (R3) until payout attempts (M2.7) show whether the debit happened. */}
          {total.disputed_out_count > 0 && <small>Includes {tzs(total.disputed_out)} in {total.disputed_out_count === 1 ? 'a payout' : `${total.disputed_out_count} payouts`} the supplier says never arrived</small>}</div></Link>
      <article className={styles.stat} data-tone="in"><span className={styles.statIcon}><Icons.chart size={26} /></span>
        <div><span>Net for period</span><strong>{signed(total.net)}</strong></div></article>
    </section>

    <div className={styles.tabBar}>
      <nav className={styles.tabs} aria-label="Cash book">
        {tabs.map(([key, label]) => <Link key={key} href={href({ status: key, page: '' })} data-active={status === key} aria-current={status === key ? 'page' : undefined}>
          {label}<span>{data.counts?.[key || 'all'] ?? ''}</span>
        </Link>)}
      </nav>
      <div className={styles.toolbar} role="search">
        <SearchBox placeholder="Search name, reference or note…" />
        <FilterMenu label={method ? methodLabel(method) : 'Filter'}>
          <label>Payment method<select name="method" defaultValue={method}><option value="">All methods</option>{METHODS.map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></label>
          <Link className={styles.filterReset} href={href({ method: '', q: '', page: '' })}>Reset filters</Link>
        </FilterMenu>
      </div>
    </div>

    <div className={styles.tableWrap}>
      <table className={styles.table} data-phone-show="2 10">
        <thead><tr><th>Date</th><th>Who</th><th>For</th><th>In (TZS)</th><th>Out (TZS)</th><th>Method</th><th>Recorded by</th><th>Notes</th><th aria-label="More" /><th className={styles.phoneOnly}>Amount (TZS)</th></tr></thead>
        <tbody>{data.items.map((p) => {
          const incoming = p.flow === 'in';
          // A supplier transfer is one row however many invoices it paid;
          // a refund from a supplier is its own money-in row.
          // App order money links to its order (buyer receipts) or supplier (payouts).
          const who = p.debt_id && p.kind !== 'transfer' ? `/finance/debts/${p.debt_id}` : p.supplier_id ? `/suppliers/${p.supplier_id}#money`
            : p.order_id ? `/orders/${p.order_id}` : null;
          const what = p.kind === 'refund' ? 'Refund from supplier'
            : p.kind === 'transfer' ? (p.invoices > 1 ? `Supplier transfer over ${p.invoices} invoices` : p.description ?? 'Supplier transfer')
            : p.description ?? '';
          return <tr key={`${p.kind}:${p.id}`} data-reversed={p.reversed || undefined}>
            <td data-label="Date" className={styles.money}>{day(p.paid_on)}</td>
            <td data-label="Who">{who ? <Link className={styles.name} href={who}>{p.party_name}</Link> : p.party_name}</td>
            <td data-label="For" className={styles.forCell}>{p.sale_id && p.kind !== 'refund' ? <Link href={`/sales/${p.sale_id}`}>{what}</Link>
              : p.order_id ? <Link href={`/orders/${p.order_id}`}>{what}</Link> : what}</td>
            <td data-label="In" className={styles.inAmount}>{incoming ? plain(p.amount) : '–'}</td>
            <td data-label="Out" className={styles.outAmount}>{incoming ? '–' : plain(p.amount)}</td>
            <td data-label="Method">{methodLabel(p.method)}{p.reference && <small className={styles.block}>{p.reference}</small>}</td>
            <td data-label="Recorded by"><div>{p.recorded_by ?? '—'}<small>{dateTime(p.created_at)}</small></div></td>
            <td data-label="Notes">{p.reversed ? <span className={styles.reversed}>{p.moved_to_credit ? 'Moved to supplier credit (still money out on its transfer)' : 'Reversed'}: {p.reverse_reason}</span> : p.note || '–'}</td>
            <td className={styles.more}>
              <details className={styles.menu}>
                <summary aria-label={`More for ${p.party_name}`}><Icons.more size={18} /></summary>
                <div>
                  {p.debt_id && <Link href={`/finance/debts/${p.debt_id}`}>{p.kind === 'transfer' ? 'Open the first invoice' : 'Open the debt'}</Link>}
                  {p.supplier_id && <Link href={`/suppliers/${p.supplier_id}#money`}>Supplier statement</Link>}
                  {p.sale_id && <Link href={`/sales/${p.sale_id}`}>Open sale</Link>}
                  {p.order_id && <Link href={`/orders/${p.order_id}`}>Open app order</Link>}
                  {!p.reversed && p.kind === 'payment' && p.debt_id && <Link href={`/finance/debts/${p.debt_id}`}>Reverse (on the debt)</Link>}
                </div>
              </details>
            </td>
            <td className={`${styles.phoneOnly} ${incoming ? styles.inAmount : styles.outAmount}`}>{incoming ? '+' : '-'}{plain(p.amount)}</td>
          </tr>;
        })}</tbody>
      </table>
      {!data.items.length && <div className={styles.empty}><Icons.file size={38} /><h2>No payments in this view.</h2><p>Try other dates, another tab or search.</p></div>}
    </div>

    <ListFooter data={data} label="Cash book" href={(page) => href({ page: String(page) })} />
  </div>;
}
