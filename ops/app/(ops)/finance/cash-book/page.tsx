import Link from 'next/link';
import { Empty, Notice, PageHeader } from '@/components/ui';
import { ListControls } from '@/components/list-controls';
import { ApiError, get } from '@/lib/api';
import { day, methodLabel, type LedgerPayment } from '@/lib/finance';
import { dateTime, tzs } from '@/lib/format';
import { listPath, param, type ListParams, type Page } from '@/lib/paging';

export const metadata = { title: 'Cash book · Omoterra Operations' };

const TABS = [
  { key: '', label: 'All' },
  { key: 'in', label: 'Money in' },
  { key: 'out', label: 'Money out' },
  { key: 'reversed', label: 'Reversed' },
];

export default async function CashBook({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let data: Page<LedgerPayment>;
  try {
    data = await get<Page<LedgerPayment>>(listPath('/ops/ledger/payments', params, ['start', 'end']));
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Cash book" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'The cash book could not be loaded.'}</Notice></div></>;
  }
  const net = data.items.filter((p) => !p.reversed)
    .reduce((sum, p) => sum + (p.direction === 'receivable' ? 1 : -1) * Number(p.amount), 0);
  return (
    <>
      <div className="topbar">
        <PageHeader title="Cash book" subtitle="Every installment received or paid out, newest first. Reversed entries stay visible." />
      </div>
      <div className="workspace">
        <form className="row" action="/finance/cash-book" style={{ flexWrap: 'wrap', alignItems: 'end' }}>
          {param(params, 'status') && <input type="hidden" name="status" value={param(params, 'status')} />}
          <div className="field"><label htmlFor="start">From</label><input id="start" name="start" type="date" className="input" defaultValue={param(params, 'start')} /></div>
          <div className="field"><label htmlFor="end">To</label><input id="end" name="end" type="date" className="input" defaultValue={param(params, 'end')} /></div>
          <button className="button" data-variant="secondary" type="submit">Filter dates</button>
          <span className="meta">Net on this page: {net >= 0 ? '+' : '−'}TZS {Math.abs(Math.round(net)).toLocaleString('en-US')}</span>
        </form>
        <ListControls path="/finance/cash-book" params={params} data={data} tabs={TABS} noun={['payment', 'payments']}
          keep={['start', 'end']} placeholder="Search name, reference or note">
          <div className="table-wrap">
            {data.items.length === 0 ? <Empty>No payments in this view.</Empty> : (
              <table>
                <thead><tr><th>Date</th><th>Who</th><th>For</th><th className="numeric">In</th><th className="numeric">Out</th><th>Method</th><th>Recorded</th></tr></thead>
                <tbody>
                  {data.items.map((p) => (
                    <tr key={p.id} style={p.reversed ? { opacity: 0.6, textDecoration: 'line-through' } : undefined}>
                      <td className="small">{day(p.paid_on)}</td>
                      <td><Link href={`/finance/debts/${p.debt_id}`} className="strong">{p.party_name}</Link></td>
                      <td className="small">{p.sale_id ? <Link href={`/sales/${p.sale_id}`}>{p.description}</Link> : p.description}</td>
                      <td className="numeric money">{p.direction === 'receivable' ? tzs(p.amount) : ''}</td>
                      <td className="numeric money">{p.direction === 'payable' ? tzs(p.amount) : ''}</td>
                      <td className="small">{methodLabel(p.method)}{p.reference && <div className="meta">{p.reference}</div>}</td>
                      <td className="small">{p.recorded_by ?? '—'}<div className="meta">{dateTime(p.created_at)}{p.reversed ? ` · reversed: ${p.reverse_reason}` : ''}</div></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </ListControls>
      </div>
    </>
  );
}
