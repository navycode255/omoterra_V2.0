'use client';

import Link from 'next/link';
import { useActionState, useMemo, useState } from 'react';
import { useFormStatus } from 'react-dom';
import { Busy } from '@/components/spinner';
import { category as categoryLabel } from '@/lib/format';
import { publishMarketPrices } from '@/lib/market-price-actions';
import { checkLadder, PRICE_CATEGORIES, PRICE_UNITS, shillings, weightRange, type DraftBand, type PriceBand } from '@/lib/market-prices';
import { PriceLadder } from './price-ladder';
import styles from './market-prices.module.css';

const MAX_BANDS = 12;
let counter = 0;
const draft = (band: Partial<DraftBand> = {}): DraftBand => ({ key: `band-${++counter}`, label: '', min: '', max: '', price: '', ...band });
const trim = (value: string | null) => value === null ? '' : String(Number(value));

// Broiler ladder as an example the first time a category is priced.
const STARTER: Partial<DraftBand>[] = [
  { label: 'Large', min: '1.0', max: '', price: '' },
  { label: 'Medium', min: '0.85', max: '1.0', price: '' },
  { label: 'Small', min: '', max: '0.85', price: '' },
];

function Publish({ disabled }: { disabled: boolean }) {
  const { pending } = useFormStatus();
  return <button type="submit" className="button" disabled={pending || disabled}>{pending ? <Busy>Publishing…</Busy> : 'Publish prices'}</button>;
}

export function PriceEditor({ initialCategory, current, today, maxDate, formKey }: {
  initialCategory: string; current: Record<string, PriceBand[]>; today: string; maxDate: string; formKey: string;
}) {
  const [category, setCategory] = useState(initialCategory);
  const startFrom = (key: string) => {
    const bands = current[key];
    if (bands?.length) return [...bands].reverse().map((b) => draft({ label: b.label, min: trim(b.min_weight_kg), max: trim(b.max_weight_kg), price: trim(b.price_per_unit) }));
    return PRICE_UNITS[key] === 'bird' ? STARTER.map((b) => draft(b)) : [draft()];
  };
  const [bands, setBands] = useState<DraftBand[]>(() => startFrom(initialCategory));
  const [effective, setEffective] = useState(today);
  const [touched, setTouched] = useState(false);
  const [state, action] = useActionState(publishMarketPrices, null);
  const unit = PRICE_UNITS[category] ?? 'unit';
  const { errors, gaps, ordered } = useMemo(() => checkLadder(bands), [bands]);

  const update = (key: string, field: keyof DraftBand, value: string) => {
    setTouched(true);
    setBands((rows) => rows.map((row) => row.key === key ? { ...row, [field]: value } : row));
  };
  const changeCategory = (key: string) => { setCategory(key); setBands(startFrom(key)); setTouched(false); };
  const preview: PriceBand[] = ordered.filter((b) => b.amount && b.amount > 0).map((b) => {
    const before = current[category]?.find((p) => Number(p.min_weight_kg ?? -1) === (b.from ?? -1) && Number(p.max_weight_kg ?? -1) === (b.to ?? -1));
    return { label: b.label.trim(), min_weight_kg: b.min.trim() || null, max_weight_kg: b.max.trim() || null,
      price_per_unit: String(b.amount), previous_price: before ? before.price_per_unit : null };
  });

  return <form action={action} className={styles.editor}>
    <input type="hidden" name="key" value={formKey}/>
    <input type="hidden" name="bands" value={JSON.stringify(ordered.map(({ label, min, max, price }) => ({ label, min, max, price })))}/>
    <div className={styles.panel}>
      <h2>Price list</h2>
      <p>Publishing creates a new version. The previous prices stay in the history.</p>
      <div className={styles.fields}>
        <div className="field">
          <label htmlFor="category">Product</label>
          <select id="category" name="category" className="input" value={category} onChange={(event) => changeCategory(event.target.value)}>
            {PRICE_CATEGORIES.map((key) => <option key={key} value={key}>{categoryLabel(key)} · per {PRICE_UNITS[key]}</option>)}
          </select>
        </div>
        <div className="field">
          <label htmlFor="effective_from">Prices apply from</label>
          <input id="effective_from" name="effective_from" type="date" className="input" value={effective} min={today} max={maxDate}
            onChange={(event) => setEffective(event.target.value)} required/>
        </div>
      </div>

      <div className={styles.bandHead} aria-hidden="true"><span>Grade label</span><span>From (kg)</span><span>Up to (kg)</span><span>Price per {unit} (TZS)</span><span/></div>
      {bands.map((band, index) => <div key={band.key} className={styles.band} role="group" aria-label={`Price band ${index + 1}`}>
        <label><span>Grade label</span><input className="input" value={band.label} maxLength={40} placeholder="e.g. Large" onChange={(e) => update(band.key, 'label', e.target.value)}/></label>
        <label><span>From (kg)</span><input className="input" value={band.min} inputMode="decimal" placeholder="No minimum" aria-label="From weight in kg" onChange={(e) => update(band.key, 'min', e.target.value)}/></label>
        <label><span>Up to (kg)</span><input className="input" value={band.max} inputMode="decimal" placeholder="No maximum" aria-label="Up to weight in kg" onChange={(e) => update(band.key, 'max', e.target.value)}/></label>
        <label><span>Price per {unit}</span><input className="input" value={band.price} inputMode="numeric" placeholder="e.g. 6500" aria-label={`Price per ${unit} in TZS`} onChange={(e) => update(band.key, 'price', e.target.value)}/></label>
        <button type="button" className={styles.remove} aria-label="Remove band" disabled={bands.length === 1}
          onClick={() => { setTouched(true); setBands((rows) => rows.filter((row) => row.key !== band.key)); }}>✕</button>
      </div>)}
      <button type="button" className={styles.add} disabled={bands.length >= MAX_BANDS} onClick={() => setBands((rows) => [...rows, draft()])}>+ Add weight band</button>
      <p className={styles.hint}>A band includes its &quot;from&quot; weight and stops just below its &quot;up to&quot; weight, so 0.85 – 1.0 and 1.0 and above never overlap. Leave &quot;from&quot; empty for &quot;below&quot;, and &quot;up to&quot; empty for &quot;and above&quot;.</p>

      {(touched || state) && errors.length > 0 && <ul className={styles.problems}>{errors.map((error) => <li key={error}>{error}</li>)}</ul>}
      {errors.length === 0 && gaps.length > 0 && <div className={styles.warning}>Birds weighing {gaps.join(' or ')} will have no published price. Close the gap if Omoterra buys at these weights.</div>}

      <div className="field">
        <label htmlFor="note">Note for the team (optional)</label>
        <textarea id="note" name="note" className="input" rows={2} maxLength={500} placeholder="e.g. Kariakoo market rate for this week"/>
      </div>
      {state && !state.ok && <div className="notice" data-tone="error" role="alert">{state.error}</div>}
      <div className={styles.footer}>
        <Link href="/market-prices" className="button" data-variant="secondary">Cancel</Link>
        <Publish disabled={errors.length > 0}/>
      </div>
    </div>

    <aside className={styles.preview} aria-label="Supplier preview">
      <div className={styles.previewCard}>
        <header><b>What suppliers will see</b><small>{categoryLabel(category)} · from {new Date(`${effective}T00:00:00`).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })}</small></header>
        {preview.length ? <PriceLadder bands={preview} unit={unit} gapNote="No price published" compact/> : <p className={styles.hint}>Enter a price to see the ladder.</p>}
        {preview.length > 0 && <p className={styles.hint}>{preview.length === 1 ? `One price: ${shillings(preview[0].price_per_unit)} for ${weightRange(preview[0]).toLowerCase()}.` : `${preview.length} weight bands, from ${shillings(Math.min(...preview.map((b) => Number(b.price_per_unit))))} to ${shillings(Math.max(...preview.map((b) => Number(b.price_per_unit))))} per ${unit}.`}</p>}
      </div>
    </aside>
  </form>;
}
