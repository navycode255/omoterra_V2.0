import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Card, Definition, Empty, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { category, date, listingTone, quantity, reference, titleCase, tzs } from '@/lib/format';
import type { SupplierDetail } from '@/lib/types';

export default async function SupplierDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let supplier: SupplierDetail;
  try {
    supplier = await get<SupplierDetail>(`/ops/suppliers/${id}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }

  const owed = supplier.settlements
    .filter((s) => s.status === 'pending')
    .reduce((sum, s) => sum + Number(s.total_payable), 0);

  return (
    <>
      <div className="topbar">
        <PageHeader title={supplier.public_alias} subtitle={supplier.legal_name} />
        <Status tone={supplier.alias_approved ? 'positive' : 'warning'}>
          {supplier.alias_approved ? 'Alias approved' : 'Alias not approved'}
        </Status>
      </div>
      <div className="workspace">
        <Card title="Internal record">
          <Definition
            items={[
              ['Legal name', supplier.legal_name],
              ['Public alias', supplier.public_alias],
              ['Phone', supplier.phone],
              ['Region', supplier.region || '—'],
              ['Pickup address', supplier.internal_pickup_address],
              ['Completed supplies', String(supplier.completed_supplies_count)],
              ['Currently owed', tzs(owed.toFixed(2))],
            ]}
          />
          <p className="meta" style={{ marginTop: 'var(--s3)' }}>
            Buyers only ever see the approved alias and the listing region.
          </p>
        </Card>

        <Card title="Stock history">
          <div className="table-wrap" style={{ border: 'none' }}>
            {supplier.listings.length === 0 ? (
              <Empty>No stock submitted yet.</Empty>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th>Reference</th>
                    <th>Category</th>
                    <th className="numeric">Total</th>
                    <th className="numeric">Available</th>
                    <th className="numeric">Asking</th>
                    <th className="numeric">Buyer price</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {supplier.listings.map((listing) => (
                    <tr key={listing.id}>
                      <td>
                        <Link href={`/supply/${listing.id}`} className="strong">
                          {reference(listing.id, 'ST')}
                        </Link>
                      </td>
                      <td>{category(listing.category)}</td>
                      <td className="numeric">{quantity(listing.quantity_total)}</td>
                      <td className="numeric">{quantity(listing.quantity_available)}</td>
                      <td className="numeric">{tzs(listing.farmer_asking_price_per_unit)}</td>
                      <td className="numeric">{tzs(listing.buyer_price_per_unit)}</td>
                      <td>
                        <Status tone={listingTone(listing.listing_status)}>
                          {titleCase(listing.listing_status)}
                        </Status>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </Card>

        <Card title="Settlement history">
          <div className="table-wrap" style={{ border: 'none' }}>
            {supplier.settlements.length === 0 ? (
              <Empty>No settlements yet.</Empty>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th>Order item</th>
                    <th className="numeric">Asking</th>
                    <th className="numeric">Commission</th>
                    <th className="numeric">Payout</th>
                    <th className="numeric">Qty</th>
                    <th className="numeric">Total</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {supplier.settlements.map((settlement) => (
                    <tr key={settlement.id}>
                      <td className="small">{reference(settlement.order_item_id, 'IT')}</td>
                      <td className="numeric">{tzs(settlement.farmer_asking_price_per_unit)}</td>
                      <td className="numeric">{tzs(settlement.commission_amount_per_unit)}</td>
                      <td className="numeric">{tzs(settlement.supplier_payout_price_per_unit)}</td>
                      <td className="numeric">{quantity(settlement.quantity)}</td>
                      <td className="numeric money">{tzs(settlement.total_payable)}</td>
                      <td>
                        {settlement.status === 'paid' ? (
                          <>
                            <Status tone="positive">Paid</Status>
                            <div className="meta">{date(settlement.paid_at)}</div>
                          </>
                        ) : (
                          <Status tone="warning">Pending</Status>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </Card>
      </div>
    </>
  );
}
