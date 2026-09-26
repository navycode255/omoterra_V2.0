'use client';

import { useState, type ReactNode } from 'react';
import { Icon, type IconName } from './icons';

// A panel card or list row that folds to its one-line header on phones. On
// wider screens the stylesheet always shows the body and hides the chevron.
export function Fold({ as: Tag = 'section', id, className = 'portal-card', head, action, open: forced, children }: {
  as?: 'section' | 'li'; id?: string; className?: string; head: ReactNode; action?: ReactNode; open?: boolean; children: ReactNode;
}) {
  const [open, setOpen] = useState(false);
  const shown = open || !!forced;
  const Head = Tag === 'section' ? 'h2' : 'div';
  return (
    <Tag id={id} className={`${className} portal-fold${shown ? ' is-open' : ''}`}>
      <Head className="portal-fold-head">
        <button type="button" className="portal-fold-toggle" aria-expanded={shown} onClick={() => setOpen(!shown)}>
          {head}
          <span className="portal-fold-chevron"><Icon name="chevron" /></span>
        </button>
        {action}
      </Head>
      <div className="portal-fold-body">{children}</div>
    </Tag>
  );
}

// The header of a folding card: its icon and title, and the summary shown
// under the title while it is folded on a phone.
export function FoldTitle({ icon, title, summary }: { icon: IconName; title: string; summary?: string }) {
  return <>
    <span className="portal-fold-icon"><Icon name={icon} /></span>
    <span className="portal-fold-title"><b>{title}</b>{summary && <small>{summary}</small>}</span>
  </>;
}
