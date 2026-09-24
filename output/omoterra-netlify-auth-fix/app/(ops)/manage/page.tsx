import Link from 'next/link';
import { Card, Notice, PageHeader } from '@/components/ui';
import { get, ApiError } from '@/lib/api';
import { tzs } from '@/lib/format';
import type { Summary } from '@/lib/types';

export const metadata = { title: 'Dashboard · Omoterra Operations' };

const ATTENTION: { key: keyof Summary['attention']; label: string; href: string }[] = [
  { key: 'listings_pending_review', label: 'Listings awaiting approval', href: '/supply?tab=pending_review' },
  { key: 'listings_needing_confirmation', label: 'Listings needing supplier confirmation', href: '/supply?tab=needs_confirmation' },
  { key: 'demand_no_matching_supply', label: 'Demand without matching supply', href: '/sourcing' },
  { key: 'partially_secured_near_deadline', label: 'Partially secured demand near deadline', href: '/sourcing?status=partially_matched' },
  { key: 'batches_ready_unallocated', label: 'Supply ready without allocation', href: '/batches' },
  { key: 'reservations_awaiting_confirmation', label: 'Reservations awaiting confirmation', href: '/sourcing' },
  { key: 'verification_overdue', label: 'Batch verification overdue', href: '/batches?status=pending_review' },
  { key: 'orders_in_progress', label: 'Orders in progress', href: '/orders' },
  { key: 'payments_pending', label: 'Buyer payments outstanding', href: '/payments' },
  { key: 'settlements_pending', label: 'Supplier payouts pending', href: '/settlements' },
];

export default async function Dashboard() {
  let summary: Summary;
  try {
    summary = await get<Summary>('/ops/summary');
  } catch (error) {
    return (
      <>
        <div className="topbar">
          <PageHeader title="Dashboard" />
        </div>
        <div className="workspace">
          <Notice tone="error">
            {error instanceof ApiError ? error.message : 'The dashboard could not be loaded.'}
          </Notice>
        </div>
      </>
    );
  }

  const stats = [
    { label: 'Orders today', value: String(summary.orders_today) },
    { label: 'Sales today', value: tzs(summary.sales_today) },
    { label: 'Gross margin today', value: tzs(summary.gross_margin_today) },
    { label: 'Pending settlements', value: tzs(summary.pending_settlements) },
  ];

  const attention = ATTENTION.map((row) => ({ ...row, count: summary.attention[row.key] }));
  const outstanding = attention.filter((row) => row.count > 0);

  return (
    <>
      <div className="topbar">
        <PageHeader title="Dashboard" subtitle="Today's trading position and what needs action." />
      </div>
      <div className="workspace">
        <div className="stat-band">
          {[
            { label: 'Active buyer demand', value: String(summary.demand_metrics.active_buyer_demand) },
            { label: 'Quantity demanded', value: summary.demand_metrics.total_quantity_demanded },
            { label: 'Expected supplier quantity', value: summary.demand_metrics.expected_supplier_quantity },
            { label: 'Commercially reserved', value: summary.demand_metrics.commercially_reserved_quantity },
            { label: 'Supply ready soon', value: String(summary.demand_metrics.supply_ready_soon) },
            { label: 'Ready for collection', value: String(summary.demand_metrics.ready_for_collection) },
          ].map((stat) => (
            <div key={stat.label} className="stat">
              <div className="stat-label">{stat.label}</div>
              <div className="stat-value numeric">{stat.value}</div>
            </div>
          ))}
        </div>
        <div className="stat-band">
          {stats.map((stat) => (
            <div key={stat.label} className="stat">
              <div className="stat-label">{stat.label}</div>
              <div className="stat-value numeric">{stat.value}</div>
            </div>
          ))}
        </div>

        <Card title="Needs attention">
          {outstanding.length === 0 ? (
            <p className="muted">Nothing is waiting. All supply, orders and payments are up to date.</p>
          ) : (
            <div className="stack" style={{ gap: 0 }}>
              {outstanding.map((row) => (
                <Link
                  key={row.key}
                  href={row.href}
                  className="between"
                  style={{
                    padding: 'var(--s4) 0',
                    borderBottom: '1px solid var(--border)',
                  }}
                >
                  <span>{row.label}</span>
                  <span className="strong numeric">{row.count}</span>
                </Link>
              ))}
            </div>
          )}
        </Card>
      </div>
    </>
  );
}
