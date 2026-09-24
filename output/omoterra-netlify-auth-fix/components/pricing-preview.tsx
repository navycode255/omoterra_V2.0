'use client';

import { useState } from 'react';
import { tzs } from '@/lib/format';

// Commission and margin are shown for the operator's own reference as they type.
// Neither field is pre-filled: the specification requires buyer price to be
// entered explicitly, never derived from a default markup.
export function PricingPreview({ asking }: { asking: string }) {
  const [payout, setPayout] = useState('');
  const [buyer, setBuyer] = useState('');

  const askingValue = Number(asking);
  const payoutValue = payout.trim() === '' ? askingValue : Number(payout);
  const buyerValue = Number(buyer);

  const commission = Number.isFinite(payoutValue) ? askingValue - payoutValue : NaN;
  const margin = Number.isFinite(buyerValue) && Number.isFinite(payoutValue) ? buyerValue - payoutValue : NaN;

  return (
    <>
      <div className="grid-2">
        <div className="field">
          <label htmlFor="supplier_payout_price_per_unit">Supplier payout per unit</label>
          <input
            id="supplier_payout_price_per_unit"
            name="supplier_payout_price_per_unit"
            className="input"
            inputMode="decimal"
            placeholder={`Defaults to asking price (${asking})`}
            value={payout}
            onChange={(event) => setPayout(event.target.value)}
          />
          <span className="meta">Must not exceed the asking price.</span>
        </div>
        <div className="field">
          <label htmlFor="buyer_price_per_unit">Buyer price per unit</label>
          <input
            id="buyer_price_per_unit"
            name="buyer_price_per_unit"
            className="input"
            inputMode="decimal"
            required
            value={buyer}
            onChange={(event) => setBuyer(event.target.value)}
          />
          <span className="meta">Set explicitly. The supplier never sees this.</span>
        </div>
      </div>
      <div className="notice">
        <div className="between">
          <span>Commission per unit</span>
          <span className="money">{Number.isFinite(commission) ? tzs(commission.toFixed(2)) : '—'}</span>
        </div>
        <div className="between" style={{ marginTop: 'var(--s2)' }}>
          <span>Gross margin per unit</span>
          <span className="money">{Number.isFinite(margin) ? tzs(margin.toFixed(2)) : '—'}</span>
        </div>
      </div>
    </>
  );
}
