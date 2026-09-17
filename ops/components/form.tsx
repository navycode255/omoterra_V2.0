'use client';

import { useActionState } from 'react';
import { useFormStatus } from 'react-dom';
import type { ReactNode } from 'react';
import type { ActionResult } from '@/lib/actions';

function Submit({
  label,
  variant,
  confirm,
}: {
  label: string;
  variant?: 'secondary' | 'danger';
  confirm?: string;
}) {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      className="button"
      data-variant={variant}
      disabled={pending}
      onClick={(event) => {
        if (confirm && !window.confirm(confirm)) event.preventDefault();
      }}
    >
      {pending ? 'Working…' : label}
    </button>
  );
}

export function ActionForm({
  action,
  label,
  variant,
  confirm,
  children,
  hidden,
  layout = 'stack',
}: {
  action: (state: ActionResult | null, formData: FormData) => Promise<ActionResult>;
  label: string;
  variant?: 'secondary' | 'danger';
  confirm?: string;
  children?: ReactNode;
  hidden?: Record<string, string>;
  layout?: 'stack' | 'row';
}) {
  const [state, formAction] = useActionState(action, null);
  return (
    <form action={formAction} className={layout === 'row' ? 'row' : 'stack'}>
      {hidden &&
        Object.entries(hidden).map(([name, value]) => (
          <input key={name} type="hidden" name={name} value={value} />
        ))}
      {children}
      {state && !state.ok && (
        <div className="notice" data-tone="error">
          {state.error}
        </div>
      )}
      <Submit label={label} variant={variant} confirm={confirm} />
    </form>
  );
}
