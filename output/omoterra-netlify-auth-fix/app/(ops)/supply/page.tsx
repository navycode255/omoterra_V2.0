import Link from 'next/link';
import { Empty, Notice, PageHeader, Pill, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { category, date, listingTone, quantity, reference, titleCase, tzs, unit } from '@/lib/format';
import type { Listing, ListingStatus } from '@/lib/types';

export const metadata = { title: 'Supply · Omoterra Operations' };

const TABS: { key: ListingStatus; label: string }[] = [
  { key: 'live', label: 'Live' },
  { key: 'pending_review', label: 'Pending approval' },
  { key: 'needs_confirmation', label: 'Needs confirmation' },
  { key: 'paused', label: 'Paused' },
  { key: 'sold_out', label: 'Sold' },
];

function stale(listing: Listing) {
  return (
    listing.listing_status === 'needs_confirmation' ||
    (listing.listing_status === 'live' &&
      listing.confirmation_due_at !== null &&
      new Date(listing.confirmation_due_at) <= new Date())
  );
}

export default async function Supply({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string; q?: string }>;
}) {
  const { tab = 'live', q = '' } = await searchParams;
  let listings: Listing[];
  try {
    listings = await get<Listing[]>('/ops/listings');
  } catch (error) {
    return (
      <>
        <div className="topbar">
          <PageHeader title="Supply" />
        </div>
        <div className="workspace">
          <Notice tone="error">
            {error instanceof ApiError ? error.message : 'Supply could not be loaded.'}
          </Notice>
        </div>
      </>
    );
  }

  const counts = Object.fromEntries(
    TABS.map((t) => [
      t.key,
      listings.filter((l) =>
        t.key === 'needs_confirmation' ? stale(l) : l.listing_status === t.key && !stale(l),
      ).length,
    ]),
  );

  const search = q.trim().toLowerCase();
  const rows = listings
    .filter((l) => (tab === 'needs_confirmation' ? stale(l) : l.listing_status === tab && !stale(l)))
    .filter(
      (l) =>
        !search ||
        category(l.category).toLowerCase().includes(search) ||
        l.region.toLowerCase().includes(search) ||
        reference(l.id, 'ST').toLowerCase().includes(search),
    );

  return (
    <>
      <div className="topbar">
        <PageHeader title="Supply" subtitle="Stock submitted by suppliers, and what buyers can currently see." />
      </div>
      <div className="workspace">
        <div className="tabs">
          {TABS.map((t) => (
            <Link
              key={t.key}
              href={`/supply?tab=${t.key}`}
              className="tab"
              data-active={tab === t.key}
            >
              {t.label}
              {counts[t.key] > 0 && <span className="meta"> {counts[t.key]}</span>}
            </Link>
          ))}
        </div>

        <form className="row" action="/supply">
          <input type="hidden" name="tab" value={tab} />
          <input
            className="input"
            name="q"
            defaultValue={q}
            placeholder="Search category, region or reference"
            style={{ maxWidth: 340 }}
          />
          <button className="button" data-variant="secondary" type="submit">
            Search
          </button>
        </form>

        <div className="table-wrap">
          {rows.length === 0 ? (
            <Empty>No stock in this state.</Empty>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Reference</th>
                  <th>Category</th>
                  <th>Region</th>
                  <th className="numeric">Available</th>
                  <th className="numeric">Asking</th>
                  <th className="numeric">Buyer price</th>
                  <th>Ready</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((listing) => (
                  <tr key={listing.id}>
                    <td>
                      <Link href={`/supply/${listing.id}`} className="strong">
                        {reference(listing.id, 'ST')}
                      </Link>
                    </td>
                    <td>
                      {category(listing.category)}
                      <div className="meta">{titleCase(listing.unit_type)}</div>
                    </td>
                    <td>{listing.region}</td>
                    <td className="numeric">
                      {quantity(listing.quantity_available)} {unit(listing.unit_type, listing.quantity_available)}
                      <div className="meta">
                        {quantity(listing.quantity_reserved)} reserved · {quantity(listing.quantity_sold)} sold
                      </div>
                    </td>
                    <td className="numeric">{tzs(listing.farmer_asking_price_per_unit)}</td>
                    <td className="numeric">{tzs(listing.buyer_price_per_unit)}</td>
                    <td className="small">{date(listing.specs?.ready_date ?? null)}</td>
                    <td>
                      {stale(listing) ? (
                        <Pill>Needs confirmation</Pill>
                      ) : (
                        <Status tone={listingTone(listing.listing_status)}>
                          {titleCase(listing.listing_status)}
                        </Status>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </>
  );
}
