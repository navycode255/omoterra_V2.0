import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { SupplierPaymentForm, SupplierReceiptMessageFields } from '@/components/finance/supplier-payment-form';
import { Card, Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { recordUnlistedSupplierPayment } from '@/lib/finance-actions';
import { METHODS, day, today, type Debt, type Parties } from '@/lib/finance';
import { tzs } from '@/lib/format';
import type { Page } from '@/lib/paging';

export const metadata = { title: 'Supplier payments · Omoterra Operations' };

export default async function SupplierPayments({ searchParams }: {
  searchParams: Promise<{ supplier?: string; debt?: string; paid?: string; sms?: string }>;
}) {
  const query = await searchParams;
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

  const open = data.items.filter((debt) => debt.direction === 'payable' && debt.status === 'open' && debt.supplier_id);
  const grouped = new Map<string, Debt[]>();
  for (const debt of open) grouped.set(debt.supplier_id!, [...(grouped.get(debt.supplier_id!) ?? []), debt]);
  const requestedByDebt = open.find((debt) => debt.id === query.debt)?.supplier_id;
  const selectedId = (query.supplier && grouped.has(query.supplier) ? query.supplier : requestedByDebt) ?? grouped.keys().next().value;
  const selected = selectedId ? grouped.get(selectedId) ?? [] : [];
  const selectedTotal = selected.reduce((sum, debt) => sum + Number(debt.balance), 0);

  return (
    <>
      <div className="topbar">
        <PageHeader title="Supplier payments" subtitle="Pay a supplier's full balance, make a part payment, or choose specific invoices." />
        <Link href="/finance/debts?status=i_owe" className="button" data-variant="secondary">All amounts I owe</Link>
      </div>
      <div className="workspace">
        {query.paid && <Notice>Payment recorded. The supplier can now see it in their dashboard, and all balances have been updated.{query.sms === 'queued' ? ' Their receipt SMS is being sent.' : ''}</Notice>}
        <Notice>These payments cover batches received through LPOs and supplier costs on direct sales. Marketplace payouts remain under <Link href="/settlements">Settlements</Link>.</Notice>

        {!grouped.size ? <Empty>You have no open registered supplier balances to pay.</Empty> : (
          <div className="supplier-payment-layout">
            <Card title="Suppliers to pay">
              <div className="supplier-balance-list">
                {[...grouped.entries()].map(([supplierId, debts]) => {
                  const total = debts.reduce((sum, debt) => sum + Number(debt.balance), 0);
                  return <Link key={supplierId} href={`/finance/supplier-payments?supplier=${supplierId}`}
                    className={supplierId === selectedId ? 'is-selected' : ''}>
                    <span><strong>{debts[0].party_name}</strong><small>{debts.length} open {debts.length === 1 ? 'invoice' : 'invoices'} · oldest {day([...debts].sort((a, b) => a.incurred_on.localeCompare(b.incurred_on))[0].incurred_on)}</small></span>
                    <b>{tzs(String(total))}</b>
                  </Link>;
                })}
              </div>
            </Card>

            {selected.length > 0 && <Card title={`Pay ${selected[0].party_name}`}
              action={<Status tone="warning">Total due {tzs(String(selectedTotal))}</Status>}>
              <SupplierPaymentForm supplierId={selected[0].supplier_id!} debts={selected} idempotencyKey={randomUUID()} />
            </Card>}
          </div>
        )}

        <Card title="Paid supplier, but no invoice is listed?">
          <p className="small muted" style={{ margin: '0 0 var(--s4)' }}>Use this only when the original batch or stock cost was never entered. It creates a supplier invoice and marks it paid in one step.</p>
          <ActionForm action={recordUnlistedSupplierPayment} label="Record paid supplier cost"
            hidden={{ idempotency_key: randomUUID(), payment_key: randomUUID() }}>
            <div className="grid-2">
              <div className="field"><label htmlFor="unlisted-supplier">Supplier</label><select id="unlisted-supplier" name="supplier_id" className="input" defaultValue="" required><option value="" disabled>Choose the supplier…</option>{parties.suppliers.map((supplier) => <option key={supplier.id} value={supplier.id}>{supplier.name} · {supplier.phone}</option>)}</select></div>
              <div className="field"><label htmlFor="unlisted-description">What was supplied</label><input id="unlisted-description" name="description" className="input" placeholder="e.g. Chicken batch sold to walk-in buyers" required minLength={2} /></div>
              <div className="field"><label htmlFor="unlisted-amount">Amount paid (TZS)</label><input id="unlisted-amount" name="amount" className="input" inputMode="decimal" required /></div>
              <div className="field"><label htmlFor="unlisted-date">Date paid</label><input id="unlisted-date" name="paid_on" type="date" className="input" defaultValue={today()} max={today()} required /></div>
              <div className="field"><label htmlFor="unlisted-method">Method</label><select id="unlisted-method" name="method" className="input" defaultValue="mpesa">{METHODS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}</select></div>
              <div className="field"><label htmlFor="unlisted-reference">Receipt / transaction number</label><input id="unlisted-reference" name="reference" className="input" placeholder="e.g. M-Pesa code" /></div>
            </div>
            <div className="field"><label htmlFor="unlisted-sms">Payment confirmation SMS (proof)</label><textarea id="unlisted-sms" name="sms_text" className="input" rows={3} placeholder="Paste the payment confirmation SMS" /></div>
            <div className="field"><label htmlFor="unlisted-receipt">Receipt image</label><input id="unlisted-receipt" name="receipt" className="input" type="file" accept="image/jpeg,image/png,image/webp" /></div>
            <div className="field"><label htmlFor="unlisted-note">Note (optional)</label><input id="unlisted-note" name="note" className="input" placeholder="e.g. Batch paid in full" /></div>
            <SupplierReceiptMessageFields idPrefix="unlisted" />
          </ActionForm>
        </Card>
      </div>
    </>
  );
}
