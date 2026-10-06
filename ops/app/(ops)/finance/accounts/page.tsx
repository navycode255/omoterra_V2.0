import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Notice, PageHeader } from '@/components/ui';
import { ListFooter } from '@/components/finance/list-footer';
import list from '@/components/finance/finance-list.module.css';
import styles from '@/components/finance/cost-states.module.css';
import { ApiError, get } from '@/lib/api';
import { assignMovement, createAccount, resolvePreCutoff, transferBetweenAccounts } from '@/lib/account-actions';
import { ACCOUNT_KINDS, type AccountsPage, type PreCutoffRow, type UnassignedRow } from '@/lib/accounts';
import { day, today } from '@/lib/finance';
import { tzs } from '@/lib/format';
import { param, type ListParams, type Page } from '@/lib/paging';
import { requireSession } from '@/lib/session';

export const metadata = { title: 'Accounts · Omoterra Operations' };

type Unassigned = Page<UnassignedRow> & { summary: { count: number; in: string; out: string } };
const KIND = Object.fromEntries(ACCOUNT_KINDS);
const signed = (flow: 'in' | 'out', amount: string) => `${flow === 'in' ? '+' : '−'}${tzs(amount)}`;

/**
 * Money accounts (build plan M2.3, decision D6): each cash box, bank account
 * and mobile wallet, from the opening balance the finance owner verified at
 * its cutoff. Beside them, money with no account yet (never in a balance) and
 * entries dated before a cutoff that still need explaining.
 */
export default async function AccountsPage({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  const operator = await requireSession();
  const admin = operator.role === 'admin';
  const query = new URLSearchParams({ page: param(params, 'page') || '1', page_size: '10' });
  let data: AccountsPage;
  let unassigned: Unassigned;
  let preCutoff: PreCutoffRow[] = [];
  try {
    [data, unassigned] = await Promise.all([get<AccountsPage>('/ops/accounts'), get<Unassigned>(`/ops/accounts/unassigned?${query}`)]);
    const details = await Promise.all(data.items.filter((a) => a.pre_cutoff_open > 0)
      .map((a) => get<{ pre_cutoff: PreCutoffRow[] }>(`/ops/accounts/${a.id}?page_size=1`)));
    preCutoff = details.flatMap((d) => d.pre_cutoff.filter((row) => !row.resolution));
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Accounts" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Accounts could not be loaded.'}</Notice></div></>;
  }
  const accounts = data.items;
  const href = (page: number) => `/finance/accounts?page=${page}`;

  return <div className={`workspace ${styles.page}`}>
    <div className={styles.heading}>
      <div><h1>Accounts</h1><p>Cash box, bank and mobile wallets: balances from the verified opening balance at each cutoff.</p></div>
      <div className={styles.search}>
        <Link href="/finance/cash-book" className="button" data-variant="secondary">Cash book</Link>
        <Link href="/finance" className="button" data-variant="secondary">Finance</Link>
      </div>
    </div>

    <section className={styles.stats} aria-label="Accounts summary">
      <article className={styles.stat}><span>Recorded balance, all accounts</span><strong>{tzs(data.total)}</strong><small>Today, from opening balances</small></article>
      <article className={styles.stat}><span>Unassigned (historical)</span><strong>{data.unassigned.count}</strong>
        <small>{tzs(data.unassigned.in)} in · {tzs(data.unassigned.out)} out, in no balance</small></article>
      <article className={styles.stat}><span>Differences to explain</span><strong>{data.open_differences}</strong><small>From counts and statements</small></article>
      <article className={styles.stat}><span>Dated before a cutoff</span><strong>{data.pre_cutoff_open}</strong><small>Entered after setup; to explain</small></article>
    </section>

    {accounts.length === 0 && <Notice>No accounts yet. Set up each account with its verified balance at the end of the cutoff day (suggested 31 October 2026). Until then, money is recorded without an account.</Notice>}

    {accounts.length > 0 && <section className={styles.panel}>
      <h2>Accounts</h2>
      <div className={list.tableWrap}>
        <table className={list.table}>
          <thead><tr><th data-phone-first>Account</th><th>Balance today (TZS)</th><th>Opening balance</th><th>Reconciled through</th><th>Last check</th><th>To explain</th></tr></thead>
          <tbody>{accounts.map((a) => <tr key={a.id}>
            <td data-label="Account"><div><Link className={list.name} href={`/finance/accounts/${a.id}`}>{a.name}</Link>
              <small><span className={styles.label}>{KIND[a.kind]}</span> {[a.provider, a.number].filter(Boolean).join(' · ')}</small></div></td>
            <td data-label="Balance today" className={list.money}>{Number(a.balance ?? 0).toLocaleString('en-US')}</td>
            <td data-label="Opening balance">{tzs(a.opening_balance)}<small> end of {day(a.cutoff_on)}</small></td>
            <td data-label="Reconciled through">{a.reconciled_through ? day(a.reconciled_through) : 'Not yet'}</td>
            <td data-label="Last check">{a.last_check ? `${a.last_check.kind === 'count' ? 'Count' : 'Statement'} ${day(a.last_check.checked_on)}${Number(a.last_check.difference) !== 0 ? ` · difference ${tzs(a.last_check.difference)}` : ' · matched'}` : '—'}</td>
            <td data-label="To explain">{a.open_differences + a.pre_cutoff_open || '—'}</td>
          </tr>)}</tbody>
        </table>
      </div>
    </section>}

    {accounts.length > 1 && <section className={styles.panel}>
      <h2>Move money between accounts</h2>
      <p className="meta">Out of one account and into the other: the business total does not change. A charge for it is recorded as a fee on the sending account.</p>
      <ActionForm action={transferBetweenAccounts} label="Record transfer" hidden={{ idempotency_key: randomUUID() }}>
        <div className="grid-3">
          <div className="field"><label htmlFor="from_account_id">From</label><select id="from_account_id" name="from_account_id" className="input" required defaultValue="">
            <option value="">Choose</option>{accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select></div>
          <div className="field"><label htmlFor="to_account_id">To</label><select id="to_account_id" name="to_account_id" className="input" required defaultValue="">
            <option value="">Choose</option>{accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select></div>
          <div className="field"><label htmlFor="transfer_amount">Amount (TZS)</label><input id="transfer_amount" name="amount" className="input" inputMode="decimal" required /></div>
          <div className="field"><label htmlFor="transferred_on">Date</label><input id="transferred_on" name="transferred_on" type="date" className="input" defaultValue={today()} max={today()} required /></div>
          <div className="field"><label htmlFor="transfer_fee">Fee charged (TZS, optional)</label><input id="transfer_fee" name="fee" className="input" inputMode="decimal" /></div>
          <div className="field"><label htmlFor="transfer_reference">Reference</label><input id="transfer_reference" name="reference" className="input" /></div>
        </div>
      </ActionForm>
    </section>}

    {preCutoff.length > 0 && <section className={styles.panel}>
      <h2>Entered after setup, dated before the cutoff</h2>
      <p className="meta">Each is outside the balance until the finance owner says it was already inside the verified opening balance, or restates the opening balance with it.</p>
      <div className={list.tableWrap}>
        <table className={list.table}>
          <thead><tr><th data-phone-first>Date</th><th>Account</th><th>Amount</th><th>What</th>{admin && <th>Explain</th>}</tr></thead>
          <tbody>{preCutoff.map((row) => <tr key={row.assignment_id}>
            <td data-label="Date">{day(row.date)}</td><td data-label="Account">{row.account}</td>
            <td data-label="Amount">{signed(row.flow, row.amount)}</td>
            <td data-label="What">{row.description}{row.party_name ? ` · ${row.party_name}` : ''}</td>
            {admin && <td data-label="Explain"><details><summary>Explain</summary>
              <ActionForm action={resolvePreCutoff} label="Save" hidden={{ assignment_id: row.assignment_id, idempotency_key: randomUUID() }}>
                <div className="field"><label htmlFor={`res-${row.assignment_id}`}>It is</label><select id={`res-${row.assignment_id}`} name="resolution" className="input">
                  <option value="inside_opening">Already inside the opening balance</option><option value="restated">Missing from it: restate the opening balance</option></select></div>
                <div className="field"><label htmlFor={`note-${row.assignment_id}`}>Evidence</label><input id={`note-${row.assignment_id}`} name="note" className="input" required minLength={3} /></div>
              </ActionForm></details></td>}
          </tr>)}</tbody>
        </table>
      </div>
    </section>}

    <section className={styles.panel} id="unassigned">
      <h2>Money with no account</h2>
      <p className="meta">Recorded before accounts existed, or where the account is not known. It counts in no account&apos;s balance until it is assigned with evidence (a statement line, an SMS, a cash book page). The payment method alone is not evidence.</p>
      <div className={list.tableWrap}>
        <table className={list.table}>
          <thead><tr><th data-phone-first>Date</th><th>Amount</th><th>Method</th><th>Reference</th><th>What</th>{admin && accounts.length > 0 && <th>Assign</th>}</tr></thead>
          <tbody>{unassigned.items.map((row) => <tr key={`${row.source_table}:${row.id}`}>
            <td data-label="Date">{day(row.paid_on)}</td>
            <td data-label="Amount">{signed(row.flow, row.amount)}</td>
            <td data-label="Method">{row.method.replaceAll('_', ' ')}</td>
            <td data-label="Reference">{row.reference || '—'}</td>
            <td data-label="What">{row.description}{row.party_name ? ` · ${row.party_name}` : ''}</td>
            {admin && accounts.length > 0 && <td data-label="Assign"><details><summary>Assign</summary>
              <ActionForm action={assignMovement} label="Assign" hidden={{ source_table: row.source_table, source_id: row.id, idempotency_key: randomUUID() }}>
                <div className="field"><label htmlFor={`acc-${row.id}`}>Account</label><select id={`acc-${row.id}`} name="account_id" className="input" required defaultValue="">
                  <option value="">Choose</option>{accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select></div>
                <div className="field"><label htmlFor={`ev-${row.id}`}>Evidence</label><input id={`ev-${row.id}`} name="evidence" className="input" required minLength={3} placeholder="e.g. M-Pesa statement, 14 Oct, QX12…" /></div>
              </ActionForm></details></td>}
          </tr>)}</tbody>
        </table>
        {!unassigned.items.length && <p className="meta">Every recorded movement has its account.</p>}
      </div>
      <ListFooter data={unassigned} label="Unassigned money" perPage={false} href={href} />
    </section>

    {admin ? <section className={styles.panel}>
      <h2>Set up an account</h2>
      <p className="meta">The opening balance is what the account held at the end of the cutoff day, verified from a statement or a count. Money dated on or before that day is inside it.</p>
      <ActionForm action={createAccount} label="Set up account" hidden={{ idempotency_key: randomUUID() }}>
        <div className="grid-3">
          <div className="field"><label htmlFor="acc-name">Name</label><input id="acc-name" name="name" className="input" required minLength={2} placeholder="e.g. Petty cash" /></div>
          <div className="field"><label htmlFor="acc-kind">Kind</label><select id="acc-kind" name="kind" className="input">{ACCOUNT_KINDS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}</select></div>
          <div className="field"><label htmlFor="acc-provider">Bank or provider</label><input id="acc-provider" name="provider" className="input" placeholder="e.g. M-Pesa, Selcom, CRDB" /></div>
          <div className="field"><label htmlFor="acc-number">Account or wallet number</label><input id="acc-number" name="number" className="input" /></div>
          <div className="field"><label htmlFor="acc-cutoff">Cutoff (end of day)</label><input id="acc-cutoff" name="cutoff_on" type="date" className="input" max={today()} required /></div>
          <div className="field"><label htmlFor="acc-opening">Verified balance then (TZS)</label><input id="acc-opening" name="opening_balance" className="input" inputMode="decimal" required /></div>
          <div className="field"><label htmlFor="acc-verified">Verified by</label><input id="acc-verified" name="verified_by" className="input" defaultValue="Maternus Joshua" required /></div>
        </div>
        <div className="field"><label htmlFor="acc-evidence">Evidence for the balance</label><input id="acc-evidence" name="opening_evidence" className="input" required minLength={3} placeholder="e.g. Bank statement 31 Oct; cash counted by two staff" /></div>
      </ActionForm>
    </section> : <Notice>Only an admin sets up accounts and assigns old money to them.</Notice>}
  </div>;
}
