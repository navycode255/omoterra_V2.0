'use client';

import { useRouter } from 'next/navigation';
import { useState, type ReactNode } from 'react';
import { saveSupplierContact, type Contact } from '@/lib/portal-actions';
import { Select, Text } from '@/components/register/wizard';
import { Icon, type IconName } from './icons';

const contacts = [['phone', 'Phone call'], ['whatsapp', 'WhatsApp'], ['sms', 'Text message']] as const;

// A panel card whose contact or pickup details the supplier can change in
// place. Both kinds save the same endpoint, so each sends the other's values
// unchanged.
export function EditableCard({ id, icon, title, kind, contact, children }: {
  id?: string; icon: IconName; title: string; kind: 'contact' | 'pickup'; contact: Contact; children: ReactNode;
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
    <section id={id} className="portal-card">
      <h2>
        <Icon name={icon} />{title}
        {!editing && <button type="button" className="portal-edit" onClick={() => { setValues(contact); setSaved(false); setEditing(true); }}>Edit</button>}
      </h2>
      {editing ? (
        <form className="portal-form" noValidate onSubmit={(event) => { event.preventDefault(); if (!busy) save(); }}>
          {kind === 'contact' ? <>
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
            <button type="submit" className="button button-primary" disabled={busy}>{busy ? 'Saving…' : 'Save'}</button>
          </div>
        </form>
      ) : <>
        {children}
        {saved && <p className="portal-saved" role="status"><Icon name="check" />Saved</p>}
      </>}
    </section>
  );
}
