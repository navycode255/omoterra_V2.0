'use client';

import { useActionState, useState } from 'react';
import { useFormStatus } from 'react-dom';
import { requestMarketReservation } from '@/lib/market-portal-actions';
import type { MarketSlot } from '@/lib/market';
import { date, label, number, units } from './supplier-format';
import { Busy } from '@/components/spinner';

function Submit() { const { pending } = useFormStatus(); return <button className="button button-primary" disabled={pending} type="submit">{pending ? <Busy>Sending…</Busy> : 'Request reservation'}</button>; }
export function MarketReserve({ slot }: { slot: MarketSlot }) {
  const [state, action] = useActionState(requestMarketReservation, null);
  const [choice, setChoice] = useState<'existing' | 'planned'>(slot.eligible_batches?.length ? 'existing' : 'planned');
  return <details className="market-reserve"><summary className="button button-primary">Reserve Supply</summary><div className="market-reserve-panel">
    <div className="market-reserve-title"><strong>{label(slot.category)}</strong><span>{date.format(new Date(slot.delivery_date))}</span></div>
    <div className="market-reserve-numbers"><span><small>Needed</small><b>{number.format(Number(slot.quantity_required))}</b></span><span><small>Remaining</small><b>{number.format(Number(slot.remaining_quantity))}</b></span></div>
    <form action={action} className="market-reserve-form"><input type="hidden" name="slot_id" value={slot.id} />
      <label>Quantity I can supply<input name="quantity" type="number" min="1" step={slot.unit_type === 'kg' ? '.001' : '1'} required placeholder="500" /><small>{units(slot.category, 2)}</small></label>
      <fieldset><legend>Production</legend><label><input type="radio" name="production_choice" value="existing" checked={choice === 'existing'} disabled={!slot.eligible_batches?.length} onChange={() => setChoice('existing')} /> Existing batch</label><label><input type="radio" name="production_choice" value="planned" checked={choice === 'planned'} onChange={() => setChoice('planned')} /> Plan a new batch</label></fieldset>
      {choice === 'existing' ? <label>Batch<select name="supplier_batch_id" required>{slot.eligible_batches?.map((batch) => <option key={batch.id} value={batch.id}>{number.format(Number(batch.available_quantity))} available · ready {batch.expected_ready_date ? date.format(new Date(batch.expected_ready_date)) : 'date not set'}</option>)}</select></label> : <div className="market-plan-dates"><span><small>Delivery</small><b>{date.format(new Date(slot.delivery_date))}</b></span>{slot.suggested_start_date && <span><small>Suggested batch start</small><b>{date.format(new Date(slot.suggested_start_date))}</b></span>}<p>Planning guidance based on your saved production cycle.</p></div>}
      {state && !state.ok && <p className="portal-form-error">{state.error}</p>}<Submit />
    </form>
  </div></details>;
}
