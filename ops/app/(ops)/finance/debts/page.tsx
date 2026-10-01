import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Card, Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ListControls } from '@/components/list-controls';
import { debtStatus, debtTone } from '@/components/finance/ledger';
import { ApiError, get } from '@/lib/api';
import { createDebt } from '@/lib/finance-actions';
import { day, today, type Debt, type Parties } from '@/lib/finance';
import { phone, tzs } from '@/lib/format';
import { listPath, type ListParams, type Page } from '@/lib/paging';

export const metadata = { title: 'Debts · Omoterra Operations' };

const TABS = [
  { key: '', label: 'All' },
  { key: 'owed_to_me', label: 'Owed to me' },
  { key: 'i_owe', label: 'I owe' },
  { key: 'settled', label: 'Settled' },
  { key: 'cancelled', label: 'Cancelled' },
];

const SOURCE: Record<string, string> = {
  sale: 'Sale',
  sale_cost: 'Stock for a sale',
  batch_receipt: 'Received supplier stock',
  manual: 'Entered by hand',
  expense: 'Expense',
  lpo: 'Received LPO batch',
};

export default async function Debts({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let data: Page<Debt>;
  let parties: Parties;
  try {
    [data, parties] = await Promise.all([
      get<Page<Debt>>(listPath('/ops/ledger/debts', params)),
      get<Parties>('/ops/finance/parties'),
    ]);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Debts" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Debts could not be loaded.'}</Notice></div></>;
  }
  return (
    <>
      <div className="topbar">
        <PageHeader title="Debts" subtitle="Every amount someone owes you or you owe, with installments until it is settled."
          info="Sales create their debts automatically. Add anything else here: transport, loans, feed on credit, staff advances." />
      </div>
      <div className="workspace">
        <div className="grid-main-side">
          <ListControls path="/finance/debts" params={params} data={data} tabs={TABS} noun={['debt', 'debts']}
            actionLabel="open" placeholder="Search name, phone or description">
            <div className="table-wrap">
              {data.items.length === 0 ? <Empty>No debts in this view.</Empty> : (
                <table>
                  <thead><tr><th>Who</th><th>What</th><th className="numeric">Amount</th><th className="numeric">Balance</th><th>Status</th><th /></tr></thead>
                  <tbody>
                    {data.items.map((debt) => (
                      <tr key={debt.id}>
                        <td><Link href={`/finance/debts/${debt.id}`} className="strong">{debt.party_name}</Link>
                          <div className="meta">{debt.direction === 'receivable' ? 'Owes me' : 'I owe'}{debt.party_phone ? ` · ${phone(debt.party_phone)}` : ''}</div></td>
                        <td className="small">{debt.description}<div className="meta">{SOURCE[debt.source]} · {day(debt.incurred_on)}{debt.due_on ? ` · due ${day(debt.due_on)}` : ''}</div></td>
                        <td className="numeric">{tzs(debt.amount)}</td>
                        <td className="numeric money">{tzs(debt.balance)}</td>
                        <td><Status tone={debtTone(debt)}>{debtStatus(debt)}</Status></td>
                        <td>{debt.direction === 'payable' && debt.status === 'open'
                          ? <Link href={`/finance/supplier-payments?debt=${debt.id}`} className="button" data-variant="secondary">Record payment</Link>
                          : <Link href={`/finance/debts/${debt.id}`} className="small">View</Link>}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </ListControls>

          <Card title="Add a debt">
            <ActionForm action={createDebt} label="Save debt" hidden={{ idempotency_key: randomUUID() }}>
              <div className="field">
                <label htmlFor="direction">Direction</label>
                <select id="direction" name="direction" className="input" required>
                  <option value="payable">I owe them</option>
                  <option value="receivable">They owe me</option>
                </select>
              </div>
              <div className="field">
                <label htmlFor="party">Who</label>
                <select id="party" name="party" className="input" defaultValue="">
                  <option value="">Someone else (type the name below)</option>
                  <optgroup label="Suppliers">
                    {parties.suppliers.map((s) => <option key={s.id} value={`supplier:${s.id}`}>{s.name} · {s.phone}</option>)}
                  </optgroup>
                  <optgroup label="Buyers">
                    {parties.buyers.filter((b) => b.kind === 'profile').map((b) => <option key={b.id} value={`buyer:${b.id}`}>{b.name}{b.phone ? ` · ${b.phone}` : ''}</option>)}
                  </optgroup>
                </select>
              </div>
              <div className="field">
                <label htmlFor="party_name">Name (if someone else)</label>
                <input id="party_name" name="party_name" className="input" placeholder="e.g. Juma transport" />
              </div>
              <div className="field">
                <label htmlFor="party_phone">Phone (optional)</label>
                <input id="party_phone" name="party_phone" className="input" inputMode="tel" />
              </div>
              <div className="field">
                <label htmlFor="description">What for</label>
                <input id="description" name="description" className="input" required minLength={2} placeholder="e.g. Transport to Kariakoo" />
              </div>
              <div className="field">
                <label htmlFor="amount">Amount (TZS)</label>
                <input id="amount" name="amount" className="input" inputMode="decimal" required />
              </div>
              <div className="grid-2">
                <div className="field">
                  <label htmlFor="incurred_on">Date</label>
                  <input id="incurred_on" name="incurred_on" type="date" className="input" defaultValue={today()} max={today()} required />
                </div>
                <div className="field">
                  <label htmlFor="due_on">Due (optional)</label>
                  <input id="due_on" name="due_on" type="date" className="input" />
                </div>
              </div>
            </ActionForm>
          </Card>
        </div>
      </div>
    </>
  );
}
