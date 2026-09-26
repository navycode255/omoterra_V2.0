import Link from 'next/link';
import { Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import {
  CUSTOMER_STATUS,
  category,
  date,
  orderTone,
  paymentTone,
  quantity,
  reference,
  titleCase,
  tzs,
} from '@/lib/format';
import { ListControls } from '@/components/list-controls';
import { listPath, type ListParams, type Page } from '@/lib/paging';
import type { Order } from '@/lib/types';

export const metadata = { title: 'Orders · Omoterra Operations' };

const TABS = [
  { key: '', label: 'All' },
  { key: 'open', label: 'In progress' },
  { key: 'delivered', label: 'Delivered' },
  { key: 'failed', label: 'Cancelled & failed' },
];

export default async function Orders({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let data: Page<Order>;
  try {
    data = await get<Page<Order>>(listPath('/ops/orders', params));
  } catch (error) {
    return (
      <>
        <div className="topbar">
          <PageHeader title="Orders" />
        </div>
        <div className="workspace">
          <Notice tone="error">
            {error instanceof ApiError ? error.message : 'Orders could not be loaded.'}
          </Notice>
        </div>
      </>
    );
  }
  const rows = data.items;

  return (
    <>
      <div className="topbar">
        <PageHeader title="Orders" subtitle="Fulfilment pipeline. Collection and delivery are recorded here." />
      </div>
      <div className="workspace">
        <ListControls path="/orders" params={params} data={data} tabs={TABS} noun={['order', 'orders']}
          actionLabel="in progress" placeholder="Search reference, buyer, supplier, category or region">
        <div className="table-wrap">
          {rows.length === 0 ? (
            <Empty>No orders in this view.</Empty>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Order</th>
                  <th>Item</th>
                  <th className="numeric">Amount</th>
                  <th>Payment</th>
                  <th>Internal status</th>
                  <th>Buyer sees</th>
                  <th>Delivery</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((order) => {
                  const item = order.items[0];
                  return (
                    <tr key={order.id}>
                      <td>
                        <Link href={`/orders/${order.id}`} className="strong">
                          {reference(order.id, 'OR')}
                        </Link>
                        <div className="meta">{date(order.created_at)}</div>
                        {order.buyer_name && <div className="meta">{order.buyer_name}</div>}
                      </td>
                      <td>
                        {item ? `${category(item.category)}` : '—'}
                        {item && (
                          <div className="meta">
                            {quantity(item.quantity)} × {tzs(item.unit_price)}
                          </div>
                        )}
                      </td>
                      <td className="numeric money">{tzs(order.total_amount)}</td>
                      <td>
                        <Status tone={paymentTone(order.payment_status)}>
                          {titleCase(order.payment_status)}
                        </Status>
                        <div className="meta">{titleCase(order.payment_method)}</div>
                      </td>
                      <td>
                        <Status tone={orderTone(order.internal_status)}>
                          {titleCase(order.internal_status)}
                        </Status>
                      </td>
                      <td className="small muted">{CUSTOMER_STATUS[order.internal_status]}</td>
                      <td className="small">{date(order.preferred_delivery_date)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
        </ListControls>
      </div>
    </>
  );
}
