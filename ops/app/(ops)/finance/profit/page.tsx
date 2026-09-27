import Link from 'next/link';
import { Card, Empty, Notice, PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { day, expenseLabel, today, type ProfitReport } from '@/lib/finance';
import { tzs } from '@/lib/format';
import { param, type ListParams } from '@/lib/paging';

export const metadata = { title: 'Profit · Omoterra Operations' };

function shift(isoDate: string, days: number) {
  const d = new Date(`${isoDate}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

function Signed({ value }: { value: string }) {
  const negative = Number(value) < 0;
  return <span className="money" style={{ color: negative ? 'var(--error)' : 'var(--positive)' }}>{negative ? '−' : ''}{tzs(String(Math.abs(Number(value))))}</span>;
}

export default async function Profit({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  const now = today();
  const presets: [string, string, string][] = [
    ['Today', now, now],
    ['Last 7 days', shift(now, -6), now],
    ['This month', `${now.slice(0, 8)}01`, now],
    ['Last 30 days', shift(now, -29), now],
    ['This year', `${now.slice(0, 4)}-01-01`, now],
  ];
  const start = param(params, 'start') || `${now.slice(0, 8)}01`;
  const end = param(params, 'end') || now;
  let data: ProfitReport;
  try {
    data = await get<ProfitReport>(`/ops/finance/profit?start=${start}&end=${end}`);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Profit" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Profit could not be calculated.'}</Notice></div></>;
  }
  const hasMarketplace = Number(data.marketplace_sales) > 0;
  const active = data.days.filter((d) => Number(d.revenue) || Number(d.expenses));
  return (
    <>
      <div className="topbar">
        <PageHeader title="Profit" subtitle={`${day(data.start)} – ${day(data.end)}: what you made, what it cost, what is left.`}
          info="Sales count on the day sold, whether paid yet or not. Stock cost is what you owe or paid suppliers for the stock sold. Expenses count on the day incurred. Cancelled sales and expenses are left out." />
        <Link href="/finance/expenses" className="button">+ Expense</Link>
      </div>
      <div className="workspace">
        <div className="row" style={{ flexWrap: 'wrap', alignItems: 'end' }}>
          {presets.map(([label, s, e]) => (
            <Link key={label} href={`/finance/profit?start=${s}&end=${e}`} className="tab" data-active={s === start && e === end}>{label}</Link>
          ))}
          <form className="row" action="/finance/profit" style={{ alignItems: 'end' }}>
            <div className="field"><label htmlFor="start">From</label><input id="start" name="start" type="date" className="input" defaultValue={start} max={now} /></div>
            <div className="field"><label htmlFor="end">To</label><input id="end" name="end" type="date" className="input" defaultValue={end} max={now} /></div>
            <button className="button" data-variant="secondary" type="submit">Show</button>
          </form>
        </div>

        <div className="stat-band">
          <div className="stat"><div className="stat-label">Made (sales)</div><div className="stat-value">{tzs(data.revenue)}</div>
            {hasMarketplace && <div className="meta">incl. marketplace {tzs(data.marketplace_sales)}</div>}</div>
          <div className="stat"><div className="stat-label">Stock cost</div><div className="stat-value">{tzs(String(Number(data.stock_cost) + Number(data.marketplace_cost)))}</div>
            <div className="meta">gross profit <Signed value={data.gross_profit} /></div></div>
          <div className="stat"><div className="stat-label">Expenses</div><div className="stat-value">{tzs(data.expenses)}</div></div>
          <div className="stat"><div className="stat-label">Net profit</div><div className="stat-value"><Signed value={data.net_profit} /></div>
            {Number(data.revenue) > 0 && <div className="meta">{Math.round((Number(data.net_profit) / Number(data.revenue)) * 100)}% of sales</div>}</div>
        </div>

        <div className="grid-2" style={{ alignItems: 'start', gridTemplateColumns: 'minmax(0, 2fr) minmax(0, 1fr)' }}>
          <Card title="Day by day">
            {active.length === 0 ? <Empty>No sales or expenses in this period.</Empty> : (
              <div className="table-wrap">
                <table>
                  <thead><tr><th>Day</th><th className="numeric">Sales</th><th className="numeric">Stock cost</th><th className="numeric">Expenses</th><th className="numeric">Net profit</th></tr></thead>
                  <tbody>
                    {active.map((d) => (
                      <tr key={d.date}>
                        <td className="small"><Link href={`/finance/expenses?start=${d.date}&end=${d.date}`}>{day(d.date)}</Link></td>
                        <td className="numeric">{tzs(d.revenue)}</td>
                        <td className="numeric">{tzs(String(Number(d.stock_cost) + Number(d.marketplace_cost)))}</td>
                        <td className="numeric">{tzs(d.expenses)}</td>
                        <td className="numeric"><Signed value={d.net_profit} /></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>
          <Card title="Where the money went">
            {data.expenses_by_category.length === 0 ? <Empty>No expenses recorded in this period.</Empty> : (
              <div className="table-wrap">
                <table>
                  <tbody>
                    {data.expenses_by_category.map((row) => (
                      <tr key={row.category}>
                        <td><Link href={`/finance/expenses?start=${data.start}&end=${data.end}&category=${row.category}`}>{expenseLabel(row.category)}</Link></td>
                        <td className="numeric money">{tzs(row.amount)}</td>
                        <td className="numeric meta">{Math.round((Number(row.amount) / Number(data.expenses)) * 100)}%</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>
        </div>
      </div>
    </>
  );
}
