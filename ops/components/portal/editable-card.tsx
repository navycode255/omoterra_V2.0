'use client';

import { useRouter } from 'next/navigation';
import { useState, type ReactNode } from 'react';
import { saveSupplierContact, type Contact } from '@/lib/portal-actions';
import { Check, Field, Select, Text } from '@/components/register/wizard';
import { PAYOUT_METHODS } from '@/lib/payout-methods';
import { Fold, FoldTitle } from './fold';
import { Icon, type IconName } from './icons';
import { Busy } from '@/components/spinner';

const contacts = [['phone', 'Phone call'], ['whatsapp', 'WhatsApp'], ['sms', 'Text message']] as const;

// A panel card whose contact, pickup or payout details the supplier can change
// in place. All kinds save the same endpoint, so each sends the others' values
// unchanged.
export function EditableCard({ id, icon, title, summary, kind, contact, children }: {
  id?: string; icon: IconName; title: string; summary?: string; kind: 'contact' | 'pickup' | 'payout'; contact: Contact; children: ReactNode;
}) {
  const router = useRouter();
  const [editing, setEditing] = useState(false);
  const [values, setValues] = useState(contact);
  const [error, setError] = useState<{ message: string; field?: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [saved, setSaved] = useState(false);
  const set = (key: keyof Contact) => (value: string) => setValues((prior) => ({ ...prior, [key]: value }));
  const fieldError = (field: string) => (error?.field === field ? error.message : undefined);

  async function save() {
    if (kind === 'payout' && !values.payout_methods.length) { setError({ message: 'Choose how you want to receive payouts.', field: 'payout_methods' }); return; }
    setBusy(true);
    try {
      const result = await saveSupplierContact(values);
      if (!result.ok) { setError({ message: result.error, field: result.field }); return; }
      setError(null);
      setEditing(false);
      setSaved(true);
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  return (
    <Fold id={id} open={editing} head={<FoldTitle icon={icon} title={title} summary={summary} />}
      action={!editing && <button type="button" className="portal-edit" onClick={() => { setValues(contact); setSaved(false); setEditing(true); }}>Edit</button>}>
      {editing ? (
        <form className="portal-form" noValidate onSubmit={(event) => { event.preventDefault(); if (!busy) save(); }}>
          {kind === 'payout' ? <Field id="payout_methods" label="How do you want to receive payouts?" error={fieldError('payout_methods')}>
            <div className="join-chips">
              {PAYOUT_METHODS.map(([key, label]) => <Check key={key} id={`edit-payout-${key}`} label={label} checked={values.payout_methods.includes(key)}
                onChange={(on) => setValues((prior) => ({ ...prior, payout_methods: on ? [...prior.payout_methods, key] : prior.payout_methods.filter((item) => item !== key) }))} />)}
            </div>
            <p className="join-hint">We ask for your account details only when a payout is due.</p>
          </Field> : kind === 'contact' ? <>
            <Text id={`${kind}-alternate_phone`} label="Alternate phone" optional type="tel" inputMode="tel" placeholder="0712 345 678"
              value={values.alternate_phone} onChange={set('alternate_phone')} error={fieldError('alternate_phone')} />
            <Select id={`${kind}-preferred_contact_method`} label="Preferred contact" options={contacts}
              value={values.preferred_contact_method} onChange={set('preferred_contact_method')} />
          </> : <>
            <Text id={`${kind}-internal_pickup_address`} label="Exact pickup location" multiline
              value={values.internal_pickup_address} onChange={set('internal_pickup_address')} error={fieldError('internal_pickup_address')} />
            <Text id={`${kind}-pickup_instructions`} label="Pickup instructions" optional multiline
              value={values.pickup_instructions} onChange={set('pickup_instructions')} error={fieldError('pickup_instructions')} />
            <p className="portal-note">Omoterra checks a new pickup location again before collecting.</p>
          </>}
          {error && !error.field && <p className="join-error" role="alert">{error.message}</p>}
          <div className="portal-form-actions">
            <button type="button" className="button button-outline" onClick={() => { setEditing(false); setError(null); }} disabled={busy}>Cancel</button>
            <button type="submit" className="button button-primary" disabled={busy}>{busy ? <Busy>Saving…</Busy> : 'Save'}</button>
          </div>
        </form>
      ) : <>
        {children}
        {saved && <p className="portal-saved" role="status"><Icon name="check" />Saved</p>}
      </>}
    </Fold>
  );
}
