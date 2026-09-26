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
  ] },
  { label: 'Finance', modules: [
    { href: '/payments', label: 'Payments', icon: Icons.card, key: 'payments_pending' },
    { href: '/settlements', label: 'Settlements', icon: Icons.clock, key: 'settlements_pending' },
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
          const active = module.href === '/manage' ? pathname === '/manage' : pathname.startsWith(module.href);
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
