import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { Card, Definition, Empty, Notice, PageHeader, Status } from '@/components/ui';
import { debtStatus, debtTone } from '@/components/finance/ledger';
import { ApiError, get } from '@/lib/api';
import { day, today } from '@/lib/finance';
import { LOSS_REASONS, LPO_STATUS, lpoTone, type LpoDetail } from '@/lib/lpo';
import {
  cancelLoss, cancelReceipt, closeLpo, extendLpo, issueLpo, receiveBatch, recordLoss, recordLpoAcceptance, uploadSignedCopy,
} from '@/lib/lpo-actions';
import { category, dateTime, phone, quantity, tzs } from '@/lib/format';
import { requireSession } from '@/lib/session';

export const metadata = { title: 'LPO · Omoterra Operations' };

export default async function LpoWorkspace({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const operator = await requireSession();
  const admin = operator.role === 'admin';
  let lpo: LpoDetail;
  try {
    lpo = await get<LpoDetail>(`/ops/lpos/${id}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }
  const now = today();
  const open = lpo.status === 'issued' || lpo.status === 'accepted';
  const supplier = lpo.supplier_snapshot;
  const receiptsActive = lpo.receipts.some((r) => !r.cancelled_at);
  return (
    <>
      <div className="topbar">
        <PageHeader title={lpo.status === 'draft' ? 'Draft LPO' : lpo.lpo_number}
          subtitle={`${supplier.name} · ${day(lpo.delivery_start)} – ${day(lpo.delivery_end)} · created by ${lpo.created_by ?? '—'}`} />
        <div className="row">
          <Status tone={lpoTone(lpo.display_status)}>{LPO_STATUS[lpo.display_status]}</Status>
          {lpo.status === 'draft' && <Link href={`/lpos/${id}/edit`} className="button" data-variant="secondary">Edit draft</Link>}
          <Link href={`/lpo-doc/${id}`} className="button" target="_blank">{lpo.status === 'draft' ? 'Preview document' : 'Open / print LPO'}</Link>
        </div>
      </div>
      <div className="workspace">
        {lpo.display_status === 'expired' && <Notice>The delivery window ended {day(lpo.delivery_end)}. An admin can extend it or close the LPO.</Notice>}
        {lpo.status === 'cancelled' && <Notice>Cancelled {dateTime(lpo.closed_at)}: {lpo.close_reason}</Notice>}

        {lpo.status !== 'draft' && (
          <div className="stat-band">
            <div className="stat"><div className="stat-label">Received value</div><div className="stat-value">{tzs(lpo.received_value)}</div></div>
            <div className="stat"><div className="stat-label">Paid to supplier</div><div className="stat-value">{tzs(lpo.paid_value)}</div></div>
            <div className="stat"><div className="stat-label">Still owed</div><div className="stat-value">{tzs(lpo.owed_value)}</div></div>
            <div className="stat"><div className="stat-label">On hand</div><div className="stat-value">
              {quantity(String(lpo.lines.reduce((sum, l) => sum + Number(l.stock?.on_hand ?? 0), 0)))}</div>
              <div className="meta">birds / units from this LPO not yet sold</div></div>
          </div>
        )}

        <div className="grid-2" style={{ alignItems: 'start' }}>
          <div className="stack">
            <Card title="Items and stock">
              <div className="table-wrap">
                <table>
                  <thead><tr><th>Item</th><th className="numeric">Price</th><th className="numeric">Ordered</th>
                    {lpo.status !== 'draft' && <><th className="numeric">Accepted</th><th className="numeric">Rejected</th><th className="numeric">Sold</th><th className="numeric">Lost</th><th className="numeric">Allocated to locations</th><th className="numeric">On hand</th></>}</tr></thead>
                  <tbody>
                    {lpo.lines.map((line) => (
                      <tr key={line.id}>
                        <td>{line.item}<div className="meta">{line.category ? category(line.category) : ''}{line.min_weight_kg ? ` · ${Number(line.min_weight_kg)}–${Number(line.max_weight_kg ?? line.min_weight_kg)} kg` : ''}</div></td>
                        <td className="numeric">{tzs(line.unit_price)}</td>
                        <td className="numeric">{line.quantity ? quantity(line.quantity) : 'Per batch'}</td>
                        {line.stock && <>
                          <td className="numeric">{quantity(line.stock.accepted)}</td><td className="numeric">{quantity(line.stock.rejected)}</td>
                          <td className="numeric">{quantity(line.stock.sold)}</td><td className="numeric">{quantity(line.stock.lost)}</td>
                          <td className="numeric">{quantity(line.stock.allocated ?? '0')}</td>
                          <td className="numeric money">{Number(line.stock.accepted) > 0
                            ? <Link href={`/stock/lpo_lines/${line.id}`}>{quantity(line.stock.on_hand)}</Link> : quantity(line.stock.on_hand)}</td></>}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Card>

            <Card title="Batches received">
              {lpo.receipts.length === 0 ? <Empty>No batches received yet.</Empty> : (
                <div className="table-wrap">
                  <table>
                    <thead><tr><th>Date</th><th>Counts</th><th className="numeric">Value</th><th>Payment</th>{admin && <th />}</tr></thead>
                    <tbody>
                      {lpo.receipts.map((r) => (
                        <tr key={r.id} style={r.cancelled_at ? { opacity: 0.6 } : undefined}>
                          <td className="small">{day(r.received_on)}<div className="meta">by {r.recorded_by ?? '—'}{r.cancelled_at ? ` · cancelled: ${r.cancel_reason}` : ''}</div></td>
                          <td className="small">{r.lines.map((l) => (
                            <div key={l.lpo_line_id}>{l.item}: {quantity(l.delivered_quantity)} delivered, <strong>{quantity(l.accepted_quantity)} accepted</strong>, {quantity(l.rejected_quantity)} rejected{l.average_weight_kg ? ` · avg ${Number(l.average_weight_kg)} kg` : ''}</div>))}
                            {r.notes && <div className="meta">{r.notes}</div>}</td>
                          <td className="numeric money">{tzs(r.amount)}</td>
                          <td>{r.debt ? <Link href={`/finance/debts/${r.debt.id}`}><Status tone={debtTone(r.debt)}>{debtStatus(r.debt)}</Status></Link> : '—'}
                            {r.debt && <div className="meta">due {day(r.debt.due_on)} · owed {tzs(r.debt.balance)}</div>}
                            {r.debt?.status === 'open' && <div className="small" style={{ marginTop: 'var(--s2)' }}>
                              <Link href={`/finance/supplier-payments?debt=${r.debt.id}`}>Record supplier payment →</Link>
                            </div>}</td>
                          {admin && <td>{!r.cancelled_at && <details><summary className="small">Cancel</summary>
                            <ActionForm action={cancelReceipt} label="Cancel receipt" variant="danger" hidden={{ lpo_id: id, receipt_id: r.id }}
                              confirm="Cancel this batch? Its supplier debt is cancelled too.">
                              <input name="reason" className="input" required minLength={3} placeholder="Reason" aria-label="Reason" />
                            </ActionForm></details>}</td>}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </Card>

            {(lpo.sales.length > 0 || lpo.losses.length > 0) && (
              <Card title="Where the stock went">
                <div className="table-wrap">
                  <table>
                    <tbody>
                      {lpo.sales.map((s) => (
                        <tr key={`${s.sale_id}-${s.lpo_line_id}`} style={s.status === 'cancelled' ? { opacity: 0.6 } : undefined}>
                          <td className="small">{day(s.sold_on)}</td>
                          <td><Link href={`/sales/${s.sale_id}`}>Sold · {s.sale_number}</Link><div className="meta">{s.buyer_name}{s.status === 'cancelled' ? ' · cancelled' : ''}</div></td>
                          <td className="numeric">{quantity(s.quantity)} @ {tzs(s.unit_price)}</td><td />
                        </tr>
                      ))}
                      {lpo.losses.map((l) => (
                        <tr key={l.id} style={l.cancelled_at ? { opacity: 0.6, textDecoration: 'line-through' } : undefined}>
                          <td className="small">{day(l.lost_on)}</td>
                          <td>Lost · {LOSS_REASONS.find(([k]) => k === l.reason)?.[1]}<div className="meta">{l.item}{l.note ? ` · ${l.note}` : ''} · {l.recorded_by}</div></td>
                          <td className="numeric">{quantity(l.quantity)} (cost {tzs(String(Number(l.quantity) * Number(l.unit_cost)))})</td>
                          <td>{admin && !l.cancelled_at && <ActionForm action={cancelLoss} label="Undo" variant="secondary" hidden={{ lpo_id: id, loss_id: l.id }} />}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </Card>
            )}

            <Card title="Details">
              <Definition items={[
                ['Supplier', <Link key="s" href={`/suppliers/${lpo.supplier_id}`}>{supplier.name}</Link>],
                ['Phone', phone(supplier.phone)],
                ['Farm', supplier.farm_address || '—'],
                ['Collection point', lpo.collection_point || '—'],
                ['Payment', `Within ${lpo.payment_terms_days} day${lpo.payment_terms_days === 1 ? '' : 's'} of accepting each batch`],
                ['Basis', lpo.supply_basis === 'fixed' ? 'Fixed quantity' : 'Batch by batch (call off)'],
                ['For demand', lpo.demand ? <Link key="d" href={`/sourcing/${lpo.demand.id}`}>{lpo.demand.requirement_number} · {quantity(lpo.demand.quantity)} {category(lpo.demand.category)} by {lpo.demand.needed_by_date}</Link> : '—'],
                ['Issued', lpo.issued_at ? `${dateTime(lpo.issued_at)} by ${lpo.issuer_name} (${lpo.issuer_position})` : 'Not yet'],
                ['Supplier accepted', lpo.supplier_accepted_at ? `${day(lpo.supplier_accepted_at)} · ${lpo.supplier_accepted_name}${lpo.supplier_accepted_position ? `, ${lpo.supplier_accepted_position}` : ''}` : 'Not yet'],
                ['Signed copy', lpo.signed_copy_media_id ? <a key="c" href={`/media/${lpo.signed_copy_media_id}`} target="_blank">View photo</a> : '—'],
                ['Internal notes', lpo.internal_notes ? <span key="n" style={{ whiteSpace: 'pre-line' }}>{lpo.internal_notes}</span> : '—'],
              ]} />
            </Card>
          </div>

          <div className="stack">
            {lpo.status === 'draft' && (admin ? (
              <Card title="Issue this LPO">
                <p className="small muted" style={{ marginBottom: 'var(--s3)' }}>Issuing gives the LPO its number, puts your signature and the company stamp on it, locks it and notifies the supplier in the app.</p>
                <ActionForm action={issueLpo} label="Issue, sign and stamp" hidden={{ lpo_id: id, idempotency_key: randomUUID() }}
                  confirm="Issue this LPO with your signature and the company stamp? It cannot be edited afterwards.">
                  <div className="field"><label htmlFor="issuer_position">Your position (printed)</label>
                    <input id="issuer_position" name="issuer_position" className="input" defaultValue="Authorized Signatory" /></div>
                  <details><summary className="small">Carry over a paper LPO number</summary>
                    <div className="field"><label htmlFor="lpo_number">LPO number already used on paper</label>
                      <input id="lpo_number" name="lpo_number" className="input" placeholder="e.g. LPO-OMO-2026-0927" /></div></details>
                </ActionForm>
              </Card>
            ) : <Card title="Waiting for an admin"><p className="small muted">An admin issues the LPO with their signature and the company stamp.</p></Card>)}

            {open && (
              <Card title="Record a batch received">
                <ActionForm action={receiveBatch} label="Save batch" hidden={{ lpo_id: id, idempotency_key: randomUUID() }}>
                  <div className="field"><label htmlFor="received_on">Date received</label>
                    <input id="received_on" name="received_on" type="date" className="input" required defaultValue={now < lpo.delivery_end ? now : lpo.delivery_end}
                      min={lpo.delivery_start} max={now < lpo.delivery_end ? now : lpo.delivery_end} /></div>
                  {lpo.lines.map((line) => (
                    <fieldset key={line.id} className="field">
                      <legend className="small strong">{line.item} @ {tzs(line.unit_price)}{line.outstanding ? ` · ${quantity(line.outstanding)} still to deliver` : ''}</legend>
                      <input type="hidden" name="line_id" value={line.id} />
                      <div className="grid-3">
                        <div className="field"><label htmlFor={`d-${line.id}`}>Delivered</label><input id={`d-${line.id}`} name={`delivered_${line.id}`} className="input" inputMode="decimal" /></div>
                        <div className="field"><label htmlFor={`a-${line.id}`}>Accepted</label><input id={`a-${line.id}`} name={`accepted_${line.id}`} className="input" inputMode="decimal" /></div>
                        <div className="field"><label htmlFor={`w-${line.id}`}>Avg kg</label><input id={`w-${line.id}`} name={`weight_${line.id}`} className="input" inputMode="decimal" /></div>
                      </div>
                    </fieldset>
                  ))}
                  <div className="field"><label htmlFor="rnotes">Notes (rejections, condition)</label><input id="rnotes" name="notes" className="input" /></div>
                  <p className="meta">Rejected = delivered − accepted. The accepted value is added to what you owe the supplier, due in {lpo.payment_terms_days} day(s).</p>
                </ActionForm>
              </Card>
            )}

            {lpo.lines.some((l) => Number(l.stock?.on_hand ?? 0) > 0) && (
              <Card title="Record stock lost">
                <ActionForm action={recordLoss} label="Save loss" variant="secondary" hidden={{ lpo_id: id, idempotency_key: randomUUID() }}>
                  <div className="grid-2">
                    <div className="field"><label htmlFor="loss-line">Item</label>
                      <select id="loss-line" name="lpo_line_id" className="input">
                        {lpo.lines.filter((l) => Number(l.stock?.on_hand ?? 0) > 0).map((l) => <option key={l.id} value={l.id}>{l.item} ({quantity(l.stock!.on_hand)} on hand)</option>)}
                      </select></div>
                    <div className="field"><label htmlFor="loss-qty">Quantity</label><input id="loss-qty" name="quantity" className="input" inputMode="decimal" required /></div>
                    <div className="field"><label htmlFor="loss-reason">Reason</label>
                      <select id="loss-reason" name="reason" className="input">{LOSS_REASONS.map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select></div>
                    <div className="field"><label htmlFor="loss-date">Date</label><input id="loss-date" name="lost_on" type="date" className="input" defaultValue={now} max={now} required /></div>
                    <div className="field"><label htmlFor="loss-late">If dated more than 3 days ago: why (admin only)</label><input id="loss-late" name="late_reason" className="input" /></div>
                  </div>
                  <div className="field"><label htmlFor="loss-note">Note</label><input id="loss-note" name="note" className="input" /></div>
                </ActionForm>
              </Card>
            )}

            {open && lpo.status === 'issued' && (
              <Card title="Supplier accepted the LPO">
                <ActionForm action={recordLpoAcceptance} label="Record acceptance" variant="secondary" hidden={{ lpo_id: id }}>
                  <div className="grid-2">
                    <div className="field"><label htmlFor="acc-name">Signed by</label><input id="acc-name" name="name" className="input" defaultValue={supplier.name} required /></div>
                    <div className="field"><label htmlFor="acc-pos">Position</label><input id="acc-pos" name="position" className="input" placeholder="e.g. Owner" /></div>
                    <div className="field"><label htmlFor="acc-date">Date</label><input id="acc-date" name="accepted_on" type="date" className="input" defaultValue={now} max={now} required /></div>
                  </div>
                </ActionForm>
              </Card>
            )}
            {lpo.status !== 'draft' && lpo.status !== 'cancelled' && (
              <Card title="Signed copy">
                <ActionForm action={uploadSignedCopy} label={lpo.signed_copy_media_id ? 'Replace photo' : 'Upload photo'} variant="secondary" hidden={{ lpo_id: id }}>
                  <input name="file" type="file" accept="image/*" className="input" required aria-label="Photo of the signed LPO" />
                  <span className="meta">A photo of the LPO signed by the supplier, kept as evidence.</span>
                </ActionForm>
              </Card>
            )}

            {admin && open && (
              <Card title="Window and closing">
                <ActionForm action={extendLpo} label="Extend delivery window" variant="secondary" hidden={{ lpo_id: id }}>
                  <div className="grid-2">
                    <div className="field"><label htmlFor="ext-end">New last day</label><input id="ext-end" name="delivery_end" type="date" className="input" min={lpo.delivery_end} required /></div>
                    <div className="field"><label htmlFor="ext-reason">Agreed because</label><input id="ext-reason" name="reason" className="input" required minLength={3} /></div>
                  </div>
                </ActionForm>
                <div style={{ marginTop: 'var(--s4)' }}>
                  <ActionForm action={closeLpo} label="Close LPO" variant="danger" hidden={{ lpo_id: id, action: 'close' }}
                    confirm="Close this LPO? Nothing more can be received on it; what is owed stays owed.">
                    <input name="reason" className="input" required minLength={3} placeholder="Reason, e.g. delivery window over" aria-label="Reason" />
                  </ActionForm>
                </div>
              </Card>
            )}
            {admin && (lpo.status === 'draft' || (open && !receiptsActive)) && (
              <Card title="Cancel LPO">
                <ActionForm action={closeLpo} label="Cancel LPO" variant="danger" hidden={{ lpo_id: id, action: 'cancel' }}
                  confirm="Cancel this LPO? It stays in the history as cancelled.">
                  <input name="reason" className="input" required minLength={3} placeholder="Reason" aria-label="Reason" />
                </ActionForm>
              </Card>
            )}
          </div>
        </div>
        <p className="meta"><Link href="/lpos">Back to LPOs</Link></p>
      </div>
    </>
  );
}
