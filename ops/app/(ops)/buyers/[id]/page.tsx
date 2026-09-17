import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Card, Definition, Empty, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import {
  CUSTOMER_STATUS,
  category,
  date,
  orderTone,
  quantity,
  reference,
  titleCase,
  tzs,
} from '@/lib/format';
import type { BuyerDetail } from '@/lib/types';

export default async function BuyerDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let buyer: BuyerDetail;
  try {
    buyer = await get<BuyerDetail>(`/ops/buyers/${id}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }

  return (
    <>
      <div className="topbar">
        <PageHeader
          title={buyer.name || 'Unnamed buyer'}
          subtitle={`${buyer.phone} · joined ${date(buyer.created_at)}`}
        />
      </div>
      <div className="workspace">
        <div className="grid-2" style={{ alignItems: 'start' }}>
          <Card title="Account">
            <Definition
              items={[
                ['Name', buyer.name || '—'],
                ['Phone', buyer.phone],
                ['Buyer type', buyer.buyer_type ? titleCase(buyer.buyer_type) : '—'],
                ['Region', buyer.region || '—'],
              ]}
            />
          </Card>

          <Card title="Delivery addresses">
            {buyer.addresses.length === 0 ? (
              <p className="muted small">No saved addresses.</p>
            ) : (
              <div className="stack" style={{ gap: 'var(--s4)' }}>
                {buyer.addresses.map((address) => (
                  <div key={address.id}>
                    <div className="strong small">{address.label}</div>
                    <div className="small muted">
                      {address.recipient_name} · {address.phone}
                    </div>
                    <div className="small muted">
                      {address.address_text}, {address.district_area}, {address.region}
                    </div>
                  </div>
                ))}
              </div>
            )}
            <p className="meta" style={{ marginTop: 'var(--s3)' }}>
              For delivery scheduling only. Suppliers never receive buyer addresses.
            </p>
          </Card>
        </div>

        <Card title="Orders">
          <div className="table-wrap" style={{ border: 'none' }}>
            {buyer.orders.length === 0 ? (
              <Empty>No orders yet.</Empty>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th>Order</th>
                    <th>Item</th>
                    <th className="numeric">Total</th>
                    <th>Internal status</th>
                    <th>Buyer sees</th>
                    <th>Delivery</th>
                  </tr>
                </thead>
                <tbody>
                  {buyer.orders.map((order) => (
                    <tr key={order.id}>
                      <td>
                        <Link href={`/orders/${order.id}`} className="strong">
                          {reference(order.id, 'OR')}
                        </Link>
                      </td>
                      <td className="small">
                        {order.items[0] ? category(order.items[0].category) : '—'}
                      </td>
                      <td className="numeric money">{tzs(order.total_amount)}</td>
                      <td>
                        <Status tone={orderTone(order.internal_status)}>
                          {titleCase(order.internal_status)}
                        </Status>
                      </td>
                      <td className="small muted">{CUSTOMER_STATUS[order.internal_status]}</td>
                      <td className="small">{date(order.preferred_delivery_date)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </Card>

        <Card title="Sourcing requests">
          <div className="table-wrap" style={{ border: 'none' }}>
            {buyer.requests.length === 0 ? (
              <Empty>No sourcing requests yet.</Empty>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th>Reference</th>
                    <th>Category</th>
                    <th className="numeric">Quantity</th>
                    <th>Needed by</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {buyer.requests.map((request) => (
                    <tr key={request.id}>
                      <td>
                        <Link href={`/sourcing/${request.id}`} className="strong">
                          {reference(request.id, 'SR')}
                        </Link>
                      </td>
                      <td>{category(request.category)}</td>
                      <td className="numeric">{quantity(request.quantity)}</td>
                      <td className="small">{date(request.needed_by_date)}</td>
                      <td>
                        <Status tone={request.status === 'converted' ? 'positive' : 'neutral'}>
                          {titleCase(request.status)}
                        </Status>
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
