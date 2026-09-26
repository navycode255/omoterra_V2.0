'use client';

import { useState } from 'react';
import { registerBuyer } from '@/lib/registration';
import { Done, Select, Text, useAccount, Wizard, type Errors } from './wizard';

// The fields and options of the member profile (contracts.Profile) the app's
// setup saves; the website submits it through the same PUT /me.
const buyerTypes = [
  ['personal', 'Personal / household'], ['restaurant', 'Restaurant'], ['butchery', 'Butchery'],
  ['hotel', 'Hotel'], ['retailer', 'Retailer'], ['caterer', 'Caterer'], ['other', 'Other business'],
] as const;
const languages = [['en', 'English'], ['sw', 'Kiswahili']] as const;
const steps = ['Account', 'Your details', 'Review'] as const;

export function BuyerWizard() {
  const account = useAccount('buyer');
  const [step, setStep] = useState(0);
  const [values, setValues] = useState({ name: '', region: '', buyer_type: '', language: 'en' as 'en' | 'sw' });
  const [errors, setErrors] = useState<Errors>({});
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<'registered' | 'existing' | null>(null);
  const set = (key: keyof typeof values) => (value: string) => setValues((prior) => ({ ...prior, [key]: value }));

  function check() {
    const next: Errors = {};
    if (values.name.trim().length < 2) next.name = 'Enter your full name.';
    else if (values.name.trim().length > 100) next.name = 'Use at most 100 characters.';
    if (values.region.trim().length < 2) next.region = 'Enter your region.';
    else if (values.region.trim().length > 80) next.region = 'Use at most 80 characters.';
    if (!values.buyer_type) next.buyer_type = 'Choose what kind of buyer you are.';
    setErrors(next);
    return !Object.keys(next).length;
  }

  async function next() {
    setBusy(true);
    try {
      if (step === 0) {
        const verified = await account.advance();
        if (!verified) return;
        if (verified.registered) { setResult('existing'); return; }
        setValues((prior) => ({ ...prior, name: prior.name || verified.name, region: prior.region || verified.region }));
        setStep(1);
      } else if (step === 1) {
        if (check()) setStep(2);
      } else {
        const saved = await registerBuyer({ name: values.name.trim(), region: values.region.trim(), language: values.language, buyer_type: values.buyer_type });
        if (saved.ok) { setResult('registered'); return; }
        if (saved.field === 'phone') { account.restart(saved.error); setErrors({}); setStep(0); }
        else if (saved.field && saved.field in values) { setErrors({ [saved.field]: saved.error }); setStep(1); }
        else setErrors({ form: saved.error });
      }
    } finally {
      setBusy(false);
    }
  }

  if (result === 'existing') {
    return <Done title="You already have an account" action={{ href: '/account', label: 'View your account' }}><p>You are signed in as {account.verified?.phone}.</p></Done>;
  }
  if (result === 'registered') {
    return <Done title="You're registered" action={{ href: '/account', label: 'View your account' }}><p>Next time, log in with {account.verified?.phone} and your PIN.</p></Done>;
  }

  const label = (options: readonly (readonly [string, string])[], key: string) => options.find(([value]) => value === key)?.[1] ?? '';
  return (
    <Wizard steps={steps} step={step} busy={busy} error={step === 0 ? undefined : errors.form}
      onBack={step === 0 ? account.back : () => { setErrors({}); setStep(step - 1); }}
      onContinue={next} continueLabel={step === 0 && account.stage === 'phone' ? 'Send code' : step === 2 ? 'Register' : 'Continue'}>
      {step === 0 && account.view}
      {step === 1 && <>
        <Text id="name" label="Full name" autoComplete="name" value={values.name} onChange={set('name')} error={errors.name} />
        <Text id="region" label="Region" value={values.region} onChange={set('region')} error={errors.region} />
        <Select id="buyer_type" label="Buyer type" placeholder="Choose…" options={buyerTypes} value={values.buyer_type} onChange={set('buyer_type')} error={errors.buyer_type} />
        <Select id="language" label="Language" options={languages} value={values.language} onChange={set('language')} />
      </>}
      {step === 2 && (
        <dl className="join-review">
          <div><dt>Phone</dt><dd>{account.verified?.phone}</dd></div>
          <div><dt>Full name</dt><dd>{values.name}</dd></div>
          <div><dt>Region</dt><dd>{values.region}</dd></div>
          <div><dt>Buyer type</dt><dd>{label(buyerTypes, values.buyer_type)}</dd></div>
          <div><dt>Language</dt><dd>{label(languages, values.language)}</dd></div>
          <button type="button" className="join-link" onClick={() => setStep(1)}>Edit details</button>
        </dl>
      )}
    </Wizard>
  );
}
