'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Icons } from '@/components/icons';

const GROUPS = [
  { label: 'Main', modules: [{ href: '/manage', label: 'Dashboard', icon: Icons.home, key: null }] },
  { label: 'Operations', modules: [
    { href: '/supply', label: 'Supply', icon: Icons.box, key: 'listings_pending_review' },
    { href: '/orders', label: 'Orders', icon: Icons.file, key: 'orders_in_progress' },
    { href: '/batches', label: 'Production Batches', icon: Icons.calendar, key: 'verification_overdue' },
    { href: '/market-schedule', label: 'Market Schedule', icon: Icons.sprout, key: null },
  ] },
  { label: 'Purchasing', modules: [
    { href: '/lpos', label: 'LPOs', icon: Icons.clipboard, key: null },
  ] },
  { label: 'Finance', modules: [
    { href: '/finance', label: 'Finance overview', icon: Icons.trend, key: null },
    { href: '/sales', label: 'Sales', icon: Icons.clipboard, key: null },
    { href: '/finance/expenses', label: 'Expenses', icon: Icons.card, key: null },
    { href: '/finance/profit', label: 'Profit', icon: Icons.chart, key: null },
    { href: '/finance/debts', label: 'Debts', icon: Icons.alert, key: null },
    { href: '/finance/supplier-payments', label: 'Supplier payments', icon: Icons.card, key: null },
    { href: '/finance/cash-book', label: 'Cash book', icon: Icons.file, key: null },
    { href: '/payments', label: 'Payments', icon: Icons.card, key: 'payments_pending' },
    { href: '/settlements', label: 'Settlements', icon: Icons.clock, key: 'settlements_pending' },
  ] },
  { label: 'Marketing', modules: [
    { href: '/promotions', label: 'Promotions', icon: Icons.bell, key: null },
  ] },
  { label: 'Business', modules: [
    { href: '/opportunities', label: 'Business Opportunities', icon: Icons.chart, key: null },
  ] },
  { label: 'Partners', modules: [
    { href: '/suppliers', label: 'Suppliers', icon: Icons.users, key: null },
    { href: '/buyers', label: 'Buyers', icon: Icons.users, key: null },
    { href: '/ratings', label: 'Ratings', icon: Icons.star, key: null },
  ] },
] as const;

// Only admins manage staff and read the activity log.
const ADMIN_GROUP = { label: 'Team', modules: [
  { href: '/staff', label: 'Staff', icon: Icons.users, key: null },
  { href: '/activity', label: 'Activity', icon: Icons.clock, key: null },
] } as const;

export function Sidebar({ counts, admin }: { counts: Record<string, number>; admin: boolean }) {
  const pathname = usePathname();
  const groups = admin ? [...GROUPS, ADMIN_GROUP] : GROUPS;
  return <aside className="sidebar">
    <nav className="nav" aria-label="Operations navigation">
      {groups.map((group) => <div className="nav-group" key={group.label}>
        <p className="nav-heading">{group.label}</p>
        {group.modules.map((module) => {
          // Pages with sub-pages of their own in the menu light up only on an exact match.
          const active = module.href === '/manage' || module.href === '/finance'
            ? pathname === module.href : pathname.startsWith(module.href);
          const count = module.key ? counts[module.key] ?? 0 : 0;
          const ModuleIcon = module.icon;
          return <Link key={module.href} href={module.href} className="nav-item" data-active={active}>
            <span className="nav-label"><ModuleIcon size={20}/>{module.label}</span>
            {count > 0 && <span className="nav-count">{count}</span>}
          </Link>;
        })}
      </div>)}
    </nav>
    <form action="/sign-out" method="post" className="signout-form">
      <button type="submit" className="nav-item nav-signout"><span className="nav-label"><Icons.logout size={20}/>Sign out</span></button>
    </form>
  </aside>;
}
