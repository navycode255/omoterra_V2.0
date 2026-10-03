import Link from 'next/link';
import { payoutLabel } from '@/lib/payout-methods';
import { notFound } from 'next/navigation';
import { Icons } from '@/components/icons';
import { SupplierStatusControl, SupplierVerificationForm } from '@/components/supplier-controls';
import { ApprovalGuide, EditableCard, EditSupplierButton, SupplierTabs } from '@/components/supplier-profile';
import { SupplierPhotosCard, SupplierVideoCard } from '@/components/supplier-media';
import { ActionForm } from '@/components/form';
import { Empty, Status } from '@/components/ui';
import { closeSupplierBatch, receiveSupplierBatch, recordSoldElsewhere, registerSupplierBatch } from '@/lib/batch-stock-actions';
import { ApiError, get } from '@/lib/api';
import { category, date, listingTone, phone, quantity, reference, titleCase, tzs } from '@/lib/format';
import { approvalRequirements, missingProfileFields, type RequiredProfileField } from '@/lib/supplier';
import { today } from '@/lib/finance';
import type { SupplierDetail } from '@/lib/types';
import { SupplierStatementSection, type SupplierStatement } from '@/components/finance/supplier-statement';
import { requireSession } from '@/lib/session';

const CATEGORY_KEYS = ['broilers','local_chicken','layers','eggs','goats','cattle','chicken_meat','beef','goat_meat'];
const MAX_PHOTOS = 30;
const SECTION_FIELDS: Record<string, RequiredProfileField[]> = {
  details: ['public_alias', 'legal_name', 'region', 'district'],
  production: [],
  pickup: ['internal_pickup_address'],
  categories: ['categories'],
};

function Details({ items }: { items: [string, React.ReactNode][] }) {
  return <dl className="supplier-definition">{items.map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value}</dd></div>)}</dl>;
}

// The pin the supplier set in the app. Coordinates are the source of truth;
// the pasted link is kept alongside for reference.
function FarmLocation({ supplier }: { supplier: SupplierDetail }) {
  if (supplier.farm_latitude == null || supplier.farm_longitude == null) return <>Not set</>;
  const point = `${Number(supplier.farm_latitude).toFixed(6)},${Number(supplier.farm_longitude).toFixed(6)}`;
  return <a href={`https://www.google.com/maps/search/?api=1&query=${point}`} target="_blank" rel="noopener noreferrer">{point} · Open in Google Maps</a>;
}

function Field({ label, name, children }: { label: string; name: string; children: React.ReactNode }) {
  return <div className="field"><label htmlFor={`edit_${name}`}>{label}</label>{children}</div>;
}

export default async function SupplierDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let supplier: SupplierDetail;
  try { supplier = await get<SupplierDetail>(`/ops/suppliers/${id}`); }
  catch (error) { if (error instanceof ApiError && error.status === 404) notFound(); throw error; }
  // Direct purchases and payments; a failure here leaves the rest of the page.
  const statement = await get<SupplierStatement>(`/ops/ledger/suppliers/${id}/statement`).catch(() => null);
  const operator = await requireSession();
  const approval = approvalRequirements(supplier);
  const canApprove = approval.every((group) => group.items.every((item) => item.done));
  const missing = missingProfileFields(supplier);
  const categoryChoices = (withCapacity: boolean) => <div className="category-editor">
    <input type="hidden" name="categories_field" value="1"/>
    {CATEGORY_KEYS.map((key) => <label key={key}><span><input type="checkbox" name="categories" value={key} defaultChecked={supplier.categories.includes(key)}/> {category(key)}</span>{withCapacity && <input className="input" aria-label={`${category(key)} typical capacity`} placeholder="Typical capacity" name={`capacity_${key}`} type="number" min="0" step="any" defaultValue={supplier.production_profile[key]?.capacity ?? ''}/>}</label>)}
  </div>;
  const requiredInputs: Record<RequiredProfileField, React.ReactNode> = {
    public_alias: <Field key="public_alias" label="Farm / supplier alias" name="x_public_alias"><input className="input" id="edit_x_public_alias" name="public_alias" defaultValue={supplier.public_alias} required minLength={2}/></Field>,
    legal_name: <Field key="legal_name" label="Legal / full name" name="x_legal_name"><input className="input" id="edit_x_legal_name" name="legal_name" defaultValue={supplier.legal_name} required minLength={2}/></Field>,
    region: <Field key="region" label="Region" name="x_region"><input className="input" id="edit_x_region" name="region" defaultValue={supplier.region} required minLength={2}/></Field>,
    district: <Field key="district" label="District" name="x_district"><input className="input" id="edit_x_district" name="district" defaultValue={supplier.district} required minLength={2}/></Field>,
    internal_pickup_address: <Field key="internal_pickup_address" label="Exact pickup address (private)" name="x_internal_pickup_address"><textarea className="input" id="edit_x_internal_pickup_address" name="internal_pickup_address" defaultValue={supplier.internal_pickup_address} required minLength={3}/></Field>,
    categories: <div key="categories" className="field"><span>Supply categories</span>{categoryChoices(false)}</div>,
  };
  const extrasFor = (section: string) => {
    const fields = missing.filter((key) => !SECTION_FIELDS[section].includes(key));
    return fields.length ? <div className="grid-2">{fields.map((key) => requiredInputs[key])}</div> : undefined;
  };
  const owed = supplier.settlements.filter((settlement) => settlement.status === 'pending').reduce((sum, settlement) => sum + Number(settlement.total_payable), 0);

  return <>
    <div className="supplier-detail-topbar">
      <div className="breadcrumbs"><Link href="/suppliers">Suppliers</Link><Icons.chevron size={14}/><span>{supplier.public_alias}</span></div>
      <div className="supplier-identity">
        <div className="supplier-mark"><Icons.home size={34}/></div>
        <div><h1>{supplier.public_alias}</h1><p>{supplier.legal_name}<i/> {phone(supplier.phone)}<i/> {supplier.region}</p></div>
        <div className="supplier-head-actions"><SupplierStatusControl id={supplier.id} status={supplier.status} canApprove={canApprove} guide={<ApprovalGuide groups={approval} status={supplier.status}/>}/><EditSupplierButton/><button className="icon-button" type="button" aria-label="More supplier actions"><Icons.more size={22}/></button></div>
      </div>
      <SupplierTabs/>
    </div>

    <main className="supplier-detail-workspace" id="overview">
      <div className="supplier-card-grid">
        <EditableCard id={supplier.id} section="details" extras={extrasFor('details')} anchor="details" icon={<Icons.clipboard size={22}/>} title="Supplier details"
          view={<Details items={[["Farm / supplier alias", supplier.public_alias], ["Legal name", supplier.legal_name], ["Primary phone", phone(supplier.phone)], ["Alternate phone", phone(supplier.alternate_phone)], ["Joined", date(supplier.created_at)], ["Region", supplier.region || '—'], ["District", supplier.district || '—'], ["General area", supplier.general_area || '—'], ["Preferred contact", titleCase(supplier.preferred_contact_method)], ["Payouts by", supplier.payout_methods?.length ? supplier.payout_methods.map(payoutLabel).join(', ') : 'Not chosen']]}/>}
          fields={<div className="grid-2">
            <Field label="Farm / supplier alias" name="public_alias"><input className="input" id="edit_public_alias" name="public_alias" defaultValue={supplier.public_alias} required minLength={2}/></Field>
            <Field label="Legal / full name" name="legal_name"><input className="input" id="edit_legal_name" name="legal_name" defaultValue={supplier.legal_name} required minLength={2}/></Field>
            <Field label="Alternate phone" name="alternate_phone"><input className="input" id="edit_alternate_phone" name="alternate_phone" defaultValue={supplier.alternate_phone} placeholder="+2557XXXXXXXX" pattern="\+255[67][0-9]{8}"/></Field>
            <Field label="Preferred contact" name="preferred_contact_method"><select className="input" id="edit_preferred_contact_method" name="preferred_contact_method" defaultValue={supplier.preferred_contact_method || 'phone'}><option value="phone">Phone</option><option value="whatsapp">WhatsApp</option><option value="sms">SMS</option></select></Field>
            <Field label="Region" name="region"><input className="input" id="edit_region" name="region" defaultValue={supplier.region} required minLength={2}/></Field>
            <Field label="District" name="district"><input className="input" id="edit_district" name="district" defaultValue={supplier.district} required minLength={2}/></Field>
            <Field label="General area" name="general_area"><input className="input" id="edit_general_area" name="general_area" defaultValue={supplier.general_area}/></Field>
          </div>}/>
        <EditableCard id={supplier.id} section="production" extras={extrasFor('production')} icon={<Icons.sprout size={23}/>} title="Production profile"
          view={<Details items={[["Main category", supplier.primary_category ? category(supplier.primary_category) : '—'], ["Production cycle", supplier.production_frequency || '—'], ["Can Omoterra collect?", supplier.omoterra_pickup ? 'Yes' : 'No'], ["Can supplier arrange transport?", supplier.supplier_transport ? 'Yes' : 'No'], ["Usual supply forms", supplier.supply_forms.map(titleCase).join(', ') || '—'], ["Operating schedule / notes", supplier.operating_notes || '—']]}/>}
          fields={<>
            <div className="grid-2">
              <Field label="Main category" name="primary_category"><select className="input" id="edit_primary_category" name="primary_category" defaultValue={supplier.primary_category ?? supplier.categories[0]}>{supplier.categories.map((key) => <option key={key} value={key}>{category(key)}</option>)}</select></Field>
              <Field label="Production cycle" name="production_frequency"><input className="input" id="edit_production_frequency" name="production_frequency" defaultValue={supplier.production_frequency} placeholder="e.g. Every 6 weeks"/></Field>
            </div>
            <div className="check-row">
              <label><input type="checkbox" name="omoterra_pickup" defaultChecked={supplier.omoterra_pickup}/> Omoterra can collect</label>
              <label><input type="checkbox" name="supplier_transport" defaultChecked={supplier.supplier_transport}/> Supplier can arrange transport</label>
            </div>
            <fieldset className="check-row"><legend>Usual supply forms</legend>{['live','dressed','chilled','frozen'].map((form) => <label key={form}><input type="checkbox" name="supply_forms" value={form} defaultChecked={supplier.supply_forms.includes(form)}/> {titleCase(form)}</label>)}</fieldset>
            <Field label="Operating schedule / notes" name="operating_notes"><textarea className="input" id="edit_operating_notes" name="operating_notes" defaultValue={supplier.operating_notes}/></Field>
          </>}/>
        <section className="card">
          <h3 style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 'var(--s3)' }}><Icons.star size={20}/>Reputation</h3>
          <Details items={[
            ['Buyer rating', supplier.reputation?.rating != null ? `${supplier.reputation.rating.toFixed(1)} of 5 (${supplier.reputation.ratings} ratings)` : `${supplier.reputation?.ratings ?? 0} ratings, not enough to show buyers an average`],
            ['Deliveries', String(supplier.reputation?.deliveries ?? 0)],
            ['Passed quality check', supplier.reputation?.quality_passed != null ? `${supplier.reputation.quality_passed}%` : 'No collections checked yet'],
          ]}/>
          <p className="meta" style={{ marginTop: 'var(--s2)' }}><a href="/ratings">See all ratings</a></p>
        </section>
        <EditableCard id={supplier.id} section="pickup" extras={extrasFor('pickup')} icon={<Icons.pin size={23}/>} title="Private pickup location"
          view={<Details items={[["Farm location", <FarmLocation key="farm" supplier={supplier}/>], ["Address", supplier.internal_pickup_address || '—'], ["Region", supplier.region || '—'], ["Pickup instructions", supplier.pickup_instructions || '—']]}/>}
          fields={<>
            <Field label="Exact pickup address (private)" name="internal_pickup_address"><textarea className="input" id="edit_internal_pickup_address" name="internal_pickup_address" defaultValue={supplier.internal_pickup_address} required minLength={3}/></Field>
            <Field label="Pickup instructions" name="pickup_instructions"><textarea className="input" id="edit_pickup_instructions" name="pickup_instructions" defaultValue={supplier.pickup_instructions}/></Field>
          </>}/>
        <EditableCard id={supplier.id} section="categories" extras={extrasFor('categories')} icon={<Icons.cubes size={23}/>} title="Supply categories"
          view={<div className="category-pills">{supplier.categories.length ? supplier.categories.map((item) => <span key={item}>{category(item)}</span>) : <span>None recorded</span>}</div>}
          fields={categoryChoices(true)}/>
        <section className="supplier-detail-card" id="verification"><SupplierVerificationForm id={supplier.id} verification={supplier.verification} notes={supplier.internal_notes}/></section>
        <SupplierPhotosCard id={supplier.id} photos={supplier.photos ?? []} limit={MAX_PHOTOS}/>
        <SupplierVideoCard id={supplier.id} video={supplier.video ?? null} uploadEnabled={supplier.video_upload_enabled ?? false}/>
      </div>
      <section className="supplier-lower-section" id="production">
        <div className="between"><div><h2>Supplier batches and received stock</h2><p className="meta">A batch is the supplier&apos;s production. Only quantities recorded on a delivery note become saleable Omoterra stock.</p></div>
          <details className="batch-action-panel"><summary className="button">Register supplier batch</summary>
            <ActionForm action={registerSupplierBatch} label="Register batch" hidden={{ supplier_id: supplier.id }}>
              <div className="grid-3">
                <div className="field"><label htmlFor="batch-category">Product</label><select id="batch-category" name="category" className="input" defaultValue={supplier.primary_category ?? 'broilers'} required>{CATEGORY_KEYS.map((key) => <option key={key} value={key}>{category(key)}</option>)}</select></div>
                <div className="field"><label htmlFor="batch-subtype">Breed / type</label><input id="batch-subtype" name="subtype" className="input" placeholder="e.g. Cobb 500" /></div>
                <div className="field"><label htmlFor="batch-quantity">Batch quantity</label><input id="batch-quantity" name="initial_quantity" type="number" min="0.001" step="0.001" className="input" required /></div>
                <div className="field"><label htmlFor="batch-ready">Ready date</label><input id="batch-ready" name="expected_ready_date" type="date" min={today()} defaultValue={today()} className="input" required /></div>
                <div className="field"><label htmlFor="batch-cost">Agreed cost per unit (TZS)</label><input id="batch-cost" name="asking_price_per_unit" type="number" min="1" step="0.01" className="input" required /></div>
                <div className="field"><label htmlFor="batch-form">Supply form</label><select id="batch-form" name="form" className="input" defaultValue="live"><option value="live">Live</option><option value="dressed">Dressed</option><option value="chilled">Chilled</option><option value="frozen">Frozen</option></select></div>
                <div className="field"><label htmlFor="batch-age">Current age</label><input id="batch-age" name="current_age" type="number" min="0" step="0.001" className="input" /></div>
                <div className="field"><label htmlFor="batch-age-unit">Age unit</label><select id="batch-age-unit" name="age_unit" className="input" defaultValue="weeks"><option value="days">Days</option><option value="weeks">Weeks</option><option value="months">Months</option></select></div>
                <div className="field"><label htmlFor="batch-region">Region</label><input id="batch-region" name="region" className="input" defaultValue={supplier.region} required minLength={2} /></div>
                <div className="field"><label htmlFor="batch-min-weight">Minimum weight (kg)</label><input id="batch-min-weight" name="expected_min_weight_kg" type="number" min="0.001" step="0.001" className="input" /></div>
                <div className="field"><label htmlFor="batch-max-weight">Maximum weight (kg)</label><input id="batch-max-weight" name="expected_max_weight_kg" type="number" min="0.001" step="0.001" className="input" /></div>
                <div className="field"><label htmlFor="batch-pickup">Pickup location</label><input id="batch-pickup" name="private_pickup_location" className="input" defaultValue={supplier.internal_pickup_address} /></div>
              </div>
            </ActionForm>
          </details>
        </div>
        {supplier.batches.length === 0 ? <Empty>No production batches recorded yet.</Empty> : <div className="batch-stock-list">{supplier.batches.map((batch) => {
          const active = batch.collections.filter((row) => !row.cancelled_at);
          const collected = active.reduce((sum, row) => sum + Number(row.accepted_quantity), 0);
          const onHand = active.reduce((sum, row) => sum + Number(row.on_hand), 0);
          const remaining = Number(batch.remaining);
          return <article key={batch.id} className="batch-stock-card">
            <div className="batch-stock-head"><div><strong>{category(batch.category)}{batch.subtype ? ` · ${batch.subtype}` : ''}</strong><span>Batch {batch.id.slice(0, 8)} · ready {batch.expected_ready_date ? date(batch.expected_ready_date) : '—'}</span></div><Status tone={batch.approved_at ? 'positive' : 'warning'}>{batch.approved_at ? titleCase(batch.status) : 'Pending review'}</Status></div>
            <dl className="batch-stock-metrics">
              <div><dt>Registered</dt><dd>{quantity(batch.registered)}</dd></div>
              <div><dt>Taken by Omoterra</dt><dd>{quantity(batch.taken_by_omoterra)}</dd><small>{quantity(String(collected))} on delivery notes · {quantity(batch.sold_direct)} sold straight to buyers</small></div>
              <div><dt>Sold elsewhere</dt><dd>{quantity(batch.sold_elsewhere)}</dd><small>by the supplier</small></div>
              <div><dt>Left in the batch</dt><dd>{quantity(String(remaining))}</dd>{Number(batch.reserved) > 0 && <small>{quantity(batch.reserved)} reserved for buyers</small>}</div>
            </dl>
            {Number(batch.registered) > 0 && <div className="batch-progress" aria-hidden="true">
              <span data-part="taken" style={{ width: `${Number(batch.taken_by_omoterra) / Number(batch.registered) * 100}%` }} />
              <span data-part="elsewhere" style={{ width: `${Number(batch.sold_elsewhere) / Number(batch.registered) * 100}%` }} />
            </div>}
            {onHand > 0 && <p className="meta">{quantity(String(onHand))} received birds still in Omoterra stock.</p>}
            {remaining > 0 && <details className="batch-receive-panel"><summary>Supplier sold some elsewhere</summary>
              <div className="grid-2">
                <ActionForm action={recordSoldElsewhere} label="Record sold elsewhere" hidden={{ supplier_id: supplier.id, batch_id: batch.id }}>
                  <div className="field"><label htmlFor={`elsewhere-${batch.id}`}>How many did they sell to others?</label><input id={`elsewhere-${batch.id}`} name="quantity" type="number" min="1" max={remaining} step="1" className="input" required /></div>
                  <div className="field"><label htmlFor={`elsewhere-note-${batch.id}`}>Note (optional)</label><input id={`elsewhere-note-${batch.id}`} name="notes" className="input" placeholder="e.g. Sold at the farm gate" /></div>
                </ActionForm>
                <ActionForm action={closeSupplierBatch} label={`Close batch (${quantity(String(remaining))} sold elsewhere)`} variant="danger"
                  confirm={`Mark the remaining ${remaining} as sold elsewhere and close this batch?`} hidden={{ supplier_id: supplier.id, batch_id: batch.id }}>
                  <p className="meta">Use this when the batch is finished: everything still left was sold by the supplier to other buyers.</p>
                  <div className="field"><label htmlFor={`close-note-${batch.id}`}>Note (optional)</label><input id={`close-note-${batch.id}`} name="notes" className="input" placeholder="e.g. Rest sold to a trader" /></div>
                </ActionForm>
              </div>
            </details>}
            {batch.elsewhere_history.length > 0 && <div className="collection-history"><h3>Sold elsewhere</h3>{batch.elsewhere_history.map((row, index) => <div key={index}><span><strong>{quantity(row.quantity)} sold elsewhere</strong><small>{date(row.at)} · {row.by_staff ? 'recorded by Omoterra' : 'recorded by the supplier'}{row.note ? ` · ${row.note}` : ''}</small></span></div>)}</div>}
            {remaining > 0 && <details className="batch-receive-panel"><summary>Receive stock / create delivery note</summary>
              <ActionForm action={receiveSupplierBatch} label="Record collection" hidden={{ supplier_id: supplier.id, batch_id: batch.id }}>
                <div className="grid-3">
                  <div className="field"><label htmlFor={`received-${batch.id}`}>Collection date</label><input id={`received-${batch.id}`} name="received_on" type="date" max={today()} defaultValue={today()} className="input" required /></div>
                  <div className="field"><label htmlFor={`delivered-${batch.id}`}>Delivered quantity</label><input id={`delivered-${batch.id}`} name="delivered_quantity" type="number" min="0.001" max={remaining} step="0.001" className="input" required /></div>
                  <div className="field"><label htmlFor={`accepted-${batch.id}`}>Accepted into stock</label><input id={`accepted-${batch.id}`} name="accepted_quantity" type="number" min="0" max={remaining} step="0.001" className="input" required /></div>
                  <div className="field"><label htmlFor={`unit-cost-${batch.id}`}>Cost per unit (TZS)</label><input id={`unit-cost-${batch.id}`} name="unit_cost" type="number" min="1" step="0.01" defaultValue={batch.supplier_payout_price_per_unit ?? batch.asking_price_per_unit ?? ''} className="input" required /></div>
                  <div className="field"><label htmlFor={`weight-${batch.id}`}>Average weight (kg)</label><input id={`weight-${batch.id}`} name="average_weight_kg" type="number" min="0.001" step="0.001" className="input" /></div>
                  <div className="field"><label htmlFor={`terms-${batch.id}`}>Payment due after (days)</label><input id={`terms-${batch.id}`} name="payment_terms_days" type="number" min="0" max="180" defaultValue="0" className="input" /></div>
                </div>
                <div className="field"><label htmlFor={`collection-note-${batch.id}`}>Delivery note comments</label><textarea id={`collection-note-${batch.id}`} name="notes" className="input" placeholder="Condition, rejected stock, vehicle or collection details" /></div>
              </ActionForm>
            </details>}
            {active.length > 0 && <div className="collection-history"><h3>Collection history</h3>{active.map((row) => <Link key={row.id} href={`/supplier-collections/${row.id}`}><span><strong>{row.collection_number}</strong><small>{date(row.received_on)} · accepted {quantity(row.accepted_quantity)} · rejected {quantity(row.rejected_quantity)}</small></span><span><b>{quantity(row.on_hand)} on hand</b><small>{quantity(row.sold)} sold</small></span></Link>)}</div>}
          </article>;
        })}</div>}
      </section>
      <section className="supplier-lower-section" id="history"><h2>Stock and supply history</h2>
        {supplier.listings.length === 0 ? <Empty>No stock submitted yet.</Empty> : <div className="table-wrap lower-table"><table><thead><tr><th>Reference</th><th>Category</th><th className="numeric">Total</th><th className="numeric">Available</th><th className="numeric">Asking</th><th className="numeric">Buyer price</th><th>Status</th></tr></thead><tbody>{supplier.listings.map((listing) => <tr key={listing.id}><td><Link href={`/supply/${listing.id}`} className="strong">{reference(listing.id, 'ST')}</Link></td><td>{category(listing.category)}</td><td className="numeric">{quantity(listing.quantity_total)}</td><td className="numeric">{quantity(listing.quantity_available)}</td><td className="numeric">{tzs(listing.farmer_asking_price_per_unit)}</td><td className="numeric">{tzs(listing.buyer_price_per_unit)}</td><td><Status tone={listingTone(listing.listing_status)}>{titleCase(listing.listing_status)}</Status></td></tr>)}</tbody></table></div>}
        <p>{supplier.completed_supplies_count ?? 0} completed supplies · {tzs(owed.toFixed(2))} pending settlements</p>
      </section>
      <SupplierStatementSection statement={statement} supplierId={id} admin={operator.role === 'admin'} />
      <section className="supplier-lower-section"><h2>App order payouts</h2>
        {supplier.settlements.length === 0 ? <Empty>No settlements yet.</Empty> : <div className="table-wrap lower-table"><table><thead><tr><th>Order item</th><th className="numeric">Asking</th><th className="numeric">Commission</th><th className="numeric">Payout</th><th className="numeric">Qty</th><th className="numeric">Total</th><th>Status</th></tr></thead><tbody>{supplier.settlements.map((settlement) => <tr key={settlement.id}><td>{reference(settlement.order_item_id, 'IT')}</td><td className="numeric">{tzs(settlement.farmer_asking_price_per_unit)}</td><td className="numeric">{tzs(settlement.commission_amount_per_unit)}</td><td className="numeric">{tzs(settlement.supplier_payout_price_per_unit)}</td><td className="numeric">{quantity(settlement.quantity)}</td><td className="numeric money">{tzs(settlement.total_payable)}</td><td>{settlement.status === 'paid' ? <Status tone="positive">Paid</Status> : <Status tone="warning">Pending</Status>}</td></tr>)}</tbody></table></div>}
      </section>
    </main>
  </>;
}
