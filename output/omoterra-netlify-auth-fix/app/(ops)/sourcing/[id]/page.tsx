import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { Card, Definition, Empty, PageHeader, Status } from '@/components/ui';
import { convertRequirementToOrder, createAllocationPlan, reviewSupplyOffer, setRequirementProgress, updateAllocation } from '@/lib/actions';
import { get } from '@/lib/api';
import { category, date, quantity, titleCase, tzs } from '@/lib/format';

type Batch = { id: string; category: string; subtype: string; initial_quantity: string; current_quantity: string; reserved_quantity: string; available_to_commit: string; current_age: string | null; age_unit: string; expected_ready_date: string | null; expected_min_weight_kg: string | null; expected_max_weight_kg: string | null; form: string; region: string; private_pickup_location: string; status: string; asking_price_per_unit: string | null };
type Candidate = { batch: Batch; supplier_id: string; supplier_name: string; supplier_phone: string; supplier_public_alias: string; supplier_approved: boolean; available_quantity: string; ready_date: string; asking_price_per_unit: string | null };
type Offer = { id: string; batch_id: string | null; supplier_id: string; supplier_name: string; offered_quantity: string; accepted_quantity: string | null; expected_ready_date: string | null; expected_min_weight_kg: string | null; expected_max_weight_kg: string | null; asking_price_per_unit: string | null; supplier_notes: string; status: string };
type Allocation = { id: string; supplier_id: string; supplier_batch_id: string; allocated_quantity: string; status: string };
type Requirement = { id: string; requirement_number: string; buyer_profile_id: string | null; buyer_id: string | null; converted_order_id: string | null; delivery_addresses: { id: string; label: string; recipient_name: string; region: string; area: string }[]; buyer: { id: string; business_name: string; buyer_type: string; contact_person: string; phone: string; region: string; area: string } | null; category: string; product_subtype: string; quantity: string; unit_type: string; minimum_weight_kg: string | null; maximum_weight_kg: string | null; weight_or_size_requirement: string; live_dressed_or_cut: string; needed_by_date: string; delivery_area: string; delivery_region: string; delivery_notes: string; requirement_type: string; recurrence_frequency: string; preferred_weekdays: string[]; notes: string; admin_notes: string; status: string; secured_quantity: string; remaining_quantity: string; allocations: Allocation[]; offers: Offer[]; candidates: Candidate[] };

export default async function DemandDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let demand: Requirement;
  try { demand = await get<Requirement>(`/ops/requirements/${id}`); }
  catch { notFound(); }
  const nextStatuses: Record<string, string[]> = {
    open: ['confirmed', 'cancelled'], partially_matched: ['confirmed', 'cancelled'],
    fully_matched: ['confirmed', 'cancelled'], confirmed: ['fulfilling', 'cancelled'],
    fulfilling: ['completed', 'cancelled'],
  };
  const statuses = nextStatuses[demand.status] ?? [];
  const canConvert = demand.status === 'confirmed' && !demand.converted_order_id && demand.secured_quantity === demand.quantity;
  return <>
    <div className="topbar between"><PageHeader title={demand.requirement_number} subtitle={`${category(demand.category)} · needed by ${date(demand.needed_by_date)}`} /><Status>{titleCase(demand.status)}</Status></div>
    <div className="workspace">
      <div className="grid-2" style={{ alignItems: 'start' }}>
        <div className="stack">
          <Card title="Buyer requirement"><Definition items={[
            ['Product', `${category(demand.category)}${demand.product_subtype ? ` · ${demand.product_subtype}` : ''}`],
            ['Quantity', `${quantity(demand.quantity)} ${demand.unit_type}`],
            ['Secured', `${quantity(demand.secured_quantity)} / ${quantity(demand.quantity)}`],
            ['Remaining', `${quantity(demand.remaining_quantity)} ${demand.unit_type}`],
            ['Weight', demand.minimum_weight_kg || demand.maximum_weight_kg ? `${demand.minimum_weight_kg ?? 'Any'}–${demand.maximum_weight_kg ?? 'Any'} kg` : demand.weight_or_size_requirement || '—'],
            ['Form', demand.live_dressed_or_cut || '—'], ['Needed by', date(demand.needed_by_date)],
            ['Delivery region', demand.delivery_region || '—'], ['Delivery area', demand.delivery_area],
            ['Type', `${titleCase(demand.requirement_type)}${demand.recurrence_frequency ? ` · ${demand.recurrence_frequency}` : ''}`],
            ['Preferred days', demand.preferred_weekdays.join(', ') || '—'], ['Delivery notes', demand.delivery_notes || '—'], ['Buyer notes', demand.notes || '—'],
          ]} /></Card>
          <Card title="Buyer CRM">
            {demand.buyer ? <><Definition items={[
              ['Business', demand.buyer.business_name], ['Type', titleCase(demand.buyer.buyer_type)],
              ['Contact', demand.buyer.contact_person || '—'], ['Phone', demand.buyer.phone || '—'],
              ['Location', `${demand.buyer.area || ''}${demand.buyer.region ? `, ${demand.buyer.region}` : ''}`],
            ]} /><Link className="small" href={`/buyers/${demand.buyer.id}`}>Open CRM record →</Link></> : <p className="muted small">Offline buyer identity was not recorded.</p>}
          </Card>
          {demand.converted_order_id && <Card title="Fulfillment order"><p className="small">Order <Link href={`/orders/${demand.converted_order_id}`}>{demand.converted_order_id}</Link> is moving through the existing pay-on-delivery fulfillment process.</p></Card>}
          {canConvert && <Card title="Create fulfillment order"><p className="small muted">This converts each reserved supplier allocation into a private order item with its approved price and payout snapshot. Payment collection continues through the existing pay-on-delivery reconciliation workflow.</p><ActionForm action={convertRequirementToOrder} label="Create order" hidden={{ id }}><div className="field"><label htmlFor="delivery_address_id">Buyer delivery address</label>{demand.buyer_id ? <select className="input" id="delivery_address_id" name="delivery_address_id" required><option value="">Select saved address</option>{demand.delivery_addresses.map((address) => <option key={address.id} value={address.id}>{address.label} · {address.recipient_name} · {address.area}, {address.region}</option>)}</select> : <p className="small">Offline delivery will use the buyer CRM region and area.</p>}</div></ActionForm></Card>}
          {statuses.length > 0 && <Card title="Requirement progress"><ActionForm action={setRequirementProgress} label="Update progress" hidden={{ id }}>
            <div className="field"><label htmlFor="status">Next status</label><select className="input" id="status" name="status">{statuses.map((status) => <option key={status} value={status}>{titleCase(status)}</option>)}</select></div>
            <div className="field"><label htmlFor="internal_notes">Internal operations notes</label><textarea className="input" id="internal_notes" name="internal_notes" defaultValue={demand.admin_notes} /></div>
          </ActionForm></Card>}
        </div>
        <div className="stack">
          <Card title="Supplier offers">
            {demand.offers.length === 0 ? <Empty>No offers received yet.</Empty> : <div className="stack">{demand.offers.map((offer) => <div key={offer.id} className="card" style={{ boxShadow: 'none' }}>
              <div className="between"><strong>{offer.supplier_name}</strong><Status>{titleCase(offer.status)}</Status></div>
              <p className="small muted">{quantity(offer.offered_quantity)} offered · ready {date(offer.expected_ready_date)} · {offer.asking_price_per_unit ? tzs(offer.asking_price_per_unit) : 'price not entered'}</p>
              {offer.supplier_notes && <p className="small">{offer.supplier_notes}</p>}
              {offer.status === 'pending' && <ActionForm action={reviewSupplyOffer} label="Review offer" layout="row" hidden={{ id: offer.id, demand_id: id }}>
                <select className="input" name="status" defaultValue="accepted"><option value="accepted">Accept</option><option value="partially_accepted">Partially accept</option><option value="rejected">Reject</option></select>
                <input className="input" name="accepted_quantity" inputMode="decimal" placeholder="Accepted quantity for partial" />
              </ActionForm>}
            </div>)}</div>}
          </Card>
          <Card title="Matching candidates">
            {demand.candidates.length === 0 ? <Empty>No approved batches match the date, product, form and weight filters.</Empty> : <ActionForm action={createAllocationPlan} label="Create allocations" hidden={{ id }}>
              <p className="small muted">Enter quantities for one or more suppliers. Total may not exceed {quantity(demand.remaining_quantity)} remaining units. Allocation reserves capacity only; it does not create a buyer order.</p>
              <div className="table-wrap"><table><thead><tr><th>Supplier / batch</th><th>Location</th><th>Available</th><th>Ready</th><th>Weight</th><th>Asking price</th><th>Allocate</th></tr></thead><tbody>
                {demand.candidates.map((candidate) => {
                  const accepted = demand.offers.find((offer) => offer.batch_id === candidate.batch.id && ['accepted','partially_accepted'].includes(offer.status));
                  return <tr key={candidate.batch.id}>
                    <td><input type="hidden" name="batch_id" value={candidate.batch.id} /><strong>{candidate.supplier_name}</strong><div className="meta">{candidate.supplier_phone} · {candidate.batch.id.slice(0,8)} · {candidate.supplier_approved ? 'Approved supplier' : 'Review supplier'}</div></td>
                    <td className="small">{candidate.batch.region}<div className="meta">{candidate.batch.private_pickup_location}</div></td>
                    <td className="numeric">{quantity(candidate.available_quantity)}</td>
                    <td className="small">{date(candidate.ready_date)}</td>
                    <td className="small">{candidate.batch.expected_min_weight_kg ?? '—'}–{candidate.batch.expected_max_weight_kg ?? '—'} kg</td>
                    <td className="money">{candidate.asking_price_per_unit ? tzs(candidate.asking_price_per_unit) : '—'}</td>
                    <td><input className="input" style={{ minWidth: 100 }} inputMode="decimal" name={`quantity_${candidate.batch.id}`} placeholder="0" />{accepted && <input type="hidden" name={`offer_${candidate.batch.id}`} value={accepted.id} />}</td>
                  </tr>;
                })}
              </tbody></table></div>
            </ActionForm>}
          </Card>
          <Card title="Current allocations">
            {demand.allocations.length === 0 ? <Empty>No supplier capacity has been allocated.</Empty> : <div className="table-wrap"><table><thead><tr><th>Batch</th><th>Supplier ID</th><th>Quantity</th><th>Status</th><th>Change</th></tr></thead><tbody>{demand.allocations.map((allocation) => <tr key={allocation.id}>
              <td>{allocation.supplier_batch_id.slice(0,8)}</td><td>{allocation.supplier_id.slice(0,8)}</td><td>{quantity(allocation.allocated_quantity)}</td><td>{titleCase(allocation.status)}</td>
              {['reserved','supplier_confirmed','ready'].includes(allocation.status) ? <td><div className="stack"><ActionForm action={updateAllocation} label="Reduce" layout="row" hidden={{ id: allocation.id, demand_id: id }}><input className="input" name="allocated_quantity" inputMode="decimal" placeholder="New quantity" /></ActionForm><ActionForm action={updateAllocation} label="Release" variant="danger" confirm="Release this supplier capacity?" hidden={{ id: allocation.id, demand_id: id }} /></div></td> : <td>—</td>}
            </tr>)}</tbody></table></div>}
          </Card>
        </div>
      </div>
    </div>
  </>;
}
