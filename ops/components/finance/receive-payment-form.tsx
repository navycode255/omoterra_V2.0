'use client';

import { useMemo, useState } from 'react';
import { ActionForm } from '@/components/form';
import { AccountSelect } from '@/components/finance/account-select';
import { recordBuyerPayment } from '@/lib/finance-actions';
import { METHODS, day, type Debt } from '@/lib/finance';
import { tzs } from '@/lib/format';

// Whole cents, so the preview never drifts from what the server records.
const cents = (value: string) => Math.round(Number(value.replace(/,/g, '')) * 100);
const money = (value: number) => tzs((value / 100).toFixed(2));

/**
 * One amount from a customer. The preview shows where it will go: the oldest
 * debt is paid off first, then the next, exactly as the backend records it.
 */
export function ReceivePaymentForm({ buyerId, debts, today, idempotencyKey }: {
  buyerId: string; debts: Debt[]; today: string; idempotencyKey: string;
}) {
  const [amount, setAmount] = useState('');
  const owed = debts.reduce((sum, debt) => sum + cents(debt.balance), 0);
  const entered = amount.trim() && Number.isFinite(Number(amount.replace(/,/g, ''))) ? cents(amount) : 0;
  const split = useMemo(() => {
    const rows: { debt: Debt; take: number; after: number }[] = [];
    let left = Math.max(entered, 0);
    for (const debt of debts) {
      const balance = cents(debt.balance);
      const take = Math.min(left, balance);
      left -= take;
      rows.push({ debt, take, after: balance - take });
    }
    return rows;
  }, [debts, entered]);
  const over = entered > owed;

  return (
    <ActionForm action={recordBuyerPayment} label="Record payment"
      hidden={{ buyer_profile_id: buyerId, idempotency_key: idempotencyKey }}>
      <div className="grid-2">
        <div className="field">
          <label htmlFor="receive-amount">Amount received (TZS) · owes {money(owed)}</label>
          <input id="receive-amount" name="amount" className="input" inputMode="decimal" required autoComplete="off"
            value={amount} onChange={(event) => setAmount(event.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="receive-date">Date</label>
          <input id="receive-date" name="paid_on" type="date" className="input" defaultValue={today} max={today} required />
        </div>
        <div className="field">
          <label htmlFor="receive-method">Method</label>
          <select id="receive-method" name="method" className="input" defaultValue="cash">
            {METHODS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
          </select>
        </div>
        <AccountSelect id="receive-account" />
        <div className="field">
          <label htmlFor="receive-reference">Transaction reference</label>
          <input id="receive-reference" name="reference" className="input" placeholder="e.g. M-Pesa code" />
        </div>
        <div className="field">
          <label htmlFor="receive-note">Note</label>
          <input id="receive-note" name="note" className="input" />
        </div>
      </div>

      <div className="table-wrap">
        <table>
          <thead><tr><th>Debt</th><th>Date</th><th className="numeric">Owed now</th><th className="numeric">This payment</th><th className="numeric">Left after</th></tr></thead>
          <tbody>{split.map(({ debt, take, after }) => (
            <tr key={debt.id} style={take === 0 && entered > 0 ? { opacity: 0.6 } : undefined}>
              <td>{debt.description}</td>
              <td className="small">{day(debt.incurred_on)}</td>
              <td className="numeric money">{tzs(debt.balance)}</td>
              <td className="numeric money">{take > 0 ? money(take) : '—'}</td>
              <td className="numeric money">{after === 0 ? 'Paid off' : money(after)}</td>
            </tr>
          ))}</tbody>
        </table>
      </div>
      {over
        ? <div className="notice" data-tone="error">That is more than the customer owes ({money(owed)}).</div>
        : <p className="meta">The oldest debt is paid first, then the next. It is saved as one payment in the cash book, and each debt shows its part.</p>}
    </ActionForm>
  );
}
