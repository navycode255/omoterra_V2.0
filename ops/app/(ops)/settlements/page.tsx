import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Card, Empty, Notice, PageHeader, Status } from '@/components/ui';
import { recordPayoutAttempt } from '@/lib/payout-actions';
import { METHODS, today } from '@/lib/finance';
import styles from '@/components/finance/payouts.module.css';
import { ApiError, get } from '@/lib/api';
import { date, quantity, reference, tzs } from '@/lib/format';
import { ListControls } from '@/components/list-controls';
import { listPath, type ListParams, type Page } from '@/lib/paging';
import type { Settlement } from '@/lib/types';
import { AccountSelect } from '@/components/finance/account-select';

export const metadata = { title: 'Settlements · Omoterra Operations' };

// Payout attempts (M2.7): paid is net paid (debited less refunds); in flight
// is sent but not confirmed as debited; disputed is money possibly paid twice.
type Settlements = Page<Settlement> & { totals: { pending: string; paid: string; refunded: string; in_flight: string;
  in_flight_count: number; disputed: string; disputed_count: number } };

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
        <div className="stat-band">
          <div className="stat">
            <div className="stat-label">Pending payouts</div>
            <div className="stat-value numeric" data-stat="pending">{tzs(data.totals.pending)}</div>
          </div>
          <div className="stat">
            <div className="stat-label">Paid to date (net)</div>
            <div className="stat-value numeric" data-stat="paid">{tzs(data.totals.paid)}</div>
          </div>
          <div className="stat">
            <div className="stat-label">Sent, debit not confirmed</div>
            <div className="stat-value numeric" data-stat="in-flight">{tzs(data.totals.in_flight)}</div>
          </div>
          <div className="stat">
            <div className="stat-label">Possibly paid twice</div>
            <div className="stat-value numeric" data-stat="exposure">{tzs(data.totals.disputed)}</div>
          </div>
        </div>
        {Number(data.totals.disputed) > 0 && <p className={styles.danger}>
          {tzs(data.totals.disputed)} on {data.totals.disputed_count === 1 ? 'one payout' : `${data.totals.disputed_count} payouts`} may
          have been paid twice: a supplier says a debited payout never arrived, or more was sent than the settlement. It stays
          money out until a refund is recorded on the attempt.
        </p>}

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
                        <Link href={`/settlements/${settlement.id}`} className="small">Open payout</Link>
                        {Number(settlement.in_flight ?? 0) > 0 && <span className={styles.statusLine}>Sent, debit not confirmed: {tzs(settlement.in_flight)}</span>}
                        {Number(settlement.exposure ?? 0) > 0 && <span className={styles.statusLine}>Possibly paid twice: {tzs(settlement.exposure)}</span>}
                        {(settlement.approvals_waiting ?? 0) > 0 && <span className={styles.statusLine}>Waiting for a second admin</span>}
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
                        ) : settlement.status === 'cancelled' ? (
                          <Status tone="neutral">Cancelled</Status>
                        ) : (
                          <Status tone="warning">{settlement.current_state === 'initiated' ? 'Sent' : 'Pending'}</Status>
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
          <Card title="Record a payout">
            <p className="muted small" style={{ marginBottom: 'var(--s4)' }}>
              Record this after sending the money; recording it does not move money. Tick the box only when the statement
              or the provider&apos;s message confirms the debit: until then it is shown as sent, not as money out. A resend, or a
              payout over TZS 500,000, needs a second admin&apos;s approval: open the payout to ask for it.
            </p>
            <ActionForm action={recordPayoutAttempt} label="Record payout">
              <div className="grid-3">
                <div className="field">
                  <label htmlFor="settlement_id">Settlement</label>
                  <select id="settlement_id" name="settlement_id" className="input" required>
                    {pending.map((settlement) => (
                      <option key={settlement.id} value={settlement.id}>
                        {settlement.supplier_alias || settlement.supplier_id} ·{' '}
                        {tzs(settlement.outstanding ?? settlement.total_payable)}
                        {settlement.supplier_confirmation === 'not_received' ? ' · resend (supplier did not receive)' : ''}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="field">
                  <label htmlFor="amount">Amount sent</label>
                  <input id="amount" name="amount" className="input" inputMode="decimal" required />
                </div>
                <div className="field">
                  <label htmlFor="method">Method</label>
                  <select id="method" name="method" className="input" defaultValue="mpesa">
                    <option value="">Not recorded</option>
                    {METHODS.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                  </select>
                </div>
                <div className="field">
                  <label htmlFor="payment_reference">Payment reference</label>
                  <input id="payment_reference" name="payment_reference" className="input" required />
                </div>
                <div className="field">
                  <label htmlFor="sent_on">Sent on</label>
                  <input id="sent_on" name="sent_on" type="date" className="input" defaultValue={today()} max={today()} required />
                </div>
                <AccountSelect id="payout-account" label="Paid from account" />
              </div>
              <label className={styles.check}><input type="checkbox" name="debited" />
                The debit is confirmed (statement line or the provider&apos;s message)</label>
              <div className="field">
                <label htmlFor="evidence">Evidence</label>
                <input id="evidence" name="evidence" className="input" placeholder="e.g. M-Pesa message, statement line" />
              </div>
            </ActionForm>
          </Card>
        )}
      </div>
    </>
  );
}
