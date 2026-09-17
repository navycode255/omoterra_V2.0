import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { ProgressForm } from '@/components/progress-form';
import { Card, Definition, Notice, PageHeader, Status } from '@/components/ui';
import { reconcilePayment, uploadCollectionPhoto } from '@/lib/actions';
import { ApiError, get } from '@/lib/api';
import {
  CUSTOMER_STATUS,
  PIPELINE,
  category,
  date,
  dateTime,
  orderTone,
  paymentTone,
  photoUrl,
  quantity,
  reference,
  titleCase,
  tzs,
} from '@/lib/format';
import type { OrderDetail } from '@/lib/types';

export default async function OrderWorkspace({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let order: OrderDetail;
  try {
    order = await get<OrderDetail>(`/ops/orders/${id}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }

  const address = order.delivery_address ?? {};
  const item = order.items[0];
  const paymentRecorded = order.payment_status === 'paid' || order.payment_status === 'partial';
  const balance = Number(order.total_amount) - Number(order.amount_received);
  const reached = PIPELINE.indexOf(order.internal_status);
  const failed = order.internal_status === 'cancelled' || order.internal_status === 'payment_failed';

  return (
    <>
      <div className="topbar">
        <PageHeader
          title={`Order ${reference(order.id, 'OR')}`}
          subtitle={`Placed ${dateTime(order.created_at)} · buyer sees "${CUSTOMER_STATUS[order.internal_status]}"`}
        />
        <Status tone={orderTone(order.internal_status)}>{titleCase(order.internal_status)}</Status>
      </div>
      <div className="workspace">
        {failed && (
          <Notice tone="error">
            {order.internal_status === 'payment_failed'
              ? 'Payment failed on this order. Reserved stock has been released. The buyer sees a payment-specific message, not a generic cancellation.'
              : 'This order was cancelled and its reserved stock released.'}
          </Notice>
        )}

        <div className="grid-2" style={{ alignItems: 'start' }}>
          <div className="stack">
            <Card title="Fulfilment">
              {!failed && (
                <ol
                  className="stack"
                  style={{ gap: 'var(--s2)', listStyle: 'none', padding: 0, margin: '0 0 var(--s5)' }}
                >
                  {PIPELINE.map((stage, index) => (
                    <li key={stage} className="row" style={{ gap: 'var(--s3)' }}>
                      <span
                        aria-hidden
                        style={{
                          width: 8,
                          height: 8,
                          borderRadius: '50%',
                          background: index <= reached ? 'var(--forest)' : 'var(--border)',
                        }}
                      />
                      <span
                        className={index <= reached ? 'strong' : 'muted'}
                        style={{ fontSize: 14 }}
                      >
                        {titleCase(stage)}
                      </span>
                      {index === reached && <span className="meta">current</span>}
                    </li>
                  ))}
                </ol>
              )}
              <ProgressForm
                id={order.id}
                current={order.internal_status}
                expected={quantity(order.expected_quantity)}
                paymentRecorded={paymentRecorded}
              />
            </Card>

            <Card title="Collection verification">
              <Definition
                items={[
                  ['Expected quantity', quantity(order.expected_quantity)],
                  ['Accepted quantity', quantity(order.actual_quantity)],
                  ['Rejected quantity', quantity(order.rejected_quantity)],
                  ['Collection notes', order.collection_notes || '—'],
                ]}
              />
              {order.collection_photos.length > 0 && (
                <div className="photo-grid" style={{ marginTop: 'var(--s4)' }}>
                  {order.collection_photos.map((photo) => (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img key={photo} src={photoUrl(photo)} alt="Collection evidence" />
                  ))}
                </div>
              )}
              <div style={{ marginTop: 'var(--s4)' }}>
                <ActionForm action={uploadCollectionPhoto} label="Upload photo" variant="secondary" hidden={{ id: order.id }}>
                  <div className="field">
                    <label htmlFor="file">Collection evidence</label>
                    <input id="file" name="file" type="file" accept="image/*" className="input" required />
                    <span className="meta">Operations only. These photos never reach the buyer or supplier app.</span>
                  </div>
                </ActionForm>
              </div>
            </Card>

            <Card title="Activity">
              {order.activity.length === 0 ? (
                <p className="muted small">No activity recorded yet.</p>
              ) : (
                <div className="stack" style={{ gap: 'var(--s3)' }}>
                  {order.activity.map((entry, index) => (
                    <div key={`${entry.at}-${index}`} className="between">
                      <span className="small">{entry.label}</span>
                      <span className="meta">{dateTime(entry.at)}</span>
                    </div>
                  ))}
                </div>
              )}
            </Card>
          </div>

          <div className="stack">
            <Card title="Item">
              {item ? (
                <Definition
                  items={[
                    ['Product', category(item.category)],
                    ['Quantity', `${quantity(item.quantity)} ${item.unit_type}`],
                    ['Unit price', tzs(item.unit_price)],
                    ['Subtotal', tzs(item.subtotal)],
                    ['Order total', tzs(order.total_amount)],
                  ]}
                />
              ) : (
                <p className="muted small">No items on this order.</p>
              )}
            </Card>

            <Card title="Supplier (internal)">
              {order.suppliers.map((supplier) => (
                <div key={supplier.listing_id} className="stack" style={{ gap: 'var(--s2)' }}>
                  <Definition
                    items={[
                      ['Legal name', supplier.legal_name],
                      ['Phone', supplier.phone],
                      ['Pickup address', supplier.internal_pickup_address],
                    ]}
                  />
                  <Link href={`/suppliers/${supplier.supplier_id}`} className="small" style={{ color: 'var(--forest)' }}>
                    View supplier →
                  </Link>
                </div>
              ))}
              <p className="meta" style={{ marginTop: 'var(--s3)' }}>
                The buyer never sees which supplier fulfils their order.
              </p>
            </Card>

            <Card title="Delivery (buyer)">
              <Definition
                items={[
                  ['Recipient', address.recipient_name ?? '—'],
                  ['Phone', address.phone ?? '—'],
                  ['Region', address.region ?? '—'],
                  ['Area', address.district_area ?? '—'],
                  ['Address', address.address_text ?? '—'],
                  ['Preferred date', date(order.preferred_delivery_date)],
                ]}
              />
              <p className="meta" style={{ marginTop: 'var(--s3)' }}>
                Snapshot taken at checkout. Never shared with the supplier.
              </p>
            </Card>

            <Card title="Payment">
              <Definition
                items={[
                  ['Method', titleCase(order.payment_method)],
                  ['Status', <Status key="s" tone={paymentTone(order.payment_status)}>{titleCase(order.payment_status)}</Status>],
                  ['Total', tzs(order.total_amount)],
                  ['Received', tzs(order.amount_received)],
                  ['Balance', tzs(balance.toFixed(2))],
                ]}
              />
              {balance > 0 && (
                <div style={{ marginTop: 'var(--s4)' }}>
                  <ActionForm action={reconcilePayment} label="Record receipt" variant="secondary" hidden={{ id: order.id }}>
                    <div className="grid-2">
                      <div className="field">
                        <label htmlFor="amount">Amount received</label>
                        <input id="amount" name="amount" className="input" inputMode="decimal" required />
                      </div>
                      <div className="field">
                        <label htmlFor="payment_reference">Reference</label>
                        <input id="payment_reference" name="payment_reference" className="input" required />
                      </div>
                    </div>
                    <span className="meta">
                      Record this only after the money has actually been received. Each reference is
                      retained and must be unique.
                    </span>
                  </ActionForm>
                </div>
              )}
            </Card>
          </div>
        </div>
      </div>
    </>
  );
}
