import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Card, Empty, Notice, PageHeader, Status } from '@/components/ui';
import { paySettlement } from '@/lib/actions';
import { ApiError, get } from '@/lib/api';
import { date, quantity, reference, tzs } from '@/lib/format';
import { ListControls } from '@/components/list-controls';
import { listPath, type ListParams, type Page } from '@/lib/paging';
import type { Settlement } from '@/lib/types';

export const metadata = { title: 'Settlements · Omoterra Operations' };

type Settlements = Page<Settlement> & { totals: { pending: string; paid: string } };

const TABS = [
  { key: '', label: 'All' },
  { key: 'pending', label: 'Unpaid' },
  { key: 'paid', label: 'Paid' },
];

export default async function Settlements({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let data: Settlements;
  try {
    data = await get<Settlements>(listPath('/ops/settlements', params));
  } catch (error) {
    return (
      <>
        <div className="topbar">
          <PageHeader title="Settlements" />
        </div>
        <div className="workspace">
          <Notice tone="error">
            {error instanceof ApiError ? error.message : 'Settlements could not be loaded.'}
          </Notice>
        </div>
      </>
    );
  }

  const settlements = data.items;
  // Every unpaid settlement is on page 1, so the payout form always lists them all.
  const pending = settlements.filter((s) => s.status === 'pending');

  return (
    <>
      <div className="topbar">
        <PageHeader
          title="Settlements"
          subtitle="What Omoterra owes suppliers. Commission is visible here and on the supplier's own payout screen."
        />
      </div>
      <div className="workspace">
        <div className="stat-band" style={{ gridTemplateColumns: 'repeat(2, minmax(0, 1fr))' }}>
          <div className="stat">
            <div className="stat-label">Pending payouts</div>
            <div className="stat-value numeric">{tzs(data.totals.pending)}</div>
          </div>
          <div className="stat">
            <div className="stat-label">Paid to date</div>
            <div className="stat-value numeric">{tzs(data.totals.paid)}</div>
          </div>
        </div>

        <ListControls path="/settlements" params={params} data={data} tabs={TABS} noun={['settlement', 'settlements']}
          actionLabel="unpaid" placeholder="Search supplier, order reference or category">
        <div className="table-wrap">
          {settlements.length === 0 ? (
            <Empty>No settlements in this view. They are created when an order is delivered.</Empty>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Supplier</th>
                  <th>Order</th>
                  <th className="numeric">Asking</th>
                  <th className="numeric">Commission</th>
                  <th className="numeric">Payout</th>
                  <th className="numeric">Qty</th>
                  <th className="numeric">Total payable</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {settlements.map((settlement) => {
                  return (
                    <tr key={settlement.id}>
                      <td>
                        <Link href={`/suppliers/${settlement.supplier_id}`} className="strong">
                          {settlement.supplier_alias || '—'}
                        </Link>
                        <div className="meta">{settlement.supplier_legal_name}</div>
                      </td>
                      <td className="small">
                        {settlement.order_id ? (
                          <Link href={`/orders/${settlement.order_id}`}>{reference(settlement.order_id, 'OR')}</Link>
                        ) : (
                          reference(settlement.order_item_id, 'IT')
                        )}
                        <div className="meta">{date(settlement.created_at)}</div>
                      </td>
                      <td className="numeric">{tzs(settlement.farmer_asking_price_per_unit)}</td>
                      <td className="numeric">{tzs(settlement.commission_amount_per_unit)}</td>
                      <td className="numeric">{tzs(settlement.supplier_payout_price_per_unit)}</td>
                      <td className="numeric">{quantity(settlement.quantity)}</td>
                      <td className="numeric money">{tzs(settlement.total_payable)}</td>
                      <td>
                        {settlement.status === 'paid' ? (
                          <>
                            <Status tone="positive">Paid</Status>
                            <div className="meta">
                              {settlement.payment_reference} · {date(settlement.paid_at)}
                            </div>
                          </>
                        ) : (
                          <Status tone="warning">Pending</Status>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
        </ListControls>

        {pending.length > 0 && (
          <Card title="Mark a settlement paid">
            <p className="muted small" style={{ marginBottom: 'var(--s4)' }}>
              Record this only after the supplier has actually been paid. Recording it here does not
              move money.
            </p>
            <ActionForm action={paySettlement} label="Record payout">
              <div className="grid-3">
                <div className="field">
                  <label htmlFor="id">Settlement</label>
                  <select id="id" name="id" className="input" required>
                    {pending.map((settlement) => (
                      <option key={settlement.id} value={settlement.id}>
                        {settlement.supplier_alias || settlement.supplier_id} ·{' '}
                        {tzs(settlement.total_payable)}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="field">
                  <label htmlFor="amount">Amount paid</label>
                  <input id="amount" name="amount" className="input" inputMode="decimal" required />
                </div>
                <div className="field">
                  <label htmlFor="payment_reference">Payment reference</label>
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
