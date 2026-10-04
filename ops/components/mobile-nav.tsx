'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { Icons } from '@/components/icons';
import { ADMIN_GROUP, GROUPS, isActive } from '@/components/sidebar';

// The phone navigation for every operations page (the desktop sidebar is
// hidden on phones). One row of chips: the main areas, the page you are on
// when it is not one of them, and "All pages", which opens every module
// from the sidebar's own list, so the two menus never disagree.
const PRIMARY = [
  { href: '/manage', label: 'Dashboard', icon: Icons.dashboard, key: null },
  { href: '/supply', label: 'Supply', icon: Icons.truck, key: 'listings_pending_review' },
  { href: '/orders', label: 'Orders', icon: Icons.file, key: 'orders_in_progress' },
  { href: '/batches', label: 'Production', icon: Icons.production, key: 'verification_overdue' },
  { href: '/finance', label: 'Finance', icon: Icons.trend, key: null },
] as const;

type Module = { href: string; label: string; icon: (typeof Icons)[keyof typeof Icons]; key: string | null };

export function MobileNav({ counts, admin }: { counts: Record<string, number>; admin: boolean }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const row = useRef<HTMLDivElement>(null);
  const groups = admin ? [...GROUPS, ADMIN_GROUP] : GROUPS;
  const modules: Module[] = groups.flatMap((group) => [...group.modules]);
  // The most specific module that matches, so /finance/expenses is Expenses, not Finance.
  const current = modules.filter((module) => isActive(module.href, pathname)).sort((a, b) => b.href.length - a.href.length)[0];
  const extra = current && !PRIMARY.some((item) => item.href === current.href) ? current : null;
  const chips: Module[] = [...PRIMARY.slice(0, 1), ...(extra ? [extra] : []), ...PRIMARY.slice(1)];
  const waiting = Object.values(counts).reduce((sum, value) => sum + (value || 0), 0);

  // Keep the active chip in view after every navigation.
  useEffect(() => {
    const chip = row.current?.querySelector<HTMLElement>('[data-active="true"]');
    if (chip && row.current) row.current.scrollTo({ left: chip.offsetLeft - (row.current.clientWidth - chip.offsetWidth) / 2 });
  }, [pathname]);
  useEffect(() => {
    if (!open) return;
    const close = (event: KeyboardEvent) => { if (event.key === 'Escape') setOpen(false); };
    document.addEventListener('keydown', close);
    document.body.style.overflow = 'hidden';
    return () => { document.removeEventListener('keydown', close); document.body.style.overflow = ''; };
  }, [open]);

  return <>
    <nav className="mobile-nav" aria-label="Operations navigation">
      <div className="mobile-nav-row" ref={row}>
        {chips.map((item) => {
          const active = current?.href === item.href;
          const count = item.key ? counts[item.key] ?? 0 : 0;
          const Icon = item.icon;
          return <Link key={item.href} href={item.href} className="mobile-chip" data-active={active} aria-current={active ? 'page' : undefined}>
            <Icon size={17}/><span>{item.label}</span>{count > 0 && <b className="mobile-chip-count">{count}</b>}
          </Link>;
        })}
        <button type="button" className="mobile-chip mobile-chip-all" aria-expanded={open} aria-controls="mobile-nav-sheet" onClick={() => setOpen(true)}>
          <Icons.more size={17}/><span>All pages</span>{waiting > 0 && <i className="mobile-chip-dot" aria-label="Items need attention"/>}
        </button>
      </div>
    </nav>
    {open && <div className="mobile-sheet-backdrop" onClick={() => setOpen(false)}>
      <div id="mobile-nav-sheet" className="mobile-sheet" role="dialog" aria-modal="true" aria-label="All pages" onClick={(event) => event.stopPropagation()}>
        <header><b>All pages</b><button type="button" onClick={() => setOpen(false)} aria-label="Close"><Icons.close size={18}/></button></header>
        <div className="mobile-sheet-body">
          {groups.map((group) => <section key={group.label}>
            <h2>{group.label}</h2>
            <div className="mobile-sheet-grid">
              {group.modules.map((module) => {
                const active = current?.href === module.href;
                const count = module.key ? counts[module.key] ?? 0 : 0;
                const Icon = module.icon;
                return <Link key={module.href} href={module.href} className="mobile-sheet-item" data-active={active} aria-current={active ? 'page' : undefined} onClick={() => setOpen(false)}>
                  <Icon size={18}/><span>{module.label}</span>{count > 0 && <b className="mobile-chip-count">{count}</b>}
                </Link>;
              })}
            </div>
          </section>)}
          <form action="/sign-out" method="post"><button type="submit" className="mobile-sheet-signout"><Icons.logout size={18}/>Sign out</button></form>
        </div>
      </div>
    </div>}
  </>;
}
