import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Card, Empty, Notice, PageHeader, Status } from '@/components/ui';
import { reconcilePayment } from '@/lib/actions';
import { ApiError, get } from '@/lib/api';
import { date, paymentTone, reference, titleCase, tzs } from '@/lib/format';
import { ListControls } from '@/components/list-controls';
import { listPath, type ListParams, type Page } from '@/lib/paging';
import type { Payment } from '@/lib/types';

export const metadata = { title: 'Payments · Omoterra Operations' };

const TABS = [
  { key: '', label: 'All' },
  { key: 'outstanding', label: 'Outstanding' },
  { key: 'paid', label: 'Paid' },
  { key: 'failed', label: 'Failed' },
];

export default async function Payments({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let data: Page<Payment>;
  try {
    data = await get<Page<Payment>>(listPath('/ops/payments', params));
  } catch (error) {
    return (
      <>
        <div className="topbar">
          <PageHeader title="Payments" />
        </div>
        <div className="workspace">
          <Notice tone="error">
            {error instanceof ApiError ? error.message : 'Payments could not be loaded.'}
          </Notice>
        </div>
      </>
    );
  }

  const payments = data.items;
  // Every outstanding payment is on page 1, so the receipt form lists them all.
  const outstanding = payments.filter((p) => Number(p.balance) > 0 && p.status !== 'failed');

  return (
    <>
      <div className="topbar">
        <PageHeader
          title="Payments"
          subtitle="Buyer payment records. Receipts are recorded here after money actually arrives."
        />
      </div>
      <div className="workspace">
        <ListControls path="/payments" params={params} data={data} tabs={TABS} noun={['payment', 'payments']}
          actionLabel="outstanding" placeholder="Search order reference, buyer or transaction">
        <div className="table-wrap">
          {payments.length === 0 ? (
            <Empty>No payments in this view.</Empty>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Order</th>
                  <th>Buyer</th>
                  <th className="numeric">Total</th>
                  <th className="numeric">Received</th>
                  <th className="numeric">Balance</th>
                  <th>Method</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {payments.map((payment) => (
                  <tr key={payment.id}>
                    <td>
                      <Link href={`/orders/${payment.order_id}`} className="strong">
                        {reference(payment.order_id, 'OR')}
                      </Link>
                      <div className="meta">{date(payment.created_at)}</div>
                    </td>
                    <td>
                      <Link href={`/buyers/${payment.buyer_id}`}>{payment.buyer_name || '—'}</Link>
                    </td>
                    <td className="numeric money">{tzs(payment.amount)}</td>
                    <td className="numeric">{tzs(payment.received_amount)}</td>
                    <td className="numeric money">{tzs(payment.balance)}</td>
                    <td className="small">{titleCase(payment.method)}</td>
                    <td>
                      <Status tone={paymentTone(payment.status)}>{titleCase(payment.status)}</Status>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
        </ListControls>

        {outstanding.length > 0 && (
          <Card title="Record a receipt">
            <p className="muted small" style={{ marginBottom: 'var(--s4)' }}>
              For pay-on-delivery orders, record the receipt once the money has been received. This
              writes a real payment record; it never marks an order paid on its own.
            </p>
            <ActionForm action={reconcilePayment} label="Record receipt">
              <div className="grid-3">
                <div className="field">
                  <label htmlFor="id">Order</label>
                  <select id="id" name="id" className="input" required>
                    {outstanding.map((payment) => (
                      <option key={payment.id} value={payment.order_id}>
                        {reference(payment.order_id, 'OR')} · {payment.buyer_name} ·{' '}
                        {tzs(payment.balance)} outstanding
                      </option>
                    ))}
                  </select>
                </div>
                <div className="field">
                  <label htmlFor="amount">Amount received</label>
                  <input id="amount" name="amount" className="input" inputMode="decimal" required />
                </div>
                <div className="field">
                  <label htmlFor="payment_reference">Reference</label>
                  <input id="payment_reference" name="payment_reference" className="input" required />
                </div>
              </div>
            </ActionForm>
          </Card>
        )}
      </div>
    </>
  );
}
