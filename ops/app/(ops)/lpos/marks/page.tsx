import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Card, Notice, PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { uploadMark } from '@/lib/lpo-actions';
import type { Marks } from '@/lib/lpo';
import { dateTime } from '@/lib/format';

export const metadata = { title: 'Stamp and signature · Omoterra Operations' };

export default async function MarksPage() {
  let marks: Marks;
  try {
    marks = await get<Marks>('/ops/marks');
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Stamp and signature" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Could not be loaded.'}</Notice></div></>;
  }
  const preview = (kind: string, when: string) => (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={`/lpos/marks/preview/${kind}?v=${encodeURIComponent(when)}`} alt={kind}
      style={{ maxWidth: 260, maxHeight: 160, mixBlendMode: 'multiply', border: '1px dashed var(--border)', padding: 8, borderRadius: 8 }} />
  );
  return (
    <>
      <div className="topbar">
        <PageHeader title="Stamp and signature" subtitle="Put on an LPO only when an admin issues it. Stored privately; never downloadable as a file."
          info="Upload a photo or scan on a white background. White prints as transparent on the letterhead." />
      </div>
      <div className="workspace">
        {!marks.admin ? <Notice>Only admins can see or change the company stamp and signatures.</Notice> : (
          <div className="grid-2" style={{ alignItems: 'start' }}>
            <Card title="Company stamp">
              {marks.stamp ? <div className="stack">{preview('stamp', marks.stamp.created_at)}
                <p className="meta">Uploaded {dateTime(marks.stamp.created_at)} by {marks.stamp.uploaded_by}</p></div>
                : <p className="muted small">No stamp yet. LPOs cannot be issued until one is uploaded.</p>}
              <div style={{ marginTop: 'var(--s4)' }}>
                <ActionForm action={uploadMark} label={marks.stamp ? 'Replace stamp' : 'Upload stamp'} variant="secondary" hidden={{ kind: 'stamp' }}
                  confirm={marks.stamp ? 'Replace the company stamp? LPOs already issued keep the old one.' : undefined}>
                  <input type="file" name="file" accept="image/png,image/jpeg,image/webp" className="input" required aria-label="Stamp image" />
                </ActionForm>
              </div>
            </Card>
            <Card title="My signature">
              {marks.my_signature ? <div className="stack">{preview('signature', marks.my_signature.created_at)}
                <p className="meta">Uploaded {dateTime(marks.my_signature.created_at)}</p></div>
                : <p className="muted small">No signature yet. Sign on white paper, photograph it close up, and upload it.</p>}
              <div style={{ marginTop: 'var(--s4)' }}>
                <ActionForm action={uploadMark} label={marks.my_signature ? 'Replace my signature' : 'Upload my signature'} variant="secondary" hidden={{ kind: 'signature' }}>
                  <input type="file" name="file" accept="image/png,image/jpeg,image/webp" className="input" required aria-label="Signature image" />
                </ActionForm>
              </div>
            </Card>
          </div>
        )}
        <p className="meta"><Link href="/lpos">Back to LPOs</Link></p>
      </div>
    </>
  );
}
