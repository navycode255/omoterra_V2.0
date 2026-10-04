'use client';
import { useRef, useState, type ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import { saveLocationForm } from '@/lib/location-actions';
import { METHODS, PRODUCTS, UNITS } from '@/lib/finance';
import type { SupplierCollectionStock } from '@/lib/finance';
import type { LpoStockRow } from '@/lib/lpo';
import type { Allocation } from '@/lib/locations';
import { Busy } from '@/components/spinner';
import styles from './locations.module.css';

export function LocationForm({kind,id='',label,children}:{kind:string;id?:string;label:string;children:ReactNode}) {
  const key=useRef('');const router=useRouter();const [busy,setBusy]=useState(false);const [error,setError]=useState('');const [saved,setSaved]=useState(false);
  return <form className={styles.form} onSubmit={async event=>{
    event.preventDefault();if(busy)return;const form=event.currentTarget;const data=new FormData(form);
    if(!key.current)key.current=crypto.randomUUID();data.set('idempotency_key',key.current);setBusy(true);setError('');setSaved(false);
    try {const result=await saveLocationForm(kind,id,data);if(!result.ok){setError(result.error);return;}
      key.current='';if(kind!=='settings')form.reset();setSaved(true);router.refresh();
    }catch{setError('Could not save. Please try again.');}finally{setBusy(false);}
  }}>
    <fieldset disabled={busy}>{children}</fieldset>
    {error&&<p role="alert" className="notice" data-tone="error">{error}</p>}
    {saved&&<p role="status">Saved.</p>}
    <button className="button" disabled={busy}>{busy?<Busy>Saving…</Busy>:label}</button>
  </form>;
}
export function AllocationForm({id,now,stock,collections,opening,admin}:{id:string;admin:boolean;now:string;stock:LpoStockRow[];collections:SupplierCollectionStock[];opening:{id:string;description:string;unit:string;on_hand:string}[]}) {
  const [source,setSource]=useState(admin?'opening':collections[0]?`collection:${collections[0].id}`:stock[0]?`lpo:${stock[0].lpo_line_id}`:opening[0]?`returned:${opening[0].id}`:'');
  if(!admin&&!collections.length&&!stock.length&&!opening.length)return <p>No receipt or returned stock is available. An admin can enter opening stock with its buying cost.</p>;
  return <LocationForm kind="allocation" id={id} label="Allocate stock">
    <label>Allocation date<input type="date" name="allocated_on" defaultValue={now} max={now} required/></label>
    <label>Stock source<select name="source" value={source} onChange={e=>setSource(e.target.value)}>
      {admin&&<option value="opening">Opening / already owned stock</option>}
      {opening.map(r=><option key={r.id} value={`returned:${r.id}`}>Returned opening stock · {r.description} · {r.on_hand} {r.unit} available</option>)}
      {collections.map(r=><option key={r.id} value={`collection:${r.id}`}>Delivery note {r.collection_number} · {r.category} · {r.on_hand} {r.unit} available</option>)}
      {stock.map(r=><option key={r.lpo_line_id} value={`lpo:${r.lpo_line_id}`}>{r.lpo_number} · {r.item} · {r.on_hand} {r.unit} available</option>)}
    </select></label>
    {source==='opening'&&<><label>Product<select name="category">{PRODUCTS.map(([id,label])=><option key={id} value={id}>{label}</option>)}</select></label>
      <label>Description<input name="description" placeholder="e.g. BBQ chickens for kitchen A"/></label>
      <label>Unit<select name="unit">{UNITS.map(([id,label])=><option key={id} value={id}>{label}</option>)}</select></label>
      <label>Buying cost per unit (TZS)<input name="unit_cost" type="number" min="0" step="0.01" required/></label></>}
    <label>Quantity given to this location<input name="quantity" type="number" min="0.001" step="0.001" required/></label>
    <label>Notes<input name="notes"/></label>
    <p>Receipt stock keeps its recorded product, unit and cost. Opening stock must already belong to the business; do not enter receipt stock again as opening stock.</p>
  </LocationForm>;
}
export function DailySaleForm({id,now,allocations}:{id:string;now:string;allocations:Allocation[]}) {
  const available=allocations.filter(a=>Number(a.on_hand)>0);
  return available.length ? <LocationForm kind="sale" id={id} label="Record location sale">
    <label>Sale date<input name="sold_on" type="date" defaultValue={now} max={now} required/></label>
    <label>Allocated stock<select name="allocation_id" required>{available.map(a=><option key={a.id} value={a.id}>{a.description} · allocated {a.allocated_on} · {a.on_hand} {a.unit} left</option>)}</select></label>
    <label>Quantity sold<input name="quantity" type="number" min="0.001" step="0.001" required/></label>
    <label>Selling price per unit (TZS)<input name="unit_price" type="number" min="0.01" step="0.01" required/></label>
    <label>Money collected now (TZS)<input name="payment_amount" type="number" min="0" step="0.01" defaultValue="0" required/></label>
    <label>Payment method<select name="method">{METHODS.map(([id,label])=><option key={id} value={id}>{label}</option>)}</select></label>
    <label>Payment reference<input name="reference"/></label><label>Notes<input name="notes"/></label>
    <p>Record each price or payment method separately. Sales are included in total business sales; any unpaid amount stays in the debts ledger.</p>
  </LocationForm>:<p>Allocate stock first to record sales at this location.</p>;
}
