'use client';

import { createContext, useContext, useRef, useState, type ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import { Icons } from '@/components/icons';
import { createExpense } from '@/lib/finance-actions';
import { EXPENSE_CATEGORIES, METHODS } from '@/lib/finance';
import styles from './expenses.module.css';
import { Busy } from '@/components/spinner';

const OpenExpense = createContext<() => void>(() => {});
export function RecordExpenseButton() {
  const open = useContext(OpenExpense);
  return <button className={styles.primary} onClick={open}><Icons.plus size={19}/>Record expense</button>;
}
export function ExpenseWorkspace({ children, now, saleId, saleNumber, locationId, locationName }: { children?: ReactNode; now: string; saleId: string; saleNumber?: string; locationId?: string; locationName?: string }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const form = useRef<HTMLFormElement>(null);
  const key = useRef('');
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [paid, setPaid] = useState('full');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [saved, setSaved] = useState(false);
  function show() { if (!key.current) key.current = crypto.randomUUID(); setSaved(false); setOpen(true); dialog.current?.showModal(); }
  function close() { if (busy) return; dialog.current?.close(); setOpen(false); }
  async function submit(data: FormData) {
    setBusy(true); setError('');
    try {
      data.set('idempotency_key', key.current);
      const result = await createExpense(null, data);
      if (!result.ok) { setError(result.error); return; }
      form.current?.reset(); setPaid('full'); key.current = ''; dialog.current?.close(); setOpen(false); setSaved(true); router.refresh();
    } catch { setError('Could not save the expense. Please try again.'); }
    finally { setBusy(false); }
  }
  return <OpenExpense.Provider value={show}><div className={saleNumber || locationName ? undefined : `${styles.workspace} ${open ? styles.drawerOpen : ''}`}>
    {saleNumber || locationName ? <RecordExpenseButton/> : <div className={styles.heading}><h1>Expenses</h1><RecordExpenseButton/></div>}
    {saved && <p className={styles.success} role="status">Expense saved.</p>}
    {children}
    <dialog ref={dialog} className={styles.drawer} aria-labelledby="expense-drawer-title" onCancel={event => { if(busy) event.preventDefault(); }} onClose={() => setOpen(false)}>
      <div className={styles.drawerHeading}><h2 id="expense-drawer-title">Record an expense</h2><button type="button" className={styles.iconButton} aria-label="Close expense form" disabled={busy} onClick={close}><Icons.close/></button></div>
      <form ref={form} onSubmit={event => { event.preventDefault(); if (!busy) void submit(new FormData(event.currentTarget)); }} className={styles.expenseForm}>
        <input type="hidden" name="sale_id" value={saleId}/>
        {locationId && <input type="hidden" name="location_id" value={locationId}/>}
        <div className={styles.fields}>
          {locationName && <p>Expense for {locationName}. Included in this location’s running costs and total business expenses.</p>}
          {saleId && <p>This expense is linked to {saleNumber ? `sale ${saleNumber}` : 'this sale'} and included in total expenses, whether paid or owed.</p>}
          <label>Date<input name="spent_on" type="date" defaultValue={now} max={now} required autoFocus/></label>
          <label>Category<select name="category" required>{EXPENSE_CATEGORIES.map(([id,label]) => <option key={id} value={id}>{label}</option>)}</select></label>
          <label>What for<input name="description" required minLength={2} placeholder={saleId ? 'e.g. Extra transport or packaging for this sale' : 'e.g. 3 helpers for chicken prep'}/></label>
          <label>Amount (TZS)<input name="amount" type="number" min="0.01" step="0.01" inputMode="decimal" required/></label>
          <fieldset className={styles.paymentStatus}><legend>Payment status</legend><div>{[['full','Paid now'],['part','Part paid'],['none','Owed']].map(([value,label]) => <label key={value} data-selected={paid===value}><input type="radio" name="paid_now" value={value} checked={paid===value} onChange={() => setPaid(value)}/>{label}</label>)}</div></fieldset>
          <section className={styles.paymentDetails}><h3><Icons.card size={19}/>{paid==='none' ? 'Expense details' : 'Payment details'}</h3>
            {paid==='part' && <label>Amount paid now (TZS)<input name="paid_amount" type="number" min="0.01" step="0.01" inputMode="decimal" required/></label>}
            {paid!=='none' && <label>Payment method<select name="method" defaultValue="cash">{METHODS.map(([id,label]) => <option key={id} value={id}>{label}</option>)}</select></label>}
            <label>{paid==='none' ? 'Owed to' : 'Paid to'}<input name="paid_to" placeholder="e.g. Juma transport"/></label>
            {paid!=='none' && <label>Reference (optional)<input name="reference"/></label>}
            {paid!=='full' && <label>Due date (optional)<input name="due_on" type="date"/></label>}
            <details className={styles.more}><summary>Add phone number</summary><label>Phone (optional)<input name="paid_to_phone" type="tel" inputMode="tel"/></label></details>
          </section>
          {error && <div role="alert" className={styles.error}>{error}</div>}
        </div>
        <footer className={styles.formFooter}><button type="button" className={styles.secondary} disabled={busy} onClick={close}>Cancel</button><button type="submit" className={styles.primary} disabled={busy}>{busy ? <Busy>Saving…</Busy> : 'Save expense'}</button></footer>
      </form>
    </dialog>
  </div></OpenExpense.Provider>;
}
