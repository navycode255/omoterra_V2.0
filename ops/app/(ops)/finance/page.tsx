import Link from 'next/link';
import { Icons } from '@/components/icons';
import { Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { day, methodLabel, type FinanceSummary, type Party } from '@/lib/finance';
import { phone, tzs } from '@/lib/format';
import styles from '@/components/finance/finance.module.css';

export const metadata = { title: 'Finance · Omoterra Operations' };

function ArrowLink({ href, label = 'View details' }: { href: string; label?: string }) {
  return <Link href={href} className={styles.roundArrow} aria-label={label}><Icons.chevron size={17} /></Link>;
}

function PartyTable({ parties, empty }: { parties: Party[]; empty: string }) {
  if (parties.length === 0) return <Empty>{empty}</Empty>;
  return (
    <div className={styles.tableWrap}>
      <table>
        <thead><tr><th>Who</th><th>Phone</th><th>Balance</th><th>Overdue</th><th>Since</th></tr></thead>
        <tbody>
          {parties.map((p) => {
            const q = encodeURIComponent(p.party_phone || p.party_name);
            return (
              <tr key={`${p.party_kind}:${p.buyer_profile_id ?? p.supplier_id ?? p.party_name}`}>
                <td><Link href={`/finance/debts?q=${q}`} className="strong">{p.party_name}</Link></td>
                <td>{p.party_phone ? phone(p.party_phone) : '—'}</td>
                <td className="money">{tzs(p.balance)}</td>
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

export default async function Finance() {
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
        <PageHeader title="Finance" />
        <div className={styles.headerActions}>
          <Link href="/finance/expenses" className="button" data-variant="secondary">+ Expense</Link>
          <Link href="/finance/debts" className="button" data-variant="secondary">+ Other debt</Link>
          <Link href="/sales/new" className="button">+ New sale</Link>
        </div>
      </div>

      <div className={styles.financeContent}>
        <section className={styles.summaryGrid} aria-label="Finance summary">
          <article className={styles.summaryCard}>
            <Icons.users className={styles.summaryIcon} size={38} />
            <div><span>Owed to me</span><strong>{tzs(data.owed_to_me.total)}</strong></div>
            <ArrowLink href="/finance/debts?status=owed_to_me" label="View money owed to me" />
          </article>
          <article className={styles.summaryCard}>
            <Icons.card className={`${styles.summaryIcon} ${styles.oweIcon}`} size={38} />
            <div><span>I owe</span><strong>{tzs(data.i_owe.total)}</strong></div>
            <ArrowLink href="/finance/debts?status=i_owe" label="View money I owe" />
          </article>
          <article className={styles.summaryCard}>
            <Icons.chart className={styles.summaryIcon} size={38} />
            <div><span>Sales today</span><strong>{tzs(data.today.sales)}</strong><small>Cash in hand: {tzs(data.today.money_in)}</small></div>
            <ArrowLink href="/sales" label="View today's sales" />
          </article>
          <article className={styles.summaryCard}>
            <Icons.trend className={styles.summaryIcon} size={38} />
            <div><span>Profit this month</span><strong>{tzs(data.profit_month.net_profit)}</strong></div>
            <ArrowLink href="/finance/profit" label="View this month's profit" />
          </article>
        </section>

        <div className={styles.twoColumn}>
          <section className={styles.panel}>
            <div className={styles.panelHeader}>
              <h2><Icons.users size={30} />Who owes me</h2>
              <Link href="/finance/debts?status=owed_to_me" className={styles.allLink}>All <Icons.chevron size={15} /></Link>
            </div>
            <PartyTable parties={data.debtors} empty="Nobody owes you anything recorded here." />
          </section>
          <section className={styles.panel}>
            <div className={styles.panelHeader}>
              <h2><Icons.users size={30} />Who I owe</h2>
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
                <table>
                  <thead><tr><th>Method</th><th>In</th><th>Out</th><th>Net</th></tr></thead>
                  <tbody>
                    {data.by_method.map((row) => (
                      <tr key={row.method}>
                        <td>{methodLabel(row.method)}</td><td>{tzs(row.in)}</td><td>{tzs(row.out)}</td><td className={styles.positive}>{tzs(row.net)}</td>
                      </tr>
                    ))}
                    <tr className={styles.totalRow}>
                      <td>Total</td><td>{tzs(data.all_time.money_in)}</td><td>{tzs(data.all_time.money_out)}</td>
                      <td className={styles.positive}>{tzs(String(Number(data.all_time.money_in) - Number(data.all_time.money_out)))}</td>
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
                <table>
                  <thead><tr><th>Date</th><th>Who</th><th>Amount</th></tr></thead>
                  <tbody>
                    {data.recent_payments.map((p) => (
                      <tr key={p.id} style={p.reversed ? { opacity: 0.6 } : undefined}>
                        <td>{day(p.paid_on)}</td>
                        <td><Link href={`/finance/debts/${p.debt_id}`}>{p.party_name}</Link><small>{p.direction === 'receivable' ? 'Received' : 'Paid out'} · {methodLabel(p.method)}{p.reversed ? ' · reversed' : ''}</small></td>
                        <td className={styles.positive}>{p.direction === 'receivable' ? '+' : '−'}{tzs(p.amount)}</td>
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
