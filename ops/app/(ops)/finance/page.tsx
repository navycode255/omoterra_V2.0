import Link from 'next/link';
import { Card, Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { day, methodLabel, type FinanceSummary, type Party } from '@/lib/finance';
import { phone, tzs } from '@/lib/format';

export const metadata = { title: 'Finance · Omoterra Operations' };

function PartyTable({ parties, empty }: { parties: Party[]; empty: string }) {
  if (parties.length === 0) return <Empty>{empty}</Empty>;
  return (
    <div className="table-wrap">
      <table>
        <thead><tr><th>Who</th><th className="numeric">Balance</th><th className="numeric">Overdue</th><th>Since</th></tr></thead>
        <tbody>
          {parties.map((p) => {
            const q = encodeURIComponent(p.party_phone || p.party_name);
            return (
              <tr key={`${p.party_kind}:${p.buyer_profile_id ?? p.supplier_id ?? p.party_name}`}>
                <td><Link href={`/finance/debts?q=${q}`} className="strong">{p.party_name}</Link>
                  <div className="meta">{p.party_phone ? phone(p.party_phone) : p.party_kind} · {p.debts} open</div></td>
                <td className="numeric money">{tzs(p.balance)}</td>
                <td className="numeric">{Number(p.overdue) > 0 ? <Status tone="error">{tzs(p.overdue)}</Status> : '—'}</td>
                <td className="small">{day(p.oldest)}</td>
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
    <>
      <div className="topbar">
        <PageHeader title="Finance" subtitle="Everything owed to you and by you, and every shilling in and out."
          info="Totals include staff-recorded sales and debts plus marketplace orders (Payments) and supplier payouts (Settlements)." />
        <div className="row">
          <Link href="/finance/expenses" className="button" data-variant="secondary">+ Expense</Link>
          <Link href="/finance/debts" className="button" data-variant="secondary">+ Other debt</Link>
          <Link href="/sales/new" className="button">+ New sale</Link>
        </div>
      </div>
      <div className="workspace">
        <div className="stat-band">
          <div className="stat">
            <div className="stat-label">Owed to me</div>
            <div className="stat-value">{tzs(data.owed_to_me.total)}</div>
            <div className="meta">Sales & debts {tzs(data.owed_to_me.ledger)} · <Link href="/payments?status=outstanding">marketplace {tzs(data.owed_to_me.marketplace)}</Link></div>
            {Number(data.owed_to_me.overdue) > 0 && <Status tone="error">{tzs(data.owed_to_me.overdue)} overdue</Status>}
          </div>
          <div className="stat">
            <div className="stat-label">I owe</div>
            <div className="stat-value">{tzs(data.i_owe.total)}</div>
            <div className="meta">Suppliers & debts {tzs(data.i_owe.ledger)} · <Link href="/settlements?status=pending">marketplace payouts {tzs(data.i_owe.marketplace)}</Link></div>
            {Number(data.i_owe.overdue) > 0 && <Status tone="error">{tzs(data.i_owe.overdue)} overdue</Status>}
          </div>
          <div className="stat">
            <div className="stat-label">Sold today</div>
            <div className="stat-value">{tzs(data.today.sales)}</div>
            <div className="meta">{data.today.sales_count} sale{data.today.sales_count === 1 ? '' : 's'} · this month {tzs(data.month.sales)}</div>
          </div>
          <div className="stat">
            <div className="stat-label">Cash today</div>
            <div className="stat-value">{tzs(data.today.money_in)}</div>
            <div className="meta">in · {tzs(data.today.money_out)} out · <Link href="/finance/cash-book">cash book</Link></div>
          </div>
        </div>

        <div className="stat-band">
          <div className="stat">
            <div className="stat-label">Profit today</div>
            <div className="stat-value">{tzs(data.profit_today.net_profit)}</div>
            <div className="meta">sales {tzs(data.profit_today.revenue)} − stock {tzs(String(Number(data.profit_today.stock_cost) + Number(data.profit_today.marketplace_cost)))} − expenses {tzs(data.profit_today.expenses)}</div>
          </div>
          <div className="stat">
            <div className="stat-label">Expenses today</div>
            <div className="stat-value">{tzs(data.profit_today.expenses)}</div>
            <div className="meta"><Link href="/finance/expenses">Record an expense</Link></div>
          </div>
          <div className="stat">
            <div className="stat-label">Profit this month</div>
            <div className="stat-value">{tzs(data.profit_month.net_profit)}</div>
            <div className="meta">gross {tzs(data.profit_month.gross_profit)} · expenses {tzs(data.profit_month.expenses)}</div>
          </div>
          <div className="stat">
            <div className="stat-label">Details</div>
            <div className="meta" style={{ marginTop: 'var(--s2)' }}><Link href="/finance/profit">Profit day by day →</Link></div>
          </div>
        </div>

        <div className="grid-2" style={{ alignItems: 'start' }}>
          <Card title="Who owes me" action={<Link href="/finance/debts?status=owed_to_me" className="small">All</Link>}>
            <PartyTable parties={data.debtors} empty="Nobody owes you anything recorded here." />
          </Card>
          <Card title="Who I owe" action={<Link href="/finance/debts?status=i_owe" className="small">All</Link>}>
            <PartyTable parties={data.creditors} empty="You owe nothing recorded here." />
          </Card>
        </div>

        <div className="grid-2" style={{ alignItems: 'start' }}>
          <Card title="Money by method (all time)">
            {data.by_method.length === 0 ? <Empty>No money recorded yet.</Empty> : (
              <div className="table-wrap">
                <table>
                  <thead><tr><th>Method</th><th className="numeric">In</th><th className="numeric">Out</th><th className="numeric">Net</th></tr></thead>
                  <tbody>
                    {data.by_method.map((row) => (
                      <tr key={row.method}>
                        <td>{methodLabel(row.method)}</td>
                        <td className="numeric">{tzs(row.in)}</td>
                        <td className="numeric">{tzs(row.out)}</td>
                        <td className="numeric money">{tzs(row.net)}</td>
                      </tr>
                    ))}
                    <tr>
                      <td className="strong">Total</td>
                      <td className="numeric strong">{tzs(data.all_time.money_in)}</td>
                      <td className="numeric strong">{tzs(data.all_time.money_out)}</td>
                      <td className="numeric money">{tzs(String(Number(data.all_time.money_in) - Number(data.all_time.money_out)))}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            )}
            <p className="meta" style={{ marginTop: 'var(--s3)' }}>Month to date: {tzs(data.month.money_in)} in, {tzs(data.month.money_out)} out. Marketplace receipts are on <Link href="/payments">Payments</Link>.</p>
          </Card>
          <Card title="Latest payments" action={<Link href="/finance/cash-book" className="small">Cash book</Link>}>
            {data.recent_payments.length === 0 ? <Empty>No payments recorded yet.</Empty> : (
              <div className="table-wrap">
                <table>
                  <thead><tr><th>Date</th><th>Who</th><th className="numeric">Amount</th></tr></thead>
                  <tbody>
                    {data.recent_payments.map((p) => (
                      <tr key={p.id} style={p.reversed ? { opacity: 0.6 } : undefined}>
                        <td className="small">{day(p.paid_on)}</td>
                        <td><Link href={`/finance/debts/${p.debt_id}`}>{p.party_name}</Link>
                          <div className="meta">{p.direction === 'receivable' ? 'Received' : 'Paid out'} · {methodLabel(p.method)}{p.reversed ? ' · reversed' : ''}</div></td>
                        <td className="numeric money">{p.direction === 'receivable' ? '+' : '−'}{tzs(p.amount)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>
        </div>
      </div>
    </>
  );
}
