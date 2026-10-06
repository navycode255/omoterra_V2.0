import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { SupplierReceiptMessageFields } from '@/components/finance/supplier-payment-form';
import { PaySupplierPanel } from '@/components/finance/pay-supplier-panel';
import { UnregisteredPaymentButton } from '@/components/finance/unregistered-payment-drawer';
import { ListFooter } from '@/components/finance/list-footer';
import { FilterMenu, SearchBox } from '@/components/list-toolbar';
import { Icons } from '@/components/icons';
import { Notice, PageHeader } from '@/components/ui';
import ui from '@/components/finance/expenses.module.css';
import styles from '@/components/finance/finance-list.module.css';
import { ApiError, get } from '@/lib/api';
import { recordUnlistedSupplierPayment } from '@/lib/finance-actions';
import { METHODS, day, today, type Debt, type Parties } from '@/lib/finance';
import { tzs } from '@/lib/format';
import { param, type ListParams, type Page } from '@/lib/paging';
import { AccountSelect } from '@/components/finance/account-select';

export const metadata = { title: 'Supplier payments · Omoterra Operations' };

type Balance = {
  supplier_id: string; name: string; alias: string; phone: string; place: string; open_invoices: number;
  owed: string; due_now: string; overdue: string; earliest_due: string | null; credit: string; settlements_pending: string;
  state: 'overdue' | 'due_now' | 'due_soon' | 'on_track'; last_payment: { paid_on: string; amount: string } | null;
};
type Balances = Page<Balance> & { summary: {
  total_owed: string; suppliers: number; due_now: string; due_now_suppliers: number;
  overdue: string; overdue_suppliers: number; total_suppliers: number; credit: string; credit_suppliers: number;
  settlements_pending: string; settlements_suppliers: number;
} };
const STATES: [string, string][] = [['', 'All suppliers'], ['overdue', 'Overdue'], ['due_now', 'Due now'], ['due_soon', 'Due soon'], ['on_track', 'On track']];
const STATE_VIEW: Record<Balance['state'], [string, string]> = {
  overdue: ['Overdue', 'red'], due_now: ['Due now', 'late'], due_soon: ['Due soon', 'late'], on_track: ['On track', 'in'],
};
const suppliers = (n: number) => `${n} ${n === 1 ? 'supplier' : 'suppliers'}`;
const plain = (value: string) => Number(value).toLocaleString('en-US', { maximumFractionDigits: 2 });

export default async function SupplierPayments({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  const query = new URLSearchParams();
  for (const key of ['q', 'state', 'page', 'page_size']) { const value = param(params, key); if (value) query.set(key, value); }
  const debtId = param(params, 'debt');
  let data: Balances; let everyone: Balances; let parties: Parties; let debt: Debt | null = null;
  try {
    [data, everyone, parties, debt] = await Promise.all([
      get<Balances>(`/ops/ledger/supplier-balances${query.size ? `?${query}` : ''}`),
      get<Balances>('/ops/ledger/supplier-balances?page_size=100'),
      get<Parties>('/ops/finance/parties'),
      debtId ? get<Debt>(`/ops/ledger/debts/${encodeURIComponent(debtId)}`).catch(() => null) : Promise.resolve(null),
    ]);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Supplier payments" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Supplier balances could not be loaded.'}</Notice></div></>;
  }
  const payDebt = debt && debt.status === 'open' && debt.direction === 'payable' && debt.supplier_id ? debt : null;
  const selected = payDebt?.supplier_id ?? param(params, 'supplier') ?? '';
  const total = data.summary;
  const state = param(params, 'state');
  function href(change: Record<string, string>) {
    const next = new URLSearchParams(query);
    for (const [key, value] of Object.entries(change)) { if (value) next.set(key, value); else next.delete(key); }
    return `/finance/supplier-payments${next.size ? `?${next}` : ''}`;
  }

  return <div className={`${ui.workspace} ${styles.page}`}>
    <div className={ui.heading}>
      <h1>Supplier payments</h1>
      <div className={styles.headingActions}>
        <UnregisteredPaymentButton>
          <p className={styles.payHint} style={{ margin: 0 }}>For a supplier you paid for stock whose cost was never entered. This records the cost and the payment in one step.</p>
          <ActionForm action={recordUnlistedSupplierPayment} label="Record payment"
            hidden={{ idempotency_key: randomUUID(), payment_key: randomUUID() }}>
            <div className="field"><label htmlFor="unlisted-supplier">Supplier</label><select id="unlisted-supplier" name="supplier_id" className="input" defaultValue="" required><option value="" disabled>Choose the supplier…</option>{parties.suppliers.map((supplier) => <option key={supplier.id} value={supplier.id}>{supplier.name} · {supplier.phone}</option>)}</select></div>
            <div className="field"><label htmlFor="unlisted-description">What was supplied</label><input id="unlisted-description" name="description" className="input" placeholder="e.g. Chicken batch sold to walk-in buyers" required minLength={2} /></div>
            <div className="field"><label htmlFor="unlisted-amount">Amount paid (TZS)</label><input id="unlisted-amount" name="amount" className="input" inputMode="decimal" required /></div>
            <div className="field"><label htmlFor="unlisted-date">Date paid</label><input id="unlisted-date" name="paid_on" type="date" className="input" defaultValue={today()} max={today()} required /></div>
            <div className="field"><label htmlFor="unlisted-method">Method</label><select id="unlisted-method" name="method" className="input" defaultValue="mpesa">{METHODS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}</select></div>
            <AccountSelect id="unlisted-account" label="Paid from account" />
            <div className="field"><label htmlFor="unlisted-reference">Reference</label><input id="unlisted-reference" name="reference" className="input" placeholder="e.g. M-Pesa code" /></div>
            <div className="field"><label htmlFor="unlisted-sms">Payment confirmation SMS</label><textarea id="unlisted-sms" name="sms_text" className="input" rows={3} placeholder="Paste the payment confirmation SMS" /></div>
            <div className="field"><label htmlFor="unlisted-receipt">Receipt image</label><input id="unlisted-receipt" name="receipt" className="input" type="file" accept="image/jpeg,image/png,image/webp" /></div>
            <SupplierReceiptMessageFields idPrefix="unlisted" />
          </ActionForm>
        </UnregisteredPaymentButton>
        <a href="#pay" className={ui.primary}><Icons.plus size={19} />Pay supplier</a>
      </div>
    </div>

    {param(params, 'paid') && <p className={ui.success} role="status">Payment recorded and balances updated.{param(params, 'sms') === 'queued' ? ' The receipt SMS is on its way.' : ''}</p>}

    <section className={styles.stats} data-count="4" aria-label="Supplier payments summary">
      <article className={styles.stat} data-tone="in"><span className={styles.statIcon}><Icons.coins size={26} /></span>
        <div><span>Total owed</span><strong>{tzs(total.total_owed)}</strong><small>Across {suppliers(total.suppliers)}{Number(total.credit) > 0 ? ` · ${tzs(total.credit)} credit held by ${suppliers(total.credit_suppliers)}` : ''}</small>
          {/* App payouts are owed too, but paid on Settlements: beside this total, not in it. */}
          {Number(total.settlements_pending) > 0 && <small>App payouts pending, paid on Settlements: {tzs(total.settlements_pending)}</small>}</div></article>
      <Link href={href({ state: 'due_now', page: '' })} className={styles.stat} data-tone="in"><span className={styles.statIcon}><Icons.clock size={26} /></span>
        <div><span>Due now (incl. overdue)</span><strong>{tzs(total.due_now)}</strong><small>{suppliers(total.due_now_suppliers)}</small></div></Link>
      <Link href={href({ state: 'overdue', page: '' })} className={styles.stat} data-tone="in"><span className={styles.statIcon}><Icons.alert size={26} /></span>
        <div><span>Overdue</span><strong>{tzs(total.overdue)}</strong><small>{suppliers(total.overdue_suppliers)}</small></div></Link>
      <Link href="/suppliers" className={styles.stat} data-tone="in"><span className={styles.statIcon}><Icons.users size={26} /></span>
        <div><span>Suppliers with open balances</span><strong>{total.suppliers}</strong><small>out of {total.total_suppliers} total suppliers</small></div></Link>
    </section>

    <div className={styles.payLayout}>
      <section className={styles.panel}>
        <h2>Supplier balances</h2>
        <div className={styles.toolbar} role="search">
          <SearchBox placeholder="Search suppliers…" />
          <FilterMenu label={STATES.find(([key]) => key === state)?.[1] ?? 'All suppliers'}>
            <label>Show<select name="state" defaultValue={state}>{STATES.map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></label>
          </FilterMenu>
        </div>
        <div className={styles.tableWrap}>
          <table className={styles.table} data-phone-show="1 3">
            <thead><tr><th>Supplier</th><th>Open invoices</th><th>Amount owed (TZS)</th><th>Due date</th><th>Last payment</th><th>Action</th></tr></thead>
            <tbody>{data.items.map((row) => {
              const [label, tone] = STATE_VIEW[row.state];
              const due = row.state === 'overdue' || row.state === 'due_now';
              return <tr key={row.supplier_id}>
                <td data-label="Supplier"><div><Link className={styles.name} href={`/suppliers/${row.supplier_id}#money`}>{row.name}</Link><small>{row.place || row.phone || '—'}</small></div></td>
                <td data-label="Open invoices">{row.open_invoices}</td>
                <td data-label="Amount owed" className={styles.money}>{plain(row.owed)}{Number(row.credit) > 0 && <small className={styles.block}>credit {plain(row.credit)}</small>}
                  {Number(row.settlements_pending) > 0 && <small className={styles.block}>app payouts {plain(row.settlements_pending)}</small>}</td>
                <td data-label="Due date"><div>{row.earliest_due ? day(row.earliest_due) : 'On receipt'}<span className={styles.dueState} data-tone={tone}>{tone === 'in' ? <Icons.checkCircle size={15} /> : tone === 'red' ? <Icons.alert size={15} /> : <Icons.clock size={15} />}{label}</span></div></td>
                <td data-label="Last payment"><div>{row.last_payment ? day(row.last_payment.paid_on) : '—'}{row.last_payment && <small>TZS {plain(row.last_payment.amount)}</small>}</div></td>
                <td data-label="Action">{due
                  ? <Link href={href({ supplier: row.supplier_id, debt: '' }) + '#pay'} className={styles.rowPay}>Pay</Link>
                  : <Link href={`/suppliers/${row.supplier_id}#money`} className={styles.rowView}>View</Link>}</td>
              </tr>;
            })}</tbody>
          </table>
          {!data.items.length && <div className={styles.empty}><Icons.checkCircle size={36} /><h2>{data.summary.suppliers ? 'No supplier matches.' : 'No open supplier balances.'}</h2><p>{data.summary.suppliers ? 'Try another search or filter.' : 'Every registered supplier is paid up.'}</p></div>}
        </div>
        <ListFooter data={data} label="Supplier" href={(page) => href({ page: page > 1 ? String(page) : '' })} />
      </section>

      <aside className={styles.panel}>
        <PaySupplierPanel key={`${selected}:${payDebt?.id ?? ''}`} suppliers={everyone.items.map(({ supplier_id, name, owed, credit }) => ({ supplier_id, name, owed, credit }))}
          selected={selected} debt={payDebt ? { id: payDebt.id, balance: payDebt.balance, description: payDebt.description } : null}
          now={today()} idempotencyKey={randomUUID()} />
      </aside>
    </div>
  </div>;
}
