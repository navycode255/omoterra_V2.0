'use client';

import { useActionState, useState } from 'react';
import { useFormStatus } from 'react-dom';
import { Icons } from '@/components/icons';
import { recordSupplierBatchPayment } from '@/lib/finance-actions';
import { METHODS } from '@/lib/finance';
import { tzs } from '@/lib/format';
import styles from './finance-list.module.css';
import { Busy } from '@/components/spinner';

export type PayableSupplier = { supplier_id: string; name: string; owed: string };

function Submit() {
  const { pending } = useFormStatus();
  return <button type="submit" className={styles.payButton} disabled={pending}>{pending ? <Busy>Recording…</Busy> : 'Record payment'}</button>;
}

// "Pay supplier": one transfer to a registered supplier, spread over their
// oldest open invoices (or the one invoice opened from Debts), with proof and
// an optional receipt SMS.
export function PaySupplierPanel({ suppliers, selected, debt, now, idempotencyKey }: {
  suppliers: PayableSupplier[]; selected?: string; debt?: { id: string; balance: string; description: string } | null;
  now: string; idempotencyKey: string;
}) {
  const [state, action] = useActionState(recordSupplierBatchPayment, null);
  const [supplier, setSupplier] = useState(selected ?? '');
  const owedBy = (id: string) => (debt ? debt.balance : suppliers.find((row) => row.supplier_id === id)?.owed ?? '');
  const owed = owedBy(supplier);
  const [amount, setAmount] = useState(owed ? String(Number(owed)) : '');
  const [file, setFile] = useState('');
  const [sms, setSms] = useState(true);
  const [thanks, setThanks] = useState(true);

  return <form action={action} className={styles.payForm} id="pay">
    <h2>Pay supplier</h2>
    <input type="hidden" name="idempotency_key" value={idempotencyKey} />
    {debt && <input type="hidden" name="debt_ids" value={debt.id} />}
    {sms && <input type="hidden" name="send_receipt_sms" value="true" />}
    {sms && thanks && <input type="hidden" name="include_thank_you" value="true" />}
    <label>Supplier
      <select name="supplier_id" value={supplier} onChange={(event) => {
        // Choosing a supplier fills in what they are owed.
        const next = owedBy(event.target.value);
        setSupplier(event.target.value); setAmount(next ? String(Number(next)) : '');
      }} required>
        <option value="" disabled>Choose the supplier…</option>
        {suppliers.map((row) => <option key={row.supplier_id} value={row.supplier_id}>{row.name} · {tzs(row.owed)}</option>)}
      </select>
    </label>
    {debt && <p className={styles.payHint}>Paying one invoice: {debt.description}</p>}
    <label>Amount (TZS)
      <input name="amount" inputMode="decimal" value={amount} onChange={(event) => setAmount(event.target.value)} placeholder="Enter amount" required />
      {owed && <small className={styles.payHint}>Owed {tzs(owed)}. A smaller amount is a part payment, oldest invoices first.</small>}
    </label>
    <label>Payment method
      <select name="method" defaultValue="mpesa">{METHODS.map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select>
    </label>
    <div className={styles.dates}>
      <label>Date<input name="paid_on" type="date" defaultValue={now} max={now} required /></label>
      <label>Reference<input name="reference" placeholder="e.g. M-Pesa code" /></label>
    </div>
    <fieldset className={styles.proof}>
      <legend>Proof of payment</legend>
      <label className={styles.upload}>
        <input type="file" name="receipt" accept="image/jpeg,image/png,image/webp" onChange={(event) => setFile(event.target.files?.[0]?.name ?? '')} />
        <span><Icons.arrowUp size={18} />{file || 'Upload receipt or proof'}</span>
        <small>{file ? 'Tap to choose another' : 'PNG, JPG or WebP (max 10MB)'}</small>
      </label>
      <textarea name="sms_text" rows={3} placeholder="Paste payment confirmation SMS (optional)" />
    </fieldset>
    <label className={styles.switch}><input type="checkbox" checked={sms} onChange={(event) => setSms(event.target.checked)} /><span aria-hidden="true" />Send receipt to supplier</label>
    {sms && <div className={styles.smsOptions}>
      <label>Language<select name="receipt_language" defaultValue="en"><option value="en">English</option><option value="sw">Swahili</option></select></label>
      <label className={styles.switch}><input type="checkbox" checked={thanks} onChange={(event) => setThanks(event.target.checked)} /><span aria-hidden="true" />Include thank-you note</label>
    </div>}
    {state && !state.ok && <p className={styles.payError} role="alert">{state.error}</p>}
    <Submit />
    <p className={styles.payHint}>Use Record unregistered payment when a payment is not linked to an existing balance.</p>
  </form>;
}
