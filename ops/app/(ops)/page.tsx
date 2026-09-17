import Link from 'next/link';
import { Card, Notice, PageHeader } from '@/components/ui';
import { get, ApiError } from '@/lib/api';
import { tzs } from '@/lib/format';
import type { Summary } from '@/lib/types';

export const metadata = { title: 'Dashboard · Omoterra Operations' };

const ATTENTION: { key: keyof Summary['attention']; label: string; href: string }[] = [
  { key: 'listings_pending_review', label: 'Listings awaiting approval', href: '/supply?tab=pending_review' },
  { key: 'listings_needing_confirmation', label: 'Listings needing supplier confirmation', href: '/supply?tab=needs_confirmation' },
  { key: 'sourcing_unmatched', label: 'Sourcing requests not yet matched', href: '/sourcing' },
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
