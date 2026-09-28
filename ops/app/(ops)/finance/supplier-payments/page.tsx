import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Card, Empty, Notice, PageHeader, Status } from '@/components/ui';
import { debtTone } from '@/components/finance/ledger';
import { ApiError, get } from '@/lib/api';
import { recordSupplierPayment, recordUnlistedSupplierPayment } from '@/lib/finance-actions';
import { METHODS, day, today, type Debt, type Parties } from '@/lib/finance';
import { tzs } from '@/lib/format';
import type { Page } from '@/lib/paging';

export const metadata = { title: 'Supplier payments · Omoterra Operations' };

function source(debt: Debt) {
  if (debt.lpo_id) return <Link href={`/lpos/${debt.lpo_id}`}>Received LPO batch</Link>;
  if (debt.sale_id) return <Link href={`/sales/${debt.sale_id}`}>Stock for a sale</Link>;
  if (debt.source === 'expense') return 'Expense';
  return 'Other supplier debt';
}

export default async function SupplierPayments({ searchParams }: {
  searchParams: Promise<{ debt?: string; paid?: string }>;
}) {
  const { debt: selectedId, paid } = await searchParams;
  let data: Page<Debt>;
  let parties: Parties;
  try {
    [data, parties] = await Promise.all([
      get<Page<Debt>>('/ops/ledger/debts?status=i_owe&page_size=100'),
      get<Parties>('/ops/finance/parties'),
    ]);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Supplier payments" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Supplier balances could not be loaded.'}</Notice></div></>;
  }

  const open = data.items.filter((debt) => debt.direction === 'payable' && debt.status === 'open');
  const selected = open.find((debt) => debt.id === selectedId) ?? open[0];

  return (
    <>
      <div className="topbar">
        <PageHeader title="Supplier payments" subtitle="Record money you have already paid for stock, received batches and other supplier balances." />
        <Link href="/finance/debts?status=i_owe" className="button" data-variant="secondary">View all amounts I owe</Link>
      </div>
      <div className="workspace">
        {paid && <Notice>Supplier payment recorded. The balance and cash book have been updated.</Notice>}
        <Notice>Use this page for direct sales and batches received on an LPO. Marketplace order payouts remain under <Link href="/settlements">Settlements</Link>.</Notice>

        {open.length === 0 ? <Empty>You have no open supplier balances to pay.</Empty> : (
          <div className="grid-2" style={{ alignItems: 'start', gridTemplateColumns: 'minmax(0, 1.7fr) minmax(340px, 1fr)' }}>
            <Card title="Amounts still owed">
              <div className="table-wrap">
                <table>
                  <thead><tr><th>Supplier</th><th>What for</th><th className="numeric">Balance</th><th /></tr></thead>
                  <tbody>
                    {open.map((debt) => (
                      <tr key={debt.id}>
                        <td><strong>{debt.party_name}</strong><div className="meta">{debt.description}</div></td>
                        <td className="small">{source(debt)}<div className="meta">Recorded {day(debt.incurred_on)}{debt.due_on ? ` · due ${day(debt.due_on)}` : ''}</div></td>
                        <td className="numeric money">{tzs(debt.balance)}</td>
                        <td><Link href={`/finance/supplier-payments?debt=${debt.id}`} className="button" data-variant={selected.id === debt.id ? undefined : 'secondary'}>
                          {selected.id === debt.id ? 'Selected' : 'Record payment'}
                        </Link></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Card>

            <Card title={`Record payment to ${selected.party_name}`}
              action={<Status tone={debtTone(selected)}>Balance {tzs(selected.balance)}</Status>}>
              <p className="small muted" style={{ margin: '0 0 var(--s4)' }}>{selected.description}</p>
              <ActionForm action={recordSupplierPayment} label="Record supplier payment"
                hidden={{ debt_id: selected.id, idempotency_key: randomUUID() }}>
                <div className="field">
                  <label htmlFor="amount">Amount paid (TZS)</label>
                  <input id="amount" name="amount" className="input" inputMode="decimal" defaultValue={selected.balance} required />
                  <span className="meta">The full remaining balance is filled in. Change it if this was a part payment.</span>
                </div>
                <div className="grid-2">
                  <div className="field">
                    <label htmlFor="paid_on">Date paid</label>
                    <input id="paid_on" name="paid_on" type="date" className="input" defaultValue={today()} max={today()} required />
                  </div>
                  <div className="field">
                    <label htmlFor="method">Method</label>
                    <select id="method" name="method" className="input" defaultValue="cash">
                      {METHODS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
                    </select>
                  </div>
                </div>
                <div className="field">
                  <label htmlFor="reference">Transaction reference (optional)</label>
                  <input id="reference" name="reference" className="input" placeholder="e.g. M-Pesa code" />
                </div>
                <div className="field">
                  <label htmlFor="note">Note (optional)</label>
                  <input id="note" name="note" className="input" placeholder="e.g. Paid in full" />
                </div>
              </ActionForm>
            </Card>
          </div>
        )}

        <Card title="Paid supplier, but no balance is listed?">
          <p className="small muted" style={{ margin: '0 0 var(--s4)' }}>
            Use this when an older sale was recorded without its supplier cost. It records the cost and marks it fully paid in one step.
          </p>
          <ActionForm action={recordUnlistedSupplierPayment} label="Record paid supplier cost"
            hidden={{ idempotency_key: randomUUID(), payment_key: randomUUID() }}>
            <div className="grid-2">
              <div className="field">
                <label htmlFor="unlisted-supplier">Supplier</label>
                <select id="unlisted-supplier" name="supplier_id" className="input" defaultValue="" required>
                  <option value="" disabled>Choose the supplier…</option>
                  {parties.suppliers.map((supplier) => <option key={supplier.id} value={supplier.id}>{supplier.name} · {supplier.phone}</option>)}
                </select>
              </div>
              <div className="field">
                <label htmlFor="unlisted-description">What was supplied</label>
                <input id="unlisted-description" name="description" className="input" placeholder="e.g. Chicken batch sold to walk-in buyers" required minLength={2} />
              </div>
              <div className="field">
                <label htmlFor="unlisted-amount">Amount paid (TZS)</label>
                <input id="unlisted-amount" name="amount" className="input" inputMode="decimal" required />
              </div>
              <div className="field">
                <label htmlFor="unlisted-date">Date paid</label>
                <input id="unlisted-date" name="paid_on" type="date" className="input" defaultValue={today()} max={today()} required />
              </div>
              <div className="field">
                <label htmlFor="unlisted-method">Method</label>
                <select id="unlisted-method" name="method" className="input" defaultValue="cash">
                  {METHODS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
                </select>
              </div>
              <div className="field">
                <label htmlFor="unlisted-reference">Transaction reference (optional)</label>
                <input id="unlisted-reference" name="reference" className="input" placeholder="e.g. M-Pesa code" />
              </div>
            </div>
            <div className="field">
              <label htmlFor="unlisted-note">Note (optional)</label>
              <input id="unlisted-note" name="note" className="input" placeholder="e.g. Batch paid in full" />
            </div>
          </ActionForm>
        </Card>
      </div>
    </>
  );
}
