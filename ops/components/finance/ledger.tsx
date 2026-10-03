import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Status } from '@/components/ui';
import { applySupplierCredit, cancelDebt, correctDebt, recordLedgerPayment, reverseLedgerPayment } from '@/lib/finance-actions';
import { ADJUSTMENT_LABELS, METHODS, day, methodLabel, type Debt, type DebtDetail, type LedgerPayment, type Parties } from '@/lib/finance';
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

/**
 * Every installment on a debt, reversed ones struck through but kept. On a
 * registered supplier's invoice, money really reached the supplier: taking it
 * off the invoice keeps it with them as credit, it never comes back.
 */
export function PaymentsTable({ payments, admin, direction, supplier = false }: {
  payments: LedgerPayment[]; admin: boolean; direction: Debt['direction']; supplier?: boolean;
}) {
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
                {p.reversed && <div className="meta">{p.moved_to_credit ? 'Moved to supplier credit' : 'Reversed'} by {p.reversed_by}: {p.reverse_reason}</div>}
              </td>
              {admin && (
                <td>
                  {!p.reversed && (supplier || p.supplier_payment_id ? (
                    <details>
                      <summary className="small">Move to supplier credit</summary>
                      <p className="meta">The supplier keeps this money as credit for their next invoice. No money comes back; a refund is recorded separately, with proof.</p>
                      <ActionForm action={reverseLedgerPayment} label="Move to supplier credit" variant="danger"
                        confirm="Take this payment off the invoice? The invoice is owed again and the money becomes the supplier's credit on the same transfer. Money out does not change."
                        hidden={{ payment_id: p.id, idempotency_key: randomUUID() }}>
                        <div className="field">
                          <label htmlFor={`reason-${p.id}`}>Reason</label>
                          <input id={`reason-${p.id}`} name="reason" className="input" required minLength={3} placeholder="e.g. Paid against the wrong invoice" />
                        </div>
                      </ActionForm>
                    </details>
                  ) : (
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
                  ))}
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
  return (
    <ActionForm action={cancelDebt} label="Cancel this debt" variant="danger"
      confirm="Cancel this debt? It stays in the history as cancelled."
      hidden={{ debt_id: debt.id, sale_id: debt.sale_id ?? '', idempotency_key: randomUUID() }}>
      <div className="field">
        <label htmlFor="cancel-reason">Reason</label>
        <input id="cancel-reason" name="reason" className="input" required minLength={3} />
      </div>
    </ActionForm>
  );
}

function ReasonField({ id, placeholder }: { id: string; placeholder: string }) {
  return (
    <div className="field">
      <label htmlFor={id}>Reason</label>
      <input id={id} name="reason" className="input" required minLength={3} placeholder={placeholder} />
    </div>
  );
}

/** What money already paid on the debt becomes. It never comes back by itself (R1). */
function PaidMoneyChoice({ debt }: { debt: Debt }) {
  if (!(Number(debt.paid_amount) > 0)) return null;
  return (
    <fieldset className="field">
      <legend className="small">{tzs(debt.paid_amount)} already paid to {debt.party_name}</legend>
      <label className="small"><input type="radio" name="payments" value="credit" required /> {debt.party_name} has the money: keep it as their credit for a later invoice</label>
      <label className="small"><input type="radio" name="payments" value="unresolved" /> Not sure who received it: leave it unresolved for the finance owner</label>
    </fieldset>
  );
}

/**
 * The four reasoned corrections of a supplier debt opened by a sale (build
 * plan M1.4). Each is admin only, needs a reason and is kept as a financial
 * adjustment with the before and after.
 */
export function DebtCorrections({ debt, suppliers }: { debt: DebtDetail; suppliers: Parties['suppliers'] }) {
  const paid = Number(debt.paid_amount) > 0;
  const unregisteredPaid = paid && !debt.supplier_id;
  const hidden = (kind: string) => ({ debt_id: debt.id, sale_id: debt.sale_id ?? '', kind, idempotency_key: randomUUID() });
  return (
    <div className="stack">
      <p className="small muted">Choose why this supplier debt is wrong. Lines received on a delivery note or LPO are never changed here; correct the receipt instead.</p>
      <details>
        <summary className="small">Wrong supplier</summary>
        <p className="meta">Another supplier really supplied this stock. They are owed the whole {tzs(debt.amount)}; the buying cost stays.
          {paid ? ` The ${tzs(debt.paid_amount)} already paid stays with ${debt.party_name} and does not reduce what the correct supplier is owed.` : ''}</p>
        {unregisteredPaid ? <p className="small muted">Money was paid to this unregistered supplier, so it cannot be kept as their credit.</p> : (
          <ActionForm action={correctDebt} label="Move to the correct supplier" variant="danger"
            confirm="Move the whole debt to the correct supplier? The buying cost stays and payments stay with whoever received them."
            hidden={hidden('wrong_supplier')}>
            <div className="field">
              <label htmlFor="correct-supplier">Correct registered supplier</label>
              <select id="correct-supplier" name="supplier_id" className="input" defaultValue="">
                <option value="">Not registered (type the name below)</option>
                {suppliers.filter((row) => row.id !== debt.supplier_id).map((row) => (
                  <option key={row.id} value={row.id}>{row.name}{row.alias ? ` · ${row.alias}` : ''}</option>
                ))}
              </select>
            </div>
            <div className="field">
              <label htmlFor="correct-supplier-name">Or their name, if not registered</label>
              <input id="correct-supplier-name" name="supplier_name" className="input" maxLength={150} />
            </div>
            <PaidMoneyChoice debt={debt} />
            <ReasonField id="wrong-supplier-reason" placeholder="e.g. Birds came from Kibaha farm, not this one" />
          </ActionForm>
        )}
      </details>
      <details>
        <summary className="small">Duplicate liability</summary>
        <p className="meta">These goods are already owed to {debt.party_name} on another debt. This one is cancelled and linked to it; the buying cost stays.</p>
        {unregisteredPaid ? <p className="small muted">Money was paid to this unregistered supplier, so it cannot be kept as their credit.</p>
          : debt.duplicate_candidates.length === 0 ? <p className="small muted">{debt.party_name} has no other open debt this could duplicate.</p> : (
          <ActionForm action={correctDebt} label="Cancel as duplicate" variant="danger"
            confirm="Cancel this debt as a duplicate of the one chosen? The buying cost stays."
            hidden={hidden('duplicate_liability')}>
            <div className="field">
              <label htmlFor="duplicate-of">The debt that really covers these goods</label>
              <select id="duplicate-of" name="duplicate_of" className="input" required defaultValue="">
                <option value="" disabled>Choose a debt…</option>
                {debt.duplicate_candidates.map((row) => (
                  <option key={row.id} value={row.id}>{day(row.incurred_on)} · {tzs(row.amount)} · {row.description || row.source}</option>
                ))}
              </select>
            </div>
            <PaidMoneyChoice debt={debt} />
            <ReasonField id="duplicate-reason" placeholder="e.g. Same birds as delivery note DN-…" />
          </ActionForm>
        )}
      </details>
      <details>
        <summary className="small">Free or gift stock</summary>
        <p className="meta">{debt.party_name} gave this stock free. The debt is cancelled and the buying cost becomes 0, so the margin rises.</p>
        {paid ? <p className="small muted">Money was paid on this debt, so the stock was not free. Move that payment to supplier credit first if it belongs elsewhere.</p> : (
          <ActionForm action={correctDebt} label="Record as free stock" variant="danger"
            confirm="Record this stock as free? Its buying cost becomes 0." hidden={hidden('free_stock')}>
            <ReasonField id="free-reason" placeholder="e.g. Three extra birds given free" />
          </ActionForm>
        )}
      </details>
      <details>
        <summary className="small">Cost never existed</summary>
        <p className="meta">Nobody was owed for this stock. The debt is cancelled and the buying cost becomes unknown, so this sale&apos;s profit is provisional until a cost is known.</p>
        {paid ? <p className="small muted">Money was paid on this debt, so it had a cost. Move that payment to supplier credit first if it belongs elsewhere.</p> : (
          <ActionForm action={correctDebt} label="Clear the cost" variant="danger"
            confirm="Clear this buying cost? It becomes unknown, not zero." hidden={hidden('cost_never_existed')}>
            <ReasonField id="no-cost-reason" placeholder="e.g. Our own birds, entered as bought" />
          </ActionForm>
        )}
      </details>
    </div>
  );
}

/** Corrections made to this debt or pointing at it, oldest first. */
export function AdjustmentsList({ debt }: { debt: DebtDetail }) {
  if (debt.adjustments.length === 0) return null;
  return (
    <ul className="stack small" style={{ listStyle: 'none', padding: 0, margin: 0 }}>
      {debt.adjustments.map((row) => {
        const other = row.entity_id === debt.id ? row.related_debt_id : row.entity_id;
        const label = row.entity_id === debt.id
          ? row.kind === 'wrong_supplier' ? 'Now owed on' : row.kind === 'duplicate_liability' ? 'Duplicate of' : null
          : row.kind === 'wrong_supplier' ? 'Moved here from' : 'Duplicated by';
        return (
          <li key={row.id}>
            <strong>{ADJUSTMENT_LABELS[row.kind]}</strong>: {row.reason}
            <div className="meta">{row.recorded_by ?? '—'} · {dateTime(row.created_at)}
              {other && label && <> · {label} <Link href={`/finance/debts/${other}`}>this debt</Link></>}</div>
          </li>
        );
      })}
    </ul>
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

/**
 * Use credit a supplier already holds (money taken off another invoice) on
 * their open invoices, oldest first or the one given. No money moves.
 */
export function UseCreditForm({ supplierId, credit, owed, debtId }: {
  supplierId: string; credit: string; owed: string; debtId?: string;
}) {
  const most = Math.min(Number(credit), Number(owed));
  if (!(most > 0)) return null;
  return (
    <ActionForm action={applySupplierCredit} label="Use credit"
      hidden={{ supplier_id: supplierId, debt_ids: debtId ?? '', idempotency_key: randomUUID() }}>
      <p className="small muted">The supplier holds {tzs(credit)} from payments taken off other invoices. Using it moves no money.</p>
      <div className="field">
        <label htmlFor={`credit-${debtId ?? supplierId}`}>Amount (TZS)</label>
        <input id={`credit-${debtId ?? supplierId}`} name="amount" className="input" inputMode="decimal" defaultValue={String(most)} required />
      </div>
    </ActionForm>
  );
}
