'use client';

import { useEffect, useRef, useState } from 'react';
import { Icons } from '@/components/icons';

// An ⓘ next to a heading that keeps explanations off the page: click to open
// a short note; click outside or press Escape to close it.
export function InfoTip({ label, children }: { label: string; children: React.ReactNode }) {
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    if (!open) return;
    const close = (event: MouseEvent | KeyboardEvent) => {
      if (event instanceof KeyboardEvent ? event.key === 'Escape' : !box.current?.contains(event.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', close);
    document.addEventListener('keydown', close);
    return () => { document.removeEventListener('mousedown', close); document.removeEventListener('keydown', close); };
  }, [open]);

  return (
    <span className="info-tip" ref={box}>
      <button type="button" className="info-tip-button" aria-label={label} aria-expanded={open} onClick={() => setOpen(!open)}>
        <Icons.info size={18} />
      </button>
      {open && <span className="info-tip-panel" role="note">{children}</span>}
    </span>
  );
}
