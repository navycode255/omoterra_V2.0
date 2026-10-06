import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Card, Empty, Notice, PageHeader, Status } from '@/components/ui';
import { paySettlement } from '@/lib/actions';
import { ApiError, get } from '@/lib/api';
import { date, quantity, reference, tzs } from '@/lib/format';
import { ListControls } from '@/components/list-controls';
import { listPath, type ListParams, type Page } from '@/lib/paging';
import type { Settlement } from '@/lib/types';
import { AccountSelect } from '@/components/finance/account-select';

export const metadata = { title: 'Settlements · Omoterra Operations' };

type Settlements = Page<Settlement> & { totals: { pending: string; paid: string } };

const TABS = [
  { key: '', label: 'All' },
  { key: 'pending', label: 'Unpaid' },
  { key: 'paid', label: 'Paid' },
  { key: 'awaiting_confirmation', label: 'Awaiting supplier' },
  { key: 'not_received', label: 'Not received' },
  { key: 'received', label: 'Confirmed' },
];

export default async function Settlements({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let data: Settlements;
  let due: Settlement[];
  try {
    // The table shows one page; the payout form needs every payout still to
    // send: unpaid ones and ones a supplier reports as not received.
    const [list, pendingRows, missingRows] = await Promise.all([
      get<Settlements>(listPath('/ops/settlements', params)),
      get<Settlements>('/ops/settlements?status=pending&page_size=100'),
      get<Settlements>('/ops/settlements?status=not_received&page_size=100'),
    ]);
    data = list;
    due = [...pendingRows.items, ...missingRows.items];
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
  const pending = due;

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
                            <div className="meta">
                              {settlement.supplier_confirmation === 'received'
                                ? <Status tone="positive">Supplier confirmed · {date(settlement.supplier_confirmed_at)}</Status>
                                : settlement.supplier_confirmation === 'not_received'
                                  ? <Status tone="error">Supplier: not received · {date(settlement.supplier_confirmed_at)}</Status>
                                  : <Status tone="warning">Awaiting supplier confirmation</Status>}
                            </div>
                            {settlement.supplier_note && <div className="meta">“{settlement.supplier_note}”</div>}
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
              move money. The supplier is then asked to confirm in their app that the money arrived; a
              payout they report as not received appears here again so a new transfer can be recorded.
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
                        {settlement.supplier_confirmation === 'not_received' ? ' · resend (supplier did not receive)' : ''}
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
                <AccountSelect id="payout-account" label="Paid from account" />
              </div>
            </ActionForm>
          </Card>
        )}
      </div>
    </>
  );
}
