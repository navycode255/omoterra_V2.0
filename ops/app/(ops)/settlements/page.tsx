import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Card, Empty, Notice, PageHeader, Status } from '@/components/ui';
import { paySettlement } from '@/lib/actions';
import { ApiError, get } from '@/lib/api';
import { date, quantity, reference, tzs } from '@/lib/format';
import type { Settlement, SupplierRow } from '@/lib/types';

export const metadata = { title: 'Settlements · Omoterra Operations' };

export default async function Settlements() {
  let settlements: Settlement[];
  let suppliers: SupplierRow[];
  try {
    [settlements, suppliers] = await Promise.all([
      get<Settlement[]>('/ops/settlements'),
      get<SupplierRow[]>('/ops/suppliers'),
    ]);
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

  const names = new Map(suppliers.map((s) => [s.id, s]));
  const pending = settlements.filter((s) => s.status === 'pending');
  const pendingTotal = pending.reduce((sum, s) => sum + Number(s.total_payable), 0);
  const paidTotal = settlements
    .filter((s) => s.status === 'paid')
    .reduce((sum, s) => sum + Number(s.total_payable), 0);

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
            <div className="stat-value numeric">{tzs(pendingTotal.toFixed(2))}</div>
          </div>
          <div className="stat">
            <div className="stat-label">Paid to date</div>
            <div className="stat-value numeric">{tzs(paidTotal.toFixed(2))}</div>
          </div>
        </div>

        <div className="table-wrap">
          {settlements.length === 0 ? (
            <Empty>No settlements yet. They are created when an order is delivered.</Empty>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Supplier</th>
                  <th>Order item</th>
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
                  const supplier = names.get(settlement.supplier_id);
                  return (
                    <tr key={settlement.id}>
                      <td>
                        <Link href={`/suppliers/${settlement.supplier_id}`} className="strong">
                          {supplier?.public_alias ?? '—'}
                        </Link>
                        <div className="meta">{supplier?.legal_name}</div>
                      </td>
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
                        {names.get(settlement.supplier_id)?.public_alias ?? settlement.supplier_id} ·{' '}
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
