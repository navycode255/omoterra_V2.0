import type { ReactNode } from 'react';
import type { Tone } from '@/lib/format';
import { RetryButton } from '@/components/retry-button';

export function Status({ children, tone = 'neutral' }: { children: ReactNode; tone?: Tone }) {
  return (
    <span className="status" data-tone={tone}>
      {children}
    </span>
  );
}

export function Pill({ children }: { children: ReactNode }) {
  return <span className="pill">{children}</span>;
}

export function Card({
  title,
  action,
  children,
}: {
  title?: string;
  action?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section className="card">
      {(title || action) && (
        <div className="between" style={{ marginBottom: 'var(--s4)' }}>
          {title && <h3>{title}</h3>}
          {action}
        </div>
      )}
      {children}
    </section>
  );
}

export function Empty({ children }: { children: ReactNode }) {
  return <div className="empty">{children}</div>;
}

export function Definition({ items }: { items: [string, ReactNode][] }) {
  return (
    <dl className="definition">
      {items.map(([term, value]) => (
        <div key={term} style={{ display: 'contents' }}>
          <dt>{term}</dt>
          <dd>{value}</dd>
        </div>
      ))}
    </dl>
  );
}

export function PageHeader({ title, subtitle }: { title: string; subtitle?: string }) {
  return (
    <div>
      <h1>{title}</h1>
      {subtitle && <p className="topbar-sub">{subtitle}</p>}
    </div>
  );
}

export function Notice({ children, tone }: { children: ReactNode; tone?: 'error' }) {
  return (
    <div className="notice" data-tone={tone} role={tone === 'error' ? 'alert' : 'status'}>
      {tone === 'error' && (
        <span className="notice-icon" aria-hidden="true">↻</span>
      )}
      <div className="notice-copy">
        {tone === 'error' && <strong>We couldn’t load this just now</strong>}
        <div>{children}</div>
        {tone === 'error' && <RetryButton />}
      </div>
    </div>
  );
}
