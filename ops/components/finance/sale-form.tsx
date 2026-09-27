'use client';

import { useActionState, useMemo, useState } from 'react';
import { useFormStatus } from 'react-dom';
import { createSale } from '@/lib/finance-actions';
import { DEFAULT_UNIT, METHODS, PRODUCTS, UNITS, type Parties } from '@/lib/finance';
import type { LpoStockRow } from '@/lib/lpo';
import { tanzanianMobile } from '@/lib/phone';

type Line = {
  key: number;
  category: string;
  description: string;
  unit: string;
  quantity: string;
  unit_price: string;
  source: 'own' | 'supplier' | 'named' | 'lpo';
  lpo_line_id: string;
  supplier_id: string;
  supplier_name: string;
  unit_cost: string;
};

const BUYER_TYPES = ['personal', 'restaurant', 'butchery', 'hotel', 'retailer', 'caterer', 'other'];

function blank(key: number): Line {
  return { key, category: 'local_chicken', description: '', unit: 'bird', quantity: '', unit_price: '',
    source: 'own', supplier_id: '', supplier_name: '', unit_cost: '', lpo_line_id: '' };
}

// Money typed as "15,000" or "15000"; NaN when not a number.
const num = (value: string) => (value.trim() === '' ? NaN : Number(value.replace(/,/g, '')));
const tzs = (value: number) => `TZS ${Math.round(value).toLocaleString('en-US')}`;
const clean = (value: string) => value.replace(/,/g, '').trim();

function Submit({ disabled }: { disabled: boolean }) {
  const { pending } = useFormStatus();
  return <button type="submit" className="button" disabled={pending || disabled}>{pending ? 'Saving…' : 'Save sale'}</button>;
}

export function SaleForm({ parties, today, stock = [] }: { parties: Parties; today: string; stock?: LpoStockRow[] }) {
  const [state, action] = useActionState(createSale, null);
  // One key per filled-in form: a double click or retry records one sale.
  const [idempotencyKey] = useState(() => crypto.randomUUID());
  const [mode, setMode] = useState<'existing' | 'new'>('existing');
  const [search, setSearch] = useState('');
  const [buyer, setBuyer] = useState('');
  const [newBuyer, setNewBuyer] = useState({ business_name: '', buyer_type: 'personal', contact_person: '', phone: '', region: '', area: '' });
  const [soldOn, setSoldOn] = useState(today);
  const [lines, setLines] = useState<Line[]>([blank(1)]);
  const [paid, setPaid] = useState({ amount: '', method: 'cash', reference: '', paid_on: today });
  const [notes, setNotes] = useState('');

  const matches = useMemo(() => {
    const q = search.trim().toLowerCase();
    const all = parties.buyers;
    return (q ? all.filter((b) => `${b.name} ${b.phone} ${b.region}`.toLowerCase().includes(q)) : all).slice(0, 200);
  }, [search, parties.buyers]);

  const total = lines.reduce((sum, l) => sum + (num(l.quantity) * num(l.unit_price) || 0), 0);
  const cost = lines.reduce((sum, l) => sum + (l.source === 'supplier' || l.source === 'named' ? num(l.quantity) * num(l.unit_cost) || 0 : 0), 0);
  const paidNow = num(paid.amount) || 0;
  const phoneProblem = mode === 'new' && newBuyer.phone.trim() !== '' && !tanzanianMobile(newBuyer.phone);

  function update(key: number, change: Partial<Line>) {
    setLines((all) => all.map((l) => (l.key === key ? { ...l, ...change } : l)));
  }

  const payload = useMemo(() => {
    const [kind, id] = buyer.split(':');
    const buyerPart = mode === 'new'
      ? { new_buyer: { ...newBuyer, phone: tanzanianMobile(newBuyer.phone) ?? newBuyer.phone.trim() } }
      : kind === 'user' ? { buyer_user_id: id } : { buyer_profile_id: id || null };
    return JSON.stringify({
      ...buyerPart,
      sold_on: soldOn,
      notes,
      items: lines.map((l) => ({
        category: l.category || null,
        description: l.description,
        unit: l.unit,
        quantity: clean(l.quantity),
        unit_price: clean(l.unit_price),
        ...(l.source === 'supplier' ? { supplier_id: l.supplier_id || null, unit_cost: clean(l.unit_cost) } : {}),
        ...(l.source === 'named' ? { supplier_name: l.supplier_name, unit_cost: clean(l.unit_cost) } : {}),
        ...(l.source === 'lpo' ? { lpo_line_id: l.lpo_line_id || null } : {}),
      })),
      ...(paidNow > 0 ? { payment: { amount: clean(paid.amount), method: paid.method, reference: paid.reference, paid_on: paid.paid_on } } : {}),
    });
  }, [buyer, mode, newBuyer, soldOn, notes, lines, paid, paidNow]);

  return (
    <form action={action} className="stack">
      <input type="hidden" name="payload" value={payload} />
      <input type="hidden" name="idempotency_key" value={idempotencyKey} />

      <section className="card stack">
        <div className="between">
          <h3>1. Buyer</h3>
          <div className="row" role="radiogroup" aria-label="Buyer">
            <label className="row"><input type="radio" checked={mode === 'existing'} onChange={() => setMode('existing')} />Existing buyer</label>
            <label className="row"><input type="radio" checked={mode === 'new'} onChange={() => setMode('new')} />New buyer</label>
          </div>
        </div>
        {mode === 'existing' ? (
          <div className="grid-2">
            <div className="field">
              <label htmlFor="buyer-search">Find buyer</label>
              <input id="buyer-search" className="input" placeholder="Name, phone or region" value={search}
                onChange={(e) => setSearch(e.target.value)} />
            </div>
            <div className="field">
              <label htmlFor="buyer">Buyer ({matches.length} shown)</label>
              <select id="buyer" className="input" value={buyer} onChange={(e) => setBuyer(e.target.value)} required>
                <option value="">Choose a buyer…</option>
                {matches.map((b) => (
                  <option key={`${b.kind}:${b.id}`} value={`${b.kind}:${b.id}`}>
                    {b.name}{b.phone ? ` · ${b.phone}` : ''}{b.region ? ` · ${b.region}` : ''}{b.kind === 'user' ? ' · app' : ''}
                  </option>
                ))}
              </select>
              <span className="meta">Not in the list? Choose “New buyer”; they are saved for next time.</span>
            </div>
          </div>
        ) : (
          <div className="grid-3">
            <div className="field">
              <label htmlFor="nb-name">Buyer or business name</label>
              <input id="nb-name" className="input" required minLength={2} value={newBuyer.business_name}
                onChange={(e) => setNewBuyer({ ...newBuyer, business_name: e.target.value })} />
            </div>
            <div className="field">
              <label htmlFor="nb-phone">Phone (for receipts and promotions)</label>
              <input id="nb-phone" className="input" inputMode="tel" placeholder="07XX XXX XXX" value={newBuyer.phone}
                onChange={(e) => setNewBuyer({ ...newBuyer, phone: e.target.value })} aria-invalid={phoneProblem} />
              {phoneProblem && <span className="meta" style={{ color: 'var(--error)' }}>Enter a Tanzanian mobile number, e.g. 0754 123 456.</span>}
              <span className="meta">If this number is already a buyer, that buyer is used.</span>
            </div>
            <div className="field">
              <label htmlFor="nb-type">Buyer type</label>
              <select id="nb-type" className="input" value={newBuyer.buyer_type}
                onChange={(e) => setNewBuyer({ ...newBuyer, buyer_type: e.target.value })}>
                {BUYER_TYPES.map((t) => <option key={t} value={t}>{t[0].toUpperCase() + t.slice(1)}</option>)}
              </select>
            </div>
            <div className="field">
              <label htmlFor="nb-contact">Contact person</label>
              <input id="nb-contact" className="input" value={newBuyer.contact_person}
                onChange={(e) => setNewBuyer({ ...newBuyer, contact_person: e.target.value })} />
            </div>
            <div className="field">
              <label htmlFor="nb-region">Region</label>
              <input id="nb-region" className="input" value={newBuyer.region}
                onChange={(e) => setNewBuyer({ ...newBuyer, region: e.target.value })} />
            </div>
            <div className="field">
              <label htmlFor="nb-area">Area</label>
              <input id="nb-area" className="input" value={newBuyer.area}
                onChange={(e) => setNewBuyer({ ...newBuyer, area: e.target.value })} />
            </div>
          </div>
        )}
      </section>

      <section className="card stack">
        <div className="between">
          <h3>2. What was sold</h3>
          <div className="field" style={{ minWidth: 180 }}>
            <label htmlFor="sold_on">Date sold</label>
            <input id="sold_on" type="date" className="input" value={soldOn} max={today} required
              onChange={(e) => setSoldOn(e.target.value)} />
          </div>
        </div>
        {lines.map((line, index) => {
          const subtotal = num(line.quantity) * num(line.unit_price);
          return (
            <fieldset key={line.key} className="stack" style={{ border: '1px solid var(--border)', borderRadius: 12, padding: 'var(--s4)' }}>
              <legend className="strong small">Line {index + 1}</legend>
              <div className="grid-3">
                <div className="field">
                  <label htmlFor={`cat-${line.key}`}>Product</label>
                  <select id={`cat-${line.key}`} className="input" value={line.category}
                    onChange={(e) => update(line.key, { category: e.target.value, unit: DEFAULT_UNIT[e.target.value] ?? line.unit })}>
                    {PRODUCTS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
                    <option value="">Something else</option>
                  </select>
                </div>
                <div className="field">
                  <label htmlFor={`desc-${line.key}`}>Details {line.category ? '(optional)' : ''}</label>
                  <input id={`desc-${line.key}`} className="input" placeholder="e.g. Kienyeji cocks, 2 kg" value={line.description}
                    required={!line.category} onChange={(e) => update(line.key, { description: e.target.value })} />
                </div>
                <div className="field">
                  <label htmlFor={`unit-${line.key}`}>Unit</label>
                  <select id={`unit-${line.key}`} className="input" value={line.unit} onChange={(e) => update(line.key, { unit: e.target.value })}>
                    {UNITS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
                  </select>
                </div>
                <div className="field">
                  <label htmlFor={`qty-${line.key}`}>Quantity</label>
                  <input id={`qty-${line.key}`} className="input" inputMode="decimal" required value={line.quantity}
                    onChange={(e) => update(line.key, { quantity: e.target.value })} />
                </div>
                <div className="field">
                  <label htmlFor={`price-${line.key}`}>Selling price per unit (TZS)</label>
                  <input id={`price-${line.key}`} className="input" inputMode="decimal" required value={line.unit_price}
                    onChange={(e) => update(line.key, { unit_price: e.target.value })} />
                </div>
                <div className="field">
                  <label>Line total</label>
                  <div className="money" style={{ paddingTop: 10 }}>{Number.isFinite(subtotal) ? tzs(subtotal) : '—'}</div>
                </div>
                <div className="field">
                  <label htmlFor={`src-${line.key}`}>Stock came from</label>
                  <select id={`src-${line.key}`} className="input" value={line.source}
                    onChange={(e) => update(line.key, { source: e.target.value as Line['source'] })}>
                    <option value="own">My own stock (nothing owed)</option>
                    <option value="supplier">A registered supplier (I owe them)</option>
                    <option value="named">Another supplier (I owe them)</option>
                    {stock.length > 0 && <option value="lpo">Stock received on an LPO (already owed there)</option>}
                  </select>
                </div>
                {line.source === 'lpo' && (() => {
                  const chosen = stock.find((row) => row.lpo_line_id === line.lpo_line_id);
                  return (
                    <div className="field">
                      <label htmlFor={`lpo-${line.key}`}>LPO stock</label>
                      <select id={`lpo-${line.key}`} className="input" required value={line.lpo_line_id}
                        onChange={(e) => {
                          const row = stock.find((r) => r.lpo_line_id === e.target.value);
                          update(line.key, { lpo_line_id: e.target.value, ...(row ? { unit: row.unit, category: row.category || line.category } : {}) });
                        }}>
                        <option value="">Choose…</option>
                        {stock.map((row) => (
                          <option key={row.lpo_line_id} value={row.lpo_line_id}>
                            {row.item} · {row.lpo_number} · {row.supplier_name} · {Number(row.on_hand)} on hand
                          </option>
                        ))}
                      </select>
                      {chosen && <span className="meta">Cost TZS {Number(chosen.unit_price).toLocaleString('en-US')} each (LPO price). Already owed on the LPO, not added again.</span>}
                    </div>
                  );
                })()}
                {line.source === 'supplier' && (
                  <div className="field">
                    <label htmlFor={`sup-${line.key}`}>Supplier</label>
                    <select id={`sup-${line.key}`} className="input" required value={line.supplier_id}
                      onChange={(e) => update(line.key, { supplier_id: e.target.value })}>
                      <option value="">Choose…</option>
                      {parties.suppliers.map((s) => (
                        <option key={s.id} value={s.id}>{s.name}{s.alias ? ` (${s.alias})` : ''} · {s.phone}</option>
                      ))}
                    </select>
                  </div>
                )}
                {line.source === 'named' && (
                  <div className="field">
                    <label htmlFor={`supname-${line.key}`}>Supplier name</label>
                    <input id={`supname-${line.key}`} className="input" required minLength={2} value={line.supplier_name}
                      onChange={(e) => update(line.key, { supplier_name: e.target.value })} />
                  </div>
                )}
                {(line.source === 'supplier' || line.source === 'named') && (
                  <div className="field">
                    <label htmlFor={`cost-${line.key}`}>Buying cost per unit (TZS)</label>
                    <input id={`cost-${line.key}`} className="input" inputMode="decimal" required value={line.unit_cost}
                      onChange={(e) => update(line.key, { unit_cost: e.target.value })} />
                    <span className="meta">
                      I owe: {Number.isFinite(num(line.quantity) * num(line.unit_cost)) ? tzs(num(line.quantity) * num(line.unit_cost)) : '—'}
                    </span>
                  </div>
                )}
              </div>
              {lines.length > 1 && (
                <div>
                  <button type="button" className="button" data-variant="secondary"
                    onClick={() => setLines((all) => all.filter((l) => l.key !== line.key))}>Remove line</button>
                </div>
              )}
            </fieldset>
          );
        })}
        <div>
          <button type="button" className="button" data-variant="secondary"
            onClick={() => setLines((all) => [...all, blank(Math.max(...all.map((l) => l.key)) + 1)])}>+ Add another line</button>
        </div>
      </section>

      <section className="card stack">
        <h3>3. Money received now (optional)</h3>
        <p className="muted small">Leave the amount empty if the buyer has not paid yet. Later installments are recorded on the sale.</p>
        <div className="grid-3">
          <div className="field">
            <label htmlFor="paid-amount">Amount received (TZS)</label>
            <input id="paid-amount" className="input" inputMode="decimal" value={paid.amount}
              onChange={(e) => setPaid({ ...paid, amount: e.target.value })} />
          </div>
          <div className="field">
            <label htmlFor="paid-method">Method</label>
            <select id="paid-method" className="input" value={paid.method} onChange={(e) => setPaid({ ...paid, method: e.target.value })}>
              {METHODS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
            </select>
          </div>
          <div className="field">
            <label htmlFor="paid-ref">Transaction reference</label>
            <input id="paid-ref" className="input" placeholder="e.g. M-Pesa code" value={paid.reference}
              onChange={(e) => setPaid({ ...paid, reference: e.target.value })} />
          </div>
          <div className="field">
            <label htmlFor="paid-on">Date received</label>
            <input id="paid-on" type="date" className="input" max={today} value={paid.paid_on}
              onChange={(e) => setPaid({ ...paid, paid_on: e.target.value })} />
          </div>
        </div>
        <div className="field">
          <label htmlFor="notes">Notes (internal)</label>
          <textarea id="notes" className="input" value={notes} onChange={(e) => setNotes(e.target.value)} />
        </div>
      </section>

      <section className="card">
        <div className="stat-band" style={{ gridTemplateColumns: 'repeat(4, minmax(0, 1fr))' }}>
          <div className="stat"><div className="stat-label">Sale total</div><div className="stat-value">{tzs(total)}</div></div>
          <div className="stat"><div className="stat-label">Received now</div><div className="stat-value">{tzs(paidNow)}</div></div>
          <div className="stat"><div className="stat-label">Buyer will owe</div><div className="stat-value">{tzs(Math.max(total - paidNow, 0))}</div></div>
          <div className="stat"><div className="stat-label">I owe suppliers</div><div className="stat-value">{tzs(cost)}</div></div>
        </div>
        {paidNow > total && <div className="notice" data-tone="error" style={{ marginTop: 'var(--s4)' }}>The amount received is more than the sale total.</div>}
        {state && !state.ok && <div className="notice" data-tone="error" style={{ marginTop: 'var(--s4)' }}>{state.error}</div>}
        <div style={{ marginTop: 'var(--s4)' }}>
          <Submit disabled={phoneProblem || paidNow > total || total <= 0} />
        </div>
      </section>
    </form>
  );
}
