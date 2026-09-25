import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { PricingPreview } from '@/components/pricing-preview';
import { Card, Definition, Notice, PageHeader, Status } from '@/components/ui';
import { approveListing, reviewListing } from '@/lib/actions';
import { get } from '@/lib/api';
import {
  category,
  date,
  listingTone,
  photoUrl,
  quantity,
  reference,
  titleCase,
  tzs,
  unit,
} from '@/lib/format';
import type { Listing, SupplierDetail } from '@/lib/types';

export default async function ListingReview({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const listings = await get<Listing[]>('/ops/listings');
  const listing = listings.find((row) => row.id === id);
  if (!listing) notFound();

  const supplier = await get<SupplierDetail>(`/ops/suppliers/${listing.supplier_id}`);
  const pending = listing.listing_status === 'pending_review';

  return (
    <>
      <div className="topbar">
        <PageHeader
          title={`${category(listing.category)} · ${reference(listing.id, 'ST')}`}
          subtitle={`${listing.region} · priced per ${unit(listing.unit_type)}`}
        />
        <Status tone={listingTone(listing.listing_status)}>{titleCase(listing.listing_status)}</Status>
      </div>
      <div className="workspace">
        <div className="grid-2" style={{ alignItems: 'start' }}>
          <div className="stack">
            <Card title="Stock">
              <Definition
                items={[
                  ['Category', category(listing.category)],
                  ['Priced per', unit(listing.unit_type)],
                  [
                    'Quantity',
                    `${quantity(listing.quantity_total)} total · ${quantity(listing.quantity_available)} available · ${quantity(listing.quantity_reserved)} reserved · ${quantity(listing.quantity_sold)} sold`,
                  ],
                  ['Asking price', tzs(listing.farmer_asking_price_per_unit)],
                  ['Region', listing.region],
                  ['Confirmation due', date(listing.confirmation_due_at)],
                ]}
              />
            </Card>

            <Card title="Specifications">
              <Definition
                items={Object.entries(listing.specs ?? {}).map(([key, value]) => [
                  titleCase(key),
                  String(value),
                ])}
              />
            </Card>

            <Card title="Photos">
              {listing.photos.length === 0 ? (
                <p className="muted small">No photos submitted.</p>
              ) : (
                <div className="photo-grid">
                  {listing.photos.map((photo) => (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img key={photo} src={photoUrl(photo)} alt="Submitted stock" />
                  ))}
                </div>
              )}
              <p className="meta" style={{ marginTop: 'var(--s3)' }}>
                Check photos for phone numbers, signage or anything identifying the supplier before
                approving.
              </p>
            </Card>

            <Card title="Video">
              {listing.video ? (
                <video src={photoUrl(listing.video)} controls preload="metadata" style={{ width: '100%', borderRadius: 12 }} />
              ) : (
                <p className="muted small">No video submitted.</p>
              )}
              {listing.video && (
                <p className="meta" style={{ marginTop: 'var(--s3)' }}>
                  Watch and listen for names, phone numbers or signage before approving.
                </p>
              )}
            </Card>
          </div>

          <div className="stack">
            <Card title="Supplier (internal)">
              <Definition
                items={[
                  ['Legal name', supplier.legal_name],
                  ['Public alias', supplier.public_alias],
                  [
                    'Alias approved',
                    supplier.alias_approved ? (
                      <Status tone="positive">Approved</Status>
                    ) : (
                      <Status tone="warning">Not yet approved</Status>
                    ),
                  ],
                  ['Phone', supplier.phone],
                  ['Pickup address', supplier.internal_pickup_address],
                  ['Completed supplies', String(supplier.completed_supplies_count)],
                ]}
              />
              <p className="meta" style={{ marginTop: 'var(--s3)' }}>
                Never shown to buyers. Buyers only ever see the approved alias and region.
              </p>
              <Link href={`/suppliers/${supplier.id}`} className="small" style={{ color: 'var(--forest)' }}>
                View supplier history →
              </Link>
            </Card>

            {pending ? (
              <Card title="Approve & publish">
                <ActionForm action={approveListing} label="Approve & publish" hidden={{ id: listing.id }}>
                  <div className="field">
                    <label htmlFor="public_alias">Public alias shown to buyers</label>
                    <input
                      id="public_alias"
                      name="public_alias"
                      className="input"
                      defaultValue={supplier.public_alias}
                      required
                    />
                    <span className="meta">
                      Letters, spaces and hyphens only. Must not embed a phone number or a
                      searchable trading name.
                    </span>
                  </div>
                  <PricingPreview asking={listing.farmer_asking_price_per_unit} />
                </ActionForm>
                <div className="row" style={{ marginTop: 'var(--s5)' }}>
                  <ActionForm
                    action={reviewListing}
                    label="Reject"
                    variant="danger"
                    layout="row"
                    confirm="Reject this listing? Any active holds on it are released."
                    hidden={{ id: listing.id, status: 'rejected' }}
                  />
                  <ActionForm
                    action={reviewListing}
                    label="Request changes (pause)"
                    variant="secondary"
                    layout="row"
                    hidden={{ id: listing.id, status: 'paused' }}
                  />
                </div>
              </Card>
            ) : (
              <Card title="Pricing">
                <Definition
                  items={[
                    ['Asking price', tzs(listing.farmer_asking_price_per_unit)],
                    ['Supplier payout', tzs(listing.supplier_payout_price_per_unit)],
                    ['Buyer price', tzs(listing.buyer_price_per_unit)],
                    [
                      'Commission per unit',
                      tzs(
                        listing.supplier_payout_price_per_unit
                          ? String(
                              Number(listing.farmer_asking_price_per_unit) -
                                Number(listing.supplier_payout_price_per_unit),
                            )
                          : null,
                      ),
                    ],
                    [
                      'Gross margin per unit',
                      tzs(
                        listing.buyer_price_per_unit && listing.supplier_payout_price_per_unit
                          ? String(
                              Number(listing.buyer_price_per_unit) -
                                Number(listing.supplier_payout_price_per_unit),
                            )
                          : null,
                      ),
                    ],
                  ]}
                />
                {listing.listing_status !== 'rejected' && (
                  <div className="row" style={{ marginTop: 'var(--s5)' }}>
                    {listing.listing_status !== 'paused' && (
                      <ActionForm
                        action={reviewListing}
                        label="Pause listing"
                        variant="secondary"
                        layout="row"
                        confirm="Pause this listing? Buyers will no longer see it."
                        hidden={{ id: listing.id, status: 'paused' }}
                      />
                    )}
                    <ActionForm
                      action={reviewListing}
                      label="Reject listing"
                      variant="danger"
                      layout="row"
                      confirm="Reject this listing? Any active holds on it are released."
                      hidden={{ id: listing.id, status: 'rejected' }}
                    />
                  </div>
                )}
              </Card>
            )}

            {!pending && listing.listing_status === 'live' && (
              <Notice>
                This listing is live and buyer-visible. Buyers see the buyer price only; the
                supplier never sees it.
              </Notice>
            )}
          </div>
        </div>
      </div>
    </>
  );
}
