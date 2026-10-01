import Link from 'next/link';
import { Notice, PageHeader } from '@/components/ui';
import { Icons } from '@/components/icons';
import { ListFooter } from '@/components/finance/list-footer';
import ui from '@/components/finance/expenses.module.css';
import styles from '@/components/finance/finance-list.module.css';
import { ApiError, get } from '@/lib/api';
import { day, thisMonth, type Sale, type SalesSummary } from '@/lib/finance';
import { phone, tzs } from '@/lib/format';
import { listPath, param, type ListParams, type Page } from '@/lib/paging';

export const metadata = { title: 'Sales · Omoterra Operations' };
const tabs = [['', 'All'], ['unpaid', 'Buyer still owes'], ['paid', 'Fully paid'], ['cancelled', 'Cancelled']];
const sales = (n: number) => `${n} ${n === 1 ? 'sale' : 'sales'}`;

// This calendar month unless other dates (or "all") were chosen.
function range(params: ListParams) {
  if (param(params, 'dates') === 'all') return { start: '', end: '' };
  const month = thisMonth();
  return { start: param(params, 'start') || month.start, end: param(params, 'end') || month.end };
}

export default async function Sales({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  const { start, end } = range(params);
  let data: Page<Sale> & { summary: SalesSummary };
  try {
    data = await get<Page<Sale> & { summary: SalesSummary }>(listPath('/ops/sales', params, ['start', 'end'], { start, end }));
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Sales" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Sales could not be loaded.'}</Notice></div></>;
  }
  const status = param(params, 'status');
  // An API that predates the totals sends none; the list still shows.
  const total: SalesSummary = data.summary ?? { sales_total: '0', sales_count: 0, received: '0', buyer_owes: '0', buyer_owes_count: 0, supplier_owed: '0', supplier_owed_count: 0 };
  const share = Number(total.sales_total) > 0 ? Math.round(Number(total.received) / Number(total.sales_total) * 100) : 0;
  function href(change: Record<string, string>) {
    const query = new URLSearchParams();
    for (const key of ['q', 'status', 'page_size', 'start', 'end', 'dates']) { const value = param(params, key); if (value) query.set(key, value); }
    for (const [key, value] of Object.entries(change)) { if (value) query.set(key, value); else query.delete(key); }
    return `/sales${query.size ? `?${query}` : ''}`;
  }

  return <div className={`${ui.workspace} ${styles.page}`}>
    <div className={ui.heading}><h1>Sales</h1><Link href="/sales/new" className={ui.primary}><Icons.plus size={19} />New sale</Link></div>

    <section className={styles.stats} data-count="4" aria-label="Sales summary">
      <article className={styles.stat} data-tone="in"><span className={styles.statIcon}><Icons.chart size={26} /></span>
        <div><span>Sales total</span><strong>{tzs(total.sales_total)}</strong><small>{sales(total.sales_count)}</small></div></article>
      <article className={styles.stat} data-tone="in"><span className={styles.statIcon}><Icons.wallet size={26} /></span>
        <div><span>Received</span><strong>{tzs(total.received)}</strong><small>{share}% received</small></div></article>
      <Link href={href({ status: 'unpaid', page: '' })} className={styles.stat} data-tone="late"><span className={styles.statIcon}><Icons.users size={26} /></span>
        <div><span>Buyer owes</span><strong>{tzs(total.buyer_owes)}</strong><small>{sales(total.buyer_owes_count)}</small></div></Link>
      <Link href="/finance/supplier-payments" className={styles.stat} data-tone="in"><span className={styles.statIcon}><Icons.truck size={26} /></span>
        <div><span>I owe suppliers</span><strong>{tzs(total.supplier_owed)}</strong><small>{sales(total.supplier_owed_count)}</small></div></Link>
    </section>

    <nav className={styles.tabs} aria-label="Sale status">
      {tabs.map(([key, label]) => <Link key={key} href={href({ status: key, page: '' })} data-active={status === key} aria-current={status === key ? 'page' : undefined}>
        {label}<span>{data.counts?.[key || 'all'] ?? ''}</span>
      </Link>)}
    </nav>

    <form className={styles.toolbar} action="/sales" role="search">
      {status && <input type="hidden" name="status" value={status} />}
      <label className={styles.search}><Icons.search size={19} /><input name="q" type="search" defaultValue={param(params, 'q')} placeholder="Search sale number, buyer, phone or product…" aria-label="Search sales" /></label>
      <div className={styles.toolbarEnd}>
        <details className={styles.filters}>
          <summary><Icons.calendar size={18} />{start ? `${day(start)} – ${day(end)}` : 'All dates'}<Icons.chevronDown size={16} /></summary>
          <div>
            <label>From<input type="date" name="start" defaultValue={start} /></label>
            <label>To<input type="date" name="end" defaultValue={end} /></label>
            <button type="submit">Apply dates</button>
            <Link href={href({ dates: 'all', start: '', end: '', page: '' })}>All dates</Link>
          </div>
        </details>
      </div>
    </form>

    <div className={styles.tableWrap}>
      <table className={styles.table} data-phone-show="1 5">
        <thead><tr><th>Sale</th><th>Buyer</th><th>Total (TZS)</th><th>Received (TZS)</th><th>Buyer owes (TZS)</th><th>Supplier owed (TZS)</th><th>Status</th><th aria-label="Open" /></tr></thead>
        <tbody>{data.items.map((sale) => {
          const tone = sale.status === 'cancelled' ? 'cancelled' : Number(sale.balance) > 0 ? 'open' : 'settled';
          return <tr key={sale.id}>
            <td data-label="Sale"><div><Link className={styles.name} href={`/sales/${sale.id}`}>{sale.sale_number}</Link><small>{day(sale.sold_on)}</small></div></td>
            <td data-label="Buyer"><div>{sale.buyer_name}<small>{sale.buyer_phone ? phone(sale.buyer_phone) : '—'}</small></div></td>
            <td data-label="Total" className={styles.balance}>{tzs(sale.total_amount)}</td>
            <td data-label="Received" className={styles.money}>{tzs(sale.received_amount)}</td>
            <td data-label="Buyer owes" className={styles.balance}>{tzs(sale.balance)}</td>
            <td data-label="Supplier owed" className={styles.money}>{tzs(sale.supplier_balance)}</td>
            <td data-label="Status"><span className={styles.status} data-tone={tone}>{tone === 'cancelled' ? 'Cancelled' : tone === 'open' ? 'Owes' : 'Paid'}</span></td>
            <td className={styles.more}><Link href={`/sales/${sale.id}`} className={styles.rowLink} aria-label={`Open ${sale.sale_number}`}><Icons.chevron size={18} /></Link></td>
          </tr>;
        })}</tbody>
      </table>
      {!data.items.length && <div className={styles.empty}><Icons.file size={38} /><h2>No sales in this view.</h2><p>Try other dates, another tab, or <Link href="/sales/new">record a sale</Link>.</p></div>}
    </div>

    <ListFooter data={data} label="Sale" href={(page) => href({ page: String(page) })} />
  </div>;
}
