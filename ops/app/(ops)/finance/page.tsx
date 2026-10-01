import Link from 'next/link';
import { Icons } from '@/components/icons';
import { Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { day, methodLabel, type FinanceSummary, type Party } from '@/lib/finance';
import { phone, tzs } from '@/lib/format';
import styles from '@/components/finance/finance.module.css';
import { Sparkline } from '@/components/finance/sparkline';

export const metadata = { title: 'Finance · Omoterra Operations' };

function PartyTable({ parties, empty }: { parties: Party[]; empty: string }) {
  if (parties.length === 0) return <Empty>{empty}</Empty>;
  return (
    <div className={styles.tableWrap}>
      <table data-phone-show="1 3">
        <thead><tr><th>Who</th><th>Phone</th><th>Balance</th><th>Overdue</th><th>Since</th></tr></thead>
        <tbody>
          {parties.slice(0, 5).map((p) => {
            const q = encodeURIComponent(p.party_phone || p.party_name);
            return (
              <tr key={`${p.party_kind}:${p.buyer_profile_id ?? p.supplier_id ?? p.party_name}`}>
                <td><Link href={`/finance/debts?q=${q}`} className="strong">{p.party_name}</Link></td>
                <td>{p.party_phone ? phone(p.party_phone) : '—'}</td>
                <td className="money strong">{tzs(p.balance)}</td>
                <td>{Number(p.overdue) > 0 ? <Status tone="error">{tzs(p.overdue)}</Status> : '–'}</td>
                <td>{day(p.oldest)}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

const PERIODS = [['month', 'This month'], ['today', 'Today']] as const;
const signed = (value: string | number) => `${Number(value) < 0 ? '-' : ''}${tzs(String(Math.abs(Number(value))))}`;

export default async function Finance({ searchParams }: { searchParams: Promise<{ period?: string }> }) {
  // Sales and profit cards show this month or today; balances are always now.
  const period = (await searchParams).period === 'today' ? 'today' : 'month';
  let data: FinanceSummary;
  try {
    data = await get<FinanceSummary>('/ops/finance/summary');
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Finance" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Finance could not be loaded.'}</Notice></div></>;
  }

  return (
    <div className={styles.financePage}>
      <div className={styles.financeHeader}>
        <div className={styles.titleRow}>
          <h1>Finance</h1>
          <details className={styles.period}>
            <summary><Icons.calendar size={17} />{PERIODS.find(([key]) => key === period)![1]}<Icons.chevronDown size={15} /></summary>
            <div>{PERIODS.map(([key, label]) => <Link key={key} href={key === 'month' ? '/finance' : `/finance?period=${key}`} data-active={key === period}>{label}</Link>)}</div>
          </details>
        </div>
        <div className={styles.headerActions}>
          <Link href="/finance/expenses" className="button" data-variant="secondary">+ Expense</Link>
          <Link href="/finance/debts" className="button" data-variant="secondary">+ Other debt</Link>
          <Link href="/sales/new" className="button">+ New sale</Link>
        </div>
      </div>

      <div className={styles.financeContent}>
        <section className={styles.summaryGrid} aria-label="Finance summary">
          <Link href="/finance/debts?status=owed_to_me" className={styles.summaryCard} aria-label="Money owed to me">
            <Icons.users className={styles.summaryIcon} size={34} />
            <div><span>Owed to me</span><strong>{tzs(data.owed_to_me.total)}</strong></div>
            <Sparkline className={styles.spark} values={data.trends.owed_to_me} />
          </Link>
          <Link href="/finance/debts?status=i_owe" className={styles.summaryCard} aria-label="Money I owe">
            <Icons.card className={`${styles.summaryIcon} ${styles.oweIcon}`} size={34} />
            <div><span>I owe</span><strong>{tzs(data.i_owe.total)}</strong></div>
            <Sparkline className={styles.spark} values={data.trends.i_owe} tone="red" />
          </Link>
          <Link href="/sales" className={styles.summaryCard} aria-label="Sales">
            <Icons.chart className={styles.summaryIcon} size={34} />
            <div><span>{period === 'today' ? 'Sales today' : 'Sales this month'}</span><strong>{tzs(period === 'today' ? data.today.sales : data.month.sales)}</strong>
              <small>Cash received: {tzs(period === 'today' ? data.today.money_in : data.month.money_in)}</small></div>
            <Sparkline className={styles.spark} values={data.trends.revenue} />
          </Link>
          <Link href="/finance/profit" className={styles.summaryCard} aria-label="Profit">
            <Icons.trend className={styles.summaryIcon} size={34} />
            <div><span>{period === 'today' ? 'Profit today' : 'Profit this month'}</span><strong>{signed(period === 'today' ? data.profit_today.net_profit : data.profit_month.net_profit)}</strong></div>
            <Sparkline className={styles.spark} values={data.trends.net_profit} tone={Number(data.profit_month.net_profit) < 0 ? 'red' : 'green'} />
          </Link>
        </section>

        <div className={styles.twoColumn}>
          <section className={styles.panel}>
            <div className={styles.panelHeader}>
              <h2><Icons.users size={30} />Who owes me</h2>
              <Link href="/finance/debts?status=owed_to_me" className={styles.allLink}>View all <Icons.chevron size={15} /></Link>
            </div>
            <PartyTable parties={data.debtors} empty="Nobody owes you anything recorded here." />
          </section>
          <section className={styles.panel}>
            <div className={styles.panelHeader}>
              <h2><span className={styles.oweIcon}><Icons.users size={30} /></span>Who I owe</h2>
              <div className={styles.panelActions}>
                <Link href="/finance/supplier-payments" className={styles.payLink}>Record payment</Link>
                <Link href="/finance/debts?status=i_owe" className={styles.allLink}>All <Icons.chevron size={15} /></Link>
              </div>
            </div>
            <PartyTable parties={data.creditors} empty="You owe nothing recorded here." />
          </section>
        </div>

        <div className={styles.twoColumn}>
          <section className={styles.panel}>
            <div className={styles.panelHeader}>
              <h2><span className={styles.headingIcon}><Icons.card size={27} /></span>Money by method</h2>
            </div>
            {data.by_method.length === 0 ? <Empty>No money recorded yet.</Empty> : (
              <div className={styles.tableWrap}>
                <table data-phone-show="1 4">
                  <thead><tr><th>Method</th><th>In</th><th>Out</th><th>Net</th></tr></thead>
                  <tbody>
                    {data.by_method.map((row) => (
                      <tr key={row.method}>
                        <td>{methodLabel(row.method)}</td><td>{tzs(row.in)}</td><td>{tzs(row.out)}</td><td className={Number(row.net) < 0 ? styles.negative : styles.positive}>{signed(row.net)}</td>
                      </tr>
                    ))}
                    <tr className={styles.totalRow}>
                      <td>Total</td><td>{tzs(data.all_time.money_in)}</td><td>{tzs(data.all_time.money_out)}</td>
                      <td className={Number(data.all_time.money_in) - Number(data.all_time.money_out) < 0 ? styles.negative : styles.positive}>{signed(Number(data.all_time.money_in) - Number(data.all_time.money_out))}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            )}
          </section>
          <section className={styles.panel}>
            <div className={styles.panelHeader}>
              <h2><span className={styles.headingIcon}><Icons.clock size={27} /></span>Latest payments</h2>
              <Link href="/finance/cash-book" className={styles.allLink}>All <Icons.chevron size={15} /></Link>
            </div>
            {data.recent_payments.length === 0 ? <Empty>No payments recorded yet.</Empty> : (
              <div className={styles.tableWrap}>
                <table data-phone-show="2 3">
                  <thead><tr><th>Date</th><th>Who</th><th>Amount</th></tr></thead>
                  <tbody>
                    {data.recent_payments.slice(0, 7).map((p) => (
                      <tr key={p.id} style={p.reversed ? { opacity: 0.6 } : undefined}>
                        <td>{day(p.paid_on)}</td>
                        <td><Link href={`/finance/debts/${p.debt_id}`}>{p.party_name}</Link><small>{p.direction === 'receivable' ? 'Received' : 'Paid out'} · {methodLabel(p.method)}{p.reversed ? ' · reversed' : ''}</small></td>
                        <td className={p.direction === 'receivable' ? styles.positive : styles.negative}>{p.direction === 'receivable' ? '+' : '-'}{tzs(p.amount)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </div>
      </div>
    </div>
  );
}
