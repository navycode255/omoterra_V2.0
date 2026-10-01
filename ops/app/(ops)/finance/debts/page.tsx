import Link from 'next/link';
import { Notice, PageHeader } from '@/components/ui';
import { Icons } from '@/components/icons';
import { DebtWorkspace, RowsPerPage } from '@/components/finance/debt-workspace';
import styles from '@/components/finance/debts.module.css';
import { ApiError, get } from '@/lib/api';
import { day, today, type Debt, type Parties, type FinanceSummary } from '@/lib/finance';
import { phone, tzs } from '@/lib/format';
import { listPath, param, pageCount, type ListParams, type Page } from '@/lib/paging';

export const metadata = { title: 'Debts · Omoterra Operations' };
const tabs = [['', 'All'], ['owed_to_me', 'Owed to me'], ['i_owe', 'I owe'], ['settled', 'Settled'], ['cancelled', 'Cancelled']];
const count = (n: number | undefined) => `${n ?? 0} ${n === 1 ? 'debt' : 'debts'}`;

// Paying a debt happens where its money is tracked: a registered supplier's
// invoices on Supplier payments, everything else on the debt's own page.
function payHref(debt: Debt) {
  return debt.direction === 'payable' && debt.supplier_id ? `/finance/supplier-payments?debt=${debt.id}` : `/finance/debts/${debt.id}#pay`;
}

export default async function Debts({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let data: Page<Debt>; let parties: Parties; let summary: FinanceSummary;
  try {
    [data, parties, summary] = await Promise.all([
      get<Page<Debt>>(listPath('/ops/ledger/debts', params, ['direction'])),
      get<Parties>('/ops/finance/parties'),
      get<FinanceSummary>('/ops/finance/summary'),
    ]);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Debts" /></div><div className="workspace"><Notice tone="error">{error instanceof ApiError ? error.message : 'Debts could not be loaded.'}</Notice></div></>;
  }
  const status = param(params, 'status');
  const pages = pageCount(data);
  const current = Math.min(data.page, pages);
  const first = data.total ? (current - 1) * data.page_size + 1 : 0;
  const last = Math.min(data.total, (current - 1) * data.page_size + data.items.length);
  function href(change: Record<string, string>) {
    const query = new URLSearchParams();
    for (const key of ['q', 'status', 'page_size', 'direction']) { const value = param(params, key); if (value) query.set(key, value); }
    for (const [key, value] of Object.entries(change)) { if (value) query.set(key, value); else query.delete(key); }
    return `/finance/debts${query.size ? `?${query}` : ''}`;
  }
  const numbers = [...new Set([1, current - 1, current, current + 1, pages])].filter((n) => n >= 1 && n <= pages).sort((a, b) => a - b);
  const overdue = Number(summary.owed_to_me.overdue) + Number(summary.i_owe.overdue);

  return <DebtWorkspace parties={parties} now={today()}>
    <section className={styles.stats} aria-label="Debt summary">
      <Link href={href({ status: 'owed_to_me', page: '' })} className={styles.stat} data-tone="in">
        <span className={styles.statIcon}><Icons.trend size={26} /></span>
        <div><span>Owed to me</span><strong>{tzs(summary.owed_to_me.ledger)}</strong><small>{count(data.counts?.owed_to_me)}</small></div>
      </Link>
      <Link href={href({ status: 'i_owe', page: '' })} className={styles.stat} data-tone="out">
        <span className={styles.statIcon}><Icons.trend size={26} /></span>
        <div><span>I owe</span><strong>{tzs(summary.i_owe.ledger)}</strong><small>{count(data.counts?.i_owe)}</small></div>
      </Link>
      <Link href={href({ status: 'overdue', page: '' })} className={styles.stat} data-tone="late">
        <span className={styles.statIcon}><Icons.clock size={26} /></span>
        <div><span>Overdue</span><strong>{tzs(String(overdue))}</strong><small>{count(data.counts?.overdue)}</small></div>
      </Link>
    </section>

    <nav className={styles.tabs} aria-label="Debt status">
      {tabs.map(([key, label]) => <Link key={key} href={href({ status: key, page: '' })} data-active={status === key} aria-current={status === key ? 'page' : undefined}>
        {label}<span>{data.counts?.[key || 'all'] ?? ''}</span>
      </Link>)}
    </nav>

    <form className={styles.toolbar} action="/finance/debts" role="search">
      {status && <input type="hidden" name="status" value={status} />}
      <label className={styles.search}><Icons.search size={19} /><input name="q" type="search" defaultValue={param(params, 'q')} placeholder="Search name, phone or description…" aria-label="Search debts" /></label>
      <details className={styles.filters}>
        <summary><svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path d="M4 5h16l-6 7.5V19l-4 1v-7.5z" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" /></svg>Filter<Icons.chevronDown size={16} /></summary>
        <div>
          <label>Direction<select name="direction" defaultValue={param(params, 'direction')}><option value="">All directions</option><option value="receivable">They owe me</option><option value="payable">I owe them</option></select></label>
          <button type="submit">Apply</button>
          <Link href="/finance/debts">Reset</Link>
        </div>
      </details>
    </form>

    <div className={styles.tableWrap}>
      <table className={styles.table}>
        <thead><tr><th>Who</th><th>What</th><th>Original amount</th><th>Balance</th><th>Status</th><th>Action</th><th aria-label="More" /></tr></thead>
        <tbody>{data.items.map((debt) => {
          const open = debt.status === 'open';
          const tone = debt.status === 'settled' ? 'settled' : debt.status === 'cancelled' ? 'cancelled' : debt.overdue ? 'overdue' : 'open';
          return <tr key={debt.id}>
            <td data-label="Who"><div><Link className={styles.name} href={`/finance/debts/${debt.id}`}>{debt.party_name}</Link><small>{debt.party_phone ? phone(debt.party_phone) : '—'}</small></div></td>
            <td data-label="What"><div>{debt.description}<small>{day(debt.incurred_on)}{debt.due_on ? ` · Due ${day(debt.due_on)}` : ''}</small></div></td>
            <td data-label="Original amount" className={styles.money}>{tzs(debt.amount)}</td>
            <td data-label="Balance" className={styles.balance}>{tzs(debt.balance)}</td>
            <td data-label="Status"><span className={styles.status} data-tone={tone}>{tone[0].toUpperCase() + tone.slice(1)}</span></td>
            <td data-label="Action"><Link className={styles.action} href={open ? payHref(debt) : `/finance/debts/${debt.id}`}>{open ? 'Record payment' : 'View'}</Link></td>
            <td className={styles.more}>
              <details className={styles.menu}>
                <summary aria-label={`More for ${debt.party_name}`}><Icons.more size={18} /></summary>
                <div>
                  <Link href={`/finance/debts/${debt.id}`}>View details</Link>
                  {open && <Link href={payHref(debt)}>Record payment</Link>}
                  {debt.sale_id && <Link href={`/sales/${debt.sale_id}`}>Open sale</Link>}
                </div>
              </details>
            </td>
          </tr>;
        })}</tbody>
      </table>
      {!data.items.length && <div className={styles.empty}><Icons.file size={38} /><h2>No debts in this view.</h2><p>Try another tab or search.</p></div>}
    </div>

    <footer className={styles.footer}>
      <span className={styles.showing}>Showing {first} – {last} of {data.total}</span>
      {pages > 1 && <nav className={styles.pages} aria-label="Debt pages">
        {current > 1 ? <Link href={href({ page: String(current - 1) })} className={styles.step}>‹ Previous</Link> : <span className={styles.step} aria-disabled="true">‹ Previous</span>}
        {numbers.map((n, index) => <span key={n} className={styles.pageGroup}>
          {index > 0 && n - numbers[index - 1] > 1 && <span className={styles.ellipsis}>…</span>}
          <Link href={href({ page: String(n) })} data-active={n === current} aria-current={n === current ? 'page' : undefined}>{n}</Link>
        </span>)}
        {current < pages ? <Link href={href({ page: String(current + 1) })} className={styles.step}>Next ›</Link> : <span className={styles.step} aria-disabled="true">Next ›</span>}
      </nav>}
      <RowsPerPage value={data.page_size} />
    </footer>
  </DebtWorkspace>;
}
