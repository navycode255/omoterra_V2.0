'use client';

import { useActionState, useMemo, useState } from 'react';
import { useFormStatus } from 'react-dom';
import { createBuyerOrder, updateBuyerOrder } from '@/lib/buyer-order-actions';
import type { BuyerOrderDetail } from '@/lib/buyer-orders';
import { DEFAULT_UNIT, METHODS, PRODUCTS, UNITS, type Parties } from '@/lib/finance';
import { tanzanianMobile } from '@/lib/phone';
import { Icons } from '@/components/icons';
import { Busy } from '@/components/spinner';
import { AccountSelect } from '@/components/finance/account-select';
import styles from './finance.module.css';
import own from './buyer-orders.module.css';

// An order a buyer placed by phone or in person (build plan M2.5): who, what
// at the agreed price, when it is expected, and any deposit paid now. It is
// not a sale until it is marked delivered.

type Line = { key: number; category: string; description: string; unit: string; quantity: string; unit_price: string };

const BUYER_TYPES = ['personal', 'restaurant', 'butchery', 'hotel', 'retailer', 'caterer', 'other'];
const blank = (key: number): Line => ({ key, category: 'local_chicken', description: '', unit: 'bird', quantity: '', unit_price: '' });
const num = (value: string) => (value.trim() === '' ? NaN : Number(value.replace(/,/g, '')));
const clean = (value: string) => value.replace(/,/g, '').trim();
const tzs = (value: number) => `TZS ${Math.round(value).toLocaleString('en-US')}`;

function Submit({ disabled, editing }: { disabled: boolean; editing: boolean }) {
  const { pending } = useFormStatus();
  return <button type="submit" className={styles.saveButton} disabled={pending || disabled}>
    {pending ? <Busy>Saving…</Busy> : editing ? 'Save changes' : 'Save order'}
  </button>;
}

export function BuyerOrderForm({ parties, today, order }: { parties: Parties; today: string; order?: BuyerOrderDetail }) {
  const editing = Boolean(order);
  const [state, action] = useActionState(editing ? updateBuyerOrder : createBuyerOrder, null);
  const [idempotencyKey] = useState(() => crypto.randomUUID());
  const [mode, setMode] = useState<'existing' | 'new'>('existing');
  const [search, setSearch] = useState('');
  const [buyer, setBuyer] = useState(order ? `profile:${order.buyer_profile_id}` : '');
  const [newBuyer, setNewBuyer] = useState({ business_name: '', buyer_type: 'personal', contact_person: '', phone: '', region: '', area: '' });
  const [orderedOn, setOrderedOn] = useState(order?.ordered_on ?? today);
  const [expectedOn, setExpectedOn] = useState(order?.expected_on ?? '');
  const [lines, setLines] = useState<Line[]>(order ? order.items.map((item, index) => ({
    key: index + 1, category: item.category, description: item.description, unit: item.unit,
    quantity: String(Number(item.quantity)), unit_price: String(Number(item.unit_price)),
  })) : [blank(1)]);
  const [notes, setNotes] = useState(order?.notes ?? '');
  const [deposit, setDeposit] = useState({ amount: '', method: 'cash', reference: '', paid_on: today, account: '' });

  const matches = useMemo(() => {
    const q = search.trim().toLowerCase();
    const all = parties.buyers;
    const found = q ? all.filter((b) => `${b.name} ${b.phone} ${b.region}`.toLowerCase().includes(q)) : all;
    return found.slice(0, 200);
  }, [search, parties.buyers]);
  // Editing keeps the current buyer in the list even if it is not in the first 500.
  const current = order && !parties.buyers.some((b) => b.kind === 'profile' && b.id === order.buyer_profile_id);

  const total = lines.reduce((sum, l) => sum + (num(l.quantity) * num(l.unit_price) || 0), 0);
  const deposited = num(deposit.amount) || 0;
  const held = Number(order?.deposit_held ?? 0);
  const phoneProblem = mode === 'new' && newBuyer.phone.trim() !== '' && !tanzanianMobile(newBuyer.phone);
  const depositProblem = deposited + held > total && total > 0;
  const update = (key: number, change: Partial<Line>) => setLines((all) => all.map((l) => (l.key === key ? { ...l, ...change } : l)));

  const payload = useMemo(() => {
    const [kind, id] = buyer.split(':');
    const buyerPart = mode === 'new'
      ? { new_buyer: { ...newBuyer, phone: tanzanianMobile(newBuyer.phone) ?? newBuyer.phone.trim() } }
      : kind === 'user' ? { buyer_user_id: id } : { buyer_profile_id: id || null };
    return JSON.stringify({
      ...buyerPart, ordered_on: orderedOn, expected_on: expectedOn || null, notes,
      items: lines.map((l) => ({ category: l.category || null, description: l.description, unit: l.unit,
        quantity: clean(l.quantity), unit_price: clean(l.unit_price) })),
      ...(!editing && deposited > 0 ? { deposit: { amount: clean(deposit.amount), method: deposit.method, reference: deposit.reference,
        paid_on: deposit.paid_on, money_account_id: deposit.account || null } } : {}),
    });
  }, [buyer, mode, newBuyer, orderedOn, expectedOn, notes, lines, editing, deposited, deposit]);

  return (
    <form action={action} className={styles.saleForm} data-buyer-order-form>
      <input type="hidden" name="payload" value={payload} />
      <input type="hidden" name="idempotency_key" value={idempotencyKey} />
      {order && <input type="hidden" name="order_id" value={order.id} />}

      <section className={styles.stepCard}>
        <div className={styles.stepHeader}>
          <h2 className={styles.stepTitle}><span>1</span>Buyer</h2>
          <div className={styles.buyerModes} role="radiogroup" aria-label="Buyer">
            <label data-active={mode === 'existing'}><input type="radio" checked={mode === 'existing'} onChange={() => setMode('existing')} />Existing buyer</label>
            <label data-active={mode === 'new'}><input type="radio" checked={mode === 'new'} onChange={() => setMode('new')} />New buyer</label>
          </div>
        </div>
        {mode === 'existing' ? <div className={styles.buyerGrid}>
          <div className="field">
            <label htmlFor="order-buyer-search">Find buyer</label>
            <div className={styles.inputWithIcon}><Icons.search size={19} /><input id="order-buyer-search" className="input" placeholder="Name, phone or region"
              value={search} onChange={(e) => setSearch(e.target.value)} /></div>
          </div>
          <div className="field">
            <label htmlFor="order-buyer">Buyer ({matches.length} shown)</label>
            <select id="order-buyer" className="input" value={buyer} onChange={(e) => setBuyer(e.target.value)} required>
              <option value="">Choose a buyer…</option>
              {current && <option value={`profile:${order.buyer_profile_id}`}>{order.buyer_name}</option>}
              {matches.map((b) => <option key={`${b.kind}:${b.id}`} value={`${b.kind}:${b.id}`}>
                {b.name}{b.phone ? ` · ${b.phone}` : ''}{b.region ? ` · ${b.region}` : ''}{b.kind === 'user' ? ' · app' : ''}</option>)}
            </select>
          </div>
        </div> : <div className={styles.threeGrid}>
          <div className="field">
            <label htmlFor="order-nb-name">Buyer or business name</label>
            <input id="order-nb-name" className="input" required minLength={2} value={newBuyer.business_name}
              onChange={(e) => setNewBuyer({ ...newBuyer, business_name: e.target.value })} />
          </div>
          <div className="field">
            <label htmlFor="order-nb-phone">Phone</label>
            <input id="order-nb-phone" className="input" inputMode="tel" placeholder="07XX XXX XXX" value={newBuyer.phone}
              aria-invalid={phoneProblem} onChange={(e) => setNewBuyer({ ...newBuyer, phone: e.target.value })} />
            {phoneProblem && <span className={own.problem}>Enter a Tanzanian mobile number, e.g. 0754 123 456.</span>}
          </div>
          <div className="field">
            <label htmlFor="order-nb-type">Buyer type</label>
            <select id="order-nb-type" className="input" value={newBuyer.buyer_type} onChange={(e) => setNewBuyer({ ...newBuyer, buyer_type: e.target.value })}>
              {BUYER_TYPES.map((t) => <option key={t} value={t}>{t[0].toUpperCase() + t.slice(1)}</option>)}
            </select>
          </div>
          <div className="field">
            <label htmlFor="order-nb-region">Region</label>
            <input id="order-nb-region" className="input" value={newBuyer.region} onChange={(e) => setNewBuyer({ ...newBuyer, region: e.target.value })} />
          </div>
        </div>}
        <div className={own.dates}>
          <div className="field">
            <label htmlFor="ordered-on">Date ordered</label>
            <input id="ordered-on" type="date" className="input" value={orderedOn} max={today} required onChange={(e) => setOrderedOn(e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="expected-on">Expected delivery (optional)</label>
            <input id="expected-on" type="date" className="input" value={expectedOn} min={orderedOn} onChange={(e) => setExpectedOn(e.target.value)} />
          </div>
        </div>
      </section>

      <section className={styles.stepCard}>
        <div className={styles.stepHeader}><h2 className={styles.stepTitle}><span>2</span>What was ordered</h2></div>
        {lines.map((line, index) => <fieldset key={line.key} className={styles.saleLine}>
          <legend className={styles.srOnly}>Line {index + 1}</legend>
          <div className={styles.lineHeader}>
            <strong>Line {index + 1}</strong>
            <button type="button" className={styles.deleteLine} aria-label={`Remove line ${index + 1}`} disabled={lines.length === 1}
              onClick={() => setLines((all) => all.filter((l) => l.key !== line.key))}><Icons.trash size={19} /></button>
          </div>
          <div className={styles.lineGrid}>
            <div className="field">
              <label htmlFor={`order-cat-${line.key}`}>Product</label>
              <select id={`order-cat-${line.key}`} className="input" value={line.category}
                onChange={(e) => update(line.key, { category: e.target.value, unit: DEFAULT_UNIT[e.target.value] ?? line.unit })}>
                {PRODUCTS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
                <option value="">Something else</option>
              </select>
            </div>
            <div className="field">
              <label htmlFor={`order-desc-${line.key}`}>Details {line.category ? '(optional)' : ''}</label>
              <input id={`order-desc-${line.key}`} className="input" placeholder="e.g. Cocks, about 2 kg" value={line.description}
                required={!line.category} onChange={(e) => update(line.key, { description: e.target.value })} />
            </div>
            <div className="field">
              <label htmlFor={`order-unit-${line.key}`}>Unit</label>
              <select id={`order-unit-${line.key}`} className="input" value={line.unit} onChange={(e) => update(line.key, { unit: e.target.value })}>
                {UNITS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
              </select>
            </div>
            <div className="field">
              <label htmlFor={`order-qty-${line.key}`}>Quantity</label>
              <input id={`order-qty-${line.key}`} className="input" inputMode="decimal" required value={line.quantity}
                onChange={(e) => update(line.key, { quantity: e.target.value })} />
            </div>
            <div className="field">
              <label htmlFor={`order-price-${line.key}`}>Agreed price per unit (TZS)</label>
              <input id={`order-price-${line.key}`} className="input" inputMode="decimal" required value={line.unit_price}
                onChange={(e) => update(line.key, { unit_price: e.target.value })} />
            </div>
          </div>
        </fieldset>)}
        <button type="button" className={styles.addLine}
          onClick={() => setLines((all) => [...all, blank(Math.max(...all.map((l) => l.key)) + 1)])}><Icons.plus size={18} />Add another line</button>
      </section>

      <section className={styles.stepCard}>
        <div className={styles.stepHeader}><h2 className={styles.stepTitle}><span>3</span>{editing ? 'Notes' : 'Deposit and notes'}</h2></div>
        <div className={styles.paymentGrid}>
          {!editing && <>
            <div className="field">
              <label htmlFor="deposit-amount">Deposit paid now (optional, TZS)</label>
              <input id="deposit-amount" className="input" inputMode="decimal" placeholder="e.g. 20000" value={deposit.amount}
                onChange={(e) => setDeposit({ ...deposit, amount: e.target.value })} />
            </div>
            {deposited > 0 && <>
              <div className="field">
                <label htmlFor="deposit-method">Method</label>
                <select id="deposit-method" className="input" value={deposit.method} onChange={(e) => setDeposit({ ...deposit, method: e.target.value })}>
                  {METHODS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
                </select>
              </div>
              <AccountSelect id="deposit-account" name="deposit-account" label="Received into account" method={deposit.method}
                value={deposit.account} onChange={(value) => setDeposit((d) => ({ ...d, account: value }))} />
              <div className="field">
                <label htmlFor="deposit-ref">Transaction reference</label>
                <input id="deposit-ref" className="input" placeholder="e.g. M-Pesa code" value={deposit.reference}
                  onChange={(e) => setDeposit({ ...deposit, reference: e.target.value })} />
              </div>
              <div className="field">
                <label htmlFor="deposit-on">Date received</label>
                <input id="deposit-on" type="date" className="input" max={today} value={deposit.paid_on}
                  onChange={(e) => setDeposit({ ...deposit, paid_on: e.target.value })} />
              </div>
            </>}
          </>}
          <div className={`field ${styles.notesField}`}>
            <label htmlFor="order-notes">Notes (optional)</label>
            <textarea id="order-notes" className="input" placeholder="Who took the order, delivery place…" value={notes} onChange={(e) => setNotes(e.target.value)} />
          </div>
        </div>
        <p className={own.hint}>Not a sale yet: the buyer owes nothing and no stock is taken until you mark it delivered.
          {!editing && ' A deposit is money received, held for the buyer until then.'}</p>
      </section>

      {(depositProblem || (state && !state.ok)) && <div className="notice" data-tone="error">
        {depositProblem ? 'The deposit is more than the order total.' : state && !state.ok ? state.error : ''}
      </div>}
      <section className={styles.saleSummary}>
        <div className={styles.summaryMetric}><span className={styles.metricIcon}><Icons.cubes size={24} /></span><div><span>Order total</span><strong>{tzs(total)}</strong></div></div>
        <div className={styles.summaryMetric}><span className={styles.metricIcon}><Icons.wallet size={24} /></span><div><span>Deposit</span><strong>{tzs(deposited + held)}</strong></div></div>
        <div className={styles.summaryMetric}><span className={styles.metricIcon}><Icons.users size={24} /></span><div><span>Due on delivery</span><strong>{tzs(Math.max(total - deposited - held, 0))}</strong></div></div>
        <Submit editing={editing} disabled={phoneProblem || depositProblem || total <= 0} />
      </section>
    </form>
  );
}
