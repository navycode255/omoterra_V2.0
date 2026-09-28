'use client';

import { useMemo, useState } from 'react';
import { ActionForm } from '@/components/form';
import { recordSupplierBatchPayment } from '@/lib/finance-actions';
import { METHODS, day, today, type Debt } from '@/lib/finance';
import { tzs } from '@/lib/format';

export function SupplierPaymentForm({ supplierId, debts, idempotencyKey }: {
  supplierId: string; debts: Debt[]; idempotencyKey: string;
}) {
  const [selected, setSelected] = useState(() => new Set(debts.map((debt) => debt.id)));
  const [mode, setMode] = useState<'full' | 'partial'>('full');
  const [partialAmount, setPartialAmount] = useState('');
  const total = useMemo(() => debts.filter((debt) => selected.has(debt.id))
    .reduce((sum, debt) => sum + Number(debt.balance), 0), [debts, selected]);
  const toggle = (id: string) => setSelected((current) => {
    const next = new Set(current);
    if (next.has(id)) next.delete(id); else next.add(id);
    return next;
  });

  return (
    <ActionForm action={recordSupplierBatchPayment} label={mode === 'full' ? `Pay ${tzs(String(total))}` : 'Record part payment'}
      hidden={{ supplier_id: supplierId, idempotency_key: idempotencyKey }}>
      <fieldset className="supplier-invoice-picker">
        <legend>Invoices included</legend>
        <p className="meta">All open invoices are selected. Untick any invoice if you only want to pay specific orders.</p>
        {debts.map((debt) => (
          <label key={debt.id} className="supplier-invoice-option">
            <input type="checkbox" name="debt_ids" value={debt.id} checked={selected.has(debt.id)} onChange={() => toggle(debt.id)} />
            <span><strong>{debt.description}</strong><small>{day(debt.incurred_on)} · {debt.lpo_id ? 'Received batch' : debt.sale_id ? 'Sale' : 'Supplier invoice'}</small></span>
            <b>{tzs(debt.balance)}</b>
          </label>
        ))}
      </fieldset>

      <div className="supplier-pay-choice" role="radiogroup" aria-label="Payment amount">
        <label><input type="radio" name="payment_mode" value="full" checked={mode === 'full'} onChange={() => setMode('full')} /> Pay selected balance <b>{tzs(String(total))}</b></label>
        <label><input type="radio" name="payment_mode" value="partial" checked={mode === 'partial'} onChange={() => setMode('partial')} /> Pay a different amount</label>
      </div>
      <div className="field">
        <label htmlFor={`amount-${supplierId}`}>Amount paid (TZS)</label>
        <input id={`amount-${supplierId}`} name="amount" className="input" inputMode="decimal"
          value={mode === 'full' ? String(total) : partialAmount} onChange={(event) => setPartialAmount(event.target.value)}
          readOnly={mode === 'full'} placeholder={mode === 'partial' ? `Up to ${total}` : undefined} min="1" max={total} required />
        {mode === 'partial' && <span className="meta">The payment is applied to the oldest selected invoice first.</span>}
      </div>
      <div className="grid-2">
        <div className="field"><label htmlFor={`paid-${supplierId}`}>Date paid</label><input id={`paid-${supplierId}`} name="paid_on" type="date" className="input" defaultValue={today()} max={today()} required /></div>
        <div className="field"><label htmlFor={`method-${supplierId}`}>Method</label><select id={`method-${supplierId}`} name="method" className="input" defaultValue="mpesa">{METHODS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}</select></div>
      </div>
      <div className="receipt-evidence">
        <div><strong>Add payment proof</strong><p className="meta">Add at least one: receipt number, payment SMS, or receipt image. You may add all three.</p></div>
        <div className="field"><label htmlFor={`reference-${supplierId}`}>Receipt / transaction number</label><input id={`reference-${supplierId}`} name="reference" className="input" placeholder="e.g. QI87KD92" /></div>
        <div className="field"><label htmlFor={`sms-${supplierId}`}>Payment SMS</label><textarea id={`sms-${supplierId}`} name="sms_text" className="input" rows={3} placeholder="Paste the payment confirmation SMS" /></div>
        <div className="field"><label htmlFor={`receipt-${supplierId}`}>Receipt image</label><input id={`receipt-${supplierId}`} name="receipt" className="input" type="file" accept="image/jpeg,image/png,image/webp" /></div>
      </div>
      <div className="field"><label htmlFor={`note-${supplierId}`}>Note (optional)</label><input id={`note-${supplierId}`} name="note" className="input" placeholder="Anything the supplier should know" /></div>
      {!selected.size && <div className="notice" data-tone="error">Select at least one invoice.</div>}
    </ActionForm>
  );
}
