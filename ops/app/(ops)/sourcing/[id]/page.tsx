import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { Card, Definition, Notice, PageHeader, Status } from '@/components/ui';
import { convertSourcing, reserveForSourcing, updateSourcing } from '@/lib/actions';
import { get } from '@/lib/api';
import { category, date, quantity, reference, titleCase, tzs } from '@/lib/format';
import type { BuyerDetail, Listing, SourcingRequest } from '@/lib/types';

const STATUSES = ['submitted', 'sourcing', 'supply_found', 'confirmed', 'cancelled'];

export default async function SourcingDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const requests = await get<SourcingRequest[]>('/ops/requests');
  const request = requests.find((row) => row.id === id);
  if (!request) notFound();

  const [buyer, listings] = await Promise.all([
    get<BuyerDetail>(`/ops/buyers/${request.buyer_id}`),
    get<Listing[]>('/ops/listings'),
  ]);

  const matches = listings.filter(
    (listing) => listing.category === request.category && listing.listing_status === 'live',
  );
  const converted = request.status === 'converted';

  return (
    <>
      <div className="topbar">
        <PageHeader
          title={`Request ${reference(request.id, 'SR')}`}
          subtitle={`${category(request.category)} · needed by ${date(request.needed_by_date)}`}
        />
        <Status tone={converted ? 'positive' : 'neutral'}>{titleCase(request.status)}</Status>
      </div>
      <div className="workspace">
        {converted && request.converted_order_id && (
          <Notice>
            Converted to order{' '}
            <Link href={`/orders/${request.converted_order_id}`} className="strong">
              {reference(request.converted_order_id, 'OR')}
            </Link>
            . It now behaves like any other order in the buyer&apos;s tracking screen.
          </Notice>
        )}

        <div className="grid-2" style={{ alignItems: 'start' }}>
          <div className="stack">
            <Card title="Request">
              <Definition
                items={[
                  ['Category', category(request.category)],
                  ['Quantity', `${quantity(request.quantity)} ${request.unit_type}`],
                  ['Weight / size', request.weight_or_size_requirement || '—'],
                  ['Condition', request.live_dressed_or_cut || '—'],
                  ['Needed by', date(request.needed_by_date)],
                  ['Delivery area', request.delivery_area],
                  ['Notes', request.notes || '—'],
                ]}
              />
            </Card>

            <Card title="Buyer">
              <Definition
                items={[
                  ['Name', buyer.name || '—'],
                  ['Phone', buyer.phone],
                  ['Type', buyer.buyer_type ? titleCase(buyer.buyer_type) : '—'],
                  ['Region', buyer.region || '—'],
                ]}
              />
              <Link href={`/buyers/${buyer.id}`} className="small" style={{ color: 'var(--forest)' }}>
                View buyer →
              </Link>
            </Card>
          </div>

          <div className="stack">
            {!converted && (
              <Card title="Progress">
                <ActionForm action={updateSourcing} label="Save progress" hidden={{ id: request.id }}>
                  <div className="field">
                    <label htmlFor="status">Status</label>
                    <select id="status" name="status" className="input" defaultValue={request.status}>
                      {STATUSES.map((status) => (
                        <option key={status} value={status}>
                          {titleCase(status)}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className="field">
                    <label htmlFor="quantity_secured">Quantity secured</label>
                    <input
                      id="quantity_secured"
                      name="quantity_secured"
                      className="input"
                      inputMode="decimal"
                      defaultValue={quantity(request.quantity_secured)}
                    />
                    <span className="meta">
                      Tracked manually. The buyer never sees a partial secured count.
                    </span>
                  </div>
                  <div className="field">
                    <label htmlFor="admin_notes">Internal notes</label>
                    <textarea
                      id="admin_notes"
                      name="admin_notes"
                      className="input"
                      defaultValue={request.admin_notes}
                      placeholder="Supplier outreach, quotes, callbacks…"
                    />
                  </div>
                </ActionForm>
              </Card>
            )}

            {!converted && (
              <Card title="Reserve stock">
                {matches.length === 0 ? (
                  <p className="muted small">
                    No live listings in this category. Approve matching supply first.
                  </p>
                ) : (
                  <ActionForm
                    action={reserveForSourcing}
                    label="Hold this stock"
                    variant="secondary"
                    hidden={{ id: request.id }}
                  >
                    <div className="field">
                      <label htmlFor="listing_id">Listing</label>
                      <select id="listing_id" name="listing_id" className="input" required>
                        {matches.map((listing) => (
                          <option key={listing.id} value={listing.id}>
                            {reference(listing.id, 'ST')} · {listing.region} ·{' '}
                            {quantity(listing.quantity_available)} available ·{' '}
                            {tzs(listing.buyer_price_per_unit)}
                          </option>
                        ))}
                      </select>
                    </div>
                    <div className="field">
                      <label htmlFor="quantity">Quantity</label>
                      <input
                        id="quantity"
                        name="quantity"
                        className="input"
                        inputMode="decimal"
                        defaultValue={quantity(request.quantity)}
                        required
                      />
                    </div>
                    <span className="meta">
                      Creates a real stock hold. V1 converts from a single listing.
                    </span>
                  </ActionForm>
                )}
              </Card>
            )}

            {!converted && (
              <Card title="Convert to order">
                {buyer.addresses.length === 0 ? (
                  <p className="muted small">
                    This buyer has no saved delivery address. They must add one before conversion.
                  </p>
                ) : (
                  <ActionForm action={convertSourcing} label="Convert to order" hidden={{ id: request.id }}>
                    <div className="field">
                      <label htmlFor="reservation_id">Reservation ID</label>
                      <input id="reservation_id" name="reservation_id" className="input" required />
                      <span className="meta">Returned when you hold stock above.</span>
                    </div>
                    <div className="field">
                      <label htmlFor="delivery_address_id">Delivery address</label>
                      <select id="delivery_address_id" name="delivery_address_id" className="input" required>
                        {buyer.addresses.map((address) => (
                          <option key={address.id} value={address.id}>
                            {address.label} · {address.district_area}, {address.region}
                          </option>
                        ))}
                      </select>
                    </div>
                    <div className="grid-2">
                      <div className="field">
                        <label htmlFor="preferred_delivery_date">Delivery date</label>
                        <input
                          id="preferred_delivery_date"
                          name="preferred_delivery_date"
                          type="date"
                          className="input"
                          required
                        />
                      </div>
                      <div className="field">
                        <label htmlFor="payment_method">Payment method</label>
                        <select id="payment_method" name="payment_method" className="input" defaultValue="pay_on_delivery">
                          <option value="pay_on_delivery">Pay on delivery</option>
                          <option value="pay_now">Pay now</option>
                        </select>
                      </div>
                    </div>
                  </ActionForm>
                )}
              </Card>
            )}
          </div>
        </div>
      </div>
    </>
  );
}
