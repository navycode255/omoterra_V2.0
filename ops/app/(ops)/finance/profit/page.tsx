import Link from 'next/link';
import type { ReactNode } from 'react';
import { Notice, PageHeader } from '@/components/ui';
import { Icons } from '@/components/icons';
import { FilterMenu } from '@/components/list-toolbar';
import { ListFooter } from '@/components/finance/list-footer';
import ui from '@/components/finance/expenses.module.css';
import styles from '@/components/finance/finance-list.module.css';
import { ApiError, get } from '@/lib/api';
import { day, expenseLabel, thisMonth, today, type ProfitReport } from '@/lib/finance';
import { tzs } from '@/lib/format';
import { param, type ListParams } from '@/lib/paging';

export const metadata = { title: 'Profit · Omoterra Operations' };

function shift(isoDate: string, days: number) {
  const d = new Date(`${isoDate}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}
const plain = (value: string | number) => Number(value).toLocaleString('en-US', { maximumFractionDigits: 2 });
const signed = (value: string | number) => `${Number(value) < 0 ? '-' : ''}${plain(Math.abs(Number(value)))}`;

// A coloured icon per expense category in "Where the money went".
const CATEGORY_ICONS: Record<string, [ReactNode, string]> = {
  transport: [<Icons.truck key="i" size={18} />, '#2f6fde'],
  labour: [<Icons.users key="i" size={18} />, '#8a4fd8'],
  fuel: [<svg key="i" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" aria-hidden="true"><path d="M5 21V5a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v16M3 21h14M15 9h2a2 2 0 0 1 2 2v5a1.5 1.5 0 0 0 3 0V9l-3-3M8 7h4" /></svg>, '#e98b1c'],
  packaging: [<Icons.box key="i" size={18} />, '#12925a'],
  feed: [<Icons.sprout key="i" size={18} />, '#5c9a2d'],
  medicine_vet: [<Icons.shield key="i" size={18} />, '#d9342b'],
};

export default async function Profit({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  const now = today();
  const month = thisMonth();
  const presets: [string, string, string][] = [
    ['Today', now, now],
    ['7 days', shift(now, -6), now],
    ['This month', month.start, now],
    ['30 days', shift(now, -29), now],
    ['This year', `${now.slice(0, 4)}-01-01`, now],
  ];
  const start = param(params, 'start') || month.start;
  const end = param(params, 'end') || now;
  // On the 1st, "Today" and "This month" are the same dates: the default
  // view (no dates chosen) is "This month".
  const preset = param(params, 'start') ? presets.find(([, s, e]) => s === start && e === end)?.[0] : 'This month';
  let data: ProfitReport;
  try {
    data = await get<ProfitReport>(`/ops/finance/profit?start=${start}&end=${end}`);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Profit" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Profit could not be calculated.'}</Notice></div></>;
  }

  // Day by day, oldest first, 10 a page. Every figure comes from the API
  // (backend reporting.profit), so each row adds up:
  // sales − stock cost − expenses − stock lost = operating profit.
  const days = [...data.days].sort((a, b) => a.date.localeCompare(b.date));
  const size = Math.min(100, Math.max(1, Number(param(params, 'page_size')) || 10));
  const pages = Math.max(1, Math.ceil(days.length / size));
  const page = Math.min(pages, Math.max(1, Number(param(params, 'page')) || 1));
  const shown = days.slice((page - 1) * size, page * size);
  const listing = { items: shown, total: days.length, page, page_size: size, actionable: 0 };
  const href = (change: Record<string, string>) => {
    const query = new URLSearchParams({ start, end });
    const keepSize = param(params, 'page_size'); if (keepSize) query.set('page_size', keepSize);
    for (const [key, value] of Object.entries(change)) { if (value) query.set(key, value); else query.delete(key); }
    return `/finance/profit?${query}`;
  };
  const loss = Number(data.net_profit) < 0;
  const app = (value: string) => Number(value) > 0 ? ` · app orders ${tzs(value)}` : '';

  return <div className={`${ui.workspace} ${styles.page}`}>
    <div className={ui.heading}><h1>Profit</h1><Link href="/finance/reports" className={ui.primary}>Reports & forecasts</Link><Link href="/finance/expenses" className={ui.primary}>+ Expense</Link></div>

    <div className={styles.periodBar}>
      <nav className={styles.periodTabs} aria-label="Period">
        {presets.map(([label, s, e]) => <Link key={label} href={`/finance/profit?start=${s}&end=${e}`} data-active={label === preset} aria-current={label === preset ? 'page' : undefined}>{label}</Link>)}
        <span data-active={!preset}>Custom</span>
      </nav>
      <FilterMenu icon="calendar" label={`${day(start)} – ${day(end)}`}>
        <label>From<input type="date" name="start" defaultValue={start} max={now} /></label>
        <label>To<input type="date" name="end" defaultValue={end} max={now} /></label>
      </FilterMenu>
    </div>

    <section className={styles.stats} data-count="4" aria-label="Profit summary">
      <article className={styles.stat} data-tone="in"><span className={styles.statIcon}><Icons.chart size={26} /></span>
        <div><span>Sales</span><strong>{tzs(data.revenue)}</strong><small>Direct {tzs(data.sales)}{app(data.marketplace_sales)}</small></div></article>
      <article className={styles.stat} data-tone="late"><span className={styles.statIcon}><Icons.box size={26} /></span>
        <div><span>Stock cost</span><strong>{tzs(data.cost_of_goods)}</strong><small>Direct {tzs(data.stock_cost)}{app(data.marketplace_cost)}</small></div></article>
      <Link href={`/finance/expenses?start=${start}&end=${end}`} className={styles.stat} data-tone="red"><span className={styles.statIcon}><Icons.file size={26} /></span>
        <div><span>Expenses</span><strong>{tzs(data.expenses)}</strong>{Number(data.stock_lost) > 0 && <small>Stock lost, also deducted: {tzs(data.stock_lost)}</small>}</div></Link>
      {/* An operating result: no depreciation, interest or tax yet (M3.2). */}
      <article className={styles.stat} data-tone={loss ? 'red' : 'in'} data-highlight={loss ? 'loss' : 'gain'}><span className={styles.statIcon}><Icons.trend size={26} /></span>
        <div><span>{loss ? 'Operating loss' : 'Operating profit'}</span><strong>{loss ? '-' : ''}{tzs(String(Math.abs(Number(data.net_profit))))}</strong></div></article>
    </section>

    {data.unresolved_marketplace.count > 0 && <p className={styles.sourceNote} role="note">
      {data.unresolved_marketplace.count} delivered app {data.unresolved_marketplace.count === 1 ? 'order has' : 'orders have'} no recorded delivery date
      ({tzs(data.unresolved_marketplace.amount)}), so {data.unresolved_marketplace.count === 1 ? 'it is' : 'they are'} in no period&apos;s sales.</p>}

    <section className={styles.panel}>
      <h2>Day by day</h2>
      <div className={styles.tableWrap}>
        <table className={styles.table} data-phone-show="1 5">
          <thead><tr><th>Date</th><th>Sales (TZS)</th><th>Stock cost (TZS)</th><th>Expenses and stock lost (TZS)</th><th>Operating profit (TZS)</th></tr></thead>
          <tbody>{shown.map((d) => <tr key={d.date}>
            <td data-label="Date"><Link className={styles.plainLink} href={`/sales?start=${d.date}&end=${d.date}`}>{day(d.date)}</Link></td>
            <td data-label="Sales" className={styles.money}>{plain(d.revenue)}</td>
            <td data-label="Stock cost" className={styles.money}>{plain(d.cost_of_goods)}</td>
            <td data-label="Expenses and stock lost" className={styles.money}>{plain(d.expenses_and_losses)}</td>
            <td data-label="Operating profit" className={Number(d.net_profit) < 0 ? styles.outAmount : styles.inAmount}>{signed(d.net_profit)}</td>
          </tr>)}</tbody>
        </table>
      </div>
      <ListFooter data={listing} label="Day" href={(n) => href({ page: String(n) })} />
    </section>

    <section className={styles.panel}>
      <h2>Where the money went</h2>
      {data.expenses_by_category.length === 0 && Number(data.stock_lost) === 0
        ? <div className={styles.empty}><Icons.file size={34} /><h2>No expenses in this period.</h2><p><Link href="/finance/expenses">Record an expense</Link></p></div>
        : <div className={styles.tableWrap}>
          <table className={styles.table}>
            <thead><tr><th>Category</th><th className={styles.right}>Amount (TZS)</th></tr></thead>
            <tbody>
              {data.expenses_by_category.map((row) => {
                const [icon, color] = CATEGORY_ICONS[row.category] ?? [<Icons.more key="i" size={18} />, '#8a96a6'];
                return <tr key={row.category}>
                  <td><Link className={styles.category} href={`/finance/expenses?start=${start}&end=${end}&category=${row.category}`}>
                    <span style={{ color, background: `${color}1a` }}>{icon}</span>{expenseLabel(row.category)}</Link></td>
                  <td className={`${styles.money} ${styles.right}`}>{plain(row.amount)}</td>
                </tr>;
              })}
              {Number(data.stock_lost) > 0 && <tr>
                <td><span className={styles.category}><span style={{ color: '#d9342b', background: '#d9342b1a' }}><Icons.alert size={18} /></span>Stock lost (dead or missing)</span></td>
                <td className={`${styles.money} ${styles.right}`}>{plain(data.stock_lost)}</td>
              </tr>}
            </tbody>
          </table>
        </div>}
    </section>
  </div>;
}
