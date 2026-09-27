import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { Card, Definition, Notice, PageHeader, Status } from '@/components/ui';
import { DebtSummary, PartyLink, PaymentForm, PaymentsTable, debtStatus, debtTone } from '@/components/finance/ledger';
import { ApiError, get } from '@/lib/api';
import { cancelSale } from '@/lib/finance-actions';
import { UNITS, day, today, type SaleDetail } from '@/lib/finance';
import { category, dateTime, phone, quantity, tzs } from '@/lib/format';
import { requireSession } from '@/lib/session';

export const metadata = { title: 'Sale · Omoterra Operations' };

export default async function SaleWorkspace({ params, searchParams }: {
  params: Promise<{ id: string }>; searchParams: Promise<{ created?: string }>;
}) {
  const { id } = await params;
  const { created } = await searchParams;
  const operator = await requireSession();
  const admin = operator.role === 'admin';
  let sale: SaleDetail;
  try {
    sale = await get<SaleDetail>(`/ops/sales/${id}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }
  const receivable = sale.debts.find((d) => d.direction === 'receivable');
  const payables = sale.debts.filter((d) => d.direction === 'payable');
  const anyPaid = sale.debts.some((d) => Number(d.paid_amount) > 0);
  const unitLabel = (value: string) => UNITS.find(([key]) => key === value)?.[1].toLowerCase() ?? value;

  return (
    <>
      <div className="topbar">
        <PageHeader title={`Sale ${sale.sale_number}`}
          subtitle={`Sold ${day(sale.sold_on)} · entered ${dateTime(sale.created_at)} by ${sale.created_by ?? '—'}`} />
        {sale.status === 'cancelled' ? <Status>Cancelled</Status>
          : Number(sale.balance) > 0 ? <Status tone="warning">Buyer owes {tzs(sale.balance)}</Status> : <Status tone="positive">Paid in full</Status>}
      </div>
      <div className="workspace">
        {created && <div className="notice" role="status">Sale saved. Record further installments below as money arrives.</div>}
        {sale.status === 'cancelled' && <Notice>Cancelled {dateTime(sale.cancelled_at)}: {sale.cancel_reason}</Notice>}

        <div className="grid-2" style={{ alignItems: 'start' }}>
          <div className="stack">
            <Card title="Buyer">
              <Definition items={[
                ['Buyer', <Link key="b" href={`/buyers/${sale.buyer_profile_id}`}>{sale.buyer_name}</Link>],
                ['Phone', phone(sale.buyer_phone)],
                ['Notes', sale.notes || '—'],
              ]} />
            </Card>
            <Card title="Items">
              <div className="table-wrap">
                <table>
                  <thead><tr><th>Item</th><th className="numeric">Qty</th><th className="numeric">Price</th><th className="numeric">Total</th><th>From</th></tr></thead>
                  <tbody>
                    {sale.items.map((item) => (
                      <tr key={item.id}>
                        <td>{item.category ? category(item.category) : item.description}{item.category && item.description && <div className="meta">{item.description}</div>}</td>
                        <td className="numeric">{quantity(item.quantity)} {unitLabel(item.unit)}</td>
                        <td className="numeric">{tzs(item.unit_price)}</td>
                        <td className="numeric money">{tzs(item.subtotal)}</td>
                        <td className="small">{item.unit_cost ? <>{item.supplier_name || payables.find((p) => p.supplier_id === item.supplier_id)?.party_name || 'Supplier'}<div className="meta">cost {tzs(item.unit_cost)} each</div></> : 'Own stock'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div style={{ marginTop: 'var(--s4)' }}>
                <Definition items={[
                  ['Sale total', <strong key="t">{tzs(sale.total_amount)}</strong>],
                  ['Cost owed to suppliers', tzs(sale.cost_amount)],
                  ['Margin before expenses', tzs(sale.margin)],
                ]} />
                {sale.status === 'active' && (
                  <p className="small" style={{ marginTop: 'var(--s3)' }}>
                    <Link href={`/finance/expenses?sale_id=${sale.id}`}>Expenses for this sale (labour, transport…)</Link>
                  </p>
                )}
              </div>
            </Card>
          </div>

          <div className="stack">
            {receivable && (
              <Card title="Buyer payments">
                <DebtSummary debt={receivable} />
                <div style={{ margin: 'var(--s4) 0' }}>
                  <PaymentsTable payments={receivable.payments} admin={admin} direction="receivable" />
                </div>
                {sale.status === 'active' && <PaymentForm debt={receivable} today={today()} saleId={sale.id} />}
              </Card>
            )}
            {payables.map((debt) => (
              <Card key={debt.id} title={`I owe ${debt.party_name}`}
                action={<Status tone={debtTone(debt)}>{debtStatus(debt)}</Status>}>
                <p className="small muted" style={{ marginBottom: 'var(--s3)' }}>
                  <PartyLink debt={debt} /> · {debt.description} · <Link href={`/finance/debts/${debt.id}`}>open debt</Link>
                </p>
                <DebtSummary debt={debt} />
                <div style={{ margin: 'var(--s4) 0' }}>
                  <PaymentsTable payments={debt.payments} admin={admin} direction="payable" />
                </div>
                {sale.status === 'active' && <PaymentForm debt={debt} today={today()} saleId={sale.id} />}
              </Card>
            ))}
            {admin && sale.status === 'active' && (
              <Card title="Cancel sale">
                {anyPaid ? (
                  <p className="small muted">Money is recorded on this sale. Reverse those payments first; then it can be cancelled.</p>
                ) : (
                  <ActionForm action={cancelSale} label="Cancel sale" variant="danger"
                    confirm="Cancel this sale? Its debts are cancelled too. It stays in the history."
                    hidden={{ sale_id: sale.id, idempotency_key: randomUUID() }}>
                    <div className="field">
                      <label htmlFor="reason">Reason</label>
                      <input id="reason" name="reason" className="input" required minLength={3} placeholder="e.g. Entered twice" />
                    </div>
                  </ActionForm>
                )}
              </Card>
            )}
          </div>
        </div>
        <p className="meta"><Link href="/sales">Back to sales</Link></p>
      </div>
    </>
  );
}
