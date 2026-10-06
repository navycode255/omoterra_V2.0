'use client';

import { useActionState, useEffect, useRef, useState } from 'react';
import type { ActionResult } from '@/lib/actions';
import styles from './duplicate-override.module.css';

// Staff answers are always English (lib/api.ts), so the backend's
// possible-duplicate refusal is told apart by its opening words.
export const POSSIBLE_DUPLICATE = 'Possible duplicate';

export function isPossibleDuplicate(error: string | null | undefined) {
  return Boolean(error?.startsWith(POSSIBLE_DUPLICATE));
}

/**
 * A payment with no reference that matches an earlier one (same party,
 * amount, day and direction) is refused until staff say it is a separate
 * payment and why (build plan M2.6). The backend keeps who decided and why.
 */
export function DuplicateOverride() {
  const [separate, setSeparate] = useState(false);
  return (
    <fieldset className={styles.override}>
      <legend>Is this the same payment?</legend>
      <label className={styles.tick}>
        <input type="checkbox" name="duplicate_override" value="true" checked={separate}
          onChange={(event) => setSeparate(event.target.checked)} />
        <span>This is a separate payment</span>
      </label>
      {separate && <div className="field">
        <label htmlFor="duplicate-reason">Why is it separate?</label>
        <input id="duplicate-reason" name="duplicate_reason" className="input" required minLength={3} maxLength={500}
          placeholder="e.g. Two cash payments, one for each order" />
      </div>}
      {!separate && <span className="meta">If it is the same payment, it is already recorded: do not save it again.</span>}
    </fieldset>
  );
}

type Field = HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement;

// React resets a form after its action runs. After a possible-duplicate
// refusal the same entry is sent again with an override, so what was typed
// is put back (a chosen file cannot be).
function restore(form: HTMLFormElement, values: FormData) {
  for (const element of Array.from(form.elements) as Field[]) {
    if (!element.name || !values.has(element.name) || element.name === 'duplicate_override') continue;
    if (element instanceof HTMLInputElement) {
      if (['hidden', 'file', 'submit', 'button'].includes(element.type)) continue;
      if (element.type === 'checkbox' || element.type === 'radio') {
        element.checked = values.getAll(element.name).map(String).includes(element.value);
        continue;
      }
    }
    const value = values.get(element.name);
    if (typeof value === 'string') element.value = value;
  }
}

/**
 * useActionState for a payment form: after a possible-duplicate refusal it
 * keeps what was typed, and says so (`duplicate`) so the form can show
 * <DuplicateOverride />.
 */
export function usePaymentAction(action: (state: ActionResult | null, formData: FormData) => Promise<ActionResult>) {
  const form = useRef<HTMLFormElement>(null);
  const sent = useRef<FormData | null>(null);
  const [state, formAction] = useActionState(async (previous: ActionResult | null, formData: FormData) => {
    const result = await action(previous, formData);
    // An action that redirected (the entry was saved) answers nothing.
    sent.current = result && !result.ok && isPossibleDuplicate(result.error) ? formData : null;
    return result;
  }, null);
  useEffect(() => {
    if (form.current && sent.current) restore(form.current, sent.current);
  }, [state]);
  return { form, state, formAction, duplicate: Boolean(state && !state.ok && isPossibleDuplicate(state.error)) };
}
