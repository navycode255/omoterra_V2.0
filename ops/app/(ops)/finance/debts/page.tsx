import Link from 'next/link';
import { Notice, PageHeader } from '@/components/ui';
import { Icons } from '@/components/icons';
import { FilterMenu, SearchBox } from '@/components/list-toolbar';
import { DebtWorkspace } from '@/components/finance/debt-workspace';
import { ListFooter } from '@/components/finance/list-footer';
import { SourceRows } from '@/components/finance/source-rows';
import styles from '@/components/finance/finance-list.module.css';
import { ApiError, get } from '@/lib/api';
import { day, today, type Debt, type Parties, type FinanceSummary, type ReportRows } from '@/lib/finance';
import { phone, tzs } from '@/lib/format';
import { listPath, param, type ListParams, type Page } from '@/lib/paging';

export const metadata = { title: 'Debts · Omoterra Operations' };
const tabs = [['', 'All'], ['owed_to_me', 'Owed to me'], ['i_owe', 'I owe'], ['settled', 'Settled'], ['cancelled', 'Cancelled']];
const count = (n: number | undefined) => `${n ?? 0} ${n === 1 ? 'debt' : 'debts'}`;
// The app-order part of a balance, listed under the ledger debts so the two
// lists add up to the card (backend reporting.receivables / payables).
const APP_ROWS: Record<string, { metric: string; title: string; note: string; empty: string }> = {
  owed_to_me: { metric: 'receivables', title: 'App orders delivered, not fully paid',
    note: 'Part of Owed to me. Orders not delivered yet are commitments, not debts.', empty: 'No delivered app order is waiting for payment.' },
  i_owe: { metric: 'payables', title: 'App order payouts pending', note: 'Part of I owe. Paid on Settlements.',
    empty: 'No app order payout is pending.' },
};

// Paying a debt happens where its money is tracked: a registered supplier's
// invoices on Supplier payments, everything else on the debt's own page.
function payHref(debt: Debt) {
  return debt.direction === 'payable' && debt.supplier_id ? `/finance/supplier-payments?debt=${debt.id}` : `/finance/debts/${debt.id}#pay`;
}

export default async function Debts({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  const app = APP_ROWS[param(params, 'status')];
  let data: Page<Debt>; let parties: Parties; let summary: FinanceSummary; let appRows: ReportRows | null;
  try {
    const appQuery = app && new URLSearchParams({ metric: app.metric, source: 'marketplace', q: param(params, 'q'), page: param(params, 'app_page') || '1' });
    [data, parties, summary, appRows] = await Promise.all([
      get<Page<Debt>>(listPath('/ops/ledger/debts', params, ['direction'])),
      get<Parties>('/ops/finance/parties'),
      get<FinanceSummary>('/ops/finance/summary'),
      appQuery ? get<ReportRows>(`/ops/finance/rows?${appQuery}`) : Promise.resolve(null),
    ]);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Debts" /></div><div className="workspace"><Notice tone="error">{error instanceof ApiError ? error.message : 'Debts could not be loaded.'}</Notice></div></>;
  }
  const status = param(params, 'status');
  function href(change: Record<string, string>) {
    const query = new URLSearchParams();
    for (const key of ['q', 'status', 'page_size', 'direction', 'page', 'app_page']) { const value = param(params, key); if (value) query.set(key, value); }
    for (const [key, value] of Object.entries(change)) { if (value) query.set(key, value); else query.delete(key); }
    return `/finance/debts${query.size ? `?${query}` : ''}`;
  }
  const { owed_to_me: owed, i_owe: owe, commitments } = summary;
  const appPart = (value: string, label: string) => Number(value) > 0 ? ` · ${label} ${tzs(value)}` : '';

  return <DebtWorkspace parties={parties} now={today()}>
    {/* Balances now, from the reporting layer: ledger debts plus app orders.
        Overdue is per direction; app orders have no due date. */}
    <section className={styles.stats} data-count="4" aria-label="Debt summary">
      <Link href={href({ status: 'owed_to_me', direction: '', page: '', app_page: '' })} className={styles.stat} data-tone="in">
        <span className={styles.statIcon}><Icons.trend size={26} /></span>
        <div><span>Owed to me</span><strong>{tzs(owed.total)}</strong>
          <small>{count(owed.count)}{appPart(owed.marketplace, 'app orders')}</small>
          {Number(commitments.total) > 0 && <small>Not delivered yet (not owed): {tzs(commitments.total)}</small>}</div>
      </Link>
      <Link href={href({ status: 'i_owe', direction: '', page: '', app_page: '' })} className={styles.stat} data-tone="out">
        <span className={styles.statIcon}><Icons.trend size={26} /></span>
        <div><span>I owe</span><strong>{tzs(owe.total)}</strong>
          <small>{count(owe.count)}{appPart(owe.marketplace, 'app payouts')}</small>
          {Number(owe.disputed) > 0 && <small>Payouts disputed: {tzs(owe.disputed)}</small>}
          {Number(owe.credit) > 0 && <small>Suppliers hold {tzs(owe.credit)} credit</small>}</div>
      </Link>
      <Link href={href({ status: 'overdue', direction: 'receivable', page: '', app_page: '' })} className={styles.stat} data-tone="late">
        <span className={styles.statIcon}><Icons.clock size={26} /></span>
        <div><span>Overdue to collect</span><strong>{tzs(owed.overdue)}</strong><small>{count(owed.overdue_count)}</small></div>
      </Link>
      <Link href={href({ status: 'overdue', direction: 'payable', page: '', app_page: '' })} className={styles.stat} data-tone="late">
        <span className={styles.statIcon}><Icons.clock size={26} /></span>
        <div><span>Overdue to pay</span><strong>{tzs(owe.overdue)}</strong><small>{count(owe.overdue_count)}</small></div>
      </Link>
    </section>

    <nav className={styles.tabs} aria-label="Debt status">
      {tabs.map(([key, label]) => <Link key={key} href={href({ status: key, page: '', app_page: '' })} data-active={status === key} aria-current={status === key ? 'page' : undefined}>
        {label}<span>{data.counts?.[key || 'all'] ?? ''}</span>
      </Link>)}
    </nav>

    <div className={styles.toolbar} role="search">
      <SearchBox placeholder="Search name, phone or description…" />
      <FilterMenu label="Filter">
        <label>Direction<select name="direction" defaultValue={param(params, 'direction')}><option value="">All directions</option><option value="receivable">They owe me</option><option value="payable">I owe them</option></select></label>
        <Link className={styles.filterReset} href="/finance/debts">Reset filters</Link>
      </FilterMenu>
    </div>

    <div className={styles.tableWrap}>
      <table className={styles.table} data-phone-show="1 4">
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

    <ListFooter data={data} label="Debt" href={(page) => href({ page: String(page) })} />

    {app && appRows && <SourceRows title={app.title} note={app.note} data={appRows} empty={app.empty}
      href={(page) => href({ app_page: String(page) })} amountLabel="Balance" />}
  </DebtWorkspace>;
}
