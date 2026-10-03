import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { Icons } from '@/components/icons';
import { Notice, PageHeader, Status } from '@/components/ui';
import { DebtSummary, PartyLink, PaymentForm, PaymentsTable, debtStatus, debtTone } from '@/components/finance/ledger';
import { categoryImage } from '@/components/portal/supplier-format';
import { ApiError, get } from '@/lib/api';
import { cancelSale } from '@/lib/finance-actions';
import { UNITS, day, today, type SaleDetail } from '@/lib/finance';
import { category, dateTime, phone, quantity, tzs } from '@/lib/format';
import { requireSession } from '@/lib/session';
import styles from '@/components/finance/finance.module.css';

export const metadata = { title: 'Sale · Omoterra Operations' };

export default async function SaleWorkspace({ params, searchParams }: {
  params: Promise<{ id: string }>; searchParams: Promise<{ created?: string; updated?: string }>;
}) {
  const { id } = await params;
  const { created, updated } = await searchParams;
  const operator = await requireSession();
  const admin = operator.role === 'admin';
  let sale: SaleDetail;
  try {
    sale = await get<SaleDetail>(`/ops/sales/${id}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }
  const receivable = sale.debts.find((debt) => debt.direction === 'receivable');
  const payables = sale.debts.filter((debt) => debt.direction === 'payable' && debt.status !== 'cancelled');
  const anyPaid = sale.debts.some((debt) => Number(debt.paid_amount) > 0);
  const unitLabel = (value: string) => UNITS.find(([key]) => key === value)?.[1].toLowerCase() ?? value;

  return <div className={styles.saleDetailPage}>
    <div className={`topbar ${styles.saleDetailTopbar}`}>
      <div>
        <nav className={styles.saleBreadcrumb} aria-label="Breadcrumb"><Link href="/sales">Sales</Link><span>›</span><span>Sale {sale.sale_number}</span></nav>
        <PageHeader title={`Sale ${sale.sale_number}`}
          subtitle={`Sold ${day(sale.sold_on)} · entered ${dateTime(sale.created_at)} by ${sale.created_by ?? '—'}`} />
      </div>
      <div className={styles.saleDetailActions}>
        {sale.status === 'active' && <Link className={styles.editSaleButton} href={`/sales/${sale.id}/edit`}><Icons.edit size={18} />Edit sale</Link>}
        {sale.status === 'cancelled' ? <Status>Cancelled</Status>
          : Number(sale.balance) > 0 ? <Status tone="warning">Buyer owes {tzs(sale.balance)}</Status> : <Status tone="positive">Paid in full</Status>}
      </div>
    </div>

    <div className={`workspace ${styles.saleDetailWorkspace}`}>
      {created && <div className="notice" role="status">Sale saved.</div>}
      {updated && <div className="notice" role="status">Sale changes saved.</div>}
      {sale.status === 'cancelled' && <Notice>Cancelled {dateTime(sale.cancelled_at)}: {sale.cancel_reason}</Notice>}

      <div className={styles.saleDetailGrid}>
        <div className={styles.saleDetailColumn}>
          <section className={styles.saleDetailCard}>
            <header className={styles.saleCardHeader}><span><Icons.users size={22} /></span><h2>Buyer details</h2></header>
            <dl className={styles.saleDefinition}>
              <div><dt>Buyer</dt><dd><Link href={`/buyers/${sale.buyer_profile_id}`}>{sale.buyer_name}</Link></dd></div>
              <div><dt>Phone</dt><dd>{phone(sale.buyer_phone)}</dd></div>
              <div><dt>Notes</dt><dd>{sale.notes || '—'}</dd></div>
            </dl>
          </section>

          <section className={styles.saleDetailCard}>
            <header className={styles.saleCardHeader}><span><Icons.box size={22} /></span><h2>Items in this sale</h2></header>
            <div className={styles.saleItemsTable}>
              <table>
                <thead><tr><th>Item</th><th>Qty</th><th>Price</th><th>Total</th><th>From (supplier)</th></tr></thead>
                <tbody>{sale.items.map((item) => {
                  const supplier = item.supplier_name || payables.find((debt) => debt.supplier_id === item.supplier_id)?.party_name || 'Supplier';
                  return <tr key={item.id}>
                    <td><div className={styles.saleProduct}>{item.category
                      ? <span style={{ backgroundImage: `url(${categoryImage(item.category)})` }} />
                      : <span className={styles.saleProductFallback}><Icons.box size={20} /></span>}
                      <div><b>{item.category ? category(item.category) : item.description}</b>{item.category && item.description && <small>{item.description}</small>}</div></div></td>
                    <td>{quantity(item.quantity)} {unitLabel(item.unit)}</td>
                    <td>{tzs(item.unit_price)}</td>
                    <td><b>{tzs(item.subtotal)}</b></td>
                    <td>{item.supplier_collection_id ? <><Link href={`/supplier-collections/${item.supplier_collection_id}`}>Received batch stock</Link><small>{supplier} · cost {tzs(item.unit_cost)} each</small></>
                      : item.lpo_line_id ? <>LPO stock<small>cost {tzs(item.unit_cost)} each</small></>
                      : item.unit_cost ? <>{supplier}<small>cost {tzs(item.unit_cost)} each</small></> : 'Own stock'}</td>
                  </tr>;
                })}</tbody>
              </table>
            </div>
          </section>

          <section className={`${styles.saleDetailCard} ${styles.saleSummaryCard}`}>
            <header className={styles.saleCardHeader}><span><Icons.chart size={22} /></span><h2>Sale summary</h2></header>
            <dl>
              <div><dt>Sale total</dt><dd>{tzs(sale.total_amount)}</dd></div>
              <div><dt>Stock buying cost</dt><dd>{tzs(sale.cost_amount)}</dd></div>
              <div><dt>Margin before expenses</dt><dd>{tzs(sale.margin)}</dd></div>
            </dl>
            {sale.status === 'active' && <Link className={styles.expenseLink} href={`/finance/expenses?sale_id=${sale.id}`}>View expenses for this sale</Link>}
          </section>
        </div>

        <div className={styles.saleDetailColumn}>
          {receivable && <section className={styles.saleDetailCard}>
            <header className={styles.saleCardHeader}><span><Icons.card size={22} /></span><h2>Buyer payments</h2></header>
            <DebtSummary debt={receivable} />
            <div className={styles.salePayments}><PaymentsTable payments={receivable.payments} admin={admin} direction="receivable" /></div>
            {sale.status === 'active' && <PaymentForm debt={receivable} today={today()} saleId={sale.id} />}
          </section>}

          {payables.map((debt) => <section key={debt.id} className={styles.saleDetailCard}>
            <header className={styles.saleCardHeader}><span><Icons.card size={22} /></span><h2>I owe {debt.party_name}</h2><Status tone={debtTone(debt)}>{debtStatus(debt)}</Status></header>
            <p className={styles.saleDebtMeta}><PartyLink debt={debt} /> · {debt.description} · <Link href={`/finance/debts/${debt.id}`}>review / reconcile</Link></p>
            <DebtSummary debt={debt} />
            <div className={styles.salePayments}><PaymentsTable payments={debt.payments} admin={admin} direction="payable" supplier={Boolean(debt.supplier_id)} /></div>
            {sale.status === 'active' && <PaymentForm debt={debt} today={today()} saleId={sale.id} />}
          </section>)}
        </div>
      </div>

      {admin && sale.status === 'active' && <section className={`${styles.saleDetailCard} ${styles.cancelSaleCard}`}>
        <header className={styles.saleCardHeader}><h2>Cancel sale</h2></header>
        {anyPaid ? <p className="small muted">Reverse recorded payments before cancelling this sale.</p>
          : <ActionForm action={cancelSale} label="Cancel sale" variant="danger"
              confirm="Cancel this sale? Its debts are cancelled too. It stays in the history."
              hidden={{ sale_id: sale.id, idempotency_key: randomUUID() }}>
              <div className="field"><label htmlFor="reason">Reason</label><input id="reason" name="reason" className="input" required minLength={3} /></div>
            </ActionForm>}
      </section>}
    </div>
  </div>;
}
