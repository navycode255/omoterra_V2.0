import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { Card, Definition, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { retryPromotion } from '@/lib/finance-actions';
import type { PromotionDetail } from '@/lib/finance';
import { dateTime, phone, type Tone } from '@/lib/format';
import { requireSession } from '@/lib/session';

export const metadata = { title: 'Promotion · Omoterra Operations' };

const TONE: Record<string, Tone> = { sent: 'positive', queued: 'warning', failed: 'error', skipped: 'neutral' };

export default async function PromotionWorkspace({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const operator = await requireSession();
  let promotion: PromotionDetail;
  try {
    promotion = await get<PromotionDetail>(`/ops/promotions/${id}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }
  const { sms } = promotion;
  return (
    <>
      <div className="topbar">
        <PageHeader title={promotion.title} subtitle={`Sent ${dateTime(promotion.created_at)} by ${promotion.created_by ?? '—'}`} />
      </div>
      <div className="workspace">
        <div className="stat-band">
          <div className="stat"><div className="stat-label">Numbers</div><div className="stat-value">{promotion.recipient_count}</div></div>
          <div className="stat"><div className="stat-label">SMS sent</div><div className="stat-value">{sms.sent}</div><div className="meta">{sms.queued} still sending</div></div>
          <div className="stat"><div className="stat-label">SMS failed</div><div className="stat-value">{sms.failed}</div><div className="meta">{sms.skipped} skipped</div></div>
          <div className="stat"><div className="stat-label">In-app</div><div className="stat-value">{promotion.in_app_count}</div></div>
        </div>
        <div className="grid-2" style={{ alignItems: 'start' }}>
          <Card title="Message">
            <Definition items={[['Title', promotion.title], ['Message', promotion.message],
              ['Channels', [promotion.send_sms && 'SMS', promotion.send_in_app && 'In-app'].filter(Boolean).join(' + ')]]} />
          </Card>
          {operator.role === 'admin' && sms.failed > 0 && (
            <Card title="Failed SMS">
              <p className="small muted" style={{ marginBottom: 'var(--s3)' }}>Try again once the cause is fixed (for example, SMS balance topped up). Numbers already sent are not texted again.</p>
              <ActionForm action={retryPromotion} label={`Retry ${sms.failed} failed`} hidden={{ promotion_id: promotion.id }} />
            </Card>
          )}
        </div>
        <Card title="Recipients">
          <div className="table-wrap">
            <table>
              <thead><tr><th>Name</th><th>Phone</th><th>SMS</th><th>Sent</th></tr></thead>
              <tbody>
                {promotion.recipients.map((r) => (
                  <tr key={r.id}>
                    <td>{r.buyer_profile_id ? <Link href={`/buyers/${r.buyer_profile_id}`}>{r.name || '—'}</Link> : r.name || '—'}</td>
                    <td className="small">{phone(r.phone)}</td>
                    <td><Status tone={TONE[r.sms_status]}>{r.sms_status}</Status>{r.sms_error && <div className="meta">{r.sms_error}</div>}</td>
                    <td className="small">{dateTime(r.sent_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
        <p className="meta"><Link href="/promotions">Back to promotions</Link></p>
      </div>
    </>
  );
}
