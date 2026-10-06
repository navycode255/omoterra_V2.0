import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { Notice, PageHeader } from '@/components/ui';
import { ListFooter } from '@/components/finance/list-footer';
import list from '@/components/finance/finance-list.module.css';
import styles from '@/components/finance/cost-states.module.css';
import { ApiError, get } from '@/lib/api';
import { explainAccountCheck, recordAccountCheck, recordAccountFee } from '@/lib/account-actions';
import { ACCOUNT_KINDS, type AccountDetail } from '@/lib/accounts';
import { day, today } from '@/lib/finance';
import { tzs } from '@/lib/format';
import { requireSession } from '@/lib/session';

export const metadata = { title: 'Account · Omoterra Operations' };

const KIND = Object.fromEntries(ACCOUNT_KINDS);
const LINE_KINDS: Record<string, string> = {
  payment: 'Payment', transfer: 'Supplier transfer', refund: 'Supplier refund', receipt: 'App order receipt',
  payout: 'App payout', payout_refund: 'App payout refund', fee: 'Fee', account_transfer: 'Between accounts', allocation: 'Payment',
};

/**
 * One money account (build plan M2.3): balance from the verified opening
 * balance, every movement after the cutoff with the balance after it, and
 * its counts or statement balances. A difference is listed to explain; the
 * balance only changes when the missing record itself is entered.
 */
export default async function AccountPage({ params, searchParams }: {
  params: Promise<{ id: string }>; searchParams: Promise<{ page?: string }>;
}) {
  const { id } = await params;
  const { page = '1' } = await searchParams;
  const operator = await requireSession();
  const admin = operator.role === 'admin';
  let account: AccountDetail;
  try {
    account = await get<AccountDetail>(`/ops/accounts/${id}?page=${Number(page) || 1}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    return <><div className="topbar"><PageHeader title="Account" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'This account could not be loaded.'}</Notice></div></>;
  }
  const open = account.checks.filter((ch) => Number(ch.difference) !== 0 && !ch.resolved_at);

  return <div className={`workspace ${styles.page}`}>
    <div className={styles.heading}>
      <div><h1>{account.name}</h1><p><span className={styles.label}>{KIND[account.kind]}</span> {[account.provider, account.number].filter(Boolean).join(' · ')}</p></div>
      <div className={styles.search}>
        <Link href={`/finance/cash-book?account=${account.id}`} className="button" data-variant="secondary">In the cash book</Link>
        <Link href="/finance/accounts" className="button" data-variant="secondary">All accounts</Link>
      </div>
    </div>

    <section className={styles.stats} aria-label="Account summary">
      <article className={styles.stat}><span>Balance today</span><strong>{tzs(account.balance ?? '0')}</strong><small>Recorded, not verified until checked</small></article>
      <article className={styles.stat}><span>Opening balance</span><strong>{tzs(account.opening_balance)}</strong><small>End of {day(account.cutoff_on)} · {account.verified_by}</small></article>
      <article className={styles.stat}><span>Reconciled through</span><strong>{account.reconciled_through ? day(account.reconciled_through) : 'Not yet'}</strong><small>Last matching count or statement</small></article>
      <article className={styles.stat}><span>To explain</span><strong>{open.length + account.pre_cutoff.filter((r) => !r.resolution).length}</strong><small>Differences and pre-cutoff entries</small></article>
    </section>

    <section className={styles.panel}>
      <h2>Movements after the cutoff</h2>
      <div className={list.tableWrap}>
        <table className={list.table}>
          <thead><tr><th data-phone-first>Date</th><th>What</th><th>In</th><th>Out</th><th>Balance after</th><th>Reference</th></tr></thead>
          <tbody>{account.movements.items.map((row) => <tr key={`${row.source_table}:${row.id}`}>
            <td data-label="Date">{day(row.date)}{row.restated ? <small> (restated)</small> : null}</td>
            <td data-label="What">{LINE_KINDS[row.kind] ?? row.kind}<small> · {row.description}{row.party_name ? ` · ${row.party_name}` : ''}</small></td>
            <td data-label="In" className={list.money}>{row.flow === 'in' ? Number(row.amount).toLocaleString('en-US') : ''}</td>
            <td data-label="Out" className={list.money}>{row.flow === 'out' ? Number(row.amount).toLocaleString('en-US') : ''}</td>
            <td data-label="Balance after" className={list.money}><b>{Number(row.balance).toLocaleString('en-US')}</b></td>
            <td data-label="Reference">{row.reference || '—'}</td>
          </tr>)}</tbody>
        </table>
        {!account.movements.items.length && <p className="meta">No movements since the cutoff.</p>}
      </div>
      <ListFooter data={account.movements} label="Movements" perPage={false} href={(n) => `/finance/accounts/${account.id}?page=${n}`} />
    </section>

    <section className={styles.panel}>
      <h2>Counts and statement balances</h2>
      <p className="meta">Enter what the cash box held, or what the statement says, at the end of a day. A difference is listed here to explain; it never changes the balance.</p>
      <ActionForm action={recordAccountCheck} label="Record check" hidden={{ account_id: account.id, idempotency_key: randomUUID() }}>
        <div className="grid-3">
          <div className="field"><label htmlFor="check-kind">Kind</label><select id="check-kind" name="kind" className="input" defaultValue={account.kind === 'cash' ? 'count' : 'statement'}>
            <option value="count">Cash count</option><option value="statement">Statement balance</option></select></div>
          <div className="field"><label htmlFor="checked_on">End of day</label><input id="checked_on" name="checked_on" type="date" className="input" defaultValue={today()} min={account.cutoff_on} max={today()} required /></div>
          <div className="field"><label htmlFor="check-balance">Balance (TZS)</label><input id="check-balance" name="balance" className="input" inputMode="decimal" required /></div>
        </div>
        <div className="field"><label htmlFor="check-evidence">Evidence</label><input id="check-evidence" name="evidence" className="input" required minLength={3} placeholder="e.g. Counted by Asha and Juma; statement page 3" /></div>
      </ActionForm>
      {account.checks.length > 0 && <div className={list.tableWrap}>
        <table className={list.table}>
          <thead><tr><th data-phone-first>Day</th><th>Kind</th><th>Found</th><th>Records</th><th>Difference</th><th>Explanation</th></tr></thead>
          <tbody>{account.checks.map((ch) => <tr key={ch.id}>
            <td data-label="Day">{day(ch.checked_on)}</td>
            <td data-label="Kind">{ch.kind === 'count' ? 'Cash count' : 'Statement'}<small> · {ch.evidence}</small></td>
            <td data-label="Found">{tzs(ch.balance)}</td>
            <td data-label="Records">{tzs(ch.expected)}</td>
            <td data-label="Difference">{Number(ch.difference) === 0 ? 'Matched' : tzs(ch.difference)}</td>
            <td data-label="Explanation">{Number(ch.difference) === 0 ? '—' : ch.resolved_at ? ch.resolution
              : admin ? <details><summary>Explain</summary>
                <ActionForm action={explainAccountCheck} label="Save explanation" hidden={{ check_id: ch.id, idempotency_key: randomUUID() }}>
                  <div className="field"><label htmlFor={`why-${ch.id}`}>What explains it</label><input id={`why-${ch.id}`} name="reason" className="input" required minLength={3} /></div>
                </ActionForm></details> : 'Waiting for an admin'}</td>
          </tr>)}</tbody>
        </table>
      </div>}
    </section>

    <section className={styles.panel}>
      <h2>Record a bank or wallet charge</h2>
      <ActionForm action={recordAccountFee} label="Record charge" hidden={{ account_id: account.id, idempotency_key: randomUUID() }}>
        <div className="grid-3">
          <div className="field"><label htmlFor="fee-amount">Amount (TZS)</label><input id="fee-amount" name="amount" className="input" inputMode="decimal" required /></div>
          <div className="field"><label htmlFor="charged_on">Date</label><input id="charged_on" name="charged_on" type="date" className="input" defaultValue={today()} max={today()} required /></div>
          <div className="field"><label htmlFor="fee-reference">Reference</label><input id="fee-reference" name="reference" className="input" /></div>
        </div>
        <div className="field"><label htmlFor="fee-description">What it was for</label><input id="fee-description" name="description" className="input" required minLength={3} placeholder="e.g. Monthly account fee" /></div>
      </ActionForm>
    </section>

    <p className="meta">Opening balance evidence: {account.opening_evidence}</p>
  </div>;
}
