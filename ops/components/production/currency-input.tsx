'use client';

import { useState } from 'react';

// Group the display string without converting financial values to floating
// point numbers. The named hidden field carries the original decimal value.
export function CurrencyInput({ id, name, defaultValue = '', required = false }: { id: string; name: string; defaultValue?: string; required?: boolean }) {
  const [raw, setRaw] = useState(defaultValue);
  const [whole, ...fraction] = raw.split('.');
  const display = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',') + (fraction.length ? `.${fraction.join('.')}` : '');
  return <><input className="input" id={id} inputMode="decimal" value={display} required={required} onChange={event => setRaw(event.target.value.replace(/,/g, ''))}/><input type="hidden" name={name} value={raw}/></>;
}
