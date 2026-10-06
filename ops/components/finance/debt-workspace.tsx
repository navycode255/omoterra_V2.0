'use client';
import { useMemo, useRef, useState, type ReactNode } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Icons } from '@/components/icons';
import { createDebt } from '@/lib/finance-actions';
import type { Parties } from '@/lib/finance';
import ui from './expenses.module.css';
import styles from './finance-list.module.css';
import { Busy } from '@/components/spinner';

// The Debts page frame: heading with "Add debt", and the drawer that adds one.
export function DebtWorkspace({ children, parties, now }: { children: ReactNode; parties: Parties; now: string }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const form = useRef<HTMLFormElement>(null);
  const key = useRef('');
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [direction, setDirection] = useState('receivable');
  const [who, setWho] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [saved, setSaved] = useState(false);

  // Known buyers and suppliers, matched by what is typed into "Who"; any
  // other name is saved as typed.
  const known = useMemo(() => [
    ...parties.suppliers.map((p) => ({ value: `supplier:${p.id}`, label: `${p.name}${p.phone ? ` · ${p.phone}` : ''}`, kind: 'Supplier' })),
    ...parties.buyers.filter((p) => p.kind === 'profile').map((p) => ({ value: `buyer:${p.id}`, label: `${p.name}${p.phone ? ` · ${p.phone}` : ''}`, kind: 'Buyer' })),
  ], [parties]);
  const match = known.find((option) => option.label === who.trim());

  function show() { if (!key.current) key.current = crypto.randomUUID(); setOpen(true); setSaved(false); dialog.current?.showModal(); }
  function close() { if (busy) return; dialog.current?.close(); setOpen(false); }
  async function submit(data: FormData) {
    setBusy(true); setError('');
    try {
      data.set('idempotency_key', key.current);
      data.set('party', match?.value ?? '');
      data.set('party_name', match ? '' : who.trim());
      const result = await createDebt(null, data);
      if (!result.ok) { setError(result.error); return; }
      form.current?.reset(); setDirection('receivable'); setWho(''); key.current = '';
      dialog.current?.close(); setOpen(false); setSaved(true); router.refresh();
    } catch { setError('Could not save the debt. Please try again.'); } finally { setBusy(false); }
  }

  return <div className={`${ui.workspace} ${styles.page} ${open ? ui.drawerOpen : ''}`}>
    <div className={ui.heading}><h1>Debts</h1><div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', justifyContent: 'flex-end' }}>
      <Link className={ui.secondary} href="/finance/debts/receive" title="One amount from a customer, put on their oldest debts first">Receive customer payment</Link>
      <button className={ui.primary} onClick={show}><Icons.plus size={19} />Add debt</button></div></div>
    {saved && <p className={ui.success} role="status">Debt saved.</p>}
    {children}
    <dialog ref={dialog} className={ui.drawer} aria-labelledby="debt-drawer-title" onCancel={(event) => { if (busy) event.preventDefault(); }} onClose={() => setOpen(false)}>
      <div className={ui.drawerHeading}><h2 id="debt-drawer-title">Add a debt</h2><button className={ui.iconButton} type="button" disabled={busy} onClick={close} aria-label="Close debt form"><Icons.close /></button></div>
      <form ref={form} onSubmit={(event) => { event.preventDefault(); if (!busy) void submit(new FormData(event.currentTarget)); }} className={ui.expenseForm}>
        <div className={ui.fields}>
          <fieldset className={`${ui.paymentStatus} ${styles.direction}`}><legend>Direction</legend><div>
            {[['receivable', 'They owe me'], ['payable', 'I owe them']].map(([value, label]) => <label key={value} data-selected={direction === value}>
              <input type="radio" name="direction" value={value} checked={direction === value} onChange={() => setDirection(value)} />{label}
            </label>)}
          </div></fieldset>
          <label>Who
            <input list="debt-parties" value={who} onChange={(event) => setWho(event.target.value)} required minLength={2} autoComplete="off" placeholder="Search or enter name" />
            <datalist id="debt-parties">{known.map((option) => <option key={option.value} value={option.label}>{option.kind}</option>)}</datalist>
            {who.trim() && <small className={styles.hint}>{match ? `${match.kind} on record` : 'New name — saved as typed'}</small>}
          </label>
          {!match && <label>Phone (optional)<input name="party_phone" type="tel" inputMode="tel" placeholder="e.g. +255 712 345 678" /></label>}
          <label>What for<input name="description" required minLength={2} placeholder="e.g. Stock for sale, Transport, Feed etc." /></label>
          <label>Amount (TZS)<input name="amount" type="number" min="0.01" step="0.01" inputMode="decimal" required /></label>
          <div className={styles.dates}>
            <label>Date<input name="incurred_on" type="date" defaultValue={now} max={now} required /></label>
            <label>Due date (optional)<input name="due_on" type="date" /></label>
          </div>
          <label>Reference (optional)<input name="reference" maxLength={80} placeholder="e.g. Invoice No. / Note" /></label>
          <label>Notes (optional)<textarea name="note" rows={3} maxLength={300} placeholder="Add a note…" /></label>
          {error && <div className={ui.error} role="alert">{error}</div>}
        </div>
        <footer className={ui.formFooter}><button type="button" className={ui.secondary} onClick={close} disabled={busy}>Cancel</button><button className={ui.primary} type="submit" disabled={busy}>{busy ? <Busy>Saving…</Busy> : 'Save debt'}</button></footer>
      </form>
    </dialog>
  </div>;
}
