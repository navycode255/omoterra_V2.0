'use client';

import { useRouter } from 'next/navigation';
import { useActionState, useEffect, useRef, useState, useTransition, type ReactNode } from 'react';
import { useFormStatus } from 'react-dom';
import { Icons } from '@/components/icons';
import { updateSupplierSection, type ActionResult } from '@/lib/actions';
import type { ApprovalGroup, ApprovalItem } from '@/lib/supplier';

// The header "Edit supplier" button and the tabs live outside the cards, so they
// talk to them through this window event instead of shared state.
const EDIT_EVENT = 'supplier-edit';

function SaveButton({ refreshing }: { refreshing: boolean }) {
  const { pending } = useFormStatus();
  const busy = pending || refreshing;
  return <button className="button section-save" type="submit" disabled={busy}>{busy ? 'Saving…' : 'Save'}</button>;
}

export function EditableCard({ id, section, icon, title, anchor, className = '', view, fields, extras }: {
  id: string; section: string; icon: ReactNode; title: string; anchor?: string; className?: string; view: ReactNode; fields: ReactNode; extras?: ReactNode;
}) {
  const [editing, setEditing] = useState(false);
  const router = useRouter();
  const [refreshing, startRefresh] = useTransition();
  // Close the editor in the same transition as the page refresh, so the card
  // never flashes the old values between saving and the new data arriving.
  const [state, action] = useActionState(async (previous: ActionResult | null, formData: FormData) => {
    const result = await updateSupplierSection(previous, formData);
    if (result.ok) startRefresh(() => { router.refresh(); setEditing(false); });
    return result;
  }, null);

  useEffect(() => {
    const open = (event: Event) => { if ((event as CustomEvent<string>).detail === section) setEditing(true); };
    window.addEventListener(EDIT_EVENT, open);
    return () => window.removeEventListener(EDIT_EVENT, open);
  }, [section]);

  return <section className={`supplier-detail-card ${className}`} id={anchor ?? `card-${section}`} data-editing={editing}>
    <header>
      <span className="section-title">{icon}{title}</span>
      {!editing && <button type="button" className="card-edit" onClick={() => setEditing(true)}><Icons.edit size={18}/>Edit</button>}
    </header>
    {editing
      ? <form action={action} className="section-form">
          <input type="hidden" name="id" value={id}/><input type="hidden" name="section" value={section}/>
          {fields}
          {extras && <div className="section-extras"><p><strong>Also needed to save.</strong> The supplier profile is incomplete, so these fields from other sections are saved together with this one.</p>{extras}</div>}
          {state && !state.ok && <p className="inline-error" role="alert">{state.error}</p>}
          <div className="section-form-actions">
            <button type="button" className="button" data-variant="secondary" onClick={() => setEditing(false)}>Cancel</button>
            <SaveButton refreshing={refreshing}/>
          </div>
        </form>
      : view}
  </section>;
}

export function EditSupplierButton() {
  return <button type="button" className="button" data-variant="secondary" onClick={() => {
    const details = document.getElementById('details');
    if (details) window.scrollTo({ top: details.getBoundingClientRect().top + window.scrollY - headerBottom() - GAP_BELOW_HEADER, behavior: 'smooth' });
    window.dispatchEvent(new CustomEvent(EDIT_EVENT, { detail: 'details' }));
  }}><Icons.edit size={18}/>Edit supplier</button>;
}

const TABS = [
  { anchor: 'overview', label: 'Overview', icon: Icons.cubes },
  { anchor: 'verification', label: 'Verification', icon: Icons.clipboard },
  { anchor: 'production', label: 'Production', icon: Icons.users },
  { anchor: 'history', label: 'History', icon: Icons.clock },
] as const;

const GAP_BELOW_HEADER = 16;

// Where the pinned supplier header ends once the page has scrolled. On phones
// the header is pinned with a negative offset so only its tab row stays on
// screen (see --supplier-head-collapse), which this accounts for.
function headerBottom() {
  const bar = document.querySelector<HTMLElement>('.supplier-detail-topbar');
  if (!bar) return 0;
  return (parseFloat(getComputedStyle(bar).top) || 0) + bar.offsetHeight;
}

// On narrow screens a fully frozen header would cover most of the page, so
// everything above the tabs is allowed to scroll away.
function collapseHeader() {
  const bar = document.querySelector<HTMLElement>('.supplier-detail-topbar');
  const tabs = document.querySelector<HTMLElement>('.supplier-tabs');
  if (!bar || !tabs) return;
  const collapse = window.matchMedia('(max-width: 700px)').matches ? bar.offsetHeight - tabs.offsetHeight : 0;
  bar.style.setProperty('--supplier-head-collapse', `${collapse}px`);
}

// Tabs scroll the page to their section and follow the reader as they scroll.
// A section is "current" once its top reaches the frozen header. After a tab
// is clicked it stays selected until the reader scrolls on their own, because
// the last sections are too short to ever reach the top of the page.
export function SupplierTabs() {
  const [active, setActive] = useState<string>('overview');
  const chosen = useRef<string | null>(null);
  useEffect(() => {
    const update = () => {
      collapseHeader();
      if (chosen.current) return setActive(chosen.current);
      const bar = headerBottom();
      let current: string = TABS[0].anchor;
      for (const tab of TABS) {
        const top = document.getElementById(tab.anchor)?.getBoundingClientRect().top;
        if (top !== undefined && top - bar <= GAP_BELOW_HEADER + 8) current = tab.anchor;
      }
      const atBottom = window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 4;
      setActive(atBottom ? TABS[TABS.length - 1].anchor : current);
    };
    const release = () => { chosen.current = null; };
    // "Edit supplier" scrolls to the details card, so the tabs follow again.
    const onEdit = () => { release(); requestAnimationFrame(update); };
    update();
    window.addEventListener(EDIT_EVENT, onEdit);
    window.addEventListener('scroll', update, { passive: true });
    window.addEventListener('resize', update);
    for (const type of ['wheel', 'touchstart', 'keydown'] as const) window.addEventListener(type, release, { passive: true });
    return () => {
      window.removeEventListener('scroll', update);
      window.removeEventListener('resize', update);
      window.removeEventListener(EDIT_EVENT, onEdit);
      for (const type of ['wheel', 'touchstart', 'keydown'] as const) window.removeEventListener(type, release);
    };
  }, []);

  return <nav className="supplier-tabs" aria-label="Supplier sections">
    {TABS.map(({ anchor, label, icon: TabIcon }) => <a key={anchor} href={`#${anchor}`} className={active === anchor ? 'active' : undefined} aria-current={active === anchor ? 'location' : undefined} onClick={(event) => {
      event.preventDefault();
      const target = document.getElementById(anchor);
      if (!target) return;
      chosen.current = anchor;
      setActive(anchor);
      const top = anchor === 'overview' ? 0 : target.getBoundingClientRect().top + window.scrollY - headerBottom() - GAP_BELOW_HEADER;
      window.scrollTo({ top, behavior: 'smooth' });
      history.replaceState(null, '', `#${anchor}`);
    }}><TabIcon size={20}/>{label}</a>)}
  </nav>;
}

function scrollToCard(element: HTMLElement) {
  window.scrollTo({ top: element.getBoundingClientRect().top + window.scrollY - headerBottom() - GAP_BELOW_HEADER, behavior: 'smooth' });
}

// Explains what approval needs, from the same rules the backend enforces, and
// takes the operator straight to whichever card still needs work.
export function ApprovalGuide({ groups, status }: { groups: ApprovalGroup[]; status: string }) {
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);
  const dialog = useRef<HTMLDivElement>(null);
  const items = groups.flatMap((group) => group.items);
  const done = items.filter((item) => item.done).length;
  const remaining = items.length - done;
  const approved = status === 'approved';

  useEffect(() => {
    if (!open) return;
    dialog.current?.focus();
    const close = (event: MouseEvent | KeyboardEvent) => {
      if (event instanceof KeyboardEvent ? event.key === 'Escape' : !box.current?.contains(event.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', close);
    document.addEventListener('keydown', close);
    return () => { document.removeEventListener('mousedown', close); document.removeEventListener('keydown', close); };
  }, [open]);

  const fix = (item: ApprovalItem) => {
    setOpen(false);
    if (item.target === 'verification') {
      const card = document.getElementById('verification');
      if (card) scrollToCard(card);
      window.setTimeout(() => document.querySelector<HTMLInputElement>(`#verification input[name="${item.key}"]`)?.focus({ preventScroll: true }), 450);
      return;
    }
    const card = document.getElementById(item.target === 'details' ? 'details' : `card-${item.target}`);
    if (card) scrollToCard(card);
    window.dispatchEvent(new CustomEvent(EDIT_EVENT, { detail: item.target }));
    // Focus the missing field once the card's editor has opened.
    const field = item.key === 'production_profile' ? 'capacity_' : item.key;
    window.setTimeout(() => card?.querySelector<HTMLElement>(`form.section-form [name^="${field}"]`)?.focus({ preventScroll: true }), 450);
  };

  return <div className="approval-guide" ref={box}>
    <button type="button" className="approval-info" aria-haspopup="dialog" aria-expanded={open} aria-label="What is needed to approve this supplier" onClick={() => setOpen((value) => !value)} data-ready={remaining === 0}>
      <Icons.info size={20}/>
    </button>
    <button type="button" className="approval-summary" onClick={() => setOpen(true)} data-ready={remaining === 0}>
      {approved ? 'Meets all approval requirements' : remaining === 0 ? 'Ready to approve' : `${remaining} ${remaining === 1 ? 'item' : 'items'} left before approval`}
    </button>
    {open && <div className="approval-popover" role="dialog" aria-modal="false" aria-labelledby="approval-title" ref={dialog} tabIndex={-1}>
      <header>
        <div><h2 id="approval-title">Approval requirements</h2><p>Omoterra can approve a supplier once every item below is complete.</p></div>
        <button type="button" className="approval-close" aria-label="Close" onClick={() => setOpen(false)}><Icons.close size={18}/></button>
      </header>
      <div className="approval-progress" aria-label={`${done} of ${items.length} complete`}>
        <i><b style={{ width: `${(done / items.length) * 100}%` }}/></i><span>{done} of {items.length} complete</span>
      </div>
      <div className="approval-groups">{groups.map((group) => {
        const groupDone = group.items.filter((item) => item.done).length;
        return <section key={group.title}>
          <h3>{group.title}<span>{groupDone}/{group.items.length}</span></h3>
          <ul>{[...group.items].sort((a, b) => Number(a.done) - Number(b.done)).map((item) => <li key={item.key} data-done={item.done}>
            <span className="approval-mark" aria-hidden="true">{item.done ? <Icons.checkCircle size={18}/> : <i/>}</span>
            <span className="approval-copy"><strong>{item.label}</strong><small>{item.hint}</small></span>
            {item.done ? <span className="sr-only">Complete</span> : <button type="button" onClick={() => fix(item)}>{item.target === 'verification' ? 'Check' : 'Add'}</button>}
          </li>)}</ul>
        </section>;
      })}</div>
      <footer data-ready={remaining === 0}>{approved
        ? 'This supplier is approved.'
        : remaining === 0
          ? 'Everything is in place. Choose Approved from the status menu.'
          : 'Verification checks are saved with Save checklist in the Supplier verification card.'}</footer>
    </div>}
  </div>;
}
