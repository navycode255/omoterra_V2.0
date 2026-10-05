'use client';

import { useId, useRef, type ReactNode } from 'react';
import { Icons } from '@/components/icons';
import styles from './finance.module.css';

export function SaleDialog({ label, title, children }: { label: string; title: string; children: ReactNode }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const heading = useId();
  return <>
    <button type="button" className={styles.saleDialogButton} onClick={() => dialog.current?.showModal()}>{label}</button>
    <dialog className={styles.saleDialog} ref={dialog} aria-labelledby={heading} onClick={event => { if (event.target === event.currentTarget) dialog.current?.close(); }}>
      <header className={styles.saleDialogHeader}><h2 id={heading}>{title}</h2><button type="button" aria-label="Close" onClick={() => dialog.current?.close()}><Icons.close size={20}/></button></header>
      {children}
    </dialog>
  </>;
}
