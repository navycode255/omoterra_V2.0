'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const MODULES = [
  { href: '/manage', label: 'Dashboard', key: null },
  { href: '/supply', label: 'Supply', key: 'listings_pending_review' },
  { href: '/orders', label: 'Orders', key: 'orders_in_progress' },
  { href: '/sourcing', label: 'Buyer Demand', key: 'demand_no_matching_supply' },
  { href: '/batches', label: 'Production Batches', key: 'verification_overdue' },
  { href: '/payments', label: 'Payments', key: 'payments_pending' },
  { href: '/settlements', label: 'Settlements', key: 'settlements_pending' },
  { href: '/opportunities', label: 'Business Opportunities', key: null },
  { href: '/suppliers', label: 'Suppliers', key: null },
  { href: '/buyers', label: 'Buyers', key: null },
] as const;

export function Sidebar({ counts }: { counts: Record<string, number> }) {
  const pathname = usePathname();
  return (
    <aside className="sidebar">
      <div className="brand">Omoterra</div>
      <nav className="nav">
        {MODULES.map((module) => {
          const active =
            module.href === '/manage' ? pathname === '/manage' : pathname.startsWith(module.href);
          const count = module.key ? counts[module.key] : 0;
          return (
            <Link key={module.href} href={module.href} className="nav-item" data-active={active}>
              <span>{module.label}</span>
              {count > 0 && <span className="nav-count">{count}</span>}
            </Link>
          );
        })}
      </nav>
      <form action="/sign-out" method="post" style={{ marginTop: 'auto' }}>
        <button type="submit" className="nav-item" style={{ width: '100%', background: 'none', border: 'none', cursor: 'pointer', textAlign: 'left' }}>
          Sign out
        </button>
      </form>
    </aside>
  );
}
