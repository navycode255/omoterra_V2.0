'use client';

import { useActionState } from 'react';
import { useFormStatus } from 'react-dom';
import { Busy } from '@/components/spinner';
import { withdrawMarketPrices } from '@/lib/market-price-actions';
import styles from './market-prices.module.css';

function Confirm() {
  const { pending } = useFormStatus();
  return <button type="submit" className="button" data-variant="danger" disabled={pending}>{pending ? <Busy>Withdrawing…</Busy> : 'Withdraw prices'}</button>;
}

// Withdrawing needs a reason; it stays on the price list's history.
export function WithdrawPrices({ id, scheduled }: { id: string; scheduled: boolean }) {
  const [state, action] = useActionState(withdrawMarketPrices, null);
  return <details className={styles.withdraw}>
    <summary className="button" data-variant="danger">{scheduled ? 'Cancel change' : 'Withdraw'}</summary>
    <form action={action}>
      <input type="hidden" name="id" value={id}/>
      <p>{scheduled ? 'This scheduled change will not take effect.' : 'Suppliers will see the previous price list again, or no price if there is none.'}</p>
      <input name="reason" className="input" required minLength={3} maxLength={300} placeholder="Reason, e.g. market rate fell"/>
      {state && !state.ok && <div className="notice" data-tone="error" role="alert">{state.error}</div>}
      <Confirm/>
    </form>
  </details>;
}
