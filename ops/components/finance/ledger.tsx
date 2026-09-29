import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Status } from '@/components/ui';
import { cancelDebt, recordLedgerPayment, reverseLedgerPayment } from '@/lib/finance-actions';
import { METHODS, day, methodLabel, type Debt, type LedgerPayment } from '@/lib/finance';
import { dateTime, tzs, type Tone } from '@/lib/format';

export function debtTone(debt: Pick<Debt, 'status' | 'overdue'>): Tone {
  if (debt.status === 'settled') return 'positive';
  if (debt.status === 'cancelled') return 'neutral';
  return debt.overdue ? 'error' : 'warning';
}

export function debtStatus(debt: Pick<Debt, 'status' | 'overdue' | 'direction'>) {
  if (debt.status === 'settled') return debt.direction === 'receivable' ? 'Fully paid' : 'Fully paid out';
  if (debt.status === 'cancelled') return 'Cancelled';
  return debt.overdue ? 'Overdue' : 'Open';
}

/** Every installment on a debt, reversed ones struck through but kept. */
export function PaymentsTable({ payments, admin, direction }: { payments: LedgerPayment[]; admin: boolean; direction: Debt['direction'] }) {
  if (payments.length === 0) return <p className="muted small">No payments recorded yet.</p>;
  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Date</th>
            <th className="numeric">{direction === 'receivable' ? 'Received' : 'Paid out'}</th>
            <th>Method</th>
            <th>Reference</th>
            <th>Recorded by</th>
            {admin && <th />}
          </tr>
        </thead>
        <tbody>
          {payments.map((p) => (
            <tr key={p.id} style={p.reversed ? { opacity: 0.6 } : undefined}>
              <td>{day(p.paid_on)}<div className="meta">entered {dateTime(p.created_at)}</div></td>
              <td className="numeric money" style={p.reversed ? { textDecoration: 'line-through' } : undefined}>{tzs(p.amount)}</td>
              <td className="small">{methodLabel(p.method)}</td>
              <td className="small">{p.reference || '—'}{p.note && <div className="meta">{p.note}</div>}</td>
              <td className="small">
                {p.recorded_by ?? '—'}
                {p.reversed && <div className="meta">Reversed by {p.reversed_by}: {p.reverse_reason}</div>}
              </td>
              {admin && (
                <td>
                  {!p.reversed && (
                    <details>
                      <summary className="small">Reverse</summary>
                      <ActionForm action={reverseLedgerPayment} label="Reverse payment" variant="danger"
                        confirm="Reverse this payment? The balance goes back up. The record stays in the history."
                        hidden={{ payment_id: p.id, idempotency_key: randomUUID() }}>
                        <div className="field">
                          <label htmlFor={`reason-${p.id}`}>Reason</label>
                          <input id={`reason-${p.id}`} name="reason" className="input" required minLength={3} />
                        </div>
                      </ActionForm>
                    </details>
                  )}
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/** Record one installment against a debt. */
export function PaymentForm({ debt, today, saleId }: { debt: Debt; today: string; saleId?: string }) {
  if (debt.status !== 'open') return null;
  const incoming = debt.direction === 'receivable';
  return (
    <ActionForm action={recordLedgerPayment} label={incoming ? 'Record money received' : 'Record payment made'}
      hidden={{ debt_id: debt.id, sale_id: saleId ?? '', idempotency_key: randomUUID() }}>
      <div className="grid-2">
        <div className="field">
          <label htmlFor={`amount-${debt.id}`}>Amount (TZS) · balance {tzs(debt.balance)}</label>
          <input id={`amount-${debt.id}`} name="amount" className="input" inputMode="decimal" required />
        </div>
        <div className="field">
          <label htmlFor={`paid_on-${debt.id}`}>Date</label>
          <input id={`paid_on-${debt.id}`} name="paid_on" type="date" className="input" defaultValue={today} max={today} required />
        </div>
        <div className="field">
          <label htmlFor={`method-${debt.id}`}>Method</label>
          <select id={`method-${debt.id}`} name="method" className="input" defaultValue="cash">
            {METHODS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
          </select>
        </div>
        <div className="field">
          <label htmlFor={`reference-${debt.id}`}>Transaction reference</label>
          <input id={`reference-${debt.id}`} name="reference" className="input" placeholder="e.g. M-Pesa code" />
        </div>
      </div>
      <div className="field">
        <label htmlFor={`note-${debt.id}`}>Note</label>
        <input id={`note-${debt.id}`} name="note" className="input" />
      </div>
    </ActionForm>
  );
}

export function CancelDebtForm({ debt }: { debt: Debt }) {
  const reconcile = debt.source === 'sale_cost';
  return (
    <ActionForm action={cancelDebt} label={reconcile ? 'Reconcile debt' : 'Cancel this debt'} variant="danger"
      confirm={reconcile ? 'Reconcile this recording error? The supplier balance and buying cost are removed, while the audit record remains.' : 'Cancel this debt? It stays in the history as cancelled.'}
      hidden={{ debt_id: debt.id, sale_id: debt.sale_id ?? '', idempotency_key: randomUUID() }}>
      <div className="field">
        <label htmlFor="cancel-reason">Reason</label>
        <input id="cancel-reason" name="reason" className="input" required minLength={3}
          placeholder={reconcile ? 'e.g. Supplier cost entered by mistake' : undefined} />
      </div>
    </ActionForm>
  );
}

export function DebtSummary({ debt }: { debt: Debt }) {
  return (
    <div className="stat-band" style={{ gridTemplateColumns: 'repeat(3, minmax(0, 1fr))' }}>
      <div className="stat"><div className="stat-label">Amount</div><div className="stat-value">{tzs(debt.amount)}</div></div>
      <div className="stat"><div className="stat-label">{debt.direction === 'receivable' ? 'Received' : 'Paid out'}</div><div className="stat-value">{tzs(debt.paid_amount)}</div></div>
      <div className="stat">
        <div className="stat-label">Balance</div>
        <div className="stat-value">{tzs(debt.balance)}</div>
        <Status tone={debtTone(debt)}>{debtStatus(debt)}</Status>
      </div>
    </div>
  );
}

export function PartyLink({ debt }: { debt: Pick<Debt, 'party_name' | 'buyer_profile_id' | 'supplier_id'> }) {
  if (debt.buyer_profile_id) return <Link href={`/buyers/${debt.buyer_profile_id}`}>{debt.party_name}</Link>;
  if (debt.supplier_id) return <Link href={`/suppliers/${debt.supplier_id}`}>{debt.party_name}</Link>;
  return <>{debt.party_name}</>;
}
