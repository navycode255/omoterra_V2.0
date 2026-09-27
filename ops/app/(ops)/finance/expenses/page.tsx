import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Card, Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ListControls } from '@/components/list-controls';
import { debtStatus, debtTone } from '@/components/finance/ledger';
import { ApiError, get } from '@/lib/api';
import { createExpense } from '@/lib/finance-actions';
import { EXPENSE_CATEGORIES, METHODS, day, expenseLabel, today, type Debt } from '@/lib/finance';
import { tzs } from '@/lib/format';
import { listPath, param, type ListParams, type Page } from '@/lib/paging';

export const metadata = { title: 'Expenses · Omoterra Operations' };

type Expenses = Page<Debt> & { total: string; by_category: { category: string; amount: string; paid: string; owed: string }[] };

export default async function ExpensesPage({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  const now = today();
  const start = param(params, 'start') || `${now.slice(0, 8)}01`;
  const end = param(params, 'end') || now;
  const saleId = param(params, 'sale_id');
  let data: Expenses;
  try {
    data = await get<Expenses>(listPath('/ops/expenses', params, ['start', 'end', 'category', 'sale_id'], saleId ? {} : { start, end }));
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Expenses" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Expenses could not be loaded.'}</Notice></div></>;
  }
  return (
    <>
      <div className="topbar">
        <PageHeader title="Expenses" subtitle="Operating costs: labour, transport, fuel, fees and anything unexpected. Record them the day they happen."
          info="An expense paid now goes into the cash book. One not yet paid shows under “I owe” until you record the payment." />
        <Link href="/finance/profit" className="button" data-variant="secondary">Profit</Link>
      </div>
      <div className="workspace">
        {saleId && <Notice>Showing and recording expenses for one sale. <Link href={`/sales/${saleId}`}>Back to the sale</Link> · <Link href="/finance/expenses">All expenses</Link></Notice>}
        <div className="grid-2" style={{ alignItems: 'start', gridTemplateColumns: 'minmax(0, 2fr) minmax(0, 1fr)' }}>
          <div className="stack">
            {!saleId && (
              <form className="row" action="/finance/expenses" style={{ flexWrap: 'wrap', alignItems: 'end' }}>
                <div className="field"><label htmlFor="start">From</label><input id="start" name="start" type="date" className="input" defaultValue={start} /></div>
                <div className="field"><label htmlFor="end">To</label><input id="end" name="end" type="date" className="input" defaultValue={end} /></div>
                <div className="field"><label htmlFor="category">Category</label>
                  <select id="category" name="category" className="input" defaultValue={param(params, 'category')}>
                    <option value="">All</option>
                    {EXPENSE_CATEGORIES.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
                  </select></div>
                <button className="button" data-variant="secondary" type="submit">Show</button>
              </form>
            )}
            <div className="stat-band" style={{ gridTemplateColumns: `repeat(${Math.min(data.by_category.length + 1, 4)}, minmax(0, 1fr))` }}>
              <div className="stat"><div className="stat-label">Total spent</div><div className="stat-value">{tzs(data.total)}</div>
                <div className="meta">{saleId ? 'on this sale' : `${day(start)} – ${day(end)}`}</div></div>
              {data.by_category.slice(0, 3).map((row) => (
                <div className="stat" key={row.category}><div className="stat-label">{expenseLabel(row.category)}</div>
                  <div className="stat-value">{tzs(row.amount)}</div>{Number(row.owed) > 0 && <div className="meta">{tzs(row.owed)} not yet paid</div>}</div>
              ))}
            </div>
            <ListControls path="/finance/expenses" params={params} data={data} noun={['expense', 'expenses']} actionLabel="unpaid"
              keep={['start', 'end', 'category', 'sale_id']} placeholder="Search description or who was paid">
              <div className="table-wrap">
                {data.items.length === 0 ? <Empty>No expenses in this period.</Empty> : (
                  <table>
                    <thead><tr><th>Date</th><th>What</th><th>Paid to</th><th className="numeric">Amount</th><th className="numeric">Unpaid</th><th>Status</th></tr></thead>
                    <tbody>
                      {data.items.map((row) => (
                        <tr key={row.id}>
                          <td className="small">{day(row.incurred_on)}</td>
                          <td><Link href={`/finance/debts/${row.id}`} className="strong">{row.description}</Link>
                            <div className="meta">{expenseLabel(row.expense_category)}{row.sale_id && <> · <Link href={`/sales/${row.sale_id}`}>sale</Link></>}</div></td>
                          <td className="small">{row.party_name}</td>
                          <td className="numeric money">{tzs(row.amount)}</td>
                          <td className="numeric">{Number(row.balance) > 0 ? tzs(row.balance) : '—'}</td>
                          <td><Status tone={debtTone(row)}>{debtStatus(row)}</Status></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
              </div>
            </ListControls>
          </div>

          <Card title="Record an expense">
            <ActionForm action={createExpense} label="Save expense" hidden={{ idempotency_key: randomUUID(), sale_id: saleId }}>
              <div className="field">
                <label htmlFor="spent_on">Date</label>
                <input id="spent_on" name="spent_on" type="date" className="input" defaultValue={now} max={now} required />
              </div>
              <div className="field">
                <label htmlFor="exp-category">Category</label>
                <select id="exp-category" name="category" className="input" required>
                  {EXPENSE_CATEGORIES.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
                </select>
              </div>
              <div className="field">
                <label htmlFor="description">What for</label>
                <input id="description" name="description" className="input" required minLength={2} placeholder="e.g. 3 helpers for chicken prep" />
              </div>
              <div className="field">
                <label htmlFor="amount">Amount (TZS)</label>
                <input id="amount" name="amount" className="input" inputMode="decimal" required />
              </div>
              <div className="grid-2">
                <div className="field">
                  <label htmlFor="paid_to">Paid to (optional)</label>
                  <input id="paid_to" name="paid_to" className="input" placeholder="e.g. Juma transport" />
                </div>
                <div className="field">
                  <label htmlFor="paid_to_phone">Their phone (optional)</label>
                  <input id="paid_to_phone" name="paid_to_phone" className="input" inputMode="tel" />
                </div>
              </div>
              <div className="field">
                <label htmlFor="paid_now">Paid?</label>
                <select id="paid_now" name="paid_now" className="input" defaultValue="full">
                  <option value="full">Paid in full now</option>
                  <option value="part">Paid part now</option>
                  <option value="none">Not paid yet (I owe it)</option>
                </select>
              </div>
              <div className="grid-2">
                <div className="field">
                  <label htmlFor="method">Paid with</label>
                  <select id="method" name="method" className="input" defaultValue="cash">
                    {METHODS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
                  </select>
                </div>
                <div className="field">
                  <label htmlFor="paid_amount">Part paid (if part)</label>
                  <input id="paid_amount" name="paid_amount" className="input" inputMode="decimal" />
                </div>
              </div>
              <div className="grid-2">
                <div className="field">
                  <label htmlFor="reference">Reference (optional)</label>
                  <input id="reference" name="reference" className="input" />
                </div>
                <div className="field">
                  <label htmlFor="due_on">Due (if owed)</label>
                  <input id="due_on" name="due_on" type="date" className="input" />
                </div>
              </div>
            </ActionForm>
          </Card>
        </div>
      </div>
    </>
  );
}
