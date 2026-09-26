import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Empty, Notice, PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { titleCase } from '@/lib/format';
import { createBuyerCRM } from '@/lib/actions';
import { ListControls } from '@/components/list-controls';
import { listPath, type ListParams, type Page } from '@/lib/paging';

export const metadata = { title: 'Buyer CRM · Omoterra Operations' };
type Buyer = { id: string; user_id: string | null; business_name: string; buyer_type: string; contact_person: string; phone: string; region: string; area: string; crm_record: boolean };
const TABS = [
  { key: '', label: 'All' },
  { key: 'crm', label: 'Business CRM' },
  { key: 'app', label: 'App accounts' },
];
export default async function Buyers({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let data: Page<Buyer>;
  try { data = await get<Page<Buyer>>(listPath('/ops/buyer-crm', params)); }
  catch (error) { return <><div className="topbar"><PageHeader title="Buyer CRM" /></div><div className="workspace"><Notice tone="error">{error instanceof ApiError ? error.message : 'Buyer records could not be loaded.'}</Notice></div></>; }
  return <>
    <div className="topbar"><PageHeader title="Buyer CRM" subtitle="Business buyer records, preferences and demand history. Details stay within Omoterra operations." /></div>
    <div className="workspace">
      <div className="grid-2" style={{ alignItems: 'start' }}>
        <ListControls path="/buyers" params={params} data={data} tabs={TABS} noun={['buyer', 'buyers']}
          placeholder="Search business, contact, phone or region">
        <div className="table-wrap">{data.items.length === 0 ? <Empty>No buyers in this view.</Empty> : <table><thead><tr><th>Business</th><th>Buyer type</th><th>Contact</th><th>Location</th><th>Record</th></tr></thead><tbody>{data.items.map((buyer) => <tr key={buyer.id}>
          <td><Link href={`/buyers/${buyer.id}`} className="strong">{buyer.business_name || 'Unnamed buyer'}</Link></td><td>{titleCase(buyer.buyer_type)}</td><td>{buyer.contact_person || '—'}<div className="meta">{buyer.phone || 'No phone recorded'}</div></td><td>{[buyer.area,buyer.region].filter(Boolean).join(', ') || '—'}</td><td>{buyer.crm_record ? 'Business CRM' : 'App account'}</td>
        </tr>)}</tbody></table>}</div>
        </ListControls>
        <section className="card"><h3 style={{ marginBottom: 'var(--s4)' }}>Add an offline buyer</h3><ActionForm action={createBuyerCRM} label="Save buyer">
          <div className="field"><label htmlFor="business_name">Business name</label><input className="input" id="business_name" name="business_name" required /></div>
          <div className="field"><label htmlFor="buyer_type">Buyer type</label><select className="input" id="buyer_type" name="buyer_type"><option value="restaurant">Restaurant</option><option value="butchery">Butchery</option><option value="hotel">Hotel</option><option value="retailer">Retailer</option><option value="caterer">Caterer</option><option value="other">Other</option></select></div>
          <div className="field"><label htmlFor="contact_person">Contact person</label><input className="input" id="contact_person" name="contact_person" /></div>
          <div className="field"><label htmlFor="phone">Phone</label><input className="input" id="phone" name="phone" inputMode="tel" /></div>
          <div className="field"><label htmlFor="region">Region</label><input className="input" id="region" name="region" /></div>
          <div className="field"><label htmlFor="area">Area</label><input className="input" id="area" name="area" /></div>
          <div className="field"><label htmlFor="internal_notes">Internal notes</label><textarea className="input" id="internal_notes" name="internal_notes" /></div>
        </ActionForm></section>
      </div>
    </div>
  </>;
}
