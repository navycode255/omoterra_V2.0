'use client';

import Link from 'next/link';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Icons } from '@/components/icons';

type Alert = { kind: string; at: string; title: string; link: string };
type Feed = { unread: number; seen_at: string; items: Alert[] };

const POLL_MS = 60_000;

function ago(iso: string) {
  const minutes = Math.round((Date.now() - new Date(iso).getTime()) / 60_000);
  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.round(minutes / 60);
  return hours < 24 ? `${hours} h ago` : `${Math.round(hours / 24)} d ago`;
}

// New work for operations: orders, stock to review, registrations, buyer
// requests and supply offers. Checks every minute; with permission, also
// raises a desktop notification so work is noticed from another tab.
export function OpsAlerts() {
  const [feed, setFeed] = useState<Feed | null>(null);
  const [open, setOpen] = useState(false);
  // Only read inside the panel, which starts closed, so the server's
  // 'unsupported' and the browser's real value never clash on hydration.
  const [permission, setPermission] = useState<NotificationPermission | 'unsupported'>(
    () => (typeof Notification === 'undefined' ? 'unsupported' : Notification.permission));
  const lastUnread = useRef<number | null>(null);

  const load = useCallback(async () => {
    try {
      const response = await fetch('/alerts', { cache: 'no-store' });
      if (!response.ok) return;
      const next: Feed = await response.json();
      const previous = lastUnread.current;
      if (previous !== null && next.unread > previous && next.items[0]
          && typeof Notification !== 'undefined' && Notification.permission === 'granted') {
        const fresh = next.unread - previous;
        new Notification(fresh === 1 ? next.items[0].title : `${fresh} new items in Omoterra Operations`, {
          body: fresh === 1 ? 'Open the dashboard to act on it.' : next.items.slice(0, 3).map((item) => item.title).join('\n'),
          tag: 'omoterra-ops-alerts',
        });
      }
      lastUnread.current = next.unread;
      setFeed(next);
    } catch {
      // Offline for a moment: the next poll catches up.
    }
  }, []);

  useEffect(() => {
    // First check right away, then every minute and whenever the tab regains focus.
    const first = window.setTimeout(load, 0);
    const timer = window.setInterval(load, POLL_MS);
    const onFocus = () => load();
    window.addEventListener('focus', onFocus);
    return () => {
      window.clearTimeout(first);
      window.clearInterval(timer);
      window.removeEventListener('focus', onFocus);
    };
  }, [load]);

  useEffect(() => {
    const base = document.title.replace(/^\(\d+\) /, '');
    document.title = feed?.unread ? `(${feed.unread}) ${base}` : base;
  }, [feed?.unread]);

  async function toggle() {
    const opening = !open;
    setOpen(opening);
    if (opening && feed?.unread) {
      // Opening the list reads it.
      await fetch('/alerts', { method: 'POST' });
      lastUnread.current = 0;
      setFeed({ ...feed, unread: 0, seen_at: new Date().toISOString() });
    }
  }

  async function enableDesktop() {
    if (typeof Notification === 'undefined') return;
    setPermission(await Notification.requestPermission());
  }

  const unread = feed?.unread ?? 0;
  const seenAt = feed ? new Date(feed.seen_at).getTime() : 0;
  return (
    <div className="ops-alerts">
      <button type="button" className="ops-alerts-bell" onClick={toggle} aria-expanded={open}
        aria-label={unread ? `Alerts, ${unread} new` : 'Alerts'}>
        <Icons.bell size={22} />
        {unread > 0 && <span className="ops-alerts-count">{unread > 99 ? '99+' : unread}</span>}
      </button>
      {open && (
        <div className="ops-alerts-panel" role="dialog" aria-label="New work">
          <div className="ops-alerts-head">
            <strong>New work</strong>
            <button type="button" className="ops-alerts-close" onClick={() => setOpen(false)} aria-label="Close"><Icons.close size={18} /></button>
          </div>
          {permission === 'default' && (
            <button type="button" className="ops-alerts-enable" onClick={enableDesktop}>
              Turn on desktop alerts
            </button>
          )}
          {!feed || feed.items.length === 0 ? (
            <p className="meta ops-alerts-empty">Nothing new in the last 7 days.</p>
          ) : (
            <ul>
              {feed.items.map((item) => (
                <li key={`${item.kind}-${item.link}-${item.at}`} data-new={new Date(item.at).getTime() > seenAt || undefined}>
                  <Link href={item.link} onClick={() => setOpen(false)}>
                    <span>{item.title}</span>
                    <small>{ago(item.at)}</small>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}
