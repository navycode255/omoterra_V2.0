import Link from 'next/link';
import { Empty, Status } from '@/components/ui';
import { day, methodLabel } from '@/lib/finance';
import { tzs } from '@/lib/format';

// GET /ops/ledger/suppliers/{id}/statement: what Omoterra bought from one
// supplier outside app orders (direct sales, LPOs, collections) and paid them.
export type SupplierStatement = {
  bought: string; paid: string; owed: string; open_count: number;
  debts: { id: string; description: string; sale_number: string | null; amount: string; paid_amount: string;
    balance: string; incurred_on: string; status: string; overdue: boolean }[];
  payments: { id: string; kind: 'transfer' | 'single'; amount: string; allocated: string; paid_on: string;
    method: string; reference: string; note: string; debt_id: string | null }[];
};

export function SupplierStatementSection({ statement }: { statement: SupplierStatement | null }) {
  return (
    <section className="supplier-lower-section" id="money"><h2>Money with this supplier</h2>
      {!statement ? <Empty>The payment history could not be loaded just now.</Empty> : <>
        <div className="stat-band" style={{ gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', margin: '14px 0' }}>
          <div className="stat"><div className="stat-label">Bought from them</div><div className="stat-value numeric">{tzs(statement.bought)}</div></div>
          <div className="stat"><div className="stat-label">Paid to them</div><div className="stat-value numeric">{tzs(statement.paid)}</div></div>
          <div className="stat"><div className="stat-label">Still owed</div><div className="stat-value numeric">{tzs(statement.owed)}</div>
            {Number(statement.owed) > 0 && <Link className="small" href="/finance/supplier-payments">Pay supplier</Link>}</div>
        </div>
        <h3 className="small strong">Payments made</h3>
        {statement.payments.length === 0 ? <Empty>No payments recorded yet.</Empty> : <div className="table-wrap lower-table"><table>
          <thead><tr><th>Date</th><th className="numeric">Amount</th><th>Method</th><th>Reference</th><th>Note</th></tr></thead>
          <tbody>{statement.payments.map((row) => <tr key={row.id}>
            <td>{day(row.paid_on)}<div className="meta">{row.kind === 'transfer' ? 'Supplier transfer' : 'Paid on one purchase'}</div></td>
            <td className="numeric money">{tzs(row.allocated)}{row.kind === 'transfer' && row.allocated !== row.amount && <div className="meta">of {tzs(row.amount)} sent</div>}</td>
            <td>{methodLabel(row.method)}</td><td>{row.reference || '—'}</td><td className="small">{row.note || '—'}</td>
          </tr>)}</tbody></table></div>}
        <h3 className="small strong" style={{ marginTop: 16 }}>Purchases</h3>
        {statement.debts.length === 0 ? <Empty>No purchases recorded yet.</Empty> : <div className="table-wrap lower-table"><table>
          <thead><tr><th>Date</th><th>What</th><th className="numeric">Amount</th><th className="numeric">Paid</th><th className="numeric">Balance</th><th>Status</th></tr></thead>
          <tbody>{statement.debts.map((row) => <tr key={row.id}>
            <td>{day(row.incurred_on)}</td>
            <td><Link href={`/finance/debts/${row.id}`}>{row.sale_number ? `Sale ${row.sale_number}` : row.description}</Link></td>
            <td className="numeric">{tzs(row.amount)}</td><td className="numeric">{tzs(row.paid_amount)}</td>
            <td className="numeric money">{tzs(row.balance)}</td>
            <td>{row.status === 'settled' ? <Status tone="positive">Paid</Status>
              : <Status tone={row.overdue ? 'error' : 'warning'}>{row.overdue ? 'Overdue' : 'Owed'}</Status>}</td>
          </tr>)}</tbody></table></div>}
      </>}
    </section>
  );
}
