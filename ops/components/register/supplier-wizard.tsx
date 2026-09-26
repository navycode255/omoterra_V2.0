'use client';

import { useState, type ReactNode } from 'react';
import { tanzanianMobile } from '@/lib/phone';
import { registerSupplier } from '@/lib/registration';
import { Check, Done, Field, Select, Text, useAccount, Wizard, type Errors } from './wizard';

// The fields, options and rules of admin supplier registration
// (app/(ops)/suppliers/new and contracts.SupplierProfileInput /
// SupplierBatchInput), minus the staff-only notes and verification checks.
// The payload is the one createSupplier builds, sent to the app's own
// POST /supplier/onboarding, which reviews it like any other registration.
const categories = [
  ['broilers', 'Broilers', 'birds', 'bird'], ['local_chicken', 'Local chicken', 'birds', 'bird'],
  ['layers', 'Layers', 'birds', 'bird'], ['eggs', 'Eggs', 'trays', 'tray'], ['goats', 'Goats', 'animals', 'animal'],
  ['cattle', 'Cattle', 'animals', 'animal'], ['chicken_meat', 'Chicken meat', 'kg', 'kg'],
  ['beef', 'Beef', 'kg', 'kg'], ['goat_meat', 'Goat meat', 'kg', 'kg'],
] as const;
const forms = [['live', 'Live'], ['dressed', 'Dressed'], ['chilled', 'Chilled'], ['frozen', 'Frozen']] as const;
const contacts = [['phone', 'Phone call'], ['whatsapp', 'WhatsApp'], ['sms', 'Text message']] as const;
const ageUnits = [['weeks', 'Weeks'], ['days', 'Days'], ['months', 'Months']] as const;
const MEAT = ['chicken_meat', 'beef', 'goat_meat'];
const LIVE_ONLY = ['broilers', 'local_chicken', 'goats', 'cattle'];
const steps = ['Account', 'Supplier details', 'Location', 'Supply', 'Production', 'Photos', 'Review'] as const;
const PUBLIC_REGION = /\d|@|https?:\/\/|www\./i;

// Which step shows each field the backend may reject.
const STEP_OF: Record<string, number> = {
  phone: 0, name: 1, public_alias: 1, legal_name: 1, alternate_phone: 1, preferred_contact_method: 1,
  region: 2, district: 2, general_area: 2, internal_pickup_address: 2, pickup_instructions: 2,
  categories: 3, primary_category: 3, production_profile: 3, production_frequency: 3, supply_forms: 3, operating_notes: 3,
  current_batch: 4, future_batches: 4, evidence_photos: 5,
};

type Batch = {
  enabled: boolean; category: string; subtype: string; quantity: string; age: string; age_unit: string;
  ready_date: string; min_weight: string; max_weight: string; form: string; asking_price: string; photos: File[];
};
const emptyBatch = (): Batch => ({ enabled: false, category: '', subtype: '', quantity: '', age: '', age_unit: 'weeks',
  ready_date: '', min_weight: '', max_weight: '', form: 'live', asking_price: '', photos: [] });

const formsFor = (category: string) => forms.filter(([key]) =>
  MEAT.includes(category) ? key !== 'live' : LIVE_ONLY.includes(category) ? key === 'live' : true);
const labelOf = (options: readonly (readonly [string, ...string[]])[], key: string) => options.find(([value]) => value === key)?.[1] ?? key;
const number = (value: string) => (value.trim() === '' ? null : Number(value));

function today() {
  const now = new Date();
  return new Date(now.getTime() - now.getTimezoneOffset() * 60000).toISOString().slice(0, 10);
}

export function SupplierWizard() {
  const account = useAccount('supplier');
  const [step, setStep] = useState(0);
  const [values, setValues] = useState({
    public_alias: '', legal_name: '', alternate_phone: '', preferred_contact_method: 'phone',
    region: '', district: '', general_area: '', internal_pickup_address: '', pickup_instructions: '',
    omoterra_pickup: false, supplier_transport: false,
    categories: [] as string[], capacity: {} as Record<string, string>, primary_category: '',
    production_frequency: '', supply_forms: [] as string[], operating_notes: '',
  });
  const [current, setCurrent] = useState<Batch>(emptyBatch);
  const [future, setFuture] = useState<Batch>(emptyBatch);
  const [evidence, setEvidence] = useState<File[]>([]);
  const [errors, setErrors] = useState<Errors>({});
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<'registered' | 'existing' | null>(null);

  type Values = typeof values;
  const set = <K extends keyof Values>(key: K) => (value: Values[K]) => setValues((prior) => ({ ...prior, [key]: value }));
  const toggle = (list: string[], key: string, on: boolean) => (on ? [...list, key] : list.filter((item) => item !== key));

  function checkBatch(prefix: string, batch: Batch, next: Errors) {
    if (!batch.enabled) return;
    const key = (field: string) => `${prefix}.${field}`;
    if (!batch.category) next[key('category')] = 'Choose a category.';
    else if (!values.categories.includes(batch.category)) next[key('category')] = 'Choose a category you selected under Supply.';
    const quantity = number(batch.quantity);
    if (quantity === null || !(quantity > 0)) next[key('initial_quantity')] = 'Enter a quantity above 0.';
    else if (!MEAT.includes(batch.category) && !Number.isInteger(quantity)) next[key('initial_quantity')] = 'Birds, animals and trays need a whole number.';
    if (batch.subtype.length > 100) next[key('subtype')] = 'Use at most 100 characters.';
    const age = number(batch.age);
    if (age !== null && !(age >= 0)) next[key('current_age')] = 'Enter an age of 0 or more.';
    if (!batch.ready_date) next[key('expected_ready_date')] = 'Choose the expected ready date.';
    else if (batch.ready_date < today()) next[key('expected_ready_date')] = 'Choose today or a later date.';
    else if ((new Date(batch.ready_date).getTime() - Date.now()) / 86400000 > 365 * 5) next[key('expected_ready_date')] = 'Choose a date within five years.';
    const min = number(batch.min_weight);
    const max = number(batch.max_weight);
    if (min !== null && !(min > 0)) next[key('expected_min_weight_kg')] = 'Enter a weight above 0.';
    if (max !== null && !(max > 0)) next[key('expected_max_weight_kg')] = 'Enter a weight above 0.';
    else if (min !== null && max !== null && min > max) next[key('expected_max_weight_kg')] = 'Maximum weight must be at least the minimum.';
    if (batch.category && !formsFor(batch.category).some(([form]) => form === batch.form)) next[key('form')] = 'Choose a supply type that fits this category.';
    const price = number(batch.asking_price);
    if (price === null || !(price > 0)) next[key('asking_price_per_unit')] = 'Enter your asking price.';
  }

  function check(at: number) {
    const next: Errors = {};
    const v = values;
    const length = (key: keyof Values, min: number, max: number, message: string) => {
      const text = String(v[key]).trim();
      if (text.length < min) next[key] = message;
      else if (text.length > max) next[key] = `Use at most ${max} characters.`;
    };
    if (at === 1) {
      length('public_alias', 2, 120, 'Enter the farm or supplier name.');
      length('legal_name', 2, 150, 'Enter your legal or full name.');
      if (v.alternate_phone.trim() && !tanzanianMobile(v.alternate_phone)) next.alternate_phone = 'Enter a Tanzanian mobile number, e.g. 0712 345 678.';
    }
    if (at === 2) {
      length('region', 2, 80, 'Enter your region.');
      if (!next.region && PUBLIC_REGION.test(v.region)) next.region = 'Enter a general region name only.';
      length('district', 2, 100, 'Enter your district.');
      length('general_area', 0, 120, '');
      length('internal_pickup_address', 3, 500, 'Enter the exact pickup location.');
      length('pickup_instructions', 0, 1000, '');
    }
    if (at === 3) {
      if (!v.categories.length) next.categories = 'Choose at least one product.';
      for (const category of v.categories) {
        const capacity = number(v.capacity[category] ?? '');
        if (capacity !== null && !(capacity >= 0)) next[`capacity_${category}`] = 'Enter 0 or more.';
      }
      if (!v.primary_category) next.primary_category = 'Choose your main category.';
      else if (!v.categories.includes(v.primary_category)) next.primary_category = 'Choose one of the products you selected.';
      // Capacity rows carry the production cycle, where the backend allows 80 characters.
      const withCapacity = v.categories.some((category) => (v.capacity[category] ?? '').trim());
      length('production_frequency', 0, withCapacity ? 80 : 120, '');
      length('operating_notes', 0, 1000, '');
    }
    if (at === 4) {
      checkBatch('current_batch', current, next);
      checkBatch('future_batches.0', future, next);
    }
    if (at === 5) {
      const all = [...evidence, ...(current.enabled ? current.photos : []), ...(future.enabled ? future.photos : [])];
      if (all.length > 8) next.evidence_photos = 'Choose up to 8 photos in total.';
      else if (all.some((file) => file.size > 8 * 1024 * 1024)) next.evidence_photos = 'Each photo must be smaller than 8 MB.';
    }
    setErrors(next);
    return !Object.keys(next).length;
  }

  function batchPayload(batch: Batch) {
    return {
      category: batch.category, subtype: batch.subtype.trim(), initial_quantity: batch.quantity.trim(),
      current_age: batch.age.trim() || null, age_unit: batch.age_unit, expected_ready_date: batch.ready_date,
      expected_min_weight_kg: batch.min_weight.trim() || null, expected_max_weight_kg: batch.max_weight.trim() || null,
      form: batch.form, asking_price_per_unit: batch.asking_price.trim() || null,
      region: values.region.trim(), private_pickup_location: values.internal_pickup_address.trim(), photos: [] as string[],
    };
  }

  async function submit() {
    const v = values;
    const production_profile: Record<string, { capacity: string; unit: string; frequency: string }> = {};
    for (const [key, , , unit] of categories) {
      const capacity = (v.capacity[key] ?? '').trim();
      if (v.categories.includes(key) && capacity) production_profile[key] = { capacity, unit, frequency: v.production_frequency.trim() };
    }
    const payload = {
      name: v.legal_name.trim(), public_alias: v.public_alias.trim(), legal_name: v.legal_name.trim(),
      alternate_phone: v.alternate_phone.trim() ? tanzanianMobile(v.alternate_phone) : '',
      region: v.region.trim(), district: v.district.trim(), general_area: v.general_area.trim(),
      categories: v.categories, primary_category: v.primary_category, production_profile, evidence_photos: [] as string[],
      production_frequency: v.production_frequency.trim(), internal_pickup_address: v.internal_pickup_address.trim(),
      pickup_instructions: v.pickup_instructions.trim(), omoterra_pickup: v.omoterra_pickup, supplier_transport: v.supplier_transport,
      supply_forms: v.supply_forms, preferred_contact_method: v.preferred_contact_method, operating_notes: v.operating_notes.trim(),
      current_batch: current.enabled ? batchPayload(current) : null,
      future_batches: future.enabled ? [batchPayload(future)] : [],
    };
    const form = new FormData();
    form.append('payload', JSON.stringify(payload));
    evidence.forEach((file) => form.append('evidence_photos', file));
    if (current.enabled) current.photos.forEach((file) => form.append('current_photos', file));
    if (future.enabled) future.photos.forEach((file) => form.append('future_photos', file));
    const saved = await registerSupplier(form);
    if (saved.ok) { setResult('registered'); return; }
    const field = saved.field ?? '';
    const at = STEP_OF[field.split('.')[0]];
    if (at === 0) { account.restart(saved.error); setErrors({}); setStep(0); }
    else if (at !== undefined) { setErrors({ [field]: saved.error }); setStep(at); }
    else setErrors({ form: saved.error });
  }

  async function next() {
    setBusy(true);
    try {
      if (step === 0) {
        const verified = await account.advance();
        if (!verified) return;
        if (verified.registered) { setResult('existing'); return; }
        setValues((prior) => ({ ...prior, legal_name: prior.legal_name || verified.name, region: prior.region || verified.region }));
        setStep(1);
      } else if (step < steps.length - 1) {
        if (check(step)) setStep(step + 1);
      } else {
        await submit();
      }
    } finally {
      setBusy(false);
    }
  }

  if (result === 'existing') {
    return <Done title="You're already registered" action={{ href: '/account', label: 'View your account' }}><p>Your supplier registration is with Omoterra.</p></Done>;
  }
  if (result === 'registered') {
    return <Done title="Registration received" action={{ href: '/account', label: 'View your account' }}><p>Omoterra will review your details and contact you on {account.verified?.phone}. Log in any time with your phone number and PIN.</p></Done>;
  }

  const batchFields = (prefix: string, title: string, batch: Batch, update: (batch: Batch) => void) => {
    const err = (field: string) => errors[`${prefix}.${field}`];
    const change = <K extends keyof Batch>(key: K) => (value: Batch[K]) => {
      const nextBatch = { ...batch, [key]: value };
      // Keep the supply type valid for the category, as the backend requires.
      if (key === 'category' && !formsFor(String(value)).some(([form]) => form === nextBatch.form)) nextBatch.form = formsFor(String(value))[0][0];
      update(nextBatch);
    };
    const chosen = categories.filter(([key]) => values.categories.includes(key)).map(([key, label]) => [key, label] as const);
    return (
      <fieldset className="join-group">
        <Check id={`${prefix}-enabled`} label={title} checked={batch.enabled} onChange={(on) => update({ ...batch, enabled: on, category: batch.category || values.primary_category })} />
        {batch.enabled && <div className="join-grid">
          <Select id={`${prefix}-category`} label="Category" placeholder="Choose…" options={chosen} value={batch.category} onChange={change('category')} error={err('category')} />
          <Text id={`${prefix}-quantity`} label="Quantity" type="number" inputMode="decimal" value={batch.quantity} onChange={change('quantity')} error={err('initial_quantity')} />
          <Text id={`${prefix}-subtype`} label="Breed / type" optional value={batch.subtype} onChange={change('subtype')} error={err('subtype')} />
          <Text id={`${prefix}-age`} label="Current age" optional type="number" inputMode="decimal" value={batch.age} onChange={change('age')} error={err('current_age')} />
          <Select id={`${prefix}-age-unit`} label="Age unit" options={ageUnits} value={batch.age_unit} onChange={change('age_unit')} />
          <Text id={`${prefix}-ready`} label="Expected ready date" type="date" value={batch.ready_date} onChange={change('ready_date')} error={err('expected_ready_date')} />
          <Text id={`${prefix}-min`} label="Expected minimum weight (kg)" optional type="number" inputMode="decimal" value={batch.min_weight} onChange={change('min_weight')} error={err('expected_min_weight_kg')} />
          <Text id={`${prefix}-max`} label="Expected maximum weight (kg)" optional type="number" inputMode="decimal" value={batch.max_weight} onChange={change('max_weight')} error={err('expected_max_weight_kg')} />
          <Select id={`${prefix}-form`} label="Supply type" options={formsFor(batch.category)} value={batch.form} onChange={change('form')} error={err('form')} />
          <Text id={`${prefix}-price`} label="Asking price (TZS / unit)" type="number" inputMode="decimal" value={batch.asking_price} onChange={change('asking_price')} error={err('asking_price_per_unit')} />
          <Photos id={`${prefix}-photos`} label="Photos" files={batch.photos} onChange={change('photos')} />
        </div>}
      </fieldset>
    );
  };

  const v = values;
  const row = (label: string, value: string | number | undefined | null) => (value === '' || value == null ? null : <div><dt>{label}</dt><dd>{value}</dd></div>);
  const reviewBatch = (label: string, batch: Batch) => batch.enabled && (
    <div><dt>{label}</dt><dd>{[labelOf(categories, batch.category), `${batch.quantity}`, batch.subtype, `ready ${batch.ready_date}`,
      labelOf(forms, batch.form), `TZS ${batch.asking_price} / unit`, batch.photos.length ? `${batch.photos.length} photo${batch.photos.length > 1 ? 's' : ''}` : '']
      .filter(Boolean).join(' · ')}</dd></div>
  );
  const section = (title: string, at: number, rows: ReactNode) => (
    <section className="join-review-section">
      <header><h2>{title}</h2><button type="button" className="join-link" onClick={() => { setErrors({}); setStep(at); }}>Edit</button></header>
      <dl className="join-review">{rows}</dl>
    </section>
  );

  return (
    <Wizard steps={steps} step={step} busy={busy} error={step === 0 ? undefined : errors.form}
      onBack={step === 0 ? account.back : () => { setErrors({}); setStep(step - 1); }}
      onContinue={next}
      continueLabel={step === 0 && account.stage === 'phone' ? 'Send code' : step === steps.length - 1 ? 'Submit registration' : 'Continue'}>
      {step === 0 && account.view}
      {step === 1 && <>
        <Text id="public_alias" label="Farm / supplier name" value={v.public_alias} onChange={set('public_alias')} error={errors.public_alias} />
        <Text id="legal_name" label="Legal / full name" autoComplete="name" value={v.legal_name} onChange={set('legal_name')} error={errors.legal_name ?? errors.name} />
        <Text id="alternate_phone" label="Alternate phone" optional type="tel" inputMode="tel" value={v.alternate_phone} onChange={set('alternate_phone')} error={errors.alternate_phone} />
        <Select id="preferred_contact_method" label="Preferred contact" options={contacts} value={v.preferred_contact_method} onChange={set('preferred_contact_method')} error={errors.preferred_contact_method} />
      </>}
      {step === 2 && <>
        <div className="join-grid">
          <Text id="region" label="Region" value={v.region} onChange={set('region')} error={errors.region} />
          <Text id="district" label="District" value={v.district} onChange={set('district')} error={errors.district} />
        </div>
        <Text id="general_area" label="General area" optional value={v.general_area} onChange={set('general_area')} error={errors.general_area} />
        <Text id="internal_pickup_address" label="Exact pickup location" multiline value={v.internal_pickup_address} onChange={set('internal_pickup_address')} error={errors.internal_pickup_address} />
        <Text id="pickup_instructions" label="Pickup instructions" optional multiline value={v.pickup_instructions} onChange={set('pickup_instructions')} error={errors.pickup_instructions} />
        <Check id="omoterra_pickup" label="Omoterra can collect from this location" checked={v.omoterra_pickup} onChange={set('omoterra_pickup')} />
        <Check id="supplier_transport" label="I can arrange transport" checked={v.supplier_transport} onChange={set('supplier_transport')} />
      </>}
      {step === 3 && <>
        <Field id="categories" label="Products you normally supply" error={errors.categories}>
          <div className="join-options" id="categories">
            {categories.map(([key, label, unit]) => {
              const on = v.categories.includes(key);
              return (
                <div key={key} className={`join-option${on ? ' is-on' : ''}`}>
                  <Check id={`category-${key}`} label={label} checked={on} onChange={(checked) => setValues((prior) => ({
                    ...prior, categories: toggle(prior.categories, key, checked),
                    primary_category: !checked && prior.primary_category === key ? '' : prior.primary_category || (checked ? key : ''),
                  }))} />
                  {on && <Text id={`capacity_${key}`} label={`Typical capacity (${unit} / cycle)`} optional type="number" inputMode="decimal"
                    value={v.capacity[key] ?? ''} onChange={(value) => setValues((prior) => ({ ...prior, capacity: { ...prior.capacity, [key]: value } }))}
                    error={errors[`capacity_${key}`]} />}
                </div>
              );
            })}
          </div>
        </Field>
        <div className="join-grid">
          <Select id="primary_category" label="Main category" placeholder="Choose…" error={errors.primary_category}
            options={categories.filter(([key]) => v.categories.includes(key)).map(([key, label]) => [key, label] as const)}
            value={v.primary_category} onChange={set('primary_category')} />
          <Text id="production_frequency" label="Production cycle / frequency" optional placeholder="e.g. every 6 weeks"
            value={v.production_frequency} onChange={set('production_frequency')} error={errors.production_frequency ?? errors.production_profile} />
        </div>
        <Field id="supply_forms" label="Supply type" optional error={errors.supply_forms}>
          <div className="join-chips" id="supply_forms">
            {forms.map(([key, label]) => <Check key={key} id={`form-${key}`} label={label} checked={v.supply_forms.includes(key)}
              onChange={(checked) => set('supply_forms')(toggle(v.supply_forms, key, checked))} />)}
          </div>
        </Field>
        <Text id="operating_notes" label="Operating schedule and notes" optional multiline value={v.operating_notes} onChange={set('operating_notes')} error={errors.operating_notes} />
      </>}
      {step === 4 && <>
        {batchFields('current_batch', 'Add current production', current, setCurrent)}
        {batchFields('future_batches.0', 'Add next planned production', future, setFuture)}
      </>}
      {step === 5 && <Photos id="evidence_photos" label="Farm / location photos" files={evidence} onChange={setEvidence} error={errors.evidence_photos} />}
      {step === 6 && <div className="join-review-wrap">
        {section('Account', 0, row('Phone', account.verified?.phone))}
        {section('Supplier details', 1, <>{row('Farm / supplier name', v.public_alias)}{row('Legal / full name', v.legal_name)}
          {row('Alternate phone', v.alternate_phone)}{row('Preferred contact', labelOf(contacts, v.preferred_contact_method))}</>)}
        {section('Location', 2, <>{row('Region', v.region)}{row('District', v.district)}{row('General area', v.general_area)}
          {row('Exact pickup location', v.internal_pickup_address)}{row('Pickup instructions', v.pickup_instructions)}
          {row('Omoterra can collect', v.omoterra_pickup ? 'Yes' : 'No')}{row('I can arrange transport', v.supplier_transport ? 'Yes' : 'No')}</>)}
        {section('Supply', 3, <>{row('Products', v.categories.map((key) => {
            const capacity = (v.capacity[key] ?? '').trim();
            const [, label, unit] = categories.find(([k]) => k === key)!;
            return capacity ? `${label} (${capacity} ${unit} / cycle)` : label;
          }).join(', '))}
          {row('Main category', labelOf(categories, v.primary_category))}{row('Production cycle', v.production_frequency)}
          {row('Supply type', v.supply_forms.map((key) => labelOf(forms, key)).join(', '))}{row('Operating notes', v.operating_notes)}</>)}
        {section('Production', 4, current.enabled || future.enabled
          ? <>{reviewBatch('Current', current)}{reviewBatch('Planned', future)}</>
          : <div><dt>Batches</dt><dd>None added</dd></div>)}
        {section('Photos', 5, <div><dt>Farm / location</dt><dd>{evidence.length ? `${evidence.length} photo${evidence.length > 1 ? 's' : ''}` : 'None added'}</dd></div>)}
      </div>}
    </Wizard>
  );
}

function Photos({ id, label, files, onChange, error }: { id: string; label: string; files: File[]; onChange: (files: File[]) => void; error?: string }) {
  return (
    <Field id={id} label={label} optional error={error}>
      <input id={id} className="join-input join-file" type="file" accept="image/jpeg,image/png,image/webp" multiple
        aria-invalid={!!error || undefined} aria-describedby={error ? `${id}-error` : undefined}
        onChange={(event) => { onChange([...files, ...Array.from(event.target.files ?? [])].slice(0, 8)); event.target.value = ''; }} />
      {!!files.length && <ul className="join-files">
        {files.map((file, index) => <li key={`${file.name}-${index}`}><span>{file.name}</span>
          <button type="button" className="join-link" onClick={() => onChange(files.filter((_, at) => at !== index))}>Remove</button></li>)}
      </ul>}
    </Field>
  );
}
