'use client';

import { useRef, type ReactNode } from 'react';
import { Icons } from '@/components/icons';
import ui from './expenses.module.css';

// "Record unregistered payment": a supplier paid for stock whose cost was
// never entered. Opens the form (passed as children) in a side drawer.
export function UnregisteredPaymentButton({ children }: { children: ReactNode }) {
  const dialog = useRef<HTMLDialogElement>(null);
  return <>
    <button type="button" className={ui.secondary} onClick={() => dialog.current?.showModal()}>Record unregistered payment</button>
    <dialog ref={dialog} className={ui.drawer} aria-labelledby="unregistered-title">
      <div className={ui.drawerHeading}>
        <h2 id="unregistered-title">Record unregistered payment</h2>
        <button type="button" className={ui.iconButton} onClick={() => dialog.current?.close()} aria-label="Close"><Icons.close /></button>
      </div>
      <div className={ui.fields} style={{ height: 'calc(100% - 70px)' }}>{children}</div>
    </dialog>
  </>;
}
