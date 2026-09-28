'use client';

import { useState } from 'react';
import { ActionForm } from '@/components/form';
import type { ActionResult } from '@/lib/actions';
import { MARKET_PRODUCTS, type MarketSlot } from '@/lib/market';

export function MarketSlotForm({ action, slot }: { action: (state: ActionResult | null, form: FormData) => Promise<ActionResult>; slot?: MarketSlot }) {
  const [category, setCategory] = useState(slot?.category ?? 'broilers');
  const unit = MARKET_PRODUCTS.find(([id]) => id === category)?.[2] ?? 'bird';
  return <ActionForm action={action} label={slot ? 'Save changes' : 'Publish market'} hidden={slot ? { id: slot.id } : undefined}>
    <input type="hidden" name="unit_type" value={unit} />
    <div className="grid-2">
      <div className="field"><label htmlFor="category">Product</label><select className="input" id="category" name="category" value={category} onChange={(event) => setCategory(event.target.value)}>{MARKET_PRODUCTS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}</select></div>
      <div className="field"><label>Unit</label><input className="input" value={unit} readOnly /></div>
      <div className="field"><label htmlFor="delivery_date">Delivery date</label><input className="input" id="delivery_date" name="delivery_date" type="date" defaultValue={slot?.delivery_date} required /></div>
      <div className="field"><label htmlFor="reservation_deadline">Reservation deadline</label><input className="input" id="reservation_deadline" name="reservation_deadline" type="date" defaultValue={slot?.reservation_deadline} required /></div>
      <div className="field"><label htmlFor="quantity_required">Quantity required</label><input className="input" id="quantity_required" name="quantity_required" inputMode="decimal" defaultValue={slot?.quantity_required} required /></div>
      <div className="field"><label htmlFor="price_per_unit">Price per {unit}</label><input className="input" id="price_per_unit" name="price_per_unit" inputMode="decimal" defaultValue={slot?.price_per_unit ?? ''} /></div>
      <div className="field"><label htmlFor="minimum_weight_kg">Minimum weight (kg)</label><input className="input" id="minimum_weight_kg" name="minimum_weight_kg" inputMode="decimal" defaultValue={slot?.minimum_weight_kg ?? ''} /></div>
      <div className="field"><label htmlFor="maximum_weight_kg">Maximum weight (kg)</label><input className="input" id="maximum_weight_kg" name="maximum_weight_kg" inputMode="decimal" defaultValue={slot?.maximum_weight_kg ?? ''} /></div>
      <div className="field"><label htmlFor="supply_type">Supply type</label><select className="input" id="supply_type" name="supply_type" defaultValue={slot?.supply_type ?? 'live'}><option value="live">Live</option><option value="dressed">Dressed</option><option value="chilled">Chilled</option><option value="frozen">Frozen</option></select></div>
      <div className="field"><label htmlFor="collection_method">Collection</label><select className="input" id="collection_method" name="collection_method" defaultValue={slot?.collection_method ?? 'omoterra_collects'}><option value="omoterra_collects">Omoterra collects</option><option value="supplier_delivers">Supplier delivers</option></select></div>
      <div className="field"><label htmlFor="region">Region</label><input className="input" id="region" name="region" defaultValue={slot?.region ?? ''} /></div>
      <div className="field"><label htmlFor="collection_point">Collection point</label><input className="input" id="collection_point" name="collection_point" defaultValue={slot?.collection_point ?? ''} /></div>
      <div className="field"><label htmlFor="status">Publishing</label><select className="input" id="status" name="status" defaultValue={slot?.status === 'draft' ? 'draft' : 'open'}><option value="open">Publish to suppliers</option><option value="draft">Save as draft</option></select></div>
    </div>
    <div className="field"><label htmlFor="internal_note">Internal note (optional)</label><textarea className="input" id="internal_note" name="internal_note" defaultValue={slot?.internal_note ?? ''} rows={3} /></div>
  </ActionForm>;
}
