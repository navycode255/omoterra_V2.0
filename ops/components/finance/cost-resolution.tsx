'use client';

import { useActionState, useState } from 'react';
import { useFormStatus } from 'react-dom';
import { Busy } from '@/components/spinner';
import { resolveCost } from '@/lib/opening-stock-actions';
import type { OpeningStock } from '@/lib/finance';
import styles from './cost-states.module.css';

function Submit() {
  const { pending } = useFormStatus();
  return <button type="submit" className="button" disabled={pending}>{pending ? <Busy>Saving…</Busy> : 'Give this line its cost'}</button>;
}

/**
 * Admins give an unknown-cost sale line its cost (build plan M1.3): sold from
 * opening stock, an evidenced cost, or free (a known zero). Always with a
 * reason; the server records the line before and after.
 */
export function CostResolution({ saleId, itemId, unit, quantity, openingStock, idempotencyKey }: {
  saleId: string; itemId: string; unit: string; quantity: string; openingStock: OpeningStock[]; idempotencyKey: string;
}) {
  const [state, action] = useActionState(resolveCost, null);
  const choices = openingStock.filter((row) => row.unit === unit && Number(row.on_hand) >= Number(quantity));
  const [how, setHow] = useState<'opening_stock' | 'cost' | 'free'>(choices.length ? 'opening_stock' : 'cost');
  return <form action={action} className={styles.resolve}>
    <input type="hidden" name="sale_id" value={saleId} />
    <input type="hidden" name="item_id" value={itemId} />
    <input type="hidden" name="idempotency_key" value={idempotencyKey} />
    <input type="hidden" name="how" value={how} />
    <fieldset className={styles.choices}>
      <legend>Where does the cost come from?</legend>
      <label><input type="radio" checked={how === 'opening_stock'} onChange={() => setHow('opening_stock')} />Sold from opening stock</label>
      <label><input type="radio" checked={how === 'cost'} onChange={() => setHow('cost')} />An evidenced cost</label>
      <label><input type="radio" checked={how === 'free'} onChange={() => setHow('free')} />Free (it cost nothing)</label>
    </fieldset>
    {how === 'opening_stock' && <div className="field">
      <label htmlFor={`os-${itemId}`}>Opening stock</label>
      <select id={`os-${itemId}`} name="opening_stock_id" className="input" required defaultValue="">
        <option value="">Choose…</option>
        {choices.map((row) => <option key={row.id} value={row.id}>
          {row.receipt_number} · {(row.category || row.description).replaceAll('_', ' ')} · {Number(row.on_hand)} {row.unit} on hand · TZS {Number(row.unit_cost).toLocaleString('en-US')} each
        </option>)}
      </select>
      {!choices.length && <span className="meta">No opening stock in this unit has {quantity} on hand. Record it under Finance → Opening stock first.</span>}
    </div>}
    {how === 'cost' && <>
      <div className="field">
        <label htmlFor={`uc-${itemId}`}>Buying cost per unit (TZS)</label>
        <input id={`uc-${itemId}`} name="unit_cost" className="input" inputMode="decimal" required />
      </div>
      <div className="field">
        <label htmlFor={`ev-${itemId}`}>Evidence for this cost</label>
        <input id={`ev-${itemId}`} name="evidence" className="input" required minLength={3} placeholder="e.g. Receipt 0412, Kariakoo, 5,500 each" />
        <span className="meta">No supplier debt is opened. If someone is still owed for this stock, record that debt separately.</span>
      </div>
    </>}
    {how === 'free' && <p className="meta">A known zero: this stock cost Omoterra nothing (a gift). Only an admin records it.</p>}
    <div className="field">
      <label htmlFor={`rs-${itemId}`}>Reason</label>
      <input id={`rs-${itemId}`} name="reason" className="input" required minLength={3} />
    </div>
    {state && !state.ok && <div className="notice" data-tone="error">{state.error}</div>}
    <Submit />
  </form>;
}
