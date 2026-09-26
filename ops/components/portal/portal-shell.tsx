import Image from 'next/image';
import Link from 'next/link';
import type { ReactNode } from 'react';
import { signOut } from '@/lib/registration';
import { Icon, type IconName } from './icons';

export type Notice = { id: string; title: string; body: string; read: boolean; created_at: string };
export type NavItem = { href: string; label: string; icon: IconName };

function ago(value: string) {
  const minutes = Math.max(1, Math.round((Date.now() - new Date(value).getTime()) / 60000));
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours} h ago`;
  return new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', timeZone: 'Africa/Dar_es_Salaam' }).format(new Date(value));
}

// The signed-in member's frame: header with notifications and account menu,
// a sidebar on wide screens and a scrolling tab row on phones.
export function PortalShell({ name, subtitle, avatar, nav, notices, unread, children }: {
  name: string; subtitle: string; avatar: string | null; nav: NavItem[]; notices: Notice[]; unread: number; children: ReactNode;
}) {
  const initials = name.split(/\s+/).filter(Boolean).slice(0, 2).map((word) => word[0]!.toUpperCase()).join('') || 'O';
  return (
    <div className="portal">
      <header className="portal-header">
        <Link href="/" className="marketing-logo" aria-label="Omoterra home">
          <Image src="/images/marketing/logo.png" alt="Omoterra" width={185} height={56} priority />
        </Link>
        <div className="portal-header-actions">
          <details className="portal-menu portal-bell">
            <summary aria-label={unread ? `Notifications, ${unread} unread` : 'Notifications'}>
              <Icon name="bell" />{unread > 0 && <span className="portal-dot" />}
            </summary>
            <div className="portal-popover portal-notices">
              <strong>Notifications</strong>
              {notices.length ? notices.slice(0, 6).map((notice) => (
                <div key={notice.id} className={notice.read ? '' : 'is-unread'}>
                  <b>{notice.title}</b><span>{notice.body}</span><small>{ago(notice.created_at)}</small>
                </div>
              )) : <span className="portal-muted">No notifications yet</span>}
            </div>
          </details>
          <details className="portal-menu portal-profile">
            <summary>
              <span className="portal-avatar">
                {/* eslint-disable-next-line @next/next/no-img-element -- private photo behind the member cookie, which next/image would not send */}
                {avatar ? <img src={avatar} alt="" /> : initials}
              </span>
              <span className="portal-who"><b>{name}</b><small>{subtitle}</small></span>
              <Icon name="chevron" />
            </summary>
            <div className="portal-popover">
              <Link href="/account/pin">Change PIN</Link>
              <form action={signOut}><button type="submit">Log out</button></form>
            </div>
          </details>
        </div>
      </header>
      <nav className="portal-tabs" aria-label="Sections">
        {nav.map((item) => <a key={item.href} href={item.href}>{item.label}</a>)}
      </nav>
      <div className="portal-body">
        <aside className="portal-sidebar" aria-label="Sections">
          {nav.map((item, at) => (
            <a key={item.href} href={item.href} className={at === 0 ? 'is-active' : ''}><Icon name={item.icon} />{item.label}</a>
          ))}
        </aside>
        <div className="portal-main">{children}</div>
      </div>
    </div>
  );
}
