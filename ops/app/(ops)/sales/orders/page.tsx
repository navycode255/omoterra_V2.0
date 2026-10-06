import Link from 'next/link';
import { Notice, PageHeader } from '@/components/ui';
import { Icons } from '@/components/icons';
import { InfoTip } from '@/components/info-tip';
import { SearchBox } from '@/components/list-toolbar';
import { ListFooter } from '@/components/finance/list-footer';
import ui from '@/components/finance/expenses.module.css';
import styles from '@/components/finance/finance-list.module.css';
import own from '@/components/finance/buyer-orders.module.css';
import { ApiError, get } from '@/lib/api';
import type { BuyerOrder, BuyerOrderSummary } from '@/lib/buyer-orders';
import { day } from '@/lib/finance';
import { phone, tzs } from '@/lib/format';
import { listPath, param, type ListParams, type Page } from '@/lib/paging';

export const metadata = { title: 'Buyer orders · Omoterra Operations' };

// Orders staff took for buyers by phone or in person (build plan M2.5):
// commitments until delivered, never sales or debts before that.
const tabs = [['', 'All'], ['open', 'Not delivered'], ['delivered', 'Delivered'], ['cancelled', 'Cancelled']];
const STATUS = { open: 'Not delivered', delivered: 'Delivered', cancelled: 'Cancelled' } as const;
const orders = (n: number) => `${n} ${n === 1 ? 'order' : 'orders'}`;

export default async function BuyerOrders({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let data: Page<BuyerOrder> & { summary: BuyerOrderSummary };
  try {
    data = await get<Page<BuyerOrder> & { summary: BuyerOrderSummary }>(listPath('/ops/buyer-orders', params, ['buyer_profile_id']));
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Buyer orders" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Orders could not be loaded.'}</Notice></div></>;
  }
  const status = param(params, 'status');
  const total = data.summary;
  function href(change: Record<string, string>) {
    const query = new URLSearchParams();
    for (const key of ['q', 'status', 'page_size', 'page', 'buyer_profile_id']) { const value = param(params, key); if (value) query.set(key, value); }
    for (const [key, value] of Object.entries(change)) { if (value) query.set(key, value); else query.delete(key); }
    return `/sales/orders${query.size ? `?${query}` : ''}`;
  }

  return <div className={`${ui.workspace} ${styles.page}`} data-buyer-orders>
    <div className={ui.heading}><h1>Buyer orders</h1>
      <div className={own.actions}>
        <Link href="/sales" className={ui.secondary}>Sales</Link>
        <Link href="/sales/orders/new" className={ui.primary}><Icons.plus size={19} />New order</Link>
      </div>
    </div>

    <section className={styles.stats} data-count="4" aria-label="Orders not delivered">
      <article className={styles.stat} data-tone="in"><span className={styles.statIcon}><Icons.file size={26} /></span>
        <div><span>Not delivered</span><strong>{tzs(total.total)}</strong><small>{orders(total.count)}</small></div>
        <span className={styles.statInfo}><InfoTip label="About orders not delivered">Orders taken for buyers that are not delivered yet. They are not sales and nobody owes anything for them until they are marked delivered.</InfoTip></span></article>
      <article className={styles.stat} data-tone="in"><span className={styles.statIcon}><Icons.wallet size={26} /></span>
        <div><span>Deposits held</span><strong>{tzs(total.deposits)}</strong><small>Money in, held for buyers</small></div></article>
      <article className={styles.stat} data-tone="late"><span className={styles.statIcon}><Icons.users size={26} /></span>
        <div><span>Due on delivery</span><strong>{tzs(String(Number(total.total) - Number(total.deposits)))}</strong><small>Total less deposits</small></div></article>
      <article className={styles.stat} data-tone="late"><span className={styles.statIcon}><Icons.calendar size={26} /></span>
        <div><span>Past expected day</span><strong>{total.overdue}</strong><small>{orders(total.overdue)} late</small></div></article>
    </section>

    <nav className={styles.tabs} aria-label="Order status">
      {tabs.map(([key, label]) => <Link key={key} href={href({ status: key, page: '' })} data-active={status === key} aria-current={status === key ? 'page' : undefined}>
        {label}<span>{data.counts?.[key || 'all'] ?? ''}</span>
      </Link>)}
    </nav>

    <div className={styles.toolbar} role="search">
      <SearchBox placeholder="Search order number, buyer, phone or product…" />
    </div>

    <div className={styles.tableWrap}>
      <table className={styles.table} data-buyer-orders-table>
        <thead><tr><th>Order</th><th>Buyer</th><th>What</th><th>Total (TZS)</th><th>Deposit (TZS)</th><th>Expected</th><th>Status</th><th aria-label="Open" /></tr></thead>
        <tbody>{data.items.map((order) => <tr key={order.id}>
          <td data-label="Order"><div><Link className={styles.name} href={`/sales/orders/${order.id}`}>{order.order_number}</Link><small>Ordered {day(order.ordered_on)}</small></div></td>
          <td data-label="Buyer"><div><span>{order.buyer_name}</span><small>{order.buyer_phone ? phone(order.buyer_phone) : '—'}</small></div></td>
          <td data-label="What">{order.summary || '—'}</td>
          <td data-label="Total" className={styles.balance}>{tzs(order.total_amount)}</td>
          <td data-label="Deposit" className={styles.money}>{tzs(order.deposit_held)}</td>
          <td data-label="Expected">{order.status === 'delivered' ? `Delivered ${day(order.delivered_on)}` : order.expected_on
            ? <span className={order.overdue ? own.late : undefined}>{day(order.expected_on)}</span> : '—'}</td>
          <td data-label="Status"><span className={styles.status} data-tone={order.status === 'open' ? 'open' : order.status === 'delivered' ? 'settled' : 'cancelled'}>{STATUS[order.status]}</span></td>
          <td className={styles.more}><Link href={`/sales/orders/${order.id}`} className={styles.rowLink} aria-label={`Open ${order.order_number}`}><Icons.chevron size={18} /></Link></td>
        </tr>)}</tbody>
      </table>
      {!data.items.length && <div className={styles.empty}><Icons.file size={38} /><h2>No orders in this view.</h2><p>Try another tab, or <Link href="/sales/orders/new">record an order</Link>.</p></div>}
    </div>

    <ListFooter data={data} label="Order" href={(page) => href({ page: String(page) })} />
  </div>;
}
