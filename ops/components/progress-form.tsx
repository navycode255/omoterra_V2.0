'use client';

import { useState } from 'react';
import { ActionForm } from '@/components/form';
import { progressOrder } from '@/lib/actions';
import { TRANSITIONS, titleCase } from '@/lib/format';
import type { InternalStatus } from '@/lib/types';

// Collection verification fields only apply at the quality check, and a pickup
// date only when scheduling one, so the form reveals them per target status.
export function ProgressForm({
  id,
  current,
  expected,
  paymentRecorded,
}: {
  id: string;
  current: InternalStatus;
  expected: string;
  paymentRecorded: boolean;
}) {
  const options = TRANSITIONS[current];
  const [target, setTarget] = useState<InternalStatus | ''>('');

  if (options.length === 0) {
    return <p className="muted small">This order has reached a final state. No further changes are possible.</p>;
  }

  const failing = target === 'cancelled' || target === 'payment_failed';

  return (
    <ActionForm
      action={progressOrder}
      label="Update status"
      variant={failing ? 'danger' : undefined}
      confirm={
        failing
          ? 'This releases the reserved stock back to the listing. Continue?'
          : undefined
      }
      hidden={{ id }}
    >
      <div className="field">
        <label htmlFor="internal_status">Move to</label>
        <select
          id="internal_status"
          name="internal_status"
          className="input"
          required
          value={target}
          onChange={(event) => setTarget(event.target.value as InternalStatus)}
        >
          <option value="">Choose a status…</option>
          {options.map((option) => (
            <option key={option} value={option}>
              {titleCase(option)}
            </option>
          ))}
        </select>
      </div>

      {target === 'pickup_scheduled' && (
        <div className="field">
          <label htmlFor="expected_collection_date">Expected collection date</label>
          <input
            id="expected_collection_date"
            name="expected_collection_date"
            type="date"
            className="input"
            required
          />
          <span className="meta">Set explicitly. It is never inferred from the buyer&apos;s delivery date.</span>
        </div>
      )}

      {target === 'quality_checked' && (
        <>
          <div className="grid-3">
            <div className="field">
              <label htmlFor="actual_quantity">Accepted quantity</label>
              <input id="actual_quantity" name="actual_quantity" className="input" inputMode="decimal" required />
            </div>
            <div className="field">
              <label htmlFor="rejected_quantity">Rejected quantity</label>
              <input id="rejected_quantity" name="rejected_quantity" className="input" inputMode="decimal" required />
            </div>
            <div className="field">
              <label htmlFor="actual_weight">Actual weight (kg)</label>
              <input id="actual_weight" name="actual_weight" className="input" inputMode="decimal" />
            </div>
          </div>
          <span className="meta">Accepted plus rejected must equal the reserved quantity ({expected}).</span>
          <div className="field">
            <label htmlFor="collection_notes">Collection notes</label>
            <textarea id="collection_notes" name="collection_notes" className="input" />
          </div>
        </>
      )}

      {failing && paymentRecorded && (
        <div className="notice" data-tone="error">
          A payment has already been recorded on this order. The backend requires manual refund
          reconciliation before it can be cancelled.
        </div>
      )}
    </ActionForm>
  );
}
