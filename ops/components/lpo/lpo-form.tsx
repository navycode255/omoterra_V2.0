'use client';

import { useActionState, useMemo, useState } from 'react';
import { useFormStatus } from 'react-dom';
import { saveLpo } from '@/lib/lpo-actions';
import { PRODUCTS, UNITS } from '@/lib/finance';
import type { DemandRow, LpoDetail, SupplierSuggestion } from '@/lib/lpo';

type Line = {
  key: number; category: string; item: string; specification: string; unit: string; unit_price: string;
  quantity: string; min_weight_kg: string; max_weight_kg: string;
};

const clean = (value: string) => value.replace(/,/g, '').trim();
const label = (value: string) => PRODUCTS.find(([key]) => key === value)?.[1] ?? value;

function Submit({ editing }: { editing: boolean }) {
  const { pending } = useFormStatus();
  return <button type="submit" className="button" disabled={pending}>{pending ? 'Saving…' : editing ? 'Save draft' : 'Create draft LPO'}</button>;
}

export function LpoForm({ suggested, others, today, demand, lpo }: {
  suggested: SupplierSuggestion[]; others: SupplierSuggestion[]; today: string; demand: DemandRow | null; lpo: LpoDetail | null;
}) {
  const [state, action] = useActionState(saveLpo, null);
  const [idempotencyKey] = useState(() => crypto.randomUUID());
  const [supplier, setSupplier] = useState(lpo?.supplier_id ?? suggested[0]?.supplier_id ?? '');
  const [lpoDate, setLpoDate] = useState(lpo?.lpo_date ?? today);
  const [start, setStart] = useState(lpo?.delivery_start ?? today);
  const defaultEnd = demand?.needed_by_date && demand.needed_by_date >= today ? demand.needed_by_date : today;
  const [end, setEnd] = useState(lpo?.delivery_end ?? defaultEnd);
  const [terms, setTerms] = useState(String(lpo?.payment_terms_days ?? 2));
  const [basis, setBasis] = useState<'call_off' | 'fixed'>(lpo?.supply_basis ?? (demand ? 'fixed' : 'call_off'));
  const [point, setPoint] = useState(lpo?.collection_point ?? '');
  const [notes, setNotes] = useState(lpo?.internal_notes ?? '');
  const [standard, setStandard] = useState(!lpo);
  const [deliveryNotes, setDeliveryNotes] = useState((lpo?.delivery_notes ?? []).join('\n'));
  const [termsText, setTermsText] = useState((lpo?.terms ?? []).join('\n'));
  const chosen = [...suggested, ...others].find((s) => s.supplier_id === supplier);
  const [lines, setLines] = useState<Line[]>(() => lpo?.lines.length ? lpo.lines.map((l, i) => ({
    key: i + 1, category: l.category, item: l.item, specification: l.specification, unit: l.unit, unit_price: l.unit_price,
    quantity: l.quantity ?? '', min_weight_kg: l.min_weight_kg ?? '', max_weight_kg: l.max_weight_kg ?? '',
  })) : [{
    key: 1, category: demand?.category ?? 'broilers', item: demand ? label(demand.category) : 'Broiler chickens',
    specification: demand ? `Live ${label(demand.category).toLowerCase()}${demand.minimum_weight_kg ? `, target weight ${Number(demand.minimum_weight_kg)} to ${Number(demand.maximum_weight_kg ?? demand.minimum_weight_kg)} kg per bird` : ''}, healthy and market ready, subject to Omoterra quality inspection and acceptance.`
      : 'Live broiler chickens, target weight 0.95 to 1.2 kg per bird, healthy and market ready, subject to Omoterra quality inspection and acceptance.',
    unit: demand?.unit_type ?? 'bird', unit_price: suggested[0]?.last_price ?? '', quantity: demand ? String(Number(demand.short)) : '',
    min_weight_kg: demand?.minimum_weight_kg ?? (demand ? '' : '0.95'), max_weight_kg: demand?.maximum_weight_kg ?? (demand ? '' : '1.2'),
  }]);

  function update(key: number, change: Partial<Line>) {
    setLines((all) => all.map((l) => (l.key === key ? { ...l, ...change } : l)));
  }

  const payload = useMemo(() => JSON.stringify({
    supplier_id: supplier, demand_id: lpo ? lpo.demand_id : demand?.id ?? null, lpo_date: lpoDate, delivery_start: start,
    delivery_end: end, payment_terms_days: Number(terms || 0), supply_basis: basis, collection_point: point, internal_notes: notes,
    delivery_notes: standard ? [] : deliveryNotes.split('\n').map((t) => t.trim()).filter(Boolean),
    terms: standard ? [] : termsText.split('\n').map((t) => t.trim()).filter(Boolean),
    lines: lines.map((l) => ({
      category: l.category || null, item: l.item, specification: l.specification, unit: l.unit, unit_price: clean(l.unit_price),
      quantity: clean(l.quantity) || null, min_weight_kg: clean(l.min_weight_kg) || null, max_weight_kg: clean(l.max_weight_kg) || null,
    })),
  }), [supplier, lpo, demand, lpoDate, start, end, terms, basis, point, notes, standard, deliveryNotes, termsText, lines]);

  return (
    <form action={action} className="stack">
      <input type="hidden" name="payload" value={payload} />
      <input type="hidden" name="id" value={lpo?.id ?? ''} />
      <input type="hidden" name="idempotency_key" value={idempotencyKey} />

      <section className="card stack">
        <h3>1. Supplier</h3>
        <div className="field">
          <label htmlFor="supplier">Supplier (approved suppliers only)</label>
          <select id="supplier" className="input" value={supplier} onChange={(e) => setSupplier(e.target.value)} required>
            <option value="">Choose a supplier…</option>
            {suggested.length > 0 && <optgroup label="Suggested for this product">
              {suggested.map((s) => <option key={s.supplier_id} value={s.supplier_id}>{s.name}{s.region ? ` · ${s.region}` : ''} · {s.reasons.join('; ')}</option>)}
            </optgroup>}
            <optgroup label={suggested.length ? 'Other approved suppliers' : 'Approved suppliers'}>
              {others.map((s) => <option key={s.supplier_id} value={s.supplier_id}>{s.name}{s.region ? ` · ${s.region}` : ''} · {s.phone}</option>)}
            </optgroup>
          </select>
          {chosen?.last_price && <span className="meta">Last LPO price from this supplier: TZS {Number(chosen.last_price).toLocaleString('en-US')}</span>}
          <span className="meta">Supplier not listed? <a href="/suppliers/new" target="_blank">Add the supplier</a> and approve them, then reload this page.</span>
        </div>
      </section>

      <section className="card stack">
        <h3>2. Order details</h3>
        <div className="grid-3">
          <div className="field"><label htmlFor="lpo_date">LPO date</label>
            <input id="lpo_date" type="date" className="input" value={lpoDate} onChange={(e) => setLpoDate(e.target.value)} required /></div>
          <div className="field"><label htmlFor="start">Delivery from</label>
            <input id="start" type="date" className="input" value={start} onChange={(e) => setStart(e.target.value)} required /></div>
          <div className="field"><label htmlFor="end">Delivery until</label>
            <input id="end" type="date" className="input" value={end} min={start} onChange={(e) => setEnd(e.target.value)} required /></div>
          <div className="field"><label htmlFor="terms">Pay within (days of accepting each batch)</label>
            <input id="terms" type="number" min={0} max={180} className="input" value={terms} onChange={(e) => setTerms(e.target.value)} required /></div>
          <div className="field"><label htmlFor="basis">Supply basis</label>
            <select id="basis" className="input" value={basis} onChange={(e) => setBasis(e.target.value as 'call_off' | 'fixed')}>
              <option value="call_off">Batch by batch (call off), quantity not fixed</option>
              <option value="fixed">Fixed quantity</option>
            </select></div>
          <div className="field"><label htmlFor="point">Collection / handover point</label>
            <input id="point" className="input" placeholder="Supplier farm address if empty" value={point} onChange={(e) => setPoint(e.target.value)} /></div>
        </div>
      </section>

      <section className="card stack">
        <h3>3. Items</h3>
        {lines.map((line, index) => (
          <fieldset key={line.key} className="stack" style={{ border: '1px solid var(--border)', borderRadius: 12, padding: 'var(--s4)' }}>
            <legend className="strong small">Line {index + 1}</legend>
            <div className="grid-3">
              <div className="field"><label htmlFor={`cat-${line.key}`}>Product</label>
                <select id={`cat-${line.key}`} className="input" value={line.category} onChange={(e) => update(line.key, { category: e.target.value })}>
                  {PRODUCTS.map(([id, text]) => <option key={id} value={id}>{text}</option>)}
                  <option value="">Other</option>
                </select></div>
              <div className="field"><label htmlFor={`item-${line.key}`}>Item name (printed)</label>
                <input id={`item-${line.key}`} className="input" required minLength={2} value={line.item} onChange={(e) => update(line.key, { item: e.target.value })} /></div>
              <div className="field"><label htmlFor={`unit-${line.key}`}>Unit</label>
                <select id={`unit-${line.key}`} className="input" value={line.unit} onChange={(e) => update(line.key, { unit: e.target.value })}>
                  {UNITS.map(([id, text]) => <option key={id} value={id}>{text}</option>)}
                </select></div>
              <div className="field"><label htmlFor={`price-${line.key}`}>Unit price (TZS)</label>
                <input id={`price-${line.key}`} className="input" inputMode="decimal" required value={line.unit_price} onChange={(e) => update(line.key, { unit_price: e.target.value })} /></div>
              <div className="field"><label htmlFor={`qty-${line.key}`}>Quantity {basis === 'call_off' ? '(empty = as requested per batch)' : ''}</label>
                <input id={`qty-${line.key}`} className="input" inputMode="decimal" required={basis === 'fixed'} value={line.quantity} onChange={(e) => update(line.key, { quantity: e.target.value })} /></div>
              <div className="grid-2">
                <div className="field"><label htmlFor={`min-${line.key}`}>Min kg</label>
                  <input id={`min-${line.key}`} className="input" inputMode="decimal" value={line.min_weight_kg} onChange={(e) => update(line.key, { min_weight_kg: e.target.value })} /></div>
                <div className="field"><label htmlFor={`max-${line.key}`}>Max kg</label>
                  <input id={`max-${line.key}`} className="input" inputMode="decimal" value={line.max_weight_kg} onChange={(e) => update(line.key, { max_weight_kg: e.target.value })} /></div>
              </div>
            </div>
            <div className="field"><label htmlFor={`spec-${line.key}`}>Specification (printed)</label>
              <textarea id={`spec-${line.key}`} className="input" rows={2} value={line.specification} onChange={(e) => update(line.key, { specification: e.target.value })} /></div>
            {lines.length > 1 && <div><button type="button" className="button" data-variant="secondary"
              onClick={() => setLines((all) => all.filter((l) => l.key !== line.key))}>Remove line</button></div>}
          </fieldset>
        ))}
        <div><button type="button" className="button" data-variant="secondary" onClick={() => setLines((all) => [...all, {
          key: Math.max(...all.map((l) => l.key)) + 1, category: 'broilers', item: '', specification: '', unit: 'bird',
          unit_price: '', quantity: '', min_weight_kg: '', max_weight_kg: '' }])}>+ Add line</button></div>
      </section>

      <section className="card stack">
        <h3>4. Delivery notes and terms</h3>
        <label className="row"><input type="checkbox" checked={standard} onChange={(e) => setStandard(e.target.checked)} />
          Use Omoterra&apos;s standard delivery notes and terms (dates and collection point filled in)</label>
        {!standard && <>
          <div className="field"><label htmlFor="dnotes">Delivery / collection notes (one per line)</label>
            <textarea id="dnotes" className="input" rows={4} value={deliveryNotes} onChange={(e) => setDeliveryNotes(e.target.value)} /></div>
          <div className="field"><label htmlFor="tterms">Terms and conditions (one per line)</label>
            <textarea id="tterms" className="input" rows={10} value={termsText} onChange={(e) => setTermsText(e.target.value)} /></div>
        </>}
        <div className="field"><label htmlFor="inotes">Internal notes (never printed)</label>
          <textarea id="inotes" className="input" value={notes} onChange={(e) => setNotes(e.target.value)} /></div>
      </section>

      {state && !state.ok && <div className="notice" data-tone="error">{state.error}</div>}
      <div className="row"><Submit editing={!!lpo} /><span className="meta">A draft can be changed until an admin issues it.</span></div>
    </form>
  );
}
