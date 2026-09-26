'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { setPin, signInWithPin } from '@/lib/registration';
import { Text, useAccount, Wizard, type Errors } from './wizard';

// Phone + PIN: signing in to the website never sends an SMS.
export function LoginForm() {
  const router = useRouter();
  const [phone, setPhone] = useState('');
  const [pin, setPinValue] = useState('');
  const [errors, setErrors] = useState<Errors>({});
  const [busy, setBusy] = useState(false);

  async function submit() {
    setBusy(true);
    try {
      const result = await signInWithPin(phone, pin);
      if (result.ok) { router.push('/account'); router.refresh(); return; }
      setErrors(result.field === 'phone' ? { phone: result.error } : { pin: result.error });
    } finally {
      setBusy(false);
    }
  }

  return (
    <Wizard steps={['Log in']} step={0} busy={busy} onContinue={submit} continueLabel="Log in" eyebrow="Welcome back">
      <Text id="phone" label="Phone number" type="tel" inputMode="tel" autoComplete="tel" placeholder="0712 345 678"
        value={phone} onChange={setPhone} error={errors.phone} />
      <Text id="pin" label="PIN" type="password" inputMode="numeric" autoComplete="current-password"
        value={pin} onChange={(value) => setPinValue(value.replace(/\D/g, '').slice(0, 6))} error={errors.pin} />
      <div className="join-inline-actions join-split">
        <Link className="join-link" href="/login/reset">Forgot PIN?</Link>
        <Link className="join-link" href="/register">Register</Link>
      </div>
    </Wizard>
  );
}

// Forgot PIN: one SMS code proves the number, then a new PIN is saved.
export function ResetPinForm() {
  const router = useRouter();
  const account = useAccount();
  const [busy, setBusy] = useState(false);

  async function next() {
    setBusy(true);
    try {
      if (await account.advance()) { router.push('/account'); router.refresh(); }
    } finally {
      setBusy(false);
    }
  }

  return (
    <Wizard steps={['Reset PIN']} step={0} busy={busy} onBack={account.back} onContinue={next} eyebrow="Forgot PIN"
      continueLabel={account.stage === 'phone' ? 'Send code' : account.stage === 'pin' ? 'Save PIN' : 'Continue'}>
      {account.view}
    </Wizard>
  );
}

// Change the PIN while signed in: the session already proves the number.
export function ChangePinForm() {
  const router = useRouter();
  const [pin, setPinValue] = useState('');
  const [confirm, setConfirm] = useState('');
  const [errors, setErrors] = useState<Errors>({});
  const [busy, setBusy] = useState(false);

  async function submit() {
    if (confirm !== pin) { setErrors({ confirm: 'The PINs do not match.' }); return; }
    setBusy(true);
    try {
      const saved = await setPin(pin);
      if (saved.ok) { router.push('/account?pin=changed'); return; }
      if (saved.field === 'phone') { router.push('/login'); return; }
      setErrors({ pin: saved.error });
    } finally {
      setBusy(false);
    }
  }

  return (
    <Wizard steps={['Change PIN']} step={0} busy={busy} onBack={() => router.push('/account')} onContinue={submit} continueLabel="Save PIN" eyebrow="Your account">
      <Text id="pin" label="New PIN" type="password" inputMode="numeric" autoComplete="new-password" placeholder="4 to 6 digits"
        value={pin} onChange={(value) => setPinValue(value.replace(/\D/g, '').slice(0, 6))} error={errors.pin} />
      <Text id="pin_confirm" label="Confirm PIN" type="password" inputMode="numeric" autoComplete="new-password"
        value={confirm} onChange={(value) => setConfirm(value.replace(/\D/g, '').slice(0, 6))} error={errors.confirm} />
    </Wizard>
  );
}
