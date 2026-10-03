import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { UseCreditForm } from '@/components/finance/ledger';
import { Empty, Notice, Status } from '@/components/ui';
import { correctTransferEntry, recordTransferRefund } from '@/lib/finance-actions';
import { METHODS, day, methodLabel, today, type TransferMoney } from '@/lib/finance';
import { tzs } from '@/lib/format';

type TransferEvent = { id: string; kind: 'credit' | 'reallocation' | 'refund' | 'entry_error'; amount: string;
  occurred_on: string; method: string | null; reference: string; evidence: string; reason: string; recorded_by: string | null };

// GET /ops/ledger/suppliers/{id}/statement: what Omoterra bought from one
// supplier outside app orders (direct sales, LPOs, collections) and the money
// sent to them. Each transfer says where its money is now:
// allocated + credit + refunded + entry error + unresolved = amount.
export type SupplierStatement = {
  bought: string; paid: string; owed: string; open_count: number;
  transferred: string; allocated: string; credit: string; refunded: string; entry_error: string;
  unresolved: string; net_paid: string; without_transfer: string;
  unresolved_items: { ledger_payment_id: string; amount: string; transfer_id: string; transfer_paid_on: string;
    debt_description: string; reverse_reason: string }[];
  debts: { id: string; description: string; sale_number: string | null; amount: string; paid_amount: string;
    balance: string; incurred_on: string; status: string; overdue: boolean }[];
  payments: (TransferMoney & { id: string; kind: 'transfer' | 'single'; origin: string; paid_on: string;
    method: string; reference: string; note: string; debt_id: string | null; events: TransferEvent[] })[];
};

const EVENT_LABEL: Record<TransferEvent['kind'], string> = {
  credit: 'Moved to supplier credit', reallocation: 'Credit used on an invoice',
  refund: 'Refunded by the supplier', entry_error: 'Entry error (never sent)',
};

function Breakdown({ row }: { row: SupplierStatement['payments'][number] }) {
  const parts: [string, string][] = [['on invoices', row.allocated], ['credit', row.credit], ['refunded', row.refunded],
    ['entry error', row.entry_error], ['unresolved', row.unresolved]];
  const shown = parts.filter(([, value]) => Number(value) > 0);
  if (shown.length <= 1 && Number(row.allocated) === Number(row.amount)) return null;
  return <div className="meta">{shown.map(([label, value]) => `${tzs(value)} ${label}`).join(' · ')}</div>;
}

function TransferActions({ row, admin }: { row: SupplierStatement['payments'][number]; admin: boolean }) {
  if (!admin || row.kind !== 'transfer' || !(Number(row.credit) > 0)) return null;
  return <>
    <details>
      <summary className="small">Record refund</summary>
      <ActionForm action={recordTransferRefund} label="Record refund" hidden={{ transfer_id: row.id, idempotency_key: randomUUID() }}>
        <p className="meta">Only money the supplier actually sent back. It is recorded as money in on the day received; the transfer itself stays as sent.</p>
        <div className="field"><label htmlFor={`refund-amount-${row.id}`}>Amount received (TZS) · up to {tzs(row.credit)}</label>
          <input id={`refund-amount-${row.id}`} name="amount" className="input" inputMode="decimal" required /></div>
        <div className="field"><label htmlFor={`refund-on-${row.id}`}>Date received</label>
          <input id={`refund-on-${row.id}`} name="received_on" type="date" className="input" defaultValue={today()} min={row.paid_on} max={today()} required /></div>
        <div className="field"><label htmlFor={`refund-method-${row.id}`}>Method</label>
          <select id={`refund-method-${row.id}`} name="method" className="input" defaultValue={row.method}>{METHODS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}</select></div>
        <div className="field"><label htmlFor={`refund-ref-${row.id}`}>Transaction reference</label>
          <input id={`refund-ref-${row.id}`} name="reference" className="input" placeholder="e.g. M-Pesa code" /></div>
        <div className="field"><label htmlFor={`refund-evidence-${row.id}`}>Proof (confirmation SMS or statement line)</label>
          <textarea id={`refund-evidence-${row.id}`} name="evidence" className="input" rows={2} /></div>
      </ActionForm>
    </details>
    <details>
      <summary className="small">Correct an entry error</summary>
      <ActionForm action={correctTransferEntry} label="Correct the transfer" variant="danger"
        confirm="Record that this part of the transfer never left the account? Money out goes down by this amount."
        hidden={{ transfer_id: row.id, idempotency_key: randomUUID() }}>
        <p className="meta">Only when the transfer was recorded higher than what was really sent. Not for money the supplier holds.</p>
        <div className="field"><label htmlFor={`error-amount-${row.id}`}>Amount never sent (TZS) · up to {tzs(row.credit)}</label>
          <input id={`error-amount-${row.id}`} name="amount" className="input" inputMode="decimal" required /></div>
        <div className="field"><label htmlFor={`error-reason-${row.id}`}>Reason</label>
          <input id={`error-reason-${row.id}`} name="reason" className="input" required minLength={3} /></div>
        <div className="field"><label htmlFor={`error-evidence-${row.id}`}>Evidence (statement line, receipt)</label>
          <textarea id={`error-evidence-${row.id}`} name="evidence" className="input" rows={2} required minLength={3} /></div>
      </ActionForm>
    </details>
  </>;
}

export function SupplierStatementSection({ statement, supplierId, admin = false }: {
  statement: SupplierStatement | null; supplierId: string; admin?: boolean;
}) {
  return (
    <section className="supplier-lower-section" id="money"><h2>Money with this supplier</h2>
      {!statement ? <Empty>The payment history could not be loaded just now.</Empty> : <>
        <div className="stat-band" style={{ gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', margin: '14px 0' }}>
          <div className="stat"><div className="stat-label">Bought from them</div><div className="stat-value numeric">{tzs(statement.bought)}</div></div>
          <div className="stat"><div className="stat-label">Paid to them</div><div className="stat-value numeric">{tzs(statement.paid)}</div></div>
          <div className="stat"><div className="stat-label">Still owed</div><div className="stat-value numeric">{tzs(statement.owed)}</div>
            {Number(statement.owed) > 0 && <Link className="small" href={`/finance/supplier-payments?supplier=${supplierId}#pay`}>Pay supplier</Link>}</div>
        </div>
        <div className="stat-band" style={{ gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', margin: '0 0 14px' }}>
          <div className="stat"><div className="stat-label">Money sent</div><div className="stat-value numeric">{tzs(statement.transferred)}</div></div>
          <div className="stat"><div className="stat-label">Credit they hold</div><div className="stat-value numeric">{tzs(statement.credit)}</div>
            {Number(statement.credit) > 0 && <span className="meta">For their next invoice</span>}</div>
          <div className="stat"><div className="stat-label">Refunded to us</div><div className="stat-value numeric">{tzs(statement.refunded)}</div></div>
          <div className="stat"><div className="stat-label">Unresolved</div><div className="stat-value numeric">{tzs(statement.unresolved)}</div>
            {Number(statement.unresolved) > 0 && <Status tone="warning">Needs a decision</Status>}</div>
        </div>
        {Number(statement.unresolved) > 0 && <Notice>
          {tzs(statement.unresolved)} was taken off invoices before supplier credit existed. The money left our account; the finance owner
          must record, with evidence, whether the supplier still holds it (credit), sent it back (refund) or it was never sent
          (entry error). Run <code>python -m app.classify_transfers --dry-run</code> on the server.
        </Notice>}
        {Number(statement.credit) > 0 && Number(statement.owed) > 0 && <div style={{ maxWidth: 420, margin: '0 0 14px' }}>
          <h3 className="small strong">Use their credit</h3>
          <UseCreditForm supplierId={supplierId} credit={statement.credit} owed={statement.owed} />
        </div>}
        <h3 className="small strong">Money sent</h3>
        {statement.payments.length === 0 ? <Empty>No payments recorded yet.</Empty> : <div className="table-wrap lower-table"><table>
          <thead><tr><th>Date</th><th className="numeric">Amount sent</th><th>Method</th><th>Reference</th><th>History</th>{admin && <th />}</tr></thead>
          <tbody>{statement.payments.map((row) => <tr key={row.id}>
            <td>{day(row.paid_on)}<div className="meta">{row.kind === 'single' ? 'Paid on one purchase (before transfers)'
              : row.origin === 'pay_supplier' ? 'Supplier transfer' : row.origin === 'legacy' ? 'Earlier payment' : 'Paid on one purchase'}</div></td>
            <td className="numeric money">{tzs(row.amount)}<Breakdown row={row} /></td>
            <td>{methodLabel(row.method)}</td><td>{row.reference || '—'}{row.note && <div className="meta">{row.note}</div>}</td>
            <td className="small">{row.events.length === 0 ? '—' : row.events.map((event) => <div key={event.id}>
              {day(event.occurred_on)} · {EVENT_LABEL[event.kind]} {tzs(event.amount)}{event.reference && ` · ${event.reference}`}
              {(event.reason || event.evidence) && <div className="meta">{[event.reason, event.evidence].filter(Boolean).join(' · ')}</div>}
            </div>)}</td>
            {admin && <td><TransferActions row={row} admin={admin} /></td>}
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
