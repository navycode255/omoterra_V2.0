import Link from 'next/link';
import { Notice, PageHeader, Status } from '@/components/ui';
import { ListFooter } from '@/components/finance/list-footer';
import { debtStatus, debtTone } from '@/components/finance/ledger';
import { ExpenseWorkspace, RecordExpenseButton } from '@/components/finance/expense-workspace';
import { Icons } from '@/components/icons';
import styles from '@/components/finance/expenses.module.css';
import list from '@/components/finance/finance-list.module.css';
import { FilterMenu, SearchBox } from '@/components/list-toolbar';
import { ApiError, get } from '@/lib/api';
import { EXPENSE_CATEGORIES, day, expenseLabel, today, type Debt } from '@/lib/finance';
import { tzs } from '@/lib/format';
import { listPath, param, type ListParams, type Page } from '@/lib/paging';

export const metadata = { title: 'Expenses · Omoterra Operations' };
// `total` is the row count; `summary` and `by_category` add up every matching row (all pages), cancelled ones left out.
type Expenses = Page<Debt> & { summary: { incurred: string; paid: string; outstanding: string }; by_category: { category: string; amount: string; paid: string; owed: string }[] };
export default async function ExpensesPage({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  const now = today();
  const start = param(params,'start') || `${now.slice(0,8)}01`;
  const end = param(params,'end') || now;
  const saleId = param(params,'sale_id');
  const locationId = param(params,'location_id');
  let data: Expenses;
  try { data = await get<Expenses>(listPath('/ops/expenses',params,['start','end','category','sale_id','location_id'],saleId ? {} : {start,end})); }
  catch(error) { return <><div className="topbar"><PageHeader title="Expenses"/></div><div className="workspace"><Notice tone="error">{error instanceof ApiError ? error.message : 'Expenses could not be loaded.'}</Notice></div></>; }
  function pageLink(page: number) { const query=new URLSearchParams(); for(const key of ['start','end','category','sale_id','location_id','q','page_size','status']) {const value=param(params,key);if(value)query.set(key,value);} query.set('page',String(page));return `/finance/expenses?${query}`; }
  return <ExpenseWorkspace now={now} saleId={saleId} locationId={locationId}>
    {locationId && <Notice>Expenses for this location. <Link href={`/locations/${locationId}`}>Back to location</Link> · <Link href="/finance/expenses">All expenses</Link></Notice>}
    {saleId && <Notice>Expenses for this sale. <Link href={`/sales/${saleId}`}>Back to sale</Link> · <Link href="/finance/expenses">All expenses</Link></Notice>}
    <div className={list.toolbar} role="search">
      <SearchBox placeholder="Search expenses…" />
      <div className={list.toolbarEnd}>
        {!saleId && <FilterMenu icon="calendar" label={`${day(start)} – ${day(end)}`}>
          <label>From<input name="start" type="date" defaultValue={start}/></label>
          <label>To<input name="end" type="date" defaultValue={end}/></label>
          <Link className={list.filterReset} href="/finance/expenses">This month</Link>
        </FilterMenu>}
        <FilterMenu label={param(params,'category') ? expenseLabel(param(params,'category')) : 'All categories'}>
          <label>Category<select name="category" defaultValue={param(params,'category')}><option value="">All categories</option>{EXPENSE_CATEGORIES.map(([id,label])=><option key={id} value={id}>{label}</option>)}</select></label>
        </FilterMenu>
      </div>
    </div>
    <section className={styles.summary} aria-label="Total expenses"><span className={styles.summaryIcon}><Icons.card size={36}/></span><div><p>Total spent</p><strong>{tzs(data.summary.incurred)}</strong><p>{saleId ? 'On this sale' : `${day(start)} – ${day(end)}`}{Number(data.summary.outstanding)>0 && ` · ${tzs(data.summary.outstanding)} still owed`}</p></div><svg className={styles.leaves} viewBox="0 0 200 145" aria-hidden="true"><path d="M200 0C156 23 150 87 181 145c24-57 29-102 19-145M122 93C64 66 31 107 16 145c58 9 98-9 106-52M162 77C110 76 90 30 99 0c50 4 83 30 63 77" fill="currentColor"/><path d="m196 12-15 126M34 139l78-39M106 10l53 58" stroke="white" fill="none"/></svg></section>
    <p className="small muted">Asset depreciation is included in Profit and reports as a non-cash cost. This ledger lists paid or owed expense obligations.</p>
    <section className={styles.history}><h2><Icons.clipboard size={22}/>Expense history</h2>
      <div className={styles.tableWrap}><table className={styles.table}><thead><tr><th>Date</th><th>Category</th><th>Description</th><th>Paid to</th><th>Amount (TZS)</th><th>Payment</th></tr></thead><tbody>{data.items.map(row=><tr key={row.id}><td data-label="Date">{day(row.incurred_on)}</td><td data-label="Category">{expenseLabel(row.expense_category)}</td><td data-label="Description"><Link className={styles.description} href={`/finance/debts/${row.id}`}>{row.description}</Link>{row.location_id && <Link className={styles.saleLink} href={`/locations/${row.location_id}`}>View location</Link>}{row.sale_id && <Link className={styles.saleLink} href={`/sales/${row.sale_id}`}>View sale</Link>}</td><td data-label="Paid to">{row.party_name || '—'}</td><td data-label="Amount" className={styles.money}>{tzs(row.amount)}</td><td data-label="Payment"><div><Status tone={debtTone(row)}>{debtStatus(row)}</Status>{Number(row.balance)>0 && <small>{tzs(row.balance)} owed</small>}</div></td></tr>)}</tbody></table></div>
      {!data.items.length && <div className={styles.empty}><span><Icons.file size={44}/></span><h3>No expenses for this period.</h3><p>Record your first expense to start tracking operating costs.</p><RecordExpenseButton/></div>}
      <ListFooter data={data} label="Expense" href={pageLink} />
    </section>
  </ExpenseWorkspace>;
}
