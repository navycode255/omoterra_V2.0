import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Card, Definition, Notice, PageHeader, Status } from '@/components/ui';
import { AdjustmentsList, CancelDebtForm, DebtCorrections, DebtSummary, PartyLink, PaymentForm, PaymentsTable, UseCreditForm, debtStatus, debtTone } from '@/components/finance/ledger';
import { ApiError, get } from '@/lib/api';
import { day, expenseLabel, today, type DebtDetail, type Parties, type SupplierCredit } from '@/lib/finance';
import { dateTime, phone } from '@/lib/format';
import { requireSession } from '@/lib/session';

export const metadata = { title: 'Debt · Omoterra Operations' };

export default async function DebtWorkspace({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const operator = await requireSession();
  const admin = operator.role === 'admin';
  let debt: DebtDetail;
  try {
    debt = await get<DebtDetail>(`/ops/ledger/debts/${id}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }
  const incoming = debt.direction === 'receivable';
  const supplierDebt = !incoming && debt.supplier_id ? debt.supplier_id : null;
  const credit = supplierDebt && debt.status === 'open'
    ? await get<SupplierCredit>(`/ops/ledger/suppliers/${supplierDebt}/credit`).catch(() => null) : null;
  // A sale's supplier debt is corrected for a reason (wrong supplier, ...), never just cancelled.
  const correctable = admin && debt.source === 'sale_cost' && debt.direction === 'payable' && debt.status !== 'cancelled';
  const suppliers = correctable ? (await get<Parties>('/ops/finance/parties').catch(() => null))?.suppliers ?? [] : [];
  return (
    <>
      <div className="topbar">
        <PageHeader title={incoming ? `${debt.party_name} owes me` : `I owe ${debt.party_name}`} subtitle={debt.description} />
        <Status tone={debtTone(debt)}>{debtStatus(debt)}</Status>
      </div>
      <div className="workspace">
        {debt.status === 'cancelled' && <Notice>Cancelled {dateTime(debt.cancelled_at)}: {debt.cancel_reason}</Notice>}
        <DebtSummary debt={debt} />
        <div className="grid-2" style={{ alignItems: 'start' }}>
          <div className="stack">
            <Card title="Details">
              <Definition items={[
                ['Who', <PartyLink key="p" debt={debt} />],
                ['Phone', phone(debt.party_phone)],
                ['Date', day(debt.incurred_on)],
                ['Due', day(debt.due_on)],
                ['From', debt.source === 'expense' ? `Expense · ${expenseLabel(debt.expense_category)}${debt.sale_number ? ` · sale ${debt.sale_number}` : ''}`
                  : debt.sale_id ? <Link key="s" href={`/sales/${debt.sale_id}`}>Sale {debt.sale_number}</Link>
                    : debt.lpo_id ? <Link key="l" href={`/lpos/${debt.lpo_id}`}>Received LPO batch</Link> : 'Entered by hand'],
                ['Recorded by', `${debt.created_by ?? '—'} · ${dateTime(debt.created_at)}`],
              ]} />
            </Card>
            <Card title={incoming ? 'Money received' : 'Payments made'}>
              <PaymentsTable payments={debt.payments} admin={admin} direction={debt.direction} supplier={Boolean(supplierDebt)} />
            </Card>
          </div>
          <div className="stack">
            {supplierDebt && credit && Number(credit.credit) > 0 && (
              <Card title="Use supplier credit">
                <UseCreditForm supplierId={supplierDebt} credit={credit.credit} owed={debt.balance} debtId={debt.id} />
              </Card>
            )}
            {debt.status === 'open' && (
              <div id="pay" style={{ scrollMarginTop: 96 }}><Card title={incoming ? 'Record money received' : 'Record a payment'}>
                <PaymentForm debt={debt} today={today()} saleId={debt.sale_id ?? undefined} />
              </Card></div>
            )}
            {correctable && (
              <Card title="Correct this supplier debt">
                <DebtCorrections debt={debt} suppliers={suppliers} />
              </Card>
            )}
            {admin && ['manual', 'expense'].includes(debt.source) && debt.status !== 'cancelled' && (
              <Card title="Cancel">
                {Number(debt.paid_amount) > 0
                  ? <p className="small muted">{supplierDebt ? 'Move the payments on it to supplier credit first.' : 'Reverse the payments recorded on it first.'}</p>
                  : <CancelDebtForm debt={debt} />}
              </Card>
            )}
            {debt.adjustments.length > 0 && (
              <Card title="Corrections">
                <AdjustmentsList debt={debt} />
              </Card>
            )}
          </div>
        </div>
        <p className="meta"><Link href="/finance/debts">Back to debts</Link></p>
      </div>
    </>
  );
}
