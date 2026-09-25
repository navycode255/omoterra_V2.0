import Link from 'next/link';
import { BatchDonut, SupplyTrendChart } from '@/components/dashboard-charts';
import { DateRangePicker, YearSelect } from '@/components/dashboard-controls';
import { Icons } from '@/components/icons';
import { Notice } from '@/components/ui';
import { get, ApiError } from '@/lib/api';
import { CUSTOMER_STATUS, date, orderTone, quantity, reference, titleCase, tzs } from '@/lib/format';
import type { Dashboard as DashboardData, DashboardActivity, Summary } from '@/lib/types';

export const metadata = { title: 'Dashboard · Omoterra Operations' };

const ATTENTION: { key: keyof Summary['attention']; label: string; href: string }[] = [
  { key: 'listings_pending_review', label: 'Listings awaiting approval', href: '/supply?tab=pending_review' },
  { key: 'listings_needing_confirmation', label: 'Listings needing supplier confirmation', href: '/supply?tab=needs_confirmation' },
  { key: 'demand_no_matching_supply', label: 'Demand without matching supply', href: '/sourcing' },
  { key: 'partially_secured_near_deadline', label: 'Partially secured demand near deadline', href: '/sourcing?status=partially_matched' },
  { key: 'batches_ready_unallocated', label: 'Supply ready without allocation', href: '/batches' },
  { key: 'reservations_awaiting_confirmation', label: 'Reservations awaiting confirmation', href: '/sourcing' },
  { key: 'verification_overdue', label: 'Batch verification overdue', href: '/batches?status=pending_review' },
  { key: 'payments_pending', label: 'Buyer payments outstanding', href: '/payments' },
  { key: 'settlements_pending', label: 'Supplier payouts pending', href: '/settlements' },
];

const ACTIVITY_ICON: Record<DashboardActivity['kind'], { icon: typeof Icons.users; tone: string }> = {
  supplier_registered: { icon: Icons.users, tone: 'green' },
  supplier_approved: { icon: Icons.checkCircle, tone: 'green' },
  supplier_suspended: { icon: Icons.alert, tone: 'red' },
  supplier_status: { icon: Icons.clock, tone: 'amber' },
  order_created: { icon: Icons.file, tone: 'green' },
  batch_created: { icon: Icons.box, tone: 'green' },
  stock_submitted: { icon: Icons.box, tone: 'green' },
  settlement_paid: { icon: Icons.card, tone: 'green' },
};

const SUPPLIER_STATUS_TONE: Record<string, string> = { approved: 'green', under_review: 'amber', new: 'amber', rejected: 'red', suspended: 'red' };

const DAY = /^\d{4}-\d{2}-\d{2}$/;

function todayInTanzania() {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Dar_es_Salaam' }).format(new Date());
}

function clock(value: string) {
  return new Date(value).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: 'Africa/Dar_es_Salaam' });
}

function sentence(value: string) {
  const text = value.replace(/_/g, ' ');
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function Panel({ icon, title, subtitle, action, className = '', children }: { icon: React.ReactNode; title: string; subtitle?: string; action?: React.ReactNode; className?: string; children: React.ReactNode }) {
  return <section className={`dash-panel ${className}`}>
    <header className="dash-panel-head">
      <span className="dash-panel-icon">{icon}</span>
      <div><h2>{title}</h2>{subtitle && <p>{subtitle}</p>}</div>
      {action && <div className="dash-panel-action">{action}</div>}
    </header>
    {children}
  </section>;
}

function EmptyState({ icon, title, text }: { icon: React.ReactNode; title: string; text: string }) {
  return <div className="dash-empty">{icon}<strong>{title}</strong><span>{text}</span></div>;
}

export default async function Dashboard({ searchParams }: { searchParams: Promise<{ from?: string; to?: string; year?: string }> }) {
  const query = await searchParams;
  const today = todayInTanzania();
  const from = query.from && DAY.test(query.from) ? query.from : today.slice(0, 8) + '01';
  const to = query.to && DAY.test(query.to) && query.to >= from ? query.to : today;
  const currentYear = Number(today.slice(0, 4));
  const year = Number(query.year) >= 2020 && Number(query.year) <= currentYear ? Number(query.year) : currentYear;

  const [summaryResult, dashboardResult] = await Promise.allSettled([
    get<Summary>('/ops/summary'),
    get<DashboardData>(`/ops/dashboard?start=${from}&end=${to}&year=${year}`),
  ]);

  const header = (picker: React.ReactNode) => <div className="dash-head">
    <div><h1>Dashboard</h1><p>Overview of key activities across the Omoterra operations.</p></div>
    {picker}
  </div>;

  if (summaryResult.status === 'rejected' || dashboardResult.status === 'rejected') {
    const error = summaryResult.status === 'rejected' ? summaryResult.reason : (dashboardResult as PromiseRejectedResult).reason;
    const outdatedApi = dashboardResult.status === 'rejected' && dashboardResult.reason instanceof ApiError && dashboardResult.reason.status === 404;
    return <>
      {header(null)}
      <div className="workspace">
        <Notice tone="error">{outdatedApi
          ? 'The dashboard needs the latest Omoterra API. Deploy the current backend and try again.'
          : error instanceof ApiError ? error.message : 'The dashboard could not be loaded.'}</Notice>
      </div>
    </>;
  }

  const summary = summaryResult.value;
  const data = dashboardResult.value;
  const period = data.period;
  const attention = ATTENTION.map((row) => ({ ...row, count: summary.attention[row.key] })).filter((row) => row.count > 0);
  const years = Array.from({ length: Math.min(4, currentYear - 2025 + 1) }, (_, i) => currentYear - i);
  const kpis = [
    { href: '/suppliers', icon: <Icons.users size={30}/>, value: String(data.kpis.active_suppliers), label: 'Active suppliers', note: `${data.kpis.approved_suppliers} approved` },
    { href: '/batches', icon: <Icons.box size={30}/>, value: String(data.kpis.active_batches), label: 'Active production batches', note: `${data.batch_status.pending} awaiting review` },
    { href: '/orders', icon: <Icons.file size={30}/>, value: String(data.kpis.open_orders), label: 'Open orders', note: `${summary.demand_metrics.ready_for_collection} ready for collection` },
    { href: '/settlements', icon: <Icons.card size={30}/>, value: tzs(data.kpis.pending_settlements), label: 'Pending settlements', note: `${data.kpis.pending_settlement_count} ${data.kpis.pending_settlement_count === 1 ? 'payout' : 'payouts'} to suppliers` },
  ];
  const demand = [
    { label: 'Active buyer demand', value: String(summary.demand_metrics.active_buyer_demand) },
    { label: 'Quantity demanded', value: quantity(summary.demand_metrics.total_quantity_demanded) },
    { label: 'Expected supplier quantity', value: quantity(summary.demand_metrics.expected_supplier_quantity) },
    { label: 'Commercially reserved', value: quantity(summary.demand_metrics.commercially_reserved_quantity) },
    { label: 'Supply ready soon', value: String(summary.demand_metrics.supply_ready_soon) },
    { label: 'Unmatched demand', value: String(summary.demand_metrics.unmatched_demand) },
  ];

  return <>
    {header(<DateRangePicker start={period.start} end={period.end} today={today}/>)}
    <main className="dashboard">
      <div className="kpi-row">
        {kpis.map((kpi) => <Link key={kpi.label} href={kpi.href} className="kpi-card">
          <span className="kpi-icon">{kpi.icon}</span>
          <span className="kpi-copy"><strong>{kpi.value}</strong><span>{kpi.label}</span><small>{kpi.note}</small></span>
          <Icons.chevron size={20}/>
        </Link>)}
      </div>

      {attention.length > 0 && <section className="attention-strip" aria-label="Needs attention">
        <span className="attention-title"><Icons.alert size={18}/>Needs attention</span>
        <div>{attention.map((row) => <Link key={row.key} href={row.href}><strong>{row.count}</strong>{row.label}</Link>)}</div>
      </section>}

      <div className="dash-row dash-row-charts">
        <Panel icon={<Icons.trend size={24}/>} title="Supply trend" subtitle="Total supplies recorded per month" action={<YearSelect year={year} years={years}/>}>
          <SupplyTrendChart months={data.supply_trend.months} year={data.supply_trend.year} currentMonth={data.supply_trend.year === currentYear ? Number(today.slice(5, 7)) - 1 : null}/>
        </Panel>
        <Panel icon={<Icons.box size={24}/>} title="Production batches" subtitle="Batch status overview">
          <BatchDonut counts={data.batch_status}/>
        </Panel>
      </div>

      <div className="dash-row dash-row-lists">
        <Panel icon={<Icons.users size={24}/>} title="Recent suppliers" action={<Link href="/suppliers" className="view-all">View all</Link>} className="dash-list">
          {data.recent_suppliers.length ? <table className="dash-table">
            <thead><tr><th>Name</th><th>Region / district</th><th>Status</th><th>Joined</th></tr></thead>
            <tbody>{data.recent_suppliers.map((supplier) => <tr key={supplier.id}>
              <td><Link href={`/suppliers/${supplier.id}`} className="dash-strong">{supplier.name}</Link></td>
              <td>{[supplier.region, supplier.district].filter(Boolean).join(' · ') || '—'}</td>
              <td><span className="dash-pill" data-tone={SUPPLIER_STATUS_TONE[supplier.status] ?? 'grey'}>{sentence(supplier.status)}</span></td>
              <td className="nowrap">{date(supplier.joined_at)}</td>
            </tr>)}</tbody>
          </table> : <EmptyState icon={<Icons.users size={30}/>} title="No new suppliers" text="Suppliers who join in this period appear here."/>}
        </Panel>

        <Panel icon={<Icons.file size={24}/>} title="Recent orders" action={<Link href="/orders" className="view-all">View all</Link>} className="dash-list">
          {data.recent_orders.length ? <table className="dash-table">
            <thead><tr><th>Order #</th><th>Buyer</th><th>Status</th><th>Created</th></tr></thead>
            <tbody>{data.recent_orders.map((order) => <tr key={order.id}>
              <td><Link href={`/orders/${order.id}`} className="dash-strong">{reference(order.id, 'OR')}</Link></td>
              <td>{order.buyer}<small>{tzs(order.total_amount)}</small></td>
              <td><span className="dash-pill" data-tone={{ positive: 'green', warning: 'amber', error: 'red', neutral: 'grey' }[orderTone(order.internal_status)]} title={`Buyer sees: ${CUSTOMER_STATUS[order.internal_status]}`}>{titleCase(order.internal_status)}</span></td>
              <td className="nowrap">{date(order.created_at)}</td>
            </tr>)}</tbody>
          </table> : <EmptyState icon={<Icons.file size={30}/>} title="No orders yet" text="Orders will appear here once created."/>}
        </Panel>

        <Panel icon={<Icons.clock size={24}/>} title="Recent activity" className="dash-list">
          {data.recent_activity.length ? <ol className="activity-list">{data.recent_activity.map((item) => {
            const { icon: ActivityIcon, tone } = ACTIVITY_ICON[item.kind];
            return <li key={`${item.kind}-${item.at}-${item.href}`}><Link href={item.href}>
              <span className="activity-icon" data-tone={tone}><ActivityIcon size={20}/></span>
              <span className="activity-copy"><strong>{item.title}</strong><span>{item.detail}</span></span>
              <time dateTime={item.at}><span>{date(item.at)}</span><span>{clock(item.at)}</span></time>
            </Link></li>;
          })}</ol> : <EmptyState icon={<Icons.clock size={30}/>} title="No activity" text="Nothing happened in this period."/>}
        </Panel>
      </div>

      <div className="dash-row dash-row-metrics">
        <Panel icon={<Icons.chart size={24}/>} title="Demand and fulfilment" subtitle="Buyer demand against expected supply, right now">
          <dl className="metric-grid">{demand.map((metric) => <div key={metric.label}><dt>{metric.label}</dt><dd>{metric.value}</dd></div>)}</dl>
        </Panel>
        <Panel icon={<Icons.card size={24}/>} title="Trading" subtitle={`Orders placed ${period.start === period.end ? 'on' : 'from'} ${date(period.start)}${period.start === period.end ? '' : ` to ${date(period.end)}`}`}>
          <dl className="metric-grid metric-grid-3">
            <div><dt>Orders</dt><dd>{data.trading.orders}</dd></div>
            <div><dt>Sales</dt><dd>{tzs(data.trading.sales)}</dd></div>
            <div><dt>Gross margin</dt><dd>{tzs(data.trading.gross_margin)}</dd></div>
          </dl>
        </Panel>
      </div>
    </main>
  </>;
}
