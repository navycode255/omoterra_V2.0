import Link from 'next/link';
import type { CSSProperties } from 'react';
import { Icons } from '@/components/icons';
import { Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { day, methodLabel, today, type FinanceSummary, type Party } from '@/lib/finance';
import { phone, tzs } from '@/lib/format';
import styles from '@/components/finance/finance.module.css';
import { BusinessPosition } from '@/components/dashboard/business-position';
import { InfoTip } from '@/components/info-tip';
import { Sparkline } from '@/components/finance/sparkline';

export const metadata = { title: 'Finance · Omoterra Operations' };

function PartyTable({ parties, empty }: { parties: Party[]; empty: string }) {
  if (parties.length === 0) return <Empty>{empty}</Empty>;
  return (
    <>
    <div className={`${styles.tableWrap} ${styles.desktopParties}`}>
      <table data-phone-native>
        <thead><tr><th>Who</th><th>Phone</th><th>Balance</th><th>Overdue</th><th>Since</th></tr></thead>
        <tbody>
          {parties.slice(0, 5).map((p) => {
            const q = encodeURIComponent(p.party_phone || p.party_name);
            return (
              <tr key={`${p.party_kind}:${p.buyer_profile_id ?? p.supplier_id ?? p.party_name}`}>
                <td><Link href={`/finance/debts?q=${q}`} className="strong">{p.party_name}</Link>{p.sources.includes('marketplace') && <small>App orders</small>}</td>
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
    <div className={styles.mobileParties}>
      <div className={styles.partyHead}><span>#</span><span>Who</span><span>Balance</span><span /></div>
      {parties.slice(0, 5).map((p, index) => <details className={styles.partyRow} key={`${p.party_kind}:${p.buyer_profile_id ?? p.supplier_id ?? p.party_name}`}>
        <summary><span>{index + 1}</span><span>{p.party_name}</span><Amount value={tzs(p.balance)}/><Icons.chevron size={16}/></summary>
        <div className={styles.partyDetails}>
          <dl><div><dt>Phone</dt><dd>{p.party_phone ? phone(p.party_phone) : '—'}</dd></div><div><dt>Overdue</dt><dd>{tzs(p.overdue)}</dd></div><div><dt>Since</dt><dd>{day(p.oldest)}</dd></div></dl>
          <Link href={`/finance/debts?q=${encodeURIComponent(p.party_phone || p.party_name)}`}>View debts <Icons.chevron size={16}/></Link>
        </div>
      </details>)}
    </div>
    </>
  );
}

function Amount({ value, cash = false }: { value: string; cash?: boolean }) {
  const sizing = { '--amount-length': value.length } as CSSProperties;
  return cash ? <small style={sizing}>{value}</small> : <strong style={sizing}>{value}</strong>;
}

const PERIODS = [['month', 'This month'], ['today', 'Today'], ['last_month', 'Last month']] as const;
const signed = (value: string | number) => `${Number(value) < 0 ? '-' : ''}${tzs(String(Math.abs(Number(value))))}`;

export default async function Finance({ searchParams }: { searchParams: Promise<{ period?: string; start?: string; end?: string }> }) {
  const params = await searchParams;
  const now = today();
  const monthStart = `${now.slice(0, 8)}01`;
  const lastMonthEnd = new Date(`${monthStart}T00:00:00Z`);
  lastMonthEnd.setUTCDate(0);
  const previousEnd = lastMonthEnd.toISOString().slice(0, 10);
  const period = params.start || params.end ? 'custom' : PERIODS.some(([key]) => key === params.period) ? params.period! : 'month';
  const start = period === 'custom' ? params.start || monthStart : period === 'today' ? now : period === 'last_month' ? `${previousEnd.slice(0, 8)}01` : monthStart;
  const end = period === 'custom' ? params.end || now : period === 'last_month' ? previousEnd : now;
  const range = new URLSearchParams({ start, end }).toString();
  const periodLabel = period === 'custom' ? 'Custom period' : PERIODS.find(([key]) => key === period)![1];
  let data: FinanceSummary;
  try {
    data = await get<FinanceSummary>(`/ops/finance/summary?${range}`);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Finance" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Finance could not be loaded.'}</Notice></div></>;
  }

  return (
    <div className={styles.financePage} data-finance-overview>
      <div className={styles.financeHeader}>
        <div className={styles.titleRow}>
          <h1>Finance</h1>
          <details className={styles.period}>
            <summary><Icons.calendar size={17} />{periodLabel}<Icons.chevronDown size={15} /></summary>
            <div>{PERIODS.map(([key, label]) => <Link key={key} href={key === 'month' ? '/finance' : `/finance?period=${key}`} data-active={key === period}>{label}</Link>)}
              <form action="/finance" className={styles.customPeriod}>
                <strong>Custom period</strong>
                <label>Start date<input type="date" name="start" defaultValue={start} max={now} required /></label>
                <label>End date<input type="date" name="end" defaultValue={end} max={now} required /></label>
                <button type="submit" className="button">Apply period</button>
              </form>
            </div>
          </details>
        </div>
        <div className={styles.headerActions}>
          <details className={styles.financeTools}><summary><Icons.more size={18}/>Manage</summary><div>
          <Link href="/finance/expenses" className="button" data-variant="secondary"><Icons.plus size={20}/><span>Expense</span></Link>
          <Link href="/finance/debts" className="button" data-variant="secondary"><Icons.plus size={20}/><span>Other debt</span></Link>
          <Link href="/finance/accounts" className="button" data-variant="secondary"><Icons.card size={20}/><span>Accounts</span></Link>
          <Link href="/stock" className="button" data-variant="secondary"><Icons.box size={20}/><span>Stock</span></Link>
          <Link href="/finance/opening-stock" className="button" data-variant="secondary"><Icons.box size={20}/><span>Opening stock</span></Link>
          </div></details>
          <Link href="/sales/new" className="button"><Icons.plus size={20}/><span>New sale</span></Link>
        </div>
      </div>

      <div className={styles.financeContent}>
        <div className={styles.financePeriodNote}><span>{day(start)} – {day(end)}</span><Link href="/sales/orders?status=open" data-commitments-link>Orders not delivered: {tzs(data.commitments.total)}</Link><InfoTip label="About finance figures">Sales, collections and profit follow these dates. Debt balances and recorded cash position are current. Orders not delivered yet ({tzs(data.commitments.total)}: app orders and orders taken for buyers) are not sales or debt. App payouts possibly paid twice: {tzs(data.i_owe.disputed)}; sent but debit not confirmed (not money out yet): {tzs(data.i_owe.payouts_in_flight)}. Unresolved supplier money: {tzs(data.i_owe.unresolved)}.</InfoTip></div>
        <BusinessPosition data={data}/>
        <section className={styles.summaryGrid} aria-label="Finance summary">
          <Link href={`/sales?${range}`} className={styles.summaryCard} aria-label="Sales"><Icons.chart className={styles.summaryIcon} size={28}/><div><span>Sales</span><Amount value={tzs(data.selected.sales)}/></div><Sparkline className={styles.spark} values={data.selected_trends.revenue}/></Link>
          <Link href={`/finance/cash-book?status=in&${range}`} className={styles.summaryCard}><Icons.arrowDown className={styles.summaryIcon} size={28}/><div><span>Money in</span><Amount value={tzs(data.selected.money_in)}/></div></Link>
          <Link href={`/finance/cash-book?status=out&${range}`} className={styles.summaryCard}><Icons.arrowUp className={styles.summaryIcon} size={28}/><div><span>Money out</span><Amount value={tzs(data.selected.money_out)}/></div></Link>
          <Link href={`/finance/cash-book?${range}`} className={`${styles.summaryCard} ${Number(data.selected.net)<0?styles.negativeCard:styles.positiveCard}`}><Icons.wallet className={styles.summaryIcon} size={28}/><div><span>Net movement</span><Amount value={signed(data.selected.net)}/></div></Link>
        </section>

        <div className={styles.twoColumn}>
          <section className={styles.panel}>
            <div className={styles.panelHeader}>
              <h2><Icons.users size={30} />Who owes me</h2>
              <Link href="/finance/debts?status=owed_to_me" className={styles.allLink}>View all <Icons.chevron size={15} /></Link>
            </div>
            <PartyTable parties={data.debtors} empty="Nobody owes you anything recorded here." />
            {data.debtors.length > 5 && <InfoTip label="About debtor list">The five largest of {data.debtors.length}. View all shows every debt and delivered app order.</InfoTip>}
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
            {data.creditors.length > 5 && <InfoTip label="About creditor list">The five largest of {data.creditors.length}. All shows every debt and pending app payout.</InfoTip>}
          </section>
        </div>

        <div className={styles.twoColumn}>
          <section className={styles.panel}>
            <div className={styles.panelHeader}>
              <h2><span className={styles.headingIcon}><Icons.card size={27} /></span>Money by method · all time</h2>
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
                      <td className={Number(data.all_time.net) < 0 ? styles.negative : styles.positive}>{signed(data.all_time.net)}</td>
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
