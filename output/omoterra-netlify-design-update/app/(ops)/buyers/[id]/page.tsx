import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { Card, Definition, Empty, PageHeader, Status } from '@/components/ui';
import { createBuyerCRM, updateBuyerCRM } from '@/lib/actions';
import { ApiError, get } from '@/lib/api';
import { category, date, quantity, titleCase } from '@/lib/format';

export const metadata = { title: 'Buyer record · Omoterra Operations' };
type Requirement = { id: string; requirement_number: string; category: string; quantity: string; unit_type: string; needed_by_date: string; secured_quantity: string; status: string };
type Buyer = { id: string; user_id: string | null; crm_record: boolean; business_name: string; buyer_type: string; contact_person: string; phone: string; region: string; area: string; internal_notes: string; preferences: Record<string, unknown>; last_known_buying_price: string | null; minimum_order: string | null; payment_terms: string; completed_orders: number; total_quantity_purchased: string; cancelled_orders: number; rejected_deliveries: number; rejected_quantity: string; last_order_at: string | null; active_requirements: Requirement[] };

export default async function BuyerCRMDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let buyer: Buyer;
  try { buyer = await get<Buyer>(`/ops/buyer-crm/${id}`); }
  catch (error) { if (error instanceof ApiError && error.status === 404) notFound(); throw error; }
  const form = <>
    <input className="input" name="business_name" aria-label="Business name" defaultValue={buyer.business_name} required />
    <div className="field"><label htmlFor="buyer_type">Buyer type</label><select className="input" id="buyer_type" name="buyer_type" defaultValue={buyer.buyer_type}><option value="personal">Personal</option><option value="restaurant">Restaurant</option><option value="butchery">Butchery</option><option value="hotel">Hotel</option><option value="retailer">Retailer</option><option value="caterer">Caterer</option><option value="other">Other</option></select></div>
    <div className="field"><label htmlFor="contact_person">Contact person</label><input className="input" id="contact_person" name="contact_person" defaultValue={buyer.contact_person} /></div>
    <div className="field"><label htmlFor="phone">Phone</label><input className="input" id="phone" name="phone" defaultValue={buyer.phone} /></div>
    <div className="field"><label htmlFor="region">Region</label><input className="input" id="region" name="region" defaultValue={buyer.region} /></div>
    <div className="field"><label htmlFor="area">Area</label><input className="input" id="area" name="area" defaultValue={buyer.area} /></div>
    <div className="field"><label htmlFor="last_known_buying_price">Last known buying price</label><input className="input" id="last_known_buying_price" name="last_known_buying_price" inputMode="decimal" defaultValue={buyer.last_known_buying_price ?? ''} /></div>
    <div className="field"><label htmlFor="minimum_order">Minimum order</label><input className="input" id="minimum_order" name="minimum_order" inputMode="decimal" defaultValue={buyer.minimum_order ?? ''} /></div>
    <div className="field"><label htmlFor="preferred_products">Preferred products (comma separated)</label><input className="input" id="preferred_products" name="preferred_products" defaultValue={Array.isArray(buyer.preferences.preferred_products) ? buyer.preferences.preferred_products.join(', ') : ''} /></div>
    <div className="field"><label htmlFor="live_dressed_preference">Live / dressed preference</label><input className="input" id="live_dressed_preference" name="live_dressed_preference" defaultValue={String(buyer.preferences.live_dressed_preference ?? '')} /></div>
    <div className="grid-2"><div className="field"><label htmlFor="preference_minimum_weight_kg">Minimum weight (kg)</label><input className="input" id="preference_minimum_weight_kg" name="preference_minimum_weight_kg" inputMode="decimal" defaultValue={String(buyer.preferences.minimum_weight_kg ?? '')} /></div><div className="field"><label htmlFor="preference_maximum_weight_kg">Maximum weight (kg)</label><input className="input" id="preference_maximum_weight_kg" name="preference_maximum_weight_kg" inputMode="decimal" defaultValue={String(buyer.preferences.maximum_weight_kg ?? '')} /></div></div>
    <div className="field"><label htmlFor="typical_quantity">Typical quantity</label><input className="input" id="typical_quantity" name="typical_quantity" inputMode="decimal" defaultValue={String(buyer.preferences.typical_quantity ?? '')} /></div>
    <div className="field"><label htmlFor="purchase_frequency">Purchase frequency</label><input className="input" id="purchase_frequency" name="purchase_frequency" defaultValue={String(buyer.preferences.purchase_frequency ?? '')} /></div>
    <div className="field"><label htmlFor="preferred_days">Preferred days (comma separated)</label><input className="input" id="preferred_days" name="preferred_days" defaultValue={Array.isArray(buyer.preferences.preferred_days) ? buyer.preferences.preferred_days.join(', ') : ''} /></div>
    <div className="field"><label htmlFor="pickup_delivery_preference">Pickup / delivery preference</label><input className="input" id="pickup_delivery_preference" name="pickup_delivery_preference" defaultValue={String(buyer.preferences.pickup_delivery_preference ?? '')} /></div>
    <div className="field"><label htmlFor="payment_terms">Payment terms (operational metadata)</label><input className="input" id="payment_terms" name="payment_terms" defaultValue={buyer.payment_terms} /></div>
    <div className="field"><label htmlFor="internal_notes">Internal notes</label><textarea className="input" id="internal_notes" name="internal_notes" defaultValue={buyer.internal_notes} /></div>
  </>;
  return <>
    <div className="topbar"><PageHeader title={buyer.business_name || 'Buyer'} subtitle={`${buyer.phone || 'No phone recorded'} · ${buyer.area}${buyer.area && buyer.region ? ', ' : ''}${buyer.region}`} /></div>
    <div className="workspace">
      <div className="grid-2" style={{ alignItems: 'start' }}>
        <Card title="Buyer identity and preferences"><Definition items={[
          ['Business', buyer.business_name], ['Type', titleCase(buyer.buyer_type)], ['Contact', buyer.contact_person || '—'],
          ['Phone', buyer.phone || '—'], ['Location', [buyer.area,buyer.region].filter(Boolean).join(', ') || '—'],
          ['Completed orders', buyer.completed_orders], ['Total quantity purchased', quantity(buyer.total_quantity_purchased)],
          ['Cancelled orders', buyer.cancelled_orders], ['Rejected deliveries', `${buyer.rejected_deliveries} (${quantity(buyer.rejected_quantity)} units)`], ['Last order', date(buyer.last_order_at)],
          ['Preferences', Object.entries(buyer.preferences ?? {}).map(([key,value]) => `${titleCase(key)}: ${String(value)}`).join(' · ') || 'Not recorded'],
          ['Payment terms', buyer.payment_terms || '—'],
        ]} /></Card>
        <Card title={buyer.crm_record ? 'Edit buyer record' : 'Create buyer record'}>
          <ActionForm action={buyer.crm_record ? updateBuyerCRM : createBuyerCRM} label={buyer.crm_record ? 'Save buyer details' : 'Create CRM record'} hidden={{ id: buyer.id, user_id: buyer.user_id ?? '' }}>{form}</ActionForm>
        </Card>
      </div>
      <Card title="Active buyer requirements"><div className="table-wrap" style={{ border: 'none' }}>
        {buyer.active_requirements.length === 0 ? <Empty>No active requirements.</Empty> : <table><thead><tr><th>Requirement</th><th>Product</th><th className="numeric">Requested</th><th className="numeric">Secured</th><th>Needed by</th><th>Status</th></tr></thead><tbody>{buyer.active_requirements.map((row) => <tr key={row.id}>
          <td><Link className="strong" href={`/sourcing/${row.id}`}>{row.requirement_number}</Link></td><td>{category(row.category)}</td><td className="numeric">{quantity(row.quantity)} {row.unit_type}</td><td className="numeric">{quantity(row.secured_quantity)}</td><td>{date(row.needed_by_date)}</td><td><Status>{titleCase(row.status)}</Status></td>
        </tr>)}</tbody></table>}
      </div></Card>
      <p className="meta">Buyer contact and exact delivery details are available to Omoterra operations and are never included in supplier demand responses.</p>
    </div>
  </>;
}
