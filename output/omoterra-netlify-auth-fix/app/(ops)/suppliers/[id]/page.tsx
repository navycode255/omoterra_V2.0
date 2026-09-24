import Link from 'next/link';
import Image from 'next/image';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { Card, Definition, Empty, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { category, date, listingTone, quantity, reference, titleCase, tzs } from '@/lib/format';
import { editSupplierProfile, updateSupplierStatus, updateSupplierVerification } from '@/lib/actions';
import type { SupplierDetail } from '@/lib/types';

export default async function SupplierDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let supplier: SupplierDetail;
  try { supplier = await get<SupplierDetail>(`/ops/suppliers/${id}`); }
  catch (error) { if (error instanceof ApiError && error.status === 404) notFound(); throw error; }
  const owed = supplier.settlements.filter((s) => s.status === 'pending').reduce((sum, s) => sum + Number(s.total_payable), 0);
  const checks: [string, string][] = [
    ['phone_confirmed', 'Phone confirmed'], ['identity_reviewed', 'Identity reviewed'],
    ['location_confirmed', 'Location confirmed'], ['location_visited', 'Farm / supply location visited'],
    ['production_seen', 'Livestock or production seen'], ['pickup_access_checked', 'Pickup access checked'],
    ['photos_reviewed', 'Photos reviewed'],
  ];
  return <>
    <div className="topbar"><div><PageHeader title={supplier.public_alias} subtitle={`${supplier.legal_name} · ${supplier.phone}`} /><p className="topbar-sub">Registered supplier · {supplier.region}{supplier.district ? `, ${supplier.district}` : ''}</p></div><Status tone={supplier.status === 'approved' ? 'positive' : supplier.status === 'rejected' || supplier.status === 'suspended' ? 'error' : 'warning'}>{titleCase(supplier.status)}</Status></div>
    <div className="workspace">
      <Card title="Supplier review"><div className="grid-2">
        <Definition items={[
          ['Farm / supplier alias', supplier.public_alias], ['Legal name', supplier.legal_name], ['Primary phone', supplier.phone], ['Alternate phone', supplier.alternate_phone || '—'],
          ['Status', titleCase(supplier.status)], ['Joined', date(supplier.created_at)], ['Region', supplier.region || '—'], ['District', supplier.district || '—'],
          ['General area', supplier.general_area || '—'], ['Categories', supplier.categories.map(category).join(', ') || '—'],
        ]} />
        <ActionForm action={updateSupplierStatus} label="Save supplier status" hidden={{ id: supplier.id }}>
          <div className="field"><label htmlFor="supplier_status">Operational status</label><select className="input" id="supplier_status" name="status" defaultValue={supplier.status}><option value="under_review">Under review</option><option value="approved">Approved supplier</option><option value="rejected">Rejected</option><option value="suspended">Suspended</option></select></div>
          <div className="field"><label htmlFor="status_notes">Internal review notes</label><textarea className="input" id="status_notes" name="notes" defaultValue={supplier.internal_notes} /></div>
          <p className="meta">Record at least one typical capacity and its production frequency before approving. Each batch still requires a separate review.</p>
        </ActionForm>
      </div></Card>
      <Card title="Edit supplier profile"><ActionForm action={editSupplierProfile} label="Save profile changes" hidden={{ id: supplier.id }}>
        <div className="grid-2">
          <div className="field"><label htmlFor="edit_public_alias">Farm / supplier alias</label><input className="input" id="edit_public_alias" name="public_alias" defaultValue={supplier.public_alias} required /></div>
          <div className="field"><label htmlFor="edit_legal_name">Legal / full name</label><input className="input" id="edit_legal_name" name="legal_name" defaultValue={supplier.legal_name} required /></div>
          <div className="field"><label htmlFor="edit_alternate_phone">Alternate phone</label><input className="input" id="edit_alternate_phone" name="alternate_phone" defaultValue={supplier.alternate_phone} /></div>
          <div className="field"><label htmlFor="edit_region">Region</label><input className="input" id="edit_region" name="region" defaultValue={supplier.region} required /></div>
          <div className="field"><label htmlFor="edit_district">District</label><input className="input" id="edit_district" name="district" defaultValue={supplier.district} required /></div>
          <div className="field"><label htmlFor="edit_area">General area</label><input className="input" id="edit_area" name="general_area" defaultValue={supplier.general_area} /></div>
        </div>
        <div className="field"><span>Normal supply categories</span><div className="grid-3">{['broilers','local_chicken','layers','eggs','goats','cattle','chicken_meat','beef','goat_meat'].map((key) => <label key={key}><input type="checkbox" name="categories" value={key} defaultChecked={supplier.categories.includes(key)} /> {category(key)}<input className="input" aria-label={`${category(key)} typical capacity`} name={`capacity_${key}`} type="number" min="0" step="any" defaultValue={supplier.production_profile[key]?.capacity ?? ''} /></label>)}</div></div>
        <div className="grid-2">
          <div className="field"><label htmlFor="edit_primary_category">Main category</label><select className="input" id="edit_primary_category" name="primary_category" defaultValue={supplier.primary_category ?? supplier.categories[0]}>{supplier.categories.map((key) => <option key={key} value={key}>{category(key)}</option>)}</select></div>
          <div className="field"><label htmlFor="edit_frequency">Production cycle</label><input className="input" id="edit_frequency" name="production_frequency" defaultValue={supplier.production_frequency} /></div>
          <div className="field"><label htmlFor="edit_pickup">Exact pickup location (private)</label><textarea className="input" id="edit_pickup" name="internal_pickup_address" defaultValue={supplier.internal_pickup_address} required /></div>
          <div className="field"><label htmlFor="edit_pickup_notes">Pickup instructions</label><textarea className="input" id="edit_pickup_notes" name="pickup_instructions" defaultValue={supplier.pickup_instructions} /></div>
          <div className="field"><label><input type="checkbox" name="omoterra_pickup" defaultChecked={supplier.omoterra_pickup} /> Omoterra can collect</label></div>
          <div className="field"><label><input type="checkbox" name="supplier_transport" defaultChecked={supplier.supplier_transport} /> Supplier can arrange transport</label></div>
          <div className="field"><label htmlFor="edit_contact">Preferred contact</label><select className="input" id="edit_contact" name="preferred_contact_method" defaultValue={supplier.preferred_contact_method}><option value="phone">Phone</option><option value="whatsapp">WhatsApp</option><option value="sms">SMS</option></select></div>
          <div className="field"><label htmlFor="edit_forms">Supply forms</label><select className="input" id="edit_forms" name="supply_forms" multiple defaultValue={supplier.supply_forms}>{['live','dressed','chilled','frozen'].map((form) => <option key={form} value={form}>{titleCase(form)}</option>)}</select></div>
        </div>
        <div className="field"><label htmlFor="edit_operating_notes">Operating notes</label><textarea className="input" id="edit_operating_notes" name="operating_notes" defaultValue={supplier.operating_notes} /></div>
        {supplier.evidence_photos?.map((photo) => <input key={photo} type="hidden" name="evidence_photo_url" value={photo} />)}
        <p className="meta">Profile changes return the registration to review before its supply can appear to buyers.</p>
      </ActionForm></Card>

      <Card title="Production profile"><Definition items={[
        ['Main category', supplier.primary_category ? category(supplier.primary_category) : '—'], ['Production cycle', supplier.production_frequency || '—'],
        ['Can Omoterra collect?', supplier.omoterra_pickup ? 'Yes' : 'No'], ['Can supplier arrange transport?', supplier.supplier_transport ? 'Yes' : 'No'],
        ['Usual supply forms', supplier.supply_forms.map(titleCase).join(', ') || '—'], ['Preferred contact', titleCase(supplier.preferred_contact_method)],
        ...Object.entries(supplier.production_profile).map(([key, value]) => [`${category(key)} capacity`, `${quantity(value.capacity)} ${value.unit} per ${value.frequency || 'cycle'}`] as [string, string]),
        ['Operating schedule / notes', supplier.operating_notes || '—'],
      ]} /></Card>
      <Card title="Private pickup location"><Definition items={[
        ['Exact address', supplier.internal_pickup_address], ['Pickup instructions', supplier.pickup_instructions || '—'], ['Region and district', `${supplier.region}, ${supplier.district}`],
      ]} /></Card>
      <Card title="Supplier verification"><ActionForm action={updateSupplierVerification} label="Save verification checklist" hidden={{ id: supplier.id }}>
        <div className="grid-2">{checks.map(([key, label]) => <label key={key} className="field"><span><input type="checkbox" name={key} defaultChecked={supplier.verification[key] ?? false} /> {label}</span></label>)}</div>
        <div className="field"><label htmlFor="verification_notes">Internal review notes</label><textarea className="input" id="verification_notes" name="notes" defaultValue={supplier.internal_notes} /></div>
        <p className="meta">Last reviewed {supplier.reviewed_at ? date(supplier.reviewed_at) : 'not yet'}{supplier.reviewed_by_actor ? ` by ${supplier.reviewed_by_actor}` : ''}. Approval is separate from batch approval.</p>
      </ActionForm><Definition items={[
        ['Supplier approved', supplier.approved_at ? `Yes · ${date(supplier.approved_at)} (${supplier.approved_by_actor ?? 'operations'})` : 'No'],
        ['Suspended', supplier.suspended_at ? `Yes · ${date(supplier.suspended_at)} (${supplier.suspended_by_actor ?? 'operations'})` : 'No'],
      ]} /></Card>
      <Card title="Farm and supply photos">{supplier.evidence_photos?.length ? <div className="photo-grid">{supplier.evidence_photos.map((photo) => <Image key={photo} src={`/media/${photo.split('/').pop()}`} alt="Supplier farm or supply location" width={480} height={360} unoptimized />)}</div> : <Empty>No farm photos have been added.</Empty>}</Card>
      <Card title="Current and planned production">{supplier.batches.length === 0 ? <Empty>No production batches recorded yet.</Empty> : <div className="table-wrap"><table><thead><tr><th>Category / type</th><th>Quantity</th><th>Age</th><th>Expected ready</th><th>Expected weight</th><th>Reserved</th><th>Available</th><th>Batch review</th></tr></thead><tbody>{supplier.batches.map((batch) => <tr key={batch.id}>
        <td>{category(batch.category)}{batch.subtype ? ` · ${batch.subtype}` : ''}<div className="meta">{batch.region}</div></td><td>{quantity(batch.current_quantity)} / {quantity(batch.initial_quantity)}</td>
        <td>{batch.current_age ? `${quantity(batch.current_age)} ${batch.age_unit}` : '—'}</td><td>{batch.expected_ready_date ? date(batch.expected_ready_date) : '—'}</td>
        <td>{batch.expected_min_weight_kg || batch.expected_max_weight_kg ? `${batch.expected_min_weight_kg ?? '—'}–${batch.expected_max_weight_kg ?? '—'} kg` : '—'}</td>
        <td>{quantity(batch.reserved_quantity)}</td><td>{quantity(batch.available_to_commit)}</td>
        <td><Status tone={batch.approved_at ? 'positive' : 'warning'}>{batch.approved_at ? 'OMOTERRA APPROVED' : titleCase(batch.status)}</Status><div className="meta">{batch.approved_at ? date(batch.approved_at) : 'Awaiting batch review'}</div></td>
      </tr>)}</tbody></table></div>}
        {supplier.batches.some((batch) => batch.photos.length > 0) && <div className="photo-grid" style={{ marginTop: 'var(--s4)' }}>{supplier.batches.flatMap((batch) => batch.photos.map((photo) => <Image key={`${batch.id}-${photo}`} src={`/media/${photo.split('/').pop()}`} alt={`${category(batch.category)} production`} width={480} height={360} unoptimized />))}</div>}
      </Card>
      <Card title="Stock and supply history"><div className="table-wrap">{supplier.listings.length === 0 ? <Empty>No stock submitted yet.</Empty> : <table><thead><tr><th>Reference</th><th>Category</th><th className="numeric">Total</th><th className="numeric">Available</th><th className="numeric">Asking</th><th className="numeric">Buyer price</th><th>Status</th></tr></thead><tbody>{supplier.listings.map((listing) => <tr key={listing.id}><td><Link href={`/supply/${listing.id}`} className="strong">{reference(listing.id, 'ST')}</Link></td><td>{category(listing.category)}</td><td className="numeric">{quantity(listing.quantity_total)}</td><td className="numeric">{quantity(listing.quantity_available)}</td><td className="numeric">{tzs(listing.farmer_asking_price_per_unit)}</td><td className="numeric">{tzs(listing.buyer_price_per_unit)}</td><td><Status tone={listingTone(listing.listing_status)}>{titleCase(listing.listing_status)}</Status></td></tr>)}</tbody></table>}</div><p className="meta">Completed supplies: {supplier.completed_supplies_count} · Pending settlements: {tzs(owed.toFixed(2))}</p></Card>
      <Card title="Settlement history">{supplier.settlements.length === 0 ? <Empty>No settlements yet.</Empty> : <div className="table-wrap"><table><thead><tr><th>Order item</th><th className="numeric">Asking</th><th className="numeric">Commission</th><th className="numeric">Payout</th><th className="numeric">Qty</th><th className="numeric">Total</th><th>Status</th></tr></thead><tbody>{supplier.settlements.map((settlement) => <tr key={settlement.id}><td className="small">{reference(settlement.order_item_id, 'IT')}</td><td className="numeric">{tzs(settlement.farmer_asking_price_per_unit)}</td><td className="numeric">{tzs(settlement.commission_amount_per_unit)}</td><td className="numeric">{tzs(settlement.supplier_payout_price_per_unit)}</td><td className="numeric">{quantity(settlement.quantity)}</td><td className="numeric money">{tzs(settlement.total_payable)}</td><td>{settlement.status === 'paid' ? <><Status tone="positive">Paid</Status><div className="meta">{date(settlement.paid_at)}</div></> : <Status tone="warning">Pending</Status>}</td></tr>)}</tbody></table></div>}</Card>
    </div>
  </>;
}
