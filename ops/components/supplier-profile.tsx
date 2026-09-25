'use client';

import Image from 'next/image';
import { useRouter } from 'next/navigation';
import { useActionState, useEffect, useRef, useState, useTransition, type ReactNode } from 'react';
import { useFormStatus } from 'react-dom';
import { Icons } from '@/components/icons';
import { addSupplierPhotos, removeSupplierPhoto, updateSupplierSection, type ActionResult } from '@/lib/actions';

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

  return <section className={`supplier-detail-card ${className}`} id={anchor} data-editing={editing}>
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

function mediaSource(photo: string) {
  return `/media/${photo.split('/').pop()}`;
}

function RemovePhoto({ id, photo }: { id: string; photo: string }) {
  const [state, action, pending] = useActionState(removeSupplierPhoto, null);
  return <form action={action} className="photo-remove-form">
    <input type="hidden" name="id" value={id}/><input type="hidden" name="url" value={photo}/>
    <button type="submit" className="photo-remove" aria-label="Remove photo" disabled={pending} title={state && !state.ok ? state.error : 'Remove photo'}>×</button>
  </form>;
}

export function SupplierPhotos({ id, photos, max }: { id: string; photos: string[]; max: number }) {
  const input = useRef<HTMLInputElement>(null);
  const form = useRef<HTMLFormElement>(null);
  const [state, action, pending] = useActionState(async (previous: ActionResult | null, formData: FormData) => {
    const result = await addSupplierPhotos(previous, formData);
    if (input.current) input.current.value = '';
    return result;
  }, null);
  const full = photos.length >= max;
  const choose = () => input.current?.click();

  return <section className="supplier-detail-card photo-card" id="photos">
    <header>
      <span className="section-title"><Icons.image size={23}/>Farm and supply photos</span>
      {!full && <button type="button" className="add-photos-button" onClick={choose} disabled={pending}><Icons.camera size={18}/>{pending ? 'Uploading…' : 'Add photos'}</button>}
    </header>
    <form ref={form} action={action} hidden>
      <input type="hidden" name="id" value={id}/><input type="hidden" name="existing" value={photos.length}/>
      <input ref={input} type="file" name="photos" accept="image/jpeg,image/png,image/webp" multiple onChange={() => form.current?.requestSubmit()}/>
    </form>
    <div className="supplier-photos">
      {photos.map((photo) => <figure key={photo}>
        <a href={mediaSource(photo)} target="_blank" rel="noreferrer"><Image src={mediaSource(photo)} width={260} height={240} alt="Supplier stock or farm" unoptimized/></a>
        <RemovePhoto id={id} photo={photo}/>
      </figure>)}
      {!full && <button type="button" className="add-photo-tile" onClick={choose} disabled={pending}>
        {pending ? <span className="add-photo-spinner" aria-hidden="true"/> : <Icons.plus size={22}/>}
        <span>{pending ? 'Uploading…' : 'Add photos'}</span>
      </button>}
    </div>
    <p className="photo-hint">{state && !state.ok ? <span className="inline-error" role="alert">{state.error}</span> : `Stock, farm or pickup area · ${photos.length} of ${max} · JPEG, PNG or WebP up to 8 MB`}</p>
  </section>;
}
