import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { SaleDialog } from '@/components/finance/sale-dialog';
import { Icons } from '@/components/icons';
import { Notice, PageHeader, Status } from '@/components/ui';
import { DebtSummary, PartyLink, PaymentForm, PaymentsTable, debtStatus, debtTone } from '@/components/finance/ledger';
import { ExpenseWorkspace } from '@/components/finance/expense-workspace';
import { CostResolution } from '@/components/finance/cost-resolution';
import costStyles from '@/components/finance/cost-states.module.css';
import { StockSourceStatus } from '@/components/finance/stock-source';
import sourceStyles from '@/components/finance/stock-source.module.css';
import { categoryImage } from '@/components/portal/supplier-format';
import { ApiError, get } from '@/lib/api';
import { cancelSale } from '@/lib/finance-actions';
import { GOODS_OUTCOMES, UNITS, day, today, type OpeningStock, type SaleDetail } from '@/lib/finance';
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
  // Unknown buying costs (rule R5): no final margin; an admin gives each a cost.
  const unknownLines = sale.items.filter((item) => item.cost_state === 'unknown');
  const openingStock = admin && sale.status === 'active' && unknownLines.length
    ? await get<OpeningStock[]>('/ops/opening-stock/available').catch(() => []) : [];
  const receivable = sale.debts.find((debt) => debt.direction === 'receivable');
  const payables = sale.debts.filter((debt) => debt.direction === 'payable' && debt.status !== 'cancelled');
  const expenseTotal = payables.filter((debt) => debt.source === 'expense').reduce((total, debt) => total + Number(debt.amount), 0);
  const anyPaid = sale.debts.some((debt) => Number(debt.paid_amount) > 0);
  // Received goods (delivery note or LPO): cancelling asks what happened to them (rule R2).
  const received = sale.items.filter((item) => item.location_allocation_id || item.supplier_collection_id || item.lpo_line_id || item.opening_stock_id);
  const goodsLabel = GOODS_OUTCOMES.find(([id]) => id === sale.cancel_goods)?.[1];
  const unitLabel = (value: string) => UNITS.find(([key]) => key === value)?.[1].toLowerCase() ?? value;

  return <div className={styles.saleDetailPage}>
    <div className={`topbar ${styles.saleDetailTopbar}`}>
      <div>
        <nav className={styles.saleBreadcrumb} aria-label="Breadcrumb"><Link href="/sales">Sales</Link><span>›</span><span>Sale {sale.sale_number}</span></nav>
        <PageHeader title={`Sale ${sale.sale_number}`}
          subtitle={`Sold ${day(sale.sold_on)} · entered ${dateTime(sale.created_at)} by ${sale.created_by ?? '—'}`} />
        {sale.buyer_order && <p className="small muted" data-from-order>Delivered from buyer order{' '}
          <Link href={`/sales/orders/${sale.buyer_order.id}`}>{sale.buyer_order.order_number}</Link> (ordered {day(sale.buyer_order.ordered_on)})</p>}
      </div>
      <div className={styles.saleDetailActions}>
        {admin && sale.status === 'active' && <SaleDialog label="More actions" title="Cancel sale">
        {anyPaid ? <p className="small muted">Reverse recorded payments before cancelling this sale.</p>
          : <ActionForm action={cancelSale} label="Cancel sale" variant="danger"
              confirm="Cancel this sale? Its own debts are cancelled too. It stays in the history."
              hidden={{ sale_id: sale.id, idempotency_key: randomUUID() }}>
              <div className="field"><label htmlFor="reason">Reason</label><input id="reason" name="reason" className="input" required minLength={3} /></div>
              {received.length > 0 && <fieldset className="field">
                <legend>What happened to the received goods ({received.map((item) => `${quantity(item.quantity)} ${unitLabel(item.unit)}`).join(', ')})?</legend>
                {GOODS_OUTCOMES.map(([id, label]) => <label key={id} className="row"><input type="radio" name="goods" value={id} required />{label}</label>)}
                <label htmlFor="goods-note">Condition of returned goods (if returned)</label>
                <input id="goods-note" name="goods_note" className="input" placeholder="e.g. All alive, checked by Juma" />
                <span className="meta">The delivery note or LPO and what is owed to the supplier do not change. To reduce what was received, correct the delivery note.</span>
              </fieldset>}
            </ActionForm>}
        </SaleDialog>}
        {sale.status === 'active' && !sale.items.some(i => i.location_allocation_id) && <Link className={styles.editSaleButton} href={`/sales/${sale.id}/edit`}><Icons.edit size={18} />Edit sale</Link>}
        {sale.status === 'cancelled' ? <Status>Cancelled</Status>
          : Number(sale.balance) > 0 ? <Status tone="warning">Buyer owes {tzs(sale.balance)}</Status> : <Status tone="positive">Paid in full</Status>}
      </div>
    </div>

    <div className={`workspace ${styles.saleDetailWorkspace}`}>
      {created && <div className="notice" role="status">Sale saved.</div>}
      {updated && <div className="notice" role="status">Sale changes saved.</div>}
      {sale.status === 'cancelled' && <Notice>Cancelled {dateTime(sale.cancelled_at)}: {sale.cancel_reason}{goodsLabel ? ` · Received goods: ${goodsLabel.split(':')[0].toLowerCase()}.` : ''}</Notice>}

      <div className={styles.saleDetailGrid}>
        <div className={styles.saleDetailColumn}>
          <section className={styles.saleDetailCard}>
            <header className={styles.saleCardHeader}><span><Icons.users size={22} /></span><h2>Buyer details</h2></header>
            <dl className={styles.saleDefinition}>
              {sale.location_id && <div><dt>Location</dt><dd><Link href={`/locations/${sale.location_id}`}>View kitchen / location</Link></dd></div>}
              <div><dt>Buyer</dt><dd><Link href={`/buyers/${sale.buyer_profile_id}`}>{sale.buyer_name}</Link></dd></div>
              <div><dt>Phone</dt><dd>{phone(sale.buyer_phone)}</dd></div>
              <div><dt>Notes</dt><dd>{sale.notes || '—'}</dd></div>
            </dl>
          </section>

          <section className={styles.saleDetailCard}>
            <header className={styles.saleCardHeader}><span><Icons.box size={22} /></span><h2>Items in this sale</h2></header>
            <div className={styles.saleItemsTable}>
              <table data-phone-native>
                <thead><tr><th>Item</th><th>Qty</th><th>Price</th><th>Total</th><th>From (supplier)</th></tr></thead>
                <tbody>{sale.items.map((item) => {
                  const supplier = item.supplier_name || payables.find((debt) => debt.supplier_id === item.supplier_id)?.party_name || 'Supplier';
                  return <tr key={item.id}>
                    <td data-label="Item"><div className={styles.saleProduct}>{item.category
                      ? <span style={{ backgroundImage: `url(${categoryImage(item.category)})` }} />
                      : <span className={styles.saleProductFallback}><Icons.box size={20} /></span>}
                      <div><b>{item.category ? category(item.category) : item.description}</b>{item.category && item.description && <small>{item.description}</small>}</div></div></td>
                    <td data-label="Quantity">{quantity(item.quantity)} {unitLabel(item.unit)}</td>
                    <td data-label="Price">{tzs(item.unit_price)}</td>
                    <td data-label="Total"><b>{tzs(item.subtotal)}</b></td>
                    <td data-label="Stock source">{item.supplier_collection_id ? <><Link href={`/supplier-collections/${item.supplier_collection_id}`}>Delivery note</Link><small>{supplier} · cost {tzs(item.unit_cost)} each</small></>
                      : item.lpo_line_id ? <>LPO stock<small>cost {tzs(item.unit_cost)} each</small></>
                      : item.location_allocation_id ? <><Link href={`/locations/${sale.location_id}`}>Location stock</Link><small>cost {item.cost_state === 'unknown' ? 'unknown' : `${tzs(item.unit_cost)} each`}</small></>
                      : item.opening_stock_id ? <><Link href={`/finance/opening-stock?q=${item.opening_stock_number ?? ''}`}>Opening stock {item.opening_stock_number}</Link><small>cost {tzs(item.unit_cost)} each</small></>
                      : item.cost_state === 'unknown' ? <>{item.supplier_name || item.supplier_id ? supplier : 'Own stock'}<small className={costStyles.unknown}>Cost unknown</small></>
                      : item.cost_state === 'free' ? <>{item.supplier_name || item.supplier_id ? supplier : 'Own stock'}<small className={costStyles.free}>Free (no cost)</small></>
                      : item.supplier_name || item.supplier_id ? <>{supplier}<small>cost {tzs(item.unit_cost)} each</small></> : <>Own stock<small>cost {tzs(item.unit_cost)} each</small></>}
                      {item.stock_source && <StockSourceStatus source={item.stock_source} />}</td>
                  </tr>;
                })}</tbody>
              </table>
            </div>
            {sale.items.some((item) => item.stock_source && item.stock_source.kind !== 'opening_stock') && <p className={sourceStyles.note}>
              The supplier payment status of received stock is for information: what is owed for it belongs to its delivery note or LPO, not to this sale.</p>}
            {unknownLines.length > 0 && <p className={costStyles.provisionalNote} role="note">
              {unknownLines.length === 1 ? 'One line has' : `${unknownLines.length} lines have`} an unknown buying cost, so this sale&apos;s margin is provisional.
              {admin && sale.status === 'active' ? ' Give each line its cost below.' : ' An admin gives each line its cost.'}</p>}
            {admin && sale.status === 'active' && unknownLines.map((item) => <div key={item.id}>
              <strong>{item.category ? category(item.category) : item.description} · {quantity(item.quantity)} {unitLabel(item.unit)}</strong>
              <CostResolution saleId={sale.id} itemId={item.id} unit={item.unit} quantity={item.quantity}
                openingStock={openingStock} idempotencyKey={randomUUID()} />
            </div>)}
          </section>

          <section className={`${styles.saleDetailCard} ${styles.saleSummaryCard}`}>
            <header className={styles.saleCardHeader}><span><Icons.chart size={22} /></span><h2>Sale summary</h2></header>
            <dl>
              <div><dt>Sale total</dt><dd>{tzs(sale.total_amount)}</dd></div>
              <div><dt>Stock buying cost</dt><dd>{sale.margin === null
                ? <span className={costStyles.lineCost}>{tzs(sale.cost_amount)} known<small className={costStyles.unknown}>{sale.unknown_cost_lines} {sale.unknown_cost_lines === 1 ? 'line' : 'lines'}: cost unknown</small></span>
                : tzs(sale.cost_amount)}</dd></div>
              <div><dt>Margin before expenses</dt><dd>{sale.margin === null ? <span className={costStyles.unknown}>Provisional: cost unknown</span> : tzs(sale.margin)}</dd></div>
              <div><dt>Sale expenses (paid or owed)</dt><dd>{tzs(String(expenseTotal))}</dd></div>
              <div><dt>Margin after sale expenses</dt><dd>{sale.margin === null ? <span className={costStyles.unknown}>Provisional: cost unknown</span> : tzs(String(Number(sale.margin) - expenseTotal))}</dd></div>
            </dl>
            {sale.status === 'active' && <ExpenseWorkspace now={today()} saleId={sale.id} saleNumber={String(sale.sale_number)}/>}
            <Link className={styles.expenseLink} href={`/finance/expenses?sale_id=${sale.id}`}>View expenses for this sale</Link>
          </section>
        </div>

        <div className={styles.saleDetailColumn}>
          {receivable && <section className={styles.saleDetailCard}>
            <header className={styles.saleCardHeader}><span><Icons.card size={22} /></span><h2>Buyer payments</h2></header>
            <DebtSummary debt={receivable} />
            <div className={styles.salePayments}><PaymentsTable payments={receivable.payments} admin={admin} direction="receivable" /></div>
            {sale.status === 'active' && <SaleDialog label="Record buyer payment" title="Buyer payment"><PaymentForm debt={receivable} today={today()} saleId={sale.id}/></SaleDialog>}
          </section>}

          {payables.map((debt) => <section key={debt.id} className={styles.saleDetailCard}>
            <header className={styles.saleCardHeader}><span><Icons.card size={22} /></span><h2>I owe {debt.party_name}</h2><Status tone={debtTone(debt)}>{debtStatus(debt)}</Status></header>
            <p className={styles.saleDebtMeta}><PartyLink debt={debt} /> · {debt.description} · <Link href={`/finance/debts/${debt.id}`}>review / reconcile</Link></p>
            <DebtSummary debt={debt} />
            <div className={styles.salePayments}><PaymentsTable payments={debt.payments} admin={admin} direction="payable" supplier={Boolean(debt.supplier_id)} /></div>
            {sale.status === 'active' && <SaleDialog label="Record supplier payment" title={`Payment to ${debt.party_name}`}><PaymentForm debt={debt} today={today()} saleId={sale.id}/></SaleDialog>}
          </section>)}
        </div>
      </div>


    </div>
  </div>;
}
