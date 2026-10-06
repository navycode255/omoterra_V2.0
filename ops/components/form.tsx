'use client';

import { useFormStatus } from 'react-dom';
import type { ReactNode } from 'react';
import type { ActionResult } from '@/lib/actions';
import { Busy } from '@/components/spinner';
import { DuplicateOverride, usePaymentAction } from '@/components/finance/duplicate-override';

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
      {pending ? <Busy>Working…</Busy> : label}
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
  // A payment refused as a possible duplicate keeps what was typed and
  // offers "This is a separate payment" (build plan M2.6).
  const { form, state, formAction, duplicate } = usePaymentAction(action);
  return (
    <form ref={form} action={formAction} className={layout === 'row' ? 'row' : 'stack'}>
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
      {duplicate && <DuplicateOverride />}
      <Submit label={label} variant={variant} confirm={confirm} />
    </form>
  );
}
