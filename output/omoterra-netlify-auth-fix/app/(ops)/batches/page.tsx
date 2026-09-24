import { ActionForm } from '@/components/form';
import { Card, Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { date, quantity, titleCase, tzs } from '@/lib/format';
import { verifyBatch } from '@/lib/actions';

export const metadata = { title: 'Production batches · Omoterra Operations' };
type Batch = { id: string; supplier_id: string; supplier_name: string; category: string; subtype: string; initial_quantity: string; current_quantity: string; reserved_quantity: string; available_to_commit: string; current_age: string | null; age_unit: string; expected_ready_date: string | null; expected_min_weight_kg: string | null; expected_max_weight_kg: string | null; actual_average_weight_kg: string | null; form: string; region: string; private_pickup_location: string; asking_price_per_unit: string | null; status: string; approved_at: string | null };
export default async function Batches() {
  let batches: Batch[];
  try { batches = await get<Batch[]>('/ops/batches'); }
  catch (error) { return <><div className="topbar"><PageHeader title="Production batches" /></div><div className="workspace"><Notice tone="error">{error instanceof ApiError ? error.message : 'Production batches could not be loaded.'}</Notice></div></>; }
  return <>
    <div className="topbar"><PageHeader title="Production batches" subtitle="Review future supplier capacity, readiness and quantity before allocating it to buyer demand." /></div>
    <div className="workspace">
      {batches.length === 0 ? <Empty>No supplier batches have been registered.</Empty> : <div className="stack">{batches.map((batch) => <Card key={batch.id} title={`${titleCase(batch.category)}${batch.subtype ? ` · ${batch.subtype}` : ''}`} action={<Status tone={batch.approved_at ? 'positive' : 'neutral'}>{batch.approved_at ? 'Reviewed' : 'Needs review'}</Status>}>
        <div className="grid-2" style={{ alignItems: 'start' }}>
          <div><p className="small">Supplier: <strong>{batch.supplier_name}</strong></p><p className="small">General region: {batch.region} · Private pickup: {batch.private_pickup_location || 'not recorded'}</p><p className="small">Total: {quantity(batch.current_quantity)} · Reserved: {quantity(batch.reserved_quantity)} · Available to commit: {quantity(batch.available_to_commit)}</p><p className="small">Age: {batch.current_age ?? '—'} {batch.age_unit} · Expected ready: {date(batch.expected_ready_date)}</p><p className="small">Expected weight: {batch.expected_min_weight_kg ?? '—'}–{batch.expected_max_weight_kg ?? '—'} kg · Form: {titleCase(batch.form)}</p><p className="meta">Asking price: {batch.asking_price_per_unit ? tzs(batch.asking_price_per_unit) : 'not entered'} · Batch {batch.id.slice(0,8)}</p></div>
          <ActionForm action={verifyBatch} label={batch.approved_at ? 'Record new verification' : 'Verify batch'} hidden={{ id: batch.id }}>
            <div className="field"><label htmlFor={`verified-${batch.id}`}>Verified quantity</label><input className="input" id={`verified-${batch.id}`} name="verified_quantity" inputMode="decimal" defaultValue={batch.current_quantity} required /></div>
            <div className="field"><label htmlFor={`rejected-${batch.id}`}>Rejected quantity</label><input className="input" id={`rejected-${batch.id}`} name="rejected_quantity" inputMode="decimal" defaultValue="0" /></div>
            <div className="field"><label htmlFor={`weight-${batch.id}`}>Sample average weight (kg)</label><input className="input" id={`weight-${batch.id}`} name="sampled_average_weight_kg" inputMode="decimal" defaultValue={batch.actual_average_weight_kg ?? ''} /></div>
            <div className="field"><label htmlFor={`asking-${batch.id}`}>Agreed supplier asking price per unit (TZS)</label><input className="input" id={`asking-${batch.id}`} name="supplier_asking_price_per_unit" inputMode="decimal" defaultValue={batch.asking_price_per_unit ?? ''} required /></div>
            <div className="field"><label htmlFor={`buyer-price-${batch.id}`}>Buyer price per unit (TZS)</label><input className="input" id={`buyer-price-${batch.id}`} name="buyer_price_per_unit" inputMode="decimal" required /></div>
            <div className="field"><label htmlFor={`payout-${batch.id}`}>Supplier payout per unit (TZS)</label><input className="input" id={`payout-${batch.id}`} name="supplier_payout_price_per_unit" inputMode="decimal" defaultValue="" /></div>
            <label className="row"><input type="checkbox" name="readiness_confirmed" /> Readiness confirmed</label>
            <label className="row"><input type="checkbox" name="location_confirmed" /> Location confirmed</label>
            <div className="field"><label htmlFor={`notes-${batch.id}`}>Inspection notes</label><textarea className="input" id={`notes-${batch.id}`} name="notes" /></div>
          </ActionForm>
        </div>
      </Card>)}</div>}
    </div>
  </>;
}
