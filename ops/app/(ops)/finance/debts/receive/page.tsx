import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { Card, Notice, PageHeader } from '@/components/ui';
import { ReceivePaymentForm } from '@/components/finance/receive-payment-form';
import { ApiError, get } from '@/lib/api';
import { day, today, type BuyerBalance, type BuyerOpenDebts } from '@/lib/finance';
import { phone, tzs } from '@/lib/format';

export const metadata = { title: 'Receive customer payment · Omoterra Operations' };

type Params = { buyer?: string; paid?: string };

export default async function ReceiveCustomerPayment({ searchParams }: { searchParams: Promise<Params> }) {
  const { buyer, paid } = await searchParams;
  let customers: BuyerBalance[]; let chosen: BuyerOpenDebts | null = null;
  try {
    [customers, chosen] = await Promise.all([
      get<{ items: BuyerBalance[] }>('/ops/ledger/buyer-balances').then((body) => body.items),
      buyer ? get<BuyerOpenDebts>(`/ops/ledger/buyers/${encodeURIComponent(buyer)}/open-debts`) : Promise.resolve(null),
    ]);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Receive customer payment" /></div><div className="workspace">
      <Notice tone="error">{error instanceof ApiError ? error.message : 'Customer debts could not be loaded.'}</Notice></div></>;
  }

  return <>
    <div className="topbar"><PageHeader title="Receive customer payment"
      subtitle="Enter what the customer paid once. It clears their oldest debt first, then the next." /></div>
    <div className="workspace">
      {paid && <Notice>Payment recorded.</Notice>}
      <div className="grid-2" style={{ alignItems: 'start' }}>
        <Card title="Customers who owe">
          {customers.length === 0 ? <p className="muted small">No customer owes anything right now.</p> : (
            <div className="table-wrap" style={{ border: 'none' }}>
              <table>
                <thead><tr><th>Customer</th><th className="numeric">Owes</th><th>Oldest debt</th></tr></thead>
                <tbody>{customers.map((row) => (
                  <tr key={row.id} aria-current={row.id === buyer ? 'true' : undefined} style={row.id === buyer ? { background: 'var(--surface-2, #f0f7f3)' } : undefined}>
                    <td><Link className="strong" href={`/finance/debts/receive?buyer=${row.id}`}>{row.name}</Link>
                      <div className="meta">{row.phone ? phone(row.phone) : 'No phone'} · {row.debts} {row.debts === 1 ? 'debt' : 'debts'}</div></td>
                    <td className="numeric money">{tzs(row.balance)}</td>
                    <td className="small">{day(row.oldest)}</td>
                  </tr>
                ))}</tbody>
              </table>
            </div>
          )}
        </Card>
        <Card title={chosen ? `Payment from ${chosen.buyer.name}` : 'Payment'}>
          {!chosen ? <p className="muted small">Choose a customer on the left.</p>
            : chosen.debts.length === 0 ? <p className="muted small">{chosen.buyer.name} has no open debts.</p>
            : <ReceivePaymentForm key={`${chosen.buyer.id}:${chosen.balance}`} buyerId={chosen.buyer.id} debts={chosen.debts}
                today={today()} idempotencyKey={randomUUID()} />}
        </Card>
      </div>
      <p className="meta">To put money on one specific debt instead, open that debt and record it there. <Link href="/finance/debts">Back to debts</Link></p>
    </div>
  </>;
}
