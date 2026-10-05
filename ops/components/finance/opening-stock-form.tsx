'use client';

import { useActionState, useRef, useState } from 'react';
import { useFormStatus } from 'react-dom';
import { Busy } from '@/components/spinner';
import { DEFAULT_UNIT, PRODUCTS, UNITS } from '@/lib/finance';
import { recordOpeningStock } from '@/lib/opening-stock-actions';
import styles from './cost-states.module.css';

function Submit() {
  const { pending } = useFormStatus();
  return <button type="submit" className="button" disabled={pending}>{pending ? <Busy>Saving…</Busy> : 'Record opening stock'}</button>;
}

const num = (value: string) => Number(value.replace(/,/g, ''));

/**
 * Stock held before the system, at the value the finance owner gives it
 * (decision D3). Admins only. It opens no supplier debt.
 */
export function OpeningStockForm({ today, valuedBy }: { today: string; valuedBy: string }) {
  const [key, setKey] = useState(() => crypto.randomUUID());
  const [category, setCategory] = useState('local_chicken');
  const [unit, setUnit] = useState('bird');
  const [quantity, setQuantity] = useState('');
  const [valueKind, setValueKind] = useState<'unit' | 'total'>('unit');
  const [value, setValue] = useState('');
  const form = useRef<HTMLFormElement>(null);
  // A saved entry clears the form and takes a fresh key for the next one.
  const [state, action] = useActionState(async (previous: Awaited<ReturnType<typeof recordOpeningStock>> | null, formData: FormData) => {
    const result = await recordOpeningStock(previous, formData);
    if (result.ok) { form.current?.reset(); setQuantity(''); setValue(''); setKey(crypto.randomUUID()); }
    return result;
  }, null);
  const q = num(quantity), v = num(value);
  const total = valueKind === 'unit' ? q * v : v;
  const each = valueKind === 'unit' ? v : v / q;
  return <form ref={form} action={action} className={styles.formGrid}>
    <input type="hidden" name="idempotency_key" value={key} />
    <input type="hidden" name="value_kind" value={valueKind} />
    <div className="field">
      <label htmlFor="os-category">Product</label>
      <select id="os-category" name="category" className="input" value={category}
        onChange={(e) => { setCategory(e.target.value); setUnit(DEFAULT_UNIT[e.target.value] ?? unit); }}>
        {PRODUCTS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
        <option value="">Something else</option>
      </select>
    </div>
    <div className="field">
      <label htmlFor="os-description">Details {category ? '(optional)' : ''}</label>
      <input id="os-description" name="description" className="input" required={!category} minLength={category ? 0 : 2}
        placeholder="e.g. Kienyeji hens at the Tegeta pen" />
    </div>
    <div className="field">
      <label htmlFor="os-unit">Unit</label>
      <select id="os-unit" name="unit" className="input" value={unit} onChange={(e) => setUnit(e.target.value)}>
        {UNITS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
      </select>
    </div>
    <div className="field">
      <label htmlFor="os-quantity">Quantity on hand</label>
      <input id="os-quantity" name="quantity" className="input" inputMode="decimal" required value={quantity}
        onChange={(e) => setQuantity(e.target.value)} />
    </div>
    <div className="field">
      <label htmlFor="os-value-kind">Value given as</label>
      <select id="os-value-kind" className="input" value={valueKind} onChange={(e) => setValueKind(e.target.value as 'unit' | 'total')}>
        <option value="unit">Cost per unit</option>
        <option value="total">Total value</option>
      </select>
    </div>
    <div className="field">
      <label htmlFor="os-value">{valueKind === 'unit' ? 'Cost per unit (TZS)' : 'Total value (TZS)'}</label>
      <input id="os-value" name="value" className="input" inputMode="decimal" required value={value} onChange={(e) => setValue(e.target.value)} />
      <span className="meta">{Number.isFinite(total) && total > 0
        ? `Total TZS ${Math.round(total).toLocaleString('en-US')} · TZS ${Math.round(each).toLocaleString('en-US')} each` : 'What this stock cost Omoterra.'}</span>
    </div>
    <div className="field">
      <label htmlFor="os-as-of">Valued as of</label>
      <input id="os-as-of" name="as_of" type="date" className="input" max={today} defaultValue={today} required />
    </div>
    <div className="field">
      <label htmlFor="os-valued-by">Value given by</label>
      <input id="os-valued-by" name="valued_by" className="input" required minLength={2} defaultValue={valuedBy} />
    </div>
    <div className={`field ${styles.wide}`}>
      <label htmlFor="os-evidence">Evidence or reason for this value</label>
      <textarea id="os-evidence" name="evidence" className="input" required minLength={3}
        placeholder="e.g. Counted 50 on 1 Oct; bought in September at 6,000 each (M-Pesa statement)" />
      <span className="meta">Opening stock was paid for before the system, so no supplier is owed and no payable is opened.</span>
    </div>
    {state && !state.ok && <div className={`notice ${styles.wide}`} data-tone="error">{state.error}</div>}
    {state?.ok && <div className={`notice ${styles.wide}`} role="status">Opening stock recorded.</div>}
    <div className={styles.wide}><Submit /></div>
  </form>;
}
