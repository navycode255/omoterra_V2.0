import Image from 'next/image';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { Icons } from '@/components/icons';
import { SupplierStatusControl, SupplierVerificationForm } from '@/components/supplier-controls';
import { Empty, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { editSupplierProfile } from '@/lib/actions';
import { category, date, listingTone, phone, quantity, reference, titleCase, tzs } from '@/lib/format';
import type { SupplierDetail } from '@/lib/types';

const CATEGORY_KEYS = ['broilers','local_chicken','layers','eggs','goats','cattle','chicken_meat','beef','goat_meat'];
const REQUIRED_CHECKS = ['phone_confirmed', 'identity_reviewed', 'location_confirmed', 'production_seen', 'pickup_access_checked'];

function DetailCard({ icon, title, editHref, children, className = '', id }: { icon: React.ReactNode; title: string; editHref?: string; children: React.ReactNode; className?: string; id?: string }) {
  return <section className={`supplier-detail-card ${className}`} id={id}>
    <header><span className="section-title">{icon}{title}</span>{editHref && <Link href={editHref} className="card-edit"><Icons.edit size={18}/>Edit</Link>}</header>
    {children}
  </section>;
}

function Details({ items }: { items: [string, React.ReactNode][] }) {
  return <dl className="supplier-definition">{items.map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value}</dd></div>)}</dl>;
}

export default async function SupplierDetailPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ edit?: string }> }) {
  const [{ id }, query] = await Promise.all([params, searchParams]);
  let supplier: SupplierDetail;
  try { supplier = await get<SupplierDetail>(`/ops/suppliers/${id}`); }
  catch (error) { if (error instanceof ApiError && error.status === 404) notFound(); throw error; }
  const editMode = query.edit === '1';
  const canApprove = REQUIRED_CHECKS.every((check) => supplier.verification[check] === true);
  const editHref = `/suppliers/${supplier.id}?edit=1#supplier-editor`;
  const photos = supplier.evidence_photos ?? [];
  const owed = supplier.settlements.filter((settlement) => settlement.status === 'pending').reduce((sum, settlement) => sum + Number(settlement.total_payable), 0);

  return <>
    <div className="supplier-detail-topbar">
      <div className="breadcrumbs"><Link href="/suppliers">Suppliers</Link><Icons.chevron size={14}/><span>{supplier.public_alias}</span></div>
      <div className="supplier-identity">
        <div className="supplier-mark"><Icons.home size={34}/></div>
        <div><h1>{supplier.public_alias}</h1><p>{supplier.legal_name}<i/> {phone(supplier.phone)}<i/> {supplier.region}</p></div>
        <div className="supplier-head-actions"><SupplierStatusControl id={supplier.id} status={supplier.status} canApprove={canApprove}/><Link href={editHref} className="button" data-variant="secondary"><Icons.edit size={18}/>Edit supplier</Link><button className="icon-button" type="button" aria-label="More supplier actions"><Icons.more size={22}/></button></div>
      </div>
      <nav className="supplier-tabs" aria-label="Supplier sections"><a href="#overview" className="active"><Icons.cubes size={20}/>Overview</a><a href="#verification"><Icons.clipboard size={20}/>Verification</a><a href="#production"><Icons.users size={20}/>Production</a><a href="#history"><Icons.clock size={20}/>History</a></nav>
    </div>

    <main className="supplier-detail-workspace" id="overview">
      {editMode && <section className="supplier-editor" id="supplier-editor">
        <div className="editor-heading"><div><h2>Edit supplier</h2><p>Update the supplier identity, production profile and pickup details.</p></div><Link href={`/suppliers/${id}`} className="button" data-variant="secondary">Close</Link></div>
        <ActionForm action={editSupplierProfile} label="Save profile changes" hidden={{ id: supplier.id }}>
          <div className="grid-2">
            <div className="field"><label htmlFor="edit_public_alias">Farm / supplier alias</label><input className="input" id="edit_public_alias" name="public_alias" defaultValue={supplier.public_alias} required/></div>
            <div className="field"><label htmlFor="edit_legal_name">Legal / full name</label><input className="input" id="edit_legal_name" name="legal_name" defaultValue={supplier.legal_name} required/></div>
            <div className="field"><label htmlFor="edit_alternate_phone">Alternate phone</label><input className="input" id="edit_alternate_phone" name="alternate_phone" defaultValue={supplier.alternate_phone}/></div>
            <div className="field"><label htmlFor="edit_region">Region</label><input className="input" id="edit_region" name="region" defaultValue={supplier.region} required/></div>
            <div className="field"><label htmlFor="edit_district">District</label><input className="input" id="edit_district" name="district" defaultValue={supplier.district} required/></div>
            <div className="field"><label htmlFor="edit_area">General area</label><input className="input" id="edit_area" name="general_area" defaultValue={supplier.general_area}/></div>
          </div>
          <div className="field"><span>Normal supply categories and capacity</span><div className="category-editor">{CATEGORY_KEYS.map((key) => <label key={key}><span><input type="checkbox" name="categories" value={key} defaultChecked={supplier.categories.includes(key)}/> {category(key)}</span><input className="input" aria-label={`${category(key)} typical capacity`} name={`capacity_${key}`} type="number" min="0" step="any" defaultValue={supplier.production_profile[key]?.capacity ?? ''}/></label>)}</div></div>
          <div className="grid-2">
            <div className="field"><label htmlFor="edit_primary_category">Main category</label><select className="input" id="edit_primary_category" name="primary_category" defaultValue={supplier.primary_category ?? supplier.categories[0]}>{supplier.categories.map((key) => <option key={key} value={key}>{category(key)}</option>)}</select></div>
            <div className="field"><label htmlFor="edit_frequency">Production cycle</label><input className="input" id="edit_frequency" name="production_frequency" defaultValue={supplier.production_frequency}/></div>
            <div className="field"><label htmlFor="edit_pickup">Exact pickup location (private)</label><textarea className="input" id="edit_pickup" name="internal_pickup_address" defaultValue={supplier.internal_pickup_address} required/></div>
            <div className="field"><label htmlFor="edit_pickup_notes">Pickup instructions</label><textarea className="input" id="edit_pickup_notes" name="pickup_instructions" defaultValue={supplier.pickup_instructions}/></div>
            <label className="field checkbox-field"><span><input type="checkbox" name="omoterra_pickup" defaultChecked={supplier.omoterra_pickup}/> Omoterra can collect</span></label>
            <label className="field checkbox-field"><span><input type="checkbox" name="supplier_transport" defaultChecked={supplier.supplier_transport}/> Supplier can arrange transport</span></label>
            <div className="field"><label htmlFor="edit_contact">Preferred contact</label><select className="input" id="edit_contact" name="preferred_contact_method" defaultValue={supplier.preferred_contact_method}><option value="phone">Phone</option><option value="whatsapp">WhatsApp</option><option value="sms">SMS</option></select></div>
            <div className="field"><label htmlFor="edit_forms">Supply forms</label><select className="input" id="edit_forms" name="supply_forms" multiple defaultValue={supplier.supply_forms}>{['live','dressed','chilled','frozen'].map((form) => <option key={form} value={form}>{titleCase(form)}</option>)}</select></div>
          </div>
          <div className="field"><label htmlFor="edit_operating_notes">Operating notes</label><textarea className="input" id="edit_operating_notes" name="operating_notes" defaultValue={supplier.operating_notes}/></div>
          {photos.map((photo) => <input key={photo} type="hidden" name="evidence_photo_url" value={photo}/>)}
        </ActionForm>
      </section>}

      <div className="supplier-card-grid">
        <DetailCard icon={<Icons.clipboard size={22}/>} title="Supplier details" editHref={editHref}>
          <Details items={[["Farm / supplier alias", supplier.public_alias], ["Legal name", supplier.legal_name], ["Primary phone", phone(supplier.phone)], ["Alternate phone", phone(supplier.alternate_phone)], ["Joined", date(supplier.created_at)], ["Region", supplier.region || '—'], ["District", supplier.district || '—'], ["General area", supplier.general_area || '—'], ["Preferred contact", titleCase(supplier.preferred_contact_method)]]}/>
        </DetailCard>
        <DetailCard icon={<Icons.sprout size={23}/>} title="Production profile" editHref={editHref} id="production">
          <Details items={[["Main category", supplier.primary_category ? category(supplier.primary_category) : '—'], ["Production cycle", supplier.production_frequency || '—'], ["Can Omoterra collect?", supplier.omoterra_pickup ? 'Yes' : 'No'], ["Can supplier arrange transport?", supplier.supplier_transport ? 'Yes' : 'No'], ["Usual supply forms", supplier.supply_forms.map(titleCase).join(', ') || '—'], ["Operating schedule / notes", supplier.operating_notes || '—']]}/>
        </DetailCard>
        <DetailCard icon={<Icons.pin size={23}/>} title="Private pickup location" editHref={editHref}>
          <Details items={[["Address", supplier.internal_pickup_address || '—'], ["Region", supplier.region || '—'], ["Pickup instructions", supplier.pickup_instructions || '—']]}/>
        </DetailCard>
        <DetailCard icon={<Icons.cubes size={23}/>} title="Supply categories" editHref={editHref}>
          <div className="category-pills">{supplier.categories.length ? supplier.categories.map((item) => <span key={item}>{category(item)}</span>) : <span>None recorded</span>}</div>
        </DetailCard>
        <section className="supplier-detail-card" id="verification"><SupplierVerificationForm id={supplier.id} verification={supplier.verification} notes={supplier.internal_notes}/></section>
        <DetailCard icon={<Icons.image size={23}/>} title="Farm and supply photos" className="photo-card">
          {photos.length ? <div className="supplier-photos">{photos.slice(0, 3).map((photo) => <Image key={photo} src={`/media/${photo.split('/').pop()}`} width={220} height={140} alt="Supplier farm or supply" unoptimized/>)}</div> : <div className="no-supplier-photos"><Icons.camera size={28}/><span>No photos added</span></div>}
        </DetailCard>
      </div>
      <section className="supplier-lower-section" id="history">
        <h2>Current and planned production</h2>
        {supplier.batches.length === 0 ? <Empty>No production batches recorded yet.</Empty> : <div className="table-wrap lower-table"><table><thead><tr><th>Category / type</th><th>Quantity</th><th>Age</th><th>Expected ready</th><th>Expected weight</th><th>Reserved</th><th>Available</th><th>Batch review</th></tr></thead><tbody>{supplier.batches.map((batch) => <tr key={batch.id}>
          <td>{category(batch.category)}{batch.subtype ? ` · ${batch.subtype}` : ''}<div className="meta">{batch.region}</div></td><td>{quantity(batch.current_quantity)} / {quantity(batch.initial_quantity)}</td>
          <td>{batch.current_age ? `${quantity(batch.current_age)} ${batch.age_unit}` : '—'}</td><td>{batch.expected_ready_date ? date(batch.expected_ready_date) : '—'}</td>
          <td>{batch.expected_min_weight_kg || batch.expected_max_weight_kg ? `${batch.expected_min_weight_kg ?? '—'}–${batch.expected_max_weight_kg ?? '—'} kg` : '—'}</td>
          <td>{quantity(batch.reserved_quantity)}</td><td>{quantity(batch.available_to_commit)}</td><td><Status tone={batch.approved_at ? 'positive' : 'warning'}>{batch.approved_at ? 'OMOTERRA APPROVED' : titleCase(batch.status)}</Status></td>
        </tr>)}</tbody></table></div>}
      </section>
      <section className="supplier-lower-section"><h2>Stock and supply history</h2>
        {supplier.listings.length === 0 ? <Empty>No stock submitted yet.</Empty> : <div className="table-wrap lower-table"><table><thead><tr><th>Reference</th><th>Category</th><th className="numeric">Total</th><th className="numeric">Available</th><th className="numeric">Asking</th><th className="numeric">Buyer price</th><th>Status</th></tr></thead><tbody>{supplier.listings.map((listing) => <tr key={listing.id}><td><Link href={`/supply/${listing.id}`} className="strong">{reference(listing.id, 'ST')}</Link></td><td>{category(listing.category)}</td><td className="numeric">{quantity(listing.quantity_total)}</td><td className="numeric">{quantity(listing.quantity_available)}</td><td className="numeric">{tzs(listing.farmer_asking_price_per_unit)}</td><td className="numeric">{tzs(listing.buyer_price_per_unit)}</td><td><Status tone={listingTone(listing.listing_status)}>{titleCase(listing.listing_status)}</Status></td></tr>)}</tbody></table></div>}
        <p>{supplier.completed_supplies_count} completed supplies · {tzs(owed.toFixed(2))} pending settlements</p>
      </section>
      <section className="supplier-lower-section"><h2>Settlement history</h2>
        {supplier.settlements.length === 0 ? <Empty>No settlements yet.</Empty> : <div className="table-wrap lower-table"><table><thead><tr><th>Order item</th><th className="numeric">Asking</th><th className="numeric">Commission</th><th className="numeric">Payout</th><th className="numeric">Qty</th><th className="numeric">Total</th><th>Status</th></tr></thead><tbody>{supplier.settlements.map((settlement) => <tr key={settlement.id}><td>{reference(settlement.order_item_id, 'IT')}</td><td className="numeric">{tzs(settlement.farmer_asking_price_per_unit)}</td><td className="numeric">{tzs(settlement.commission_amount_per_unit)}</td><td className="numeric">{tzs(settlement.supplier_payout_price_per_unit)}</td><td className="numeric">{quantity(settlement.quantity)}</td><td className="numeric money">{tzs(settlement.total_payable)}</td><td>{settlement.status === 'paid' ? <Status tone="positive">Paid</Status> : <Status tone="warning">Pending</Status>}</td></tr>)}</tbody></table></div>}
      </section>
    </main>
  </>;
}
