'use client';

import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { useEffect, useRef, useState, useTransition, type ReactNode } from 'react';
import { Icons } from '@/components/icons';
import styles from '@/components/finance/finance-list.module.css';

// The one search box and filter menu every operations list uses (the Debts
// page's design). Both update the address as you type or choose, so results
// follow without a Search or Apply button, and a filtered view can still be
// shared or bookmarked.

function useListAddress() {
  const router = useRouter();
  const pathname = usePathname();
  const search = useSearchParams();
  const [pending, start] = useTransition();
  function update(change: Record<string, string>) {
    const query = new URLSearchParams(search.toString());
    for (const [key, value] of Object.entries(change)) { if (value) query.set(key, value); else query.delete(key); }
    query.delete('page');
    start(() => router.replace(query.size ? `${pathname}?${query}` : pathname, { scroll: false }));
  }
  return { search, update, pending };
}

export function SearchBox({ placeholder = 'Search…', name = 'q' }: { placeholder?: string; name?: string }) {
  const { search, update, pending } = useListAddress();
  const current = search.get(name) ?? '';
  const [value, setValue] = useState(current);
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const typed = useRef(current);
  // Follow the address when it changes elsewhere (a tab, Back).
  useEffect(() => { if (current !== typed.current) { typed.current = current; setValue(current); } }, [current]);
  function change(next: string) {
    setValue(next);
    clearTimeout(timer.current);
    timer.current = setTimeout(() => { typed.current = next.trim(); update({ [name]: next.trim() }); }, 350);
  }
  return <label className={styles.search} data-busy={pending || undefined}>
    <Icons.search size={19} />
    <input type="search" name={name} value={value} onChange={(event) => change(event.target.value)}
      onKeyDown={(event) => { if (event.key === 'Enter') { event.preventDefault(); clearTimeout(timer.current); typed.current = value.trim(); update({ [name]: value.trim() }); } }}
      placeholder={placeholder} aria-label={placeholder.replace(/…$/, '')} autoComplete="off" />
    {value && <button type="button" className={styles.clear} aria-label="Clear search" onClick={() => { clearTimeout(timer.current); typed.current = ''; setValue(''); update({ [name]: '' }); }}><Icons.close size={16} /></button>}
  </label>;
}

/** A dropdown of filters: every select or date inside applies on change. */
export function FilterMenu({ label, icon = 'filter', children, align = 'end' }: {
  label: ReactNode; icon?: 'filter' | 'calendar'; children: ReactNode; align?: 'start' | 'end';
}) {
  const { update, pending } = useListAddress();
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined);
  return <details className={styles.filters} data-align={align} data-busy={pending || undefined}
    onChange={(event) => {
      const field = event.target as unknown as HTMLInputElement | HTMLSelectElement;
      if (!field.name) return;
      // A date applies once it is complete (or cleared).
      if (field.type === 'date' && field.value && !/^\d{4}-\d{2}-\d{2}$/.test(field.value)) return;
      const change = { [field.name]: field.value.trim(), ...(field.type === 'date' ? { dates: '' } : {}) };
      clearTimeout(timer.current);
      // Typed text waits for a pause; choices apply at once.
      if (field.tagName === 'INPUT' && ['text', 'search'].includes(field.type)) timer.current = setTimeout(() => update(change), 450);
      else update(change);
    }}>
    <summary>
      {icon === 'calendar' ? <Icons.calendar size={18} /> : <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path d="M4 5h16l-6 7.5V19l-4 1v-7.5z" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" /></svg>}
      {label}<Icons.chevronDown size={16} />
    </summary>
    <div>{children}</div>
  </details>;
}
