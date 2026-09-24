'use client';

import { useActionState } from 'react';
import { useFormStatus } from 'react-dom';
import { Icons } from '@/components/icons';
import { updateSupplierStatus, updateSupplierVerification, type ActionResult } from '@/lib/actions';

const CHECKS = [
  ['phone_confirmed', 'Phone confirmed', true],
  ['identity_reviewed', 'Identity reviewed', true],
  ['location_confirmed', 'Location confirmed', true],
  ['location_visited', 'Farm / supply location visited', false],
  ['production_seen', 'Livestock or production seen', true],
  ['pickup_access_checked', 'Pickup access checked', true],
  ['photos_reviewed', 'Photos reviewed', false],
] as const;

function StatusSelect({ status, canApprove }: { status: string; canApprove: boolean }) {
  const { pending } = useFormStatus();
  return <select name="status" defaultValue={status} aria-label="Supplier status" disabled={pending} onChange={(event) => event.currentTarget.form?.requestSubmit()}>
    <option value="under_review">{pending ? 'Saving…' : 'Under review'}</option>
    <option value="approved" disabled={!canApprove}>Approved</option>
    <option value="rejected">Rejected</option>
    <option value="suspended">Suspended</option>
  </select>;
}

export function SupplierStatusControl({ id, status, canApprove }: { id: string; status: string; canApprove: boolean }) {
  const [state, action] = useActionState<ActionResult | null, FormData>(updateSupplierStatus, null);
  return <div className="status-control-wrap">
    <form action={action} className="status-control" data-status={status}>
      <input type="hidden" name="id" value={id}/><input type="hidden" name="notes" value=""/>
      <span className="status-dot"/>
      <StatusSelect status={status} canApprove={canApprove}/><Icons.chevronDown size={15}/>
    </form>
    {!canApprove && status !== 'approved' && <small>Complete all 5 required checks to approve.</small>}
    {state && !state.ok && <p className="inline-error" role="alert">{state.error}</p>}
  </div>;
}

function VerificationSubmit() {
  const { pending } = useFormStatus();
  return <button className="verification-save" type="submit" disabled={pending}>{pending ? 'Saving…' : 'Save checklist'}</button>;
}

export function SupplierVerificationForm({ id, verification, notes }: { id: string; verification: Record<string, boolean>; notes: string }) {
  const [state, action] = useActionState<ActionResult | null, FormData>(updateSupplierVerification, null);
  const completed = CHECKS.filter(([, , required]) => required).filter(([key]) => verification[key]).length;
  return <form action={action} className="verification-form">
    <input type="hidden" name="id" value={id}/><input type="hidden" name="notes" value={notes}/>
    <div className="verification-heading"><span className="section-title"><Icons.shield size={23}/>Supplier verification</span><span className="verification-progress"><i><b style={{ width: `${completed * 20}%` }}/></i>{completed} / 5 completed</span></div>
    <div className="verification-checks">{CHECKS.map(([key, label, required]) => <label key={key}><input type="checkbox" name={key} defaultChecked={verification[key] ?? false}/><span>{label}</span>{required && <em className="sr-only"> required for approval</em>}</label>)}</div>
    <div className="verification-actions">{state && !state.ok && <span className="inline-error" role="alert">{state.error}</span>}<VerificationSubmit/></div>
  </form>;
}
