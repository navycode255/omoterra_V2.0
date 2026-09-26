'use client';

import Link from 'next/link';
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { sendCode, setPin, verifyCode, type Role, type Verified } from '@/lib/registration';

export type Errors = Record<string, string>;

export function Field({ id, label, error, optional, children }: { id: string; label: string; error?: string; optional?: boolean; children: ReactNode }) {
  return (
    <div className={`join-field${error ? ' has-error' : ''}`}>
      <label htmlFor={id}>{label}{optional && <span className="join-optional"> (optional)</span>}</label>
      {children}
      {error && <p className="join-error" id={`${id}-error`}>{error}</p>}
    </div>
  );
}

type TextProps = {
  id: string; label: string; value: string; onChange: (value: string) => void; error?: string; optional?: boolean;
  type?: string; inputMode?: 'numeric' | 'decimal' | 'tel' | 'text'; placeholder?: string; multiline?: boolean; autoComplete?: string;
};

export function Text({ id, label, value, onChange, error, optional, multiline, ...rest }: TextProps) {
  const common = {
    id, name: id, value, className: 'join-input', 'aria-invalid': !!error || undefined,
    'aria-describedby': error ? `${id}-error` : undefined,
  };
  return (
    <Field id={id} label={label} error={error} optional={optional}>
      {multiline
        ? <textarea {...common} rows={3} onChange={(event) => onChange(event.target.value)} />
        : <input {...common} {...rest} onChange={(event) => onChange(event.target.value)} />}
    </Field>
  );
}

export function Select({ id, label, value, onChange, options, error, placeholder }: {
  id: string; label: string; value: string; onChange: (value: string) => void; options: readonly (readonly [string, string])[]; error?: string; placeholder?: string;
}) {
  return (
    <Field id={id} label={label} error={error}>
      <select id={id} name={id} className="join-input" value={value} aria-invalid={!!error || undefined}
        aria-describedby={error ? `${id}-error` : undefined} onChange={(event) => onChange(event.target.value)}>
        {placeholder !== undefined && <option value="">{placeholder}</option>}
        {options.map(([key, label]) => <option key={key} value={key}>{label}</option>)}
      </select>
    </Field>
  );
}

export function Check({ id, label, checked, onChange }: { id: string; label: string; checked: boolean; onChange: (checked: boolean) => void }) {
  return (
    <label className="join-check" htmlFor={id}>
      <input id={id} type="checkbox" checked={checked} onChange={(event) => onChange(event.target.checked)} />
      <span>{label}</span>
    </label>
  );
}

export function Wizard({ steps, step, children, error, busy, onBack, onContinue, continueLabel = 'Continue', eyebrow }: {
  steps: readonly string[]; step: number; children: ReactNode; error?: string; busy?: boolean;
  onBack?: (() => void) | null; onContinue: () => void; continueLabel?: string;
  // Replaces "Step n of m" on single-page forms such as log in.
  eyebrow?: string;
}) {
  const heading = useRef<HTMLHeadingElement>(null);
  const first = useRef(true);
  useEffect(() => {
    // Each step starts at its heading, so keyboard and screen reader users land
    // on the new step rather than on the button they just pressed.
    if (first.current) { first.current = false; return; }
    heading.current?.focus();
    heading.current?.scrollIntoView({ block: 'start' });
  }, [step]);
  return (
    <section className="join-card">
      {steps.length > 1 && <div className="join-progress" role="progressbar" aria-label="Registration progress" aria-valuemin={1} aria-valuemax={steps.length} aria-valuenow={step + 1}>
        <span style={{ width: `${((step + 1) / steps.length) * 100}%` }} />
      </div>}
      <p className="join-eyebrow">{eyebrow ?? `Step ${step + 1} of ${steps.length}`}</p>
      <h1 ref={heading} tabIndex={-1}>{steps[step]}</h1>
      <form noValidate onSubmit={(event) => { event.preventDefault(); if (!busy) onContinue(); }}>
        <div className="join-fields">{children}</div>
        {error && <p className="join-error join-form-error" role="alert">{error}</p>}
        <div className="join-nav">
          {onBack ? <button type="button" className="button button-outline" onClick={onBack} disabled={busy}>Back</button> : <span />}
          <button type="submit" className="button button-primary" disabled={busy}>{busy ? 'Please wait…' : continueLabel}</button>
        </div>
      </form>
    </section>
  );
}

export function Done({ title, children, action = { href: '/', label: 'Back to home' } }: { title: string; children: ReactNode; action?: { href: string; label: string } }) {
  return (
    <section className="join-card join-done">
      <span className="join-done-mark" aria-hidden="true">
        <svg viewBox="0 0 24 24"><path d="m6 12.5 4 4 8-9" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" /></svg>
      </span>
      <h1>{title}</h1>
      {children}
      <Link className="button button-primary" href={action.href}>{action.label}</Link>
    </section>
  );
}

// The Account step: confirm the phone number with the same SMS code the app
// uses, then create the PIN used to sign in to the website without another
// SMS. `advance` sends the code, verifies it, saves the PIN, then lets the
// wizard move on. With no `role` it resets a forgotten PIN instead.
export function useAccount(role?: Role) {
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [pin, setPinValue] = useState('');
  const [confirm, setConfirm] = useState('');
  const [stage, setStage] = useState<'phone' | 'code' | 'pin' | 'done'>('phone');
  const [sentTo, setSentTo] = useState('');
  const [developmentCode, setDevelopmentCode] = useState<string | undefined>();
  const [errors, setErrors] = useState<Errors>({});
  const [verified, setVerified] = useState<Verified | null>(null);

  async function request() {
    const sent = await sendCode(phone);
    if (!sent.ok) { setErrors({ [sent.field === 'phone' ? 'phone' : 'form']: sent.error }); return; }
    setSentTo(sent.phone);
    setDevelopmentCode(sent.developmentCode);
    setCode('');
    setErrors({});
    setStage('code');
  }

  async function advance(): Promise<Verified | null> {
    if (stage === 'done') return verified;
    if (stage === 'phone') { await request(); return null; }
    if (stage === 'pin') return savePin();
    const result = await verifyCode(code, role);
    if (!result.ok) { setErrors({ [result.field === 'phone' ? 'phone' : 'code']: result.error }); return null; }
    setErrors({});
    setVerified(result);
    if (!role || !result.hasPin) { setPinValue(''); setConfirm(''); setStage('pin'); return null; }
    setStage('done');
    return result;
  }

  async function savePin(): Promise<Verified | null> {
    if (!/^\d{4,6}$/.test(pin)) { setErrors({ pin: 'Use 4 to 6 digits.' }); return null; }
    if (confirm !== pin) { setErrors({ confirm: 'The PINs do not match.' }); return null; }
    const saved = await setPin(pin);
    if (!saved.ok) {
      if (saved.field === 'phone') change(saved.error);
      else setErrors({ pin: saved.error });
      return null;
    }
    setErrors({});
    setStage('done');
    return verified;
  }

  function change(message?: string) {
    setStage('phone');
    setVerified(null);
    setErrors(message ? { phone: message } : {});
  }

  const view = stage === 'phone'
    ? <Text id="phone" label="Phone number" type="tel" inputMode="tel" autoComplete="tel" placeholder="0712 345 678"
        value={phone} onChange={setPhone} error={errors.phone ?? errors.form} />
    : stage === 'code'
      ? <>
          <Text id="code" label={`Code sent to ${sentTo}`} inputMode="numeric" autoComplete="one-time-code"
            value={code} onChange={(value) => setCode(value.replace(/\D/g, '').slice(0, 8))} error={errors.code ?? errors.phone} />
          {developmentCode && <p className="join-dev-code">Development code: <strong>{developmentCode}</strong></p>}
          <div className="join-inline-actions">
            <button type="button" className="join-link" onClick={() => request()}>Send a new code</button>
            <button type="button" className="join-link" onClick={() => change()}>Change number</button>
          </div>
        </>
      : stage === 'pin'
      ? <>
          <div className="join-confirmed"><span>{verified?.phone}</span></div>
          <Text id="pin" label={role ? 'Create a PIN' : 'New PIN'} type="password" inputMode="numeric" autoComplete="new-password"
            placeholder="4 to 6 digits" value={pin} onChange={(value) => setPinValue(value.replace(/\D/g, '').slice(0, 6))} error={errors.pin} />
          <Text id="pin_confirm" label="Confirm PIN" type="password" inputMode="numeric" autoComplete="new-password"
            value={confirm} onChange={(value) => setConfirm(value.replace(/\D/g, '').slice(0, 6))} error={errors.confirm} />
        </>
      : <div className="join-confirmed">
          <span>{verified?.phone}</span>
          <button type="button" className="join-link" onClick={() => change()}>Change number</button>
        </div>;

  // `restart` sends a visitor whose verification expired back to confirm again.
  return { view, advance, verified, stage, restart: change, back: stage === 'code' ? () => change() : null };
}
