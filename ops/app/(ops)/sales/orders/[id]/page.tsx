import Link from 'next/link';
import { randomUUID } from 'node:crypto';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { Icons } from '@/components/icons';
import { Notice, PageHeader } from '@/components/ui';
import { AccountSelect } from '@/components/finance/account-select';
import ui from '@/components/finance/expenses.module.css';
import styles from '@/components/finance/finance-list.module.css';
import own from '@/components/finance/buyer-orders.module.css';
import { ApiError, get } from '@/lib/api';
import { cancelBuyerOrder, recordOrderDeposit, refundOrderDeposit, voidOrderDeposit } from '@/lib/buyer-order-actions';
import type { BuyerOrderDetail, BuyerOrderPayment } from '@/lib/buyer-orders';
import { METHODS, PRODUCTS, UNITS, day, today } from '@/lib/finance';
import { phone, tzs } from '@/lib/format';

export const metadata = { title: 'Buyer order · Omoterra Operations' };

const STATUS = { open: 'Not delivered', delivered: 'Delivered', cancelled: 'Cancelled' } as const;
const STATE: Record<BuyerOrderPayment['state'], string> = { held: 'Held', applied: 'Applied to the sale', given_back: 'Given back', voided: 'Voided' };
const label = (list: [string, string][], id: string) => list.find(([key]) => key === id)?.[1] ?? id;

function MethodFields({ prefix, date }: { prefix: string; date: string }) {
  return <div className="grid-2">
    <div className="field"><label htmlFor={`${prefix}-method`}>Method</label>
      <select id={`${prefix}-method`} name="method" className="input" defaultValue="cash">
        {METHODS.map(([id, text]) => <option key={id} value={id}>{text}</option>)}</select></div>
    <AccountSelect id={`${prefix}-account`} label="Account" />
    <div className="field"><label htmlFor={`${prefix}-reference`}>Transaction reference</label>
      <input id={`${prefix}-reference`} name="reference" className="input" placeholder="e.g. M-Pesa code" /></div>
    <div className="field"><label htmlFor={`${prefix}-on`}>Date</label>
      <input id={`${prefix}-on`} name="paid_on" type="date" className="input" defaultValue={date} max={date} required /></div>
  </div>;
}

export default async function BuyerOrderPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<Record<string, string | undefined>> }) {
  const { id } = await params;
  const query = await searchParams;
  let order: BuyerOrderDetail;
  try {
    order = await get<BuyerOrderDetail>(`/ops/buyer-orders/${encodeURIComponent(id)}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    return <><div className="topbar"><PageHeader title="Buyer order" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'The order could not be loaded.'}</Notice></div></>;
  }
  const open = order.status === 'open';
  const now = today();
  const due = Number(order.total_amount) - Number(order.deposit_held);

  return <div className={`${ui.workspace} ${styles.page}`} data-buyer-order={order.order_number}>
    <div className={ui.heading}>
      <h1>{order.order_number}</h1>
      <div className={own.actions}>
        {open && <Link href={`/sales/orders/${order.id}/edit`} className={ui.secondary}>Edit</Link>}
        {open && <Link href={`/sales/orders/${order.id}/deliver`} className={ui.primary}><Icons.truck size={19} />Mark delivered</Link>}
        {order.sale_id && <Link href={`/sales/${order.sale_id}`} className={ui.primary}>Open sale {order.sale_number}</Link>}
      </div>
    </div>
    {query.created && <Notice>Order saved. It is not a sale until you mark it delivered.</Notice>}
    {query.updated && <Notice>Order updated.</Notice>}
    {open && <p className={own.note} role="note">Not delivered yet: not a sale, the buyer owes nothing and no stock is taken.
      {Number(order.deposit_held) > 0 && ` The deposit of ${tzs(order.deposit_held)} is held for the buyer and goes on the sale when it is delivered.`}</p>}

    <div className={own.detail}>
      <div className={own.panel}>
        <h2>Order</h2>
        <dl className={own.facts}>
          <div><dt>Buyer</dt><dd>{order.buyer_name}</dd></div>
          <div><dt>Phone</dt><dd>{order.buyer_phone ? phone(order.buyer_phone) : '—'}</dd></div>
          <div><dt>Ordered</dt><dd>{day(order.ordered_on)}</dd></div>
          <div><dt>Expected</dt><dd className={order.overdue ? own.late : undefined}>{day(order.expected_on)}</dd></div>
          <div><dt>Status</dt><dd>{STATUS[order.status]}{order.status === 'delivered' ? ` on ${day(order.delivered_on)}` : ''}</dd></div>
          <div><dt>Recorded by</dt><dd>{order.created_by ?? '—'}</dd></div>
          {order.status === 'cancelled' && <div><dt>Cancelled because</dt><dd>{order.cancel_reason}</dd></div>}
          {order.sale_status === 'cancelled' && <div><dt>Sale</dt><dd>The sale {order.sale_number} was later cancelled</dd></div>}
          {order.notes && <div><dt>Notes</dt><dd>{order.notes}</dd></div>}
        </dl>
        <table className={own.lines} data-phone-native>
          <thead><tr><th>Product</th><th>Quantity</th><th>Price</th><th>Amount</th></tr></thead>
          <tbody>{order.items.map((item) => <tr key={item.id}>
            <td>{item.category ? label(PRODUCTS, item.category) : item.description}{item.category && item.description ? ` · ${item.description}` : ''}</td>
            <td>{Number(item.quantity)} {label(UNITS, item.unit).toLowerCase()}</td>
            <td>{tzs(item.unit_price)}</td><td>{tzs(item.subtotal)}</td>
          </tr>)}</tbody>
          <tfoot><tr><td colSpan={3}>Total</td><td>{tzs(order.total_amount)}</td></tr>
            {open && <tr><td colSpan={3}>Due on delivery</td><td>{tzs(String(due))}</td></tr>}</tfoot>
        </table>
      </div>

      <div className={own.panel}>
        <h2>Deposits</h2>
        {!order.payments.length && <p className={own.hint}>No deposit recorded.</p>}
        {order.payments.filter((p) => p.kind === 'deposit').map((p) => {
          const back = order.payments.find((r) => r.refund_of === p.id);
          return <div key={p.id} className={own.payment}>
            <header><span>{tzs(p.amount)}</span><span className={own.state} data-state={p.state}>{STATE[p.state]}</span></header>
            <small>{day(p.paid_on)} · {label(METHODS, p.method)}{p.reference ? ` · ${p.reference}` : ''}{p.account_name ? ` · ${p.account_name}` : ''}</small>
            {back && <small>Given back {day(back.paid_on)} · {label(METHODS, back.method)}{back.reference ? ` · ${back.reference}` : ''}</small>}
            {p.state === 'voided' && <small>Voided: {p.void_reason}</small>}
            {open && p.state === 'held' && <details><summary>Give it back</summary>
              <ActionForm action={refundOrderDeposit} label="Record money given back" variant="secondary"
                hidden={{ order_id: order.id, payment_id: p.id, idempotency_key: randomUUID() }}>
                <MethodFields prefix={`refund-${p.id}`} date={now} />
                <div className="field"><label htmlFor={`refund-note-${p.id}`}>Note (optional)</label><input id={`refund-note-${p.id}`} name="note" className="input" /></div>
              </ActionForm></details>}
            {open && p.state === 'held' && <details className={own.danger}><summary>Entered by mistake (admin)</summary>
              <ActionForm action={voidOrderDeposit} label="Void deposit" variant="danger" hidden={{ order_id: order.id, payment_id: p.id }}>
                <div className="field"><label htmlFor={`void-${p.id}`}>Why (the money never came)</label>
                  <input id={`void-${p.id}`} name="reason" className="input" required minLength={3} /></div>
              </ActionForm></details>}
          </div>;
        })}
        {open && <details><summary className={own.hint}>Record a deposit</summary>
          <ActionForm action={recordOrderDeposit} label="Record deposit" variant="secondary" hidden={{ order_id: order.id, idempotency_key: randomUUID() }}>
            <div className="field"><label htmlFor="deposit-amount">Amount (TZS)</label>
              <input id="deposit-amount" name="amount" className="input" inputMode="decimal" required /></div>
            <MethodFields prefix="deposit" date={now} />
          </ActionForm></details>}
        {open && <details className={own.danger}><summary>Cancel this order</summary>
          <ActionForm action={cancelBuyerOrder} label="Cancel order" variant="danger" confirm="Cancel this order?"
            hidden={{ order_id: order.id, idempotency_key: randomUUID() }}>
            <div className="field"><label htmlFor="cancel-reason">Reason</label>
              <input id="cancel-reason" name="reason" className="input" required minLength={3} placeholder="e.g. Buyer no longer needs the birds" /></div>
            {Number(order.deposit_held) > 0 && <span className="meta">Give the deposit back first.</span>}
          </ActionForm></details>}
      </div>
    </div>
    <Link href="/sales/orders" className={styles.filterReset}>← Back to buyer orders</Link>
  </div>;
}
