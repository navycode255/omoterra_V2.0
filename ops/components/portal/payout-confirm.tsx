'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { confirmPayout } from '@/lib/portal-actions';
import { Icon } from './icons';

// Asks the supplier whether a payout Omoterra recorded as sent reached them.
// "Not received" can be followed later by "I have received it".
export function PayoutConfirm({ id, disputed }: { id: string; disputed: boolean }) {
  const router = useRouter();
  const [reporting, setReporting] = useState(false);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function answer(received: boolean) {
    setBusy(true);
    setError('');
    try {
      const result = await confirmPayout(id, received, received ? '' : note);
      if (!result.ok) { setError(result.error); return; }
      setReporting(false);
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  if (reporting) {
    return (
      <div className="portal-confirm">
        <label htmlFor={`note-${id}`}>What happened? (optional)</label>
        <textarea id={`note-${id}`} rows={3} maxLength={500} value={note} onChange={(event) => setNote(event.target.value)}
          placeholder="For example: nothing arrived on my M-Pesa yet" />
        {error && <p className="join-error" role="alert">{error}</p>}
        <div className="portal-confirm-actions">
          <button type="button" className="button button-outline" disabled={busy} onClick={() => setReporting(false)}>Back</button>
          <button type="button" className="button portal-button-danger" disabled={busy} onClick={() => answer(false)}>{busy ? 'Sending…' : 'Report not received'}</button>
        </div>
      </div>
    );
  }
  return (
    <div className="portal-confirm">
      {error && <p className="join-error" role="alert">{error}</p>}
      <div className="portal-confirm-actions">
        <button type="button" className="button button-primary" disabled={busy} onClick={() => answer(true)}>
          <Icon name="check" />{busy ? 'Saving…' : disputed ? 'I have now received it' : 'Yes, I received it'}
        </button>
        {!disputed && <button type="button" className="button button-outline" disabled={busy} onClick={() => setReporting(true)}>Not received</button>}
      </div>
    </div>
  );
}
