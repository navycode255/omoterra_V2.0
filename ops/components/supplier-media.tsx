'use client';

import Image from 'next/image';
import { useActionState, useCallback, useEffect, useRef, useState, useTransition, type ReactNode } from 'react';
import { Icons } from '@/components/icons';
import { addSupplierPhotos, deleteSupplierVideo, removeSupplierPhoto, saveSupplierVideo, type ActionResult } from '@/lib/actions';
import { date } from '@/lib/format';
import type { SupplierPhoto, SupplierVideo } from '@/lib/types';

function mediaSource(url: string) {
  return `/media/${url.split('/').pop()}`;
}

// A modal shell shared by the lightbox, confirmations and the video form:
// Escape and the backdrop close it, focus moves in and returns afterwards.
function Modal({ label, onClose, className = '', children }: { label: string; onClose: () => void; className?: string; children: ReactNode }) {
  const panel = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    panel.current?.focus();
    const onKey = (event: KeyboardEvent) => { if (event.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    const overflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => { document.removeEventListener('keydown', onKey); document.body.style.overflow = overflow; previous?.focus(); };
  }, [onClose]);
  return <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
    <div className={`modal-panel ${className}`} role="dialog" aria-modal="true" aria-label={label} ref={panel} tabIndex={-1}>{children}</div>
  </div>;
}

function ConfirmDialog({ title, message, confirmLabel, busy, error, onConfirm, onCancel }: {
  title: string; message: string; confirmLabel: string; busy: boolean; error?: string; onConfirm: () => void; onCancel: () => void;
}) {
  return <Modal label={title} onClose={busy ? () => {} : onCancel} className="confirm-panel">
    <span className="confirm-icon"><Icons.alert size={22}/></span>
    <h2>{title}</h2>
    <p>{message}</p>
    {error && <p className="inline-error" role="alert">{error}</p>}
    <div className="confirm-actions">
      <button type="button" className="button" data-variant="secondary" onClick={onCancel} disabled={busy}>Cancel</button>
      <button type="button" className="button danger-button" onClick={onConfirm} disabled={busy}>{busy ? 'Deleting…' : confirmLabel}</button>
    </div>
  </Modal>;
}

// Runs a server action outside a <form>, for buttons inside dialogs.
function useAction(action: (previous: ActionResult | null, formData: FormData) => Promise<ActionResult>) {
  const [state, setState] = useState<ActionResult | null>(null);
  const [busy, start] = useTransition();
  const runAction = (fields: Record<string, string>, onSuccess?: () => void) => {
    const formData = new FormData();
    for (const [key, value] of Object.entries(fields)) formData.set(key, value);
    start(async () => {
      const result = await action(null, formData);
      setState(result);
      if (result.ok) onSuccess?.();
    });
  };
  return { state, busy, run: runAction, reset: () => setState(null) };
}

function Lightbox({ photos, index, onIndex, onClose, onDelete }: { photos: SupplierPhoto[]; index: number; onIndex: (index: number) => void; onClose: () => void; onDelete: (photo: SupplierPhoto) => void }) {
  const photo = photos[index];
  const step = useCallback((delta: number) => onIndex((index + delta + photos.length) % photos.length), [index, onIndex, photos.length]);
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'ArrowRight') step(1);
      if (event.key === 'ArrowLeft') step(-1);
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [step]);
  if (!photo) return null;
  return <Modal label="Supplier photo" onClose={onClose} className="lightbox-panel">
    <header className="lightbox-bar">
      <span>{index + 1} / {photos.length} · Added {date(photo.created_at)}</span>
      <div>
        <button type="button" className="lightbox-tool" onClick={() => onDelete(photo)}><Icons.trash size={18}/>Delete</button>
        <button type="button" className="lightbox-tool" onClick={onClose} aria-label="Close preview"><Icons.close size={20}/></button>
      </div>
    </header>
    <div className="lightbox-stage">
      {photos.length > 1 && <button type="button" className="lightbox-nav" data-side="left" onClick={() => step(-1)} aria-label="Previous photo"><Icons.chevron size={26} style={{ transform: 'rotate(180deg)' }}/></button>}
      <Image key={photo.id} src={mediaSource(photo.url)} alt={`Supplier photo ${index + 1} of ${photos.length}`} width={1600} height={1200} unoptimized className="lightbox-image"/>
      {photos.length > 1 && <button type="button" className="lightbox-nav" data-side="right" onClick={() => step(1)} aria-label="Next photo"><Icons.chevron size={26}/></button>}
    </div>
  </Modal>;
}

export function SupplierPhotosCard({ id, photos, limit }: { id: string; photos: SupplierPhoto[]; limit: number }) {
  const input = useRef<HTMLInputElement>(null);
  const form = useRef<HTMLFormElement>(null);
  const [uploading, setUploading] = useState(0);
  const [preview, setPreview] = useState<number | null>(null);
  const [pendingDelete, setPendingDelete] = useState<SupplierPhoto | null>(null);
  const remove = useAction(removeSupplierPhoto);
  const [state, action] = useActionState(async (previous: ActionResult | null, formData: FormData) => {
    const result = await addSupplierPhotos(previous, formData);
    setUploading(0);
    if (input.current) input.current.value = '';
    return result;
  }, null);
  const full = photos.length >= limit;
  const choose = () => input.current?.click();

  return <section className="supplier-detail-card photo-card" id="photos">
    <header>
      <span className="section-title"><Icons.image size={23}/>Farm and supply photos</span>
      {!full && <button type="button" className="add-photos-button" onClick={choose} disabled={uploading > 0}><Icons.camera size={18}/>{uploading ? 'Uploading…' : 'Add photos'}</button>}
    </header>
    <form ref={form} action={action} hidden>
      <input type="hidden" name="id" value={id}/>
      <input ref={input} type="file" name="photos" accept="image/jpeg,image/png,image/webp" multiple onChange={(event) => {
        const count = event.currentTarget.files?.length ?? 0;
        if (!count) return;
        setUploading(count);
        form.current?.requestSubmit();
      }}/>
    </form>
    <div className="supplier-photos">
      {photos.map((photo, index) => <figure key={photo.id}>
        <button type="button" className="photo-open" onClick={() => setPreview(index)} aria-label={`Open photo ${index + 1} of ${photos.length}`}>
          <Image src={mediaSource(photo.url)} width={320} height={240} alt="" unoptimized/>
        </button>
        <button type="button" className="photo-remove" aria-label={`Delete photo ${index + 1}`} onClick={() => { remove.reset(); setPendingDelete(photo); }}><Icons.trash size={14}/></button>
      </figure>)}
      {Array.from({ length: uploading }, (_, index) => <div key={`uploading-${index}`} className="photo-placeholder" aria-hidden="true"><span className="add-photo-spinner"/></div>)}
      {!full && !uploading && <button type="button" className="add-photo-tile" onClick={choose}><Icons.plus size={22}/><span>Add photos</span></button>}
    </div>
    <p className="photo-hint">{state && !state.ok
      ? <span className="inline-error" role="alert">{state.error}</span>
      : uploading ? `Uploading ${uploading} ${uploading === 1 ? 'photo' : 'photos'}…`
      : photos.length ? `${photos.length} ${photos.length === 1 ? 'photo' : 'photos'} · click a photo to preview` : 'Stock, farm or pickup area · JPEG, PNG or WebP up to 8 MB each'}</p>

    {preview !== null && photos[preview] && <Lightbox photos={photos} index={preview} onIndex={setPreview} onClose={() => setPreview(null)} onDelete={(photo) => { remove.reset(); setPendingDelete(photo); }}/>}
    {pendingDelete && <ConfirmDialog title="Delete this photo?" message="It will be removed from this supplier's profile. This can't be undone."
      confirmLabel="Delete photo" busy={remove.busy} error={remove.state && !remove.state.ok ? remove.state.error : undefined}
      onCancel={() => setPendingDelete(null)}
      onConfirm={() => remove.run({ id, photo: pendingDelete.id }, () => {
        setPendingDelete(null);
        setPreview((current) => current === null || photos.length <= 1 ? null : Math.min(current, photos.length - 2));
      })}/>}
  </section>;
}

function VideoForm({ id, mode, video, uploadEnabled, onDone, onCancel }: { id: string; mode: 'add' | 'replace'; video: SupplierVideo | null; uploadEnabled: boolean; onDone: () => void; onCancel: () => void }) {
  const [state, action, pending] = useActionState(async (previous: ActionResult | null, formData: FormData) => {
    const result = await saveSupplierVideo(previous, formData);
    if (result.ok) onDone();
    return result;
  }, null);
  return <Modal label={mode === 'add' ? 'Add supplier video' : 'Replace supplier video'} onClose={pending ? () => {} : onCancel} className="video-form-panel">
    <header className="video-form-head">
      <div><h2>{mode === 'add' ? 'Add supplier video' : 'Replace supplier video'}</h2>
        <p>{mode === 'add' ? 'One video per supplier, such as a farm or production tour.' : 'The new video takes the place of the current one.'}</p></div>
      <button type="button" className="approval-close" onClick={onCancel} aria-label="Close" disabled={pending}><Icons.close size={18}/></button>
    </header>
    <form action={action} className="video-form">
      <input type="hidden" name="id" value={id}/><input type="hidden" name="mode" value={mode}/>
      <div className="field"><label htmlFor="video_url">YouTube link</label>
        <input className="input" id="video_url" name="youtube_url" type="url" inputMode="url" placeholder="https://youtu.be/…" required autoFocus defaultValue={mode === 'replace' ? '' : undefined}/></div>
      <div className="field"><label htmlFor="video_title">Title <span className="optional">(optional)</span></label>
        <input className="input" id="video_title" name="title" maxLength={120} placeholder="e.g. Broiler houses, September 2026" defaultValue={mode === 'replace' ? video?.title : ''}/></div>
      <p className="video-note">{uploadEnabled
        ? 'You can also upload a file, which is published to the Omoterra YouTube channel.'
        : 'Paste a link to a video that is already on YouTube. Uploading files straight to the Omoterra YouTube channel will be available once the channel is connected.'}</p>
      {state && !state.ok && <p className="inline-error" role="alert">{state.error}</p>}
      <div className="confirm-actions">
        <button type="button" className="button" data-variant="secondary" onClick={onCancel} disabled={pending}>Cancel</button>
        <button type="submit" className="button" disabled={pending}>{pending ? 'Saving…' : mode === 'add' ? 'Add video' : 'Replace video'}</button>
      </div>
    </form>
  </Modal>;
}

export function SupplierVideoCard({ id, video, uploadEnabled }: { id: string; video: SupplierVideo | null; uploadEnabled: boolean }) {
  const [playing, setPlaying] = useState(false);
  const [form, setForm] = useState<'add' | 'replace' | null>(null);
  const [confirming, setConfirming] = useState(false);
  const remove = useAction(deleteSupplierVideo);
  const [shown, setShown] = useState(video?.id + (video?.updated_at ?? ''));
  const current = video?.id + (video?.updated_at ?? '');
  // A replaced video starts again from its thumbnail.
  if (shown !== current) { setShown(current); setPlaying(false); }

  return <section className="supplier-detail-card video-card" id="video">
    <header>
      <span className="section-title"><Icons.video size={23}/>Supplier video</span>
      {video && <span className="video-limit">1 of 1</span>}
    </header>
    {video ? <div className="video-body">
      <div className="video-frame">
        {playing
          ? <iframe src={`https://www.youtube-nocookie.com/embed/${video.youtube_video_id}?autoplay=1&rel=0`} title={video.title || 'Supplier video'}
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowFullScreen/>
          : <button type="button" className="video-poster" onClick={() => setPlaying(true)} aria-label={`Play ${video.title || 'supplier video'}`} disabled={video.status !== 'ready'}>
              <Image src={video.thumbnail_url} alt="" fill sizes="(max-width: 700px) 100vw, 480px" unoptimized/>
              <span className="video-play">{video.status === 'ready' ? <Icons.play size={30}/> : <span className="add-photo-spinner"/>}</span>
            </button>}
      </div>
      <div className="video-details">
        <div>
          <h3>{video.title || 'Untitled video'}</h3>
          <p>{video.source === 'upload' ? 'Uploaded to the Omoterra YouTube channel' : 'Linked from YouTube'} · {video.updated_at !== video.created_at ? 'Updated' : 'Added'} {date(video.updated_at)}</p>
          {video.status !== 'ready' && <span className="dash-pill" data-tone={video.status === 'failed' ? 'red' : 'amber'}>{video.status === 'failed' ? 'Processing failed' : 'Processing on YouTube'}</span>}
        </div>
        <a href={video.youtube_url} target="_blank" rel="noreferrer" className="video-link">Open on YouTube</a>
        <div className="video-actions">
          <button type="button" className="button" data-variant="secondary" onClick={() => setForm('replace')}><Icons.refresh size={16}/>Replace video</button>
          <button type="button" className="button danger-outline" onClick={() => { remove.reset(); setConfirming(true); }}><Icons.trash size={16}/>Delete</button>
        </div>
        <p className="video-note">Each supplier has one video. Replace it to show a different one.</p>
      </div>
    </div> : <div className="video-empty">
      <span className="video-empty-icon"><Icons.video size={28}/></span>
      <div><strong>No video yet</strong><span>Add one farm or production video for this supplier.</span></div>
      <button type="button" className="button" onClick={() => setForm('add')}><Icons.plus size={18}/>Add video</button>
    </div>}

    {form && <VideoForm id={id} mode={form} video={video} uploadEnabled={uploadEnabled} onDone={() => setForm(null)} onCancel={() => setForm(null)}/>}
    {confirming && <ConfirmDialog title="Delete the supplier video?" message="The video is removed from this supplier's profile. You can add a new one afterwards."
      confirmLabel="Delete video" busy={remove.busy} error={remove.state && !remove.state.ok ? remove.state.error : undefined}
      onCancel={() => setConfirming(false)} onConfirm={() => remove.run({ id }, () => setConfirming(false))}/>}
  </section>;
}
