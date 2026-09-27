import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Card, Empty, Notice, PageHeader } from '@/components/ui';
import { ListControls } from '@/components/list-controls';
import { ApiError, get } from '@/lib/api';
import { addOptOut, removeOptOut, sendPromotion } from '@/lib/finance-actions';
import type { Promotion } from '@/lib/finance';
import { dateTime, phone } from '@/lib/format';
import { listPath, type ListParams, type Page } from '@/lib/paging';
import { requireSession } from '@/lib/session';

export const metadata = { title: 'Promotions · Omoterra Operations' };

type Audience = { audience: string; numbers: number; with_app: number; opted_out: number; sms_ready: boolean };
type OptOut = { phone: string; note: string; created_at: string };
const AUDIENCES = [['buyers', 'All buyers'], ['suppliers', 'All suppliers'], ['everyone', 'Buyers and suppliers']] as const;

export default async function Promotions({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  const operator = await requireSession();
  const admin = operator.role === 'admin';
  let data: Page<Promotion>;
  let sizes: Audience[];
  let optOuts: OptOut[];
  try {
    [data, sizes, optOuts] = await Promise.all([
      get<Page<Promotion>>(listPath('/ops/promotions', params)),
      Promise.all(AUDIENCES.map(([key]) => get<Audience>(`/ops/promotions/audience?who=${key}`))),
      get<OptOut[]>('/ops/promotions/opt-outs'),
    ]);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Promotions" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'Promotions could not be loaded.'}</Notice></div></>;
  }
  const smsReady = sizes[0]?.sms_ready;
  return (
    <>
      <div className="topbar">
        <PageHeader title="Promotions" subtitle="Send offers and news to buyers and suppliers by SMS and in the app."
          info="SMS reaches every buyer and supplier with a mobile number, including buyers recorded only through sales. Each SMS costs one message credit per 160 characters." />
      </div>
      <div className="workspace">
        {!smsReady && <Notice>SMS is not set up on this server (OMOTERRA_SMS_PROVIDER is not “sema”). In-app messages still go out; SMS recipients are marked skipped.</Notice>}
        <div className="grid-2" style={{ alignItems: 'start' }}>
          {admin ? (
            <Card title="New promotion">
              <ActionForm action={sendPromotion} label="Send promotion" hidden={{ idempotency_key: randomUUID() }}
                confirm="Send this promotion now? SMS cannot be recalled once sent.">
                <div className="field">
                  <label htmlFor="audience">Send to</label>
                  <select id="audience" name="audience" className="input">
                    {AUDIENCES.map(([key, label], i) => (
                      <option key={key} value={key}>{label} · {sizes[i].numbers} numbers ({sizes[i].with_app} with the app)</option>
                    ))}
                  </select>
                </div>
                <div className="field">
                  <label htmlFor="title">Title (shown in the app)</label>
                  <input id="title" name="title" className="input" required minLength={2} maxLength={80} placeholder="e.g. Kuku wa kienyeji offer" />
                </div>
                <div className="field">
                  <label htmlFor="message">Message</label>
                  <textarea id="message" name="message" className="input" required minLength={5} maxLength={459} rows={5}
                    placeholder="e.g. Omoterra: Kuku wa kienyeji TZS 14,000 wiki hii. Piga 07XX XXX XXX kuagiza." />
                  <span className="meta">Up to 459 characters. 160 characters = 1 SMS; longer messages cost 2 or 3 SMS each. Say who you are and how to order.</span>
                </div>
                <fieldset className="field">
                  <legend>Channels</legend>
                  <div className="row">
                    <label className="row"><input type="checkbox" name="channel" value="sms" defaultChecked />SMS</label>
                    <label className="row"><input type="checkbox" name="channel" value="in_app" defaultChecked />In-app notification</label>
                  </div>
                </fieldset>
              </ActionForm>
            </Card>
          ) : (
            <Card title="New promotion"><p className="muted small">Only admins can send promotions.</p></Card>
          )}

          <Card title={`Do not message (${optOuts.length})`}>
            <p className="muted small" style={{ marginBottom: 'var(--s3)' }}>Numbers that asked to stop receiving promotions. They are left out of every promotion.</p>
            <ActionForm action={addOptOut} label="Add number" variant="secondary">
              <div className="grid-2">
                <div className="field"><label htmlFor="optout-phone">Phone</label><input id="optout-phone" name="phone" className="input" inputMode="tel" required /></div>
                <div className="field"><label htmlFor="optout-note">Note</label><input id="optout-note" name="note" className="input" /></div>
              </div>
            </ActionForm>
            {optOuts.length > 0 && (
              <div className="table-wrap" style={{ marginTop: 'var(--s4)' }}>
                <table>
                  <tbody>
                    {optOuts.map((row) => (
                      <tr key={row.phone}>
                        <td>{phone(row.phone)}<div className="meta">{row.note || '—'} · {dateTime(row.created_at)}</div></td>
                        <td>{admin && <ActionForm action={removeOptOut} label="Remove" variant="secondary" hidden={{ phone: row.phone }} />}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>
        </div>

        <ListControls path="/promotions" params={params} data={data} noun={['promotion', 'promotions']} placeholder="Search title or message">
          <div className="table-wrap">
            {data.items.length === 0 ? <Empty>No promotions sent yet.</Empty> : (
              <table>
                <thead><tr><th>Promotion</th><th>Audience</th><th className="numeric">Numbers</th><th>SMS</th><th className="numeric">In-app</th></tr></thead>
                <tbody>
                  {data.items.map((p) => (
                    <tr key={p.id}>
                      <td><Link href={`/promotions/${p.id}`} className="strong">{p.title}</Link>
                        <div className="meta">{dateTime(p.created_at)} · {p.created_by ?? '—'}</div></td>
                      <td className="small">{AUDIENCES.find(([k]) => k === p.audience)?.[1]}</td>
                      <td className="numeric">{p.recipient_count}</td>
                      <td className="small">{p.send_sms
                        ? `${p.sms.sent} sent${p.sms.queued ? ` · ${p.sms.queued} sending` : ''}${p.sms.failed ? ` · ${p.sms.failed} failed` : ''}${p.sms.skipped ? ` · ${p.sms.skipped} skipped` : ''}`
                        : 'Not sent by SMS'}</td>
                      <td className="numeric">{p.send_in_app ? p.in_app_count : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </ListControls>
      </div>
    </>
  );
}
