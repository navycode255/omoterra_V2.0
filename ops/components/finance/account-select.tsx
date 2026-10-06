'use client';

import { useEffect, useRef, useState } from 'react';
import { activeAccounts } from '@/lib/account-actions';
import { accountForMethod, type AccountOption } from '@/lib/accounts';

/**
 * Which money account a payment went through (build plan M2.3). Shown only
 * once accounts exist; then it is required. It suggests the account that fits
 * the form's payment method (`method`, or the form's own "method" field) and
 * staff can change it.
 */
export function AccountSelect({ name = 'money_account_id', method, value, onChange, id, inline = false, label = 'Account' }: {
  name?: string; method?: string; value?: string; onChange?: (value: string) => void; id?: string; inline?: boolean; label?: string;
}) {
  const [accounts, setAccounts] = useState<AccountOption[]>([]);
  const [chosen, setChosen] = useState(value ?? '');
  const [touched, setTouched] = useState(false);
  const ref = useRef<HTMLSelectElement>(null);
  const [formMethod, setFormMethod] = useState('');

  useEffect(() => { let live = true; activeAccounts().then((rows) => { if (live) setAccounts(rows); }); return () => { live = false; }; }, []);
  useEffect(() => {
    const form = ref.current?.form;
    if (!form || method !== undefined) return;
    const field = form.elements.namedItem('method') as HTMLSelectElement | null;
    if (field) setFormMethod(field.value);
    const listen = (event: Event) => { const t = event.target as HTMLSelectElement; if (t.name === 'method') setFormMethod(t.value); };
    form.addEventListener('change', listen);
    return () => form.removeEventListener('change', listen);
  }, [method, accounts.length]);

  const current = method ?? formMethod;
  const suggested = accountForMethod(accounts, current);
  const shown = value !== undefined ? value : (touched ? chosen : chosen || suggested);
  useEffect(() => { if (value !== undefined && !value && suggested && onChange) onChange(suggested); }, [suggested, value, onChange]);

  if (!accounts.length) return null;
  const select = <select ref={ref} id={id} name={name} className="input" required value={shown}
    onChange={(e) => { setTouched(true); setChosen(e.target.value); onChange?.(e.target.value); }}>
    <option value="">Choose the account</option>
    {accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
  </select>;
  return inline ? <label>{label}{select}</label> : <div className="field"><label htmlFor={id}>{label}</label>{select}</div>;
}
