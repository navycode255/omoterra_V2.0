import Link from 'next/link';
import { Empty, Notice, PageHeader, Pill, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { category, date, listingTone, quantity, reference, titleCase, tzs, unit } from '@/lib/format';
import { ListControls } from '@/components/list-controls';
import { listPath, type ListParams, type Page } from '@/lib/paging';
import type { Listing } from '@/lib/types';

export const metadata = { title: 'Supply · Omoterra Operations' };

const TABS = [
  { key: '', label: 'All' },
  { key: 'pending_review', label: 'Pending approval' },
  { key: 'needs_confirmation', label: 'Needs confirmation' },
  { key: 'live', label: 'Live' },
  { key: 'changes_requested', label: 'Changes requested' },
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

export default async function Supply({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let data: Page<Listing>;
  try {
    data = await get<Page<Listing>>(listPath('/ops/listings', params));
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
  const rows = data.items;

  return (
    <>
      <div className="topbar">
        <PageHeader title="Supply" subtitle="Stock submitted by suppliers, and what buyers can currently see." />
      </div>
      <div className="workspace">
        <ListControls path="/supply" params={params} data={data} tabs={TABS} noun={['listing', 'listings']}
          placeholder="Search supplier, category, region or reference">
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
        </ListControls>
      </div>
    </>
  );
}
