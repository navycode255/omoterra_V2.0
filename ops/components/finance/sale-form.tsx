'use client';

import { useActionState, useMemo, useState } from 'react';
import { useFormStatus } from 'react-dom';
import { createSale, updateSale } from '@/lib/finance-actions';
import { Icons } from '@/components/icons';
import { DEFAULT_UNIT, METHODS, PRODUCTS, UNITS, type OpenBatch, type Parties, type SaleDetail, type SupplierCollectionStock } from '@/lib/finance';
import type { LpoStockRow } from '@/lib/lpo';
import { tanzanianMobile } from '@/lib/phone';
import styles from './finance.module.css';

type Line = {
  key: number;
  category: string;
  description: string;
  unit: string;
  quantity: string;
  unit_price: string;
  source: 'own' | 'supplier' | 'named' | 'lpo' | 'collection';
  lpo_line_id: string;
  supplier_collection_id: string;
  supplier_batch_id: string;
  supplier_id: string;
  supplier_name: string;
  unit_cost: string;
  cost_status: 'owed' | 'paid';
  cost_method: string;
  cost_reference: string;
  cost_paid_on: string;
};

const BUYER_TYPES = ['personal', 'restaurant', 'butchery', 'hotel', 'retailer', 'caterer', 'other'];

function blank(key: number): Line {
  return { key, category: 'local_chicken', description: '', unit: 'bird', quantity: '', unit_price: '',
    source: 'own', supplier_id: '', supplier_name: '', unit_cost: '', lpo_line_id: '', supplier_collection_id: '', supplier_batch_id: '',
    cost_status: 'owed', cost_method: 'cash', cost_reference: '', cost_paid_on: '' };
}

// Money typed as "15,000" or "15000"; NaN when not a number.
const num = (value: string) => (value.trim() === '' ? NaN : Number(value.replace(/,/g, '')));
const tzs = (value: number) => `TZS ${Math.round(value).toLocaleString('en-US')}`;
const clean = (value: string) => value.replace(/,/g, '').trim();

function Submit({ disabled, editing = false }: { disabled: boolean; editing?: boolean }) {
  const { pending } = useFormStatus();
  return <button type="submit" className={styles.saveButton} disabled={pending || disabled}>
    <span aria-hidden="true">▣</span>{pending ? 'Saving…' : editing ? 'Save changes' : 'Save sale'}
  </button>;
}

function StepTitle({ number, children }: { number: number; children: React.ReactNode }) {
  return <h2 className={styles.stepTitle}><span>{number}</span>{children}</h2>;
}

export function SaleForm({ parties, today, stock = [], supplierStock = [], batches = [], sale }: { parties: Parties; today: string; stock?: LpoStockRow[]; supplierStock?: SupplierCollectionStock[]; batches?: OpenBatch[]; sale?: SaleDetail }) {
  const editing = Boolean(sale);
  const [state, action] = useActionState(editing ? updateSale : createSale, null);
  // One key per filled-in form: a double click or retry records one sale.
  const [idempotencyKey] = useState(() => crypto.randomUUID());
  const [mode, setMode] = useState<'existing' | 'new'>('existing');
  const [search, setSearch] = useState('');
  const [buyer, setBuyer] = useState(sale ? `profile:${sale.buyer_profile_id}` : '');
  const [newBuyer, setNewBuyer] = useState({ business_name: '', buyer_type: 'personal', contact_person: '', phone: '', region: '', area: '' });
  const [soldOn, setSoldOn] = useState(sale?.sold_on ?? today);
  const [lines, setLines] = useState<Line[]>(sale ? sale.items.map((item, index) => ({
    key: index + 1, category: item.category, description: item.description, unit: item.unit,
    quantity: item.quantity, unit_price: item.unit_price,
    source: item.supplier_collection_id ? 'collection' : item.lpo_line_id ? 'lpo' : item.supplier_id ? 'supplier' : item.supplier_name ? 'named' : 'own',
    lpo_line_id: item.lpo_line_id ?? '', supplier_collection_id: item.supplier_collection_id ?? '', supplier_batch_id: item.supplier_batch_id ?? '',
    supplier_id: item.supplier_id ?? '', supplier_name: item.supplier_name,
    unit_cost: item.unit_cost ?? '', cost_status: 'owed', cost_method: 'cash', cost_reference: '', cost_paid_on: sale.sold_on,
  })) : [blank(1)]);
  const [paid, setPaid] = useState({ amount: '', method: 'cash', reference: '', paid_on: today });
  const [notes, setNotes] = useState(sale?.notes ?? '');

  const matches = useMemo(() => {
    const q = search.trim().toLowerCase();
    const all = parties.buyers;
    return (q ? all.filter((b) => `${b.name} ${b.phone} ${b.region}`.toLowerCase().includes(q)) : all).slice(0, 200);
  }, [search, parties.buyers]);

  const total = lines.reduce((sum, l) => sum + (num(l.quantity) * num(l.unit_price) || 0), 0);
  const cost = lines.reduce((sum, l) => sum + (l.source !== 'own' ? num(l.quantity) * num(l.unit_cost) || 0 : 0), 0);
  const supplierCost = lines.reduce((sum, l) => sum + ((l.source === 'supplier' || l.source === 'named') ? num(l.quantity) * num(l.unit_cost) || 0 : 0), 0);
  const alreadyPaidToSuppliers = sale?.debts.filter((d) => d.direction === 'payable' && d.status !== 'cancelled')
    .reduce((sum, debt) => sum + Number(debt.paid_amount), 0) ?? 0;
  const supplierDue = editing ? Math.max(supplierCost - alreadyPaidToSuppliers, 0)
    : lines.reduce((sum, l) => sum + ((l.source === 'supplier' || l.source === 'named') && l.cost_status === 'owed' ? num(l.quantity) * num(l.unit_cost) || 0 : 0), 0);
  const paidNow = num(paid.amount) || 0;
  const recordedReceived = editing ? Number(sale?.received_amount ?? 0) : paidNow;
  const paymentProblem = recordedReceived > total;
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
        ...(l.source === 'supplier' ? { supplier_id: l.supplier_id || null, unit_cost: clean(l.unit_cost), supplier_batch_id: l.supplier_batch_id || null,
          ...(!editing && l.cost_status === 'paid' ? { cost_payment: { paid_on: l.cost_paid_on || soldOn, method: l.cost_method, reference: l.cost_reference } } : {}) } : {}),
        ...(l.source === 'named' ? { supplier_name: l.supplier_name, unit_cost: clean(l.unit_cost),
          ...(!editing && l.cost_status === 'paid' ? { cost_payment: { paid_on: l.cost_paid_on || soldOn, method: l.cost_method, reference: l.cost_reference } } : {}) } : {}),
        ...(l.source === 'lpo' ? { lpo_line_id: l.lpo_line_id || null } : {}),
        ...(l.source === 'collection' ? { supplier_collection_id: l.supplier_collection_id || null } : {}),
      })),
      ...(!editing && paidNow > 0 ? { payment: { amount: clean(paid.amount), method: paid.method, reference: paid.reference, paid_on: paid.paid_on } } : {}),
    });
  }, [buyer, mode, newBuyer, soldOn, notes, lines, paid, paidNow, editing]);

  return (
    <form action={action} className={styles.saleForm}>
      <input type="hidden" name="payload" value={payload} />
      <input type="hidden" name="idempotency_key" value={idempotencyKey} />
      {sale && <input type="hidden" name="sale_id" value={sale.id} />}

      <section className={styles.stepCard}>
        <div className={styles.stepHeader}>
          <StepTitle number={1}>Buyer</StepTitle>
          <div className={styles.buyerModes} role="radiogroup" aria-label="Buyer">
            <label data-active={mode === 'existing'}><input type="radio" checked={mode === 'existing'} onChange={() => setMode('existing')} />Existing buyer</label>
            <label data-active={mode === 'new'}><input type="radio" checked={mode === 'new'} onChange={() => setMode('new')} />New buyer</label>
          </div>
        </div>
        {mode === 'existing' ? (
          <div className={styles.buyerGrid}>
            <div className="field">
              <label htmlFor="buyer-search">Find buyer</label>
              <div className={styles.inputWithIcon}><Icons.search size={19} /><input id="buyer-search" className="input" placeholder="Name, phone or region" value={search}
                onChange={(e) => setSearch(e.target.value)} /></div>
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
            </div>
          </div>
        ) : (
          <div className={styles.threeGrid}>
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

      <section className={styles.stepCard}>
        <div className={styles.stepHeader}><StepTitle number={2}>What was sold</StepTitle></div>
        {lines.map((line, index) => {
          return (
            <fieldset key={line.key} className={styles.saleLine}>
              <legend className={styles.srOnly}>Line {index + 1}</legend>
              <div className={styles.lineHeader}>
                <strong>Line {index + 1}</strong>
                <button type="button" className={styles.deleteLine} aria-label={`Remove line ${index + 1}`} disabled={lines.length === 1}
                  onClick={() => setLines((all) => all.filter((l) => l.key !== line.key))}><Icons.trash size={19} /></button>
              </div>
              <div className={styles.lineGrid}>
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
                  <input id={`qty-${line.key}`} className="input" inputMode="decimal" placeholder="e.g. 10" required value={line.quantity}
                    onChange={(e) => update(line.key, { quantity: e.target.value })} />
                </div>
                <div className="field">
                  <label htmlFor={`price-${line.key}`}>Selling price per unit (TZS)</label>
                  <input id={`price-${line.key}`} className="input" inputMode="decimal" placeholder="e.g. 15000" required value={line.unit_price}
                    onChange={(e) => update(line.key, { unit_price: e.target.value })} />
                </div>
                <div className="field">
                  <label htmlFor={`sold-on-${line.key}`}>Date sold</label>
                  <input id={`sold-on-${line.key}`} type="date" className="input" value={soldOn} max={today} required
                    onChange={(e) => setSoldOn(e.target.value)} />
                </div>
                <div className={`field ${styles.sourceField}`}>
                  <label htmlFor={`src-${line.key}`}>Stock came from</label>
                  <select id={`src-${line.key}`} className="input" value={line.source}
                    onChange={(e) => update(line.key, { source: e.target.value as Line['source'] })}>
                    <option value="own">Stock I already owned (no buying cost for this sale)</option>
                    <option value="supplier">Bought for this sale · registered supplier</option>
                    <option value="named">Bought for this sale · other supplier</option>
                    {supplierStock.length > 0 && <option value="collection">Stock collected from a supplier batch</option>}
                    {stock.length > 0 && <option value="lpo">Stock received on an LPO (already owed there)</option>}
                  </select>
                </div>
                {line.source === 'collection' && (() => {
                  const chosen = supplierStock.find((row) => row.id === line.supplier_collection_id);
                  return (
                    <div className="field">
                      <label htmlFor={`collection-${line.key}`}>Received supplier stock</label>
                      <select id={`collection-${line.key}`} className="input" required value={line.supplier_collection_id}
                        onChange={(e) => {
                          const row = supplierStock.find((item) => item.id === e.target.value);
                          update(line.key, { supplier_collection_id: e.target.value,
                            ...(row ? { unit: row.unit, category: row.category, unit_cost: row.unit_cost } : {}) });
                        }}>
                        <option value="">Choose a delivery note…</option>
                        {supplierStock.map((row) => (
                          <option key={row.id} value={row.id}>
                            {row.category.replaceAll('_', ' ')} · {row.collection_number} · {row.supplier_name} · {Number(row.on_hand)} {row.unit}s on hand
                          </option>
                        ))}
                      </select>
                      {chosen && <span className="meta">Received {chosen.received_on} from batch {chosen.batch_id.slice(0, 8)} · cost TZS {Number(chosen.unit_cost).toLocaleString('en-US')} each. Supplier debt was recorded on collection.</span>}
                    </div>
                  );
                })()}
                {line.source === 'lpo' && (() => {
                  const chosen = stock.find((row) => row.lpo_line_id === line.lpo_line_id);
                  return (
                    <div className="field">
                      <label htmlFor={`lpo-${line.key}`}>LPO stock</label>
                      <select id={`lpo-${line.key}`} className="input" required value={line.lpo_line_id}
                        onChange={(e) => {
                          const row = stock.find((r) => r.lpo_line_id === e.target.value);
                          update(line.key, { lpo_line_id: e.target.value, ...(row ? { unit: row.unit, category: row.category || line.category, unit_cost: row.unit_price } : {}) });
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
                      onChange={(e) => {
                        // Their oldest open batch of this product is the usual source.
                        const own = batches.filter((b) => b.supplier_id === e.target.value);
                        const first = own.find((b) => b.category === line.category) ?? own[0];
                        update(line.key, { supplier_id: e.target.value, supplier_batch_id: first?.id ?? '',
                          ...(first?.asking_price_per_unit && !line.unit_cost ? { unit_cost: String(Number(first.asking_price_per_unit)) } : {}) });
                      }}>
                      <option value="">Choose…</option>
                      {parties.suppliers.map((s) => (
                        <option key={s.id} value={s.id}>{s.name}{s.alias ? ` (${s.alias})` : ''} · {s.phone}</option>
                      ))}
                    </select>
                  </div>
                )}
                {line.source === 'supplier' && line.supplier_id && (() => {
                  const own = batches.filter((b) => b.supplier_id === line.supplier_id);
                  const chosen = own.find((b) => b.id === line.supplier_batch_id);
                  const qty = num(line.quantity) || 0;
                  const short = chosen && !editing && qty > Number(chosen.remaining);
                  return (
                    <div className="field">
                      <label htmlFor={`batch-${line.key}`}>From batch</label>
                      <select id={`batch-${line.key}`} className="input" value={line.supplier_batch_id}
                        onChange={(e) => update(line.key, { supplier_batch_id: e.target.value })}>
                        {line.supplier_batch_id && !chosen && <option value={line.supplier_batch_id}>Batch used on this sale</option>}
                        {own.map((b) => (
                          <option key={b.id} value={b.id}>
                            {b.category.replaceAll('_', ' ')}{b.subtype ? ` (${b.subtype})` : ''} · {Number(b.remaining)} of {Number(b.registered)} left · registered {b.created_at.slice(0, 10)}
                          </option>
                        ))}
                        <option value="">Not from a registered batch</option>
                      </select>
                      <span className="meta" style={short ? { color: 'var(--error)' } : undefined}>
                        {chosen ? (short ? `Only ${Number(chosen.remaining)} left in this batch.` : `This sale reduces the batch to ${Math.max(Number(chosen.remaining) - qty, 0)} left.`)
                          : own.length ? 'The batch will not change.' : 'This supplier has no open batch registered.'}
                      </span>
                    </div>
                  );
                })()}
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
                      Purchase total: {Number.isFinite(num(line.quantity) * num(line.unit_cost)) ? tzs(num(line.quantity) * num(line.unit_cost)) : '—'}
                    </span>
                  </div>
                )}
                {(line.source === 'supplier' || line.source === 'named') && !editing && (
                  <div className="field">
                    <label htmlFor={`cost-status-${line.key}`}>Supplier payment</label>
                    <select id={`cost-status-${line.key}`} className="input" value={line.cost_status}
                      onChange={(e) => update(line.key, { cost_status: e.target.value as Line['cost_status'] })}>
                      <option value="owed">Pay later · add to supplier balance</option>
                      <option value="paid">Already paid · record money out</option>
                    </select>
                  </div>
                )}
                {(line.source === 'supplier' || line.source === 'named') && !editing && line.cost_status === 'paid' && <>
                  <div className="field">
                    <label htmlFor={`cost-method-${line.key}`}>How supplier was paid</label>
                    <select id={`cost-method-${line.key}`} className="input" value={line.cost_method}
                      onChange={(e) => update(line.key, { cost_method: e.target.value })}>
                      {METHODS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
                    </select>
                  </div>
                  <div className="field">
                    <label htmlFor={`cost-ref-${line.key}`}>Receipt / transaction reference (optional)</label>
                    <input id={`cost-ref-${line.key}`} className="input" value={line.cost_reference}
                      onChange={(e) => update(line.key, { cost_reference: e.target.value })} />
                  </div>
                  <div className="field">
                    <label htmlFor={`cost-date-${line.key}`}>Date supplier was paid</label>
                    <input id={`cost-date-${line.key}`} type="date" className="input" max={today} required value={line.cost_paid_on || soldOn}
                      onChange={(e) => update(line.key, { cost_paid_on: e.target.value })} />
                  </div>
                </>}
                {(line.source === 'supplier' || line.source === 'named') && editing && (
                  <div className="field"><label>Supplier payment</label><span className="meta">Edit the cost here. Record or reverse payments from the sale page.</span></div>
                )}
              </div>
            </fieldset>
          );
        })}
        <button type="button" className={styles.addLine}
          onClick={() => setLines((all) => [...all, blank(Math.max(...all.map((l) => l.key)) + 1)])}><Icons.plus size={18} />Add another line</button>
      </section>

      {!editing && <section className={styles.stepCard}>
        <div className={styles.stepHeader}><StepTitle number={3}>Money received now (optional)</StepTitle></div>
        <div className={styles.paymentGrid}>
          <div className="field">
            <label htmlFor="paid-amount">Amount received (TZS)</label>
            <input id="paid-amount" className="input" inputMode="decimal" placeholder="e.g. 50000" value={paid.amount}
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
          <div className={`field ${styles.notesField}`}>
            <label htmlFor="notes">Notes (optional)</label>
            <textarea id="notes" className="input" placeholder="Add any notes about this payment..." value={notes} onChange={(e) => setNotes(e.target.value)} />
          </div>
        </div>
      </section>}
      {editing && <section className={styles.stepCard}><div className={styles.stepHeader}><StepTitle number={3}>Notes</StepTitle></div><div className={styles.paymentGrid}><div className={`field ${styles.notesField}`}><label htmlFor="notes">Notes (optional)</label><textarea id="notes" className="input" value={notes} onChange={(e) => setNotes(e.target.value)} /></div></div></section>}

      {(paymentProblem || (state && !state.ok)) && <div className="notice" data-tone="error">
        {paymentProblem ? editing ? 'The sale total cannot be less than money already received.' : 'The amount received is more than the sale total.' : state && !state.ok ? state.error : ''}
      </div>}
      <section className={styles.saleSummary}>
        <div className={styles.summaryMetric}><span className={styles.metricIcon}><Icons.cubes size={24} /></span><div><span>Sale total</span><strong>{tzs(total)}</strong></div></div>
        <div className={styles.summaryMetric}><span className={styles.metricIcon}><Icons.card size={24} /></span><div><span>Stock buying cost</span><strong>{tzs(cost)}</strong></div></div>
        <div className={styles.summaryMetric}><span className={styles.metricIcon}><Icons.users size={24} /></span><div><span>Gross profit</span><strong>{tzs(total - cost)}</strong></div></div>
        <div className={styles.summaryMetric}><span className={styles.metricIcon}><Icons.card size={24} /></span><div><span>Buyer will owe</span><strong>{tzs(Math.max(total - recordedReceived, 0))}</strong></div></div>
        <div className={styles.summaryMetric}><span className={styles.metricIcon}><Icons.box size={24} /></span><div><span>Supplier balance</span><strong>{tzs(supplierDue)}</strong></div></div>
        <Submit editing={editing} disabled={phoneProblem || paymentProblem || total <= 0} />
      </section>
    </form>
  );
}
