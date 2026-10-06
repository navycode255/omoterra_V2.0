import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm } from '@/components/form';
import { Notice, PageHeader } from '@/components/ui';
import { AccountSelect } from '@/components/finance/account-select';
import base from '@/components/finance/cost-states.module.css';
import styles from '@/components/finance/payouts.module.css';
import { ApiError, get } from '@/lib/api';
import { METHODS, day, methodLabel, today } from '@/lib/finance';
import { dateTime, reference, tzs } from '@/lib/format';
import {
  decidePayoutApproval, markPayoutDebited, markPayoutFailed, recordPayoutAttempt, recordPayoutRefund,
  recordPayoutResolution, requestPayoutApproval, requestPayoutResolution, useSupplierCredit,
} from '@/lib/payout-actions';
import {
  APPROVAL_KIND, ATTEMPT_STATE, RESOLUTION, RESOLUTION_KINDS, SEND_KINDS, type PayoutAttempt, type SettlementDetail,
} from '@/lib/payouts';
import { requireSession } from '@/lib/session';

export const metadata = { title: 'Settlement · Omoterra Operations' };

function MethodSelect({ id }: { id: string }) {
  return <div className="field"><label htmlFor={id}>Method</label>
    <select id={id} name="method" className="input" defaultValue="mpesa">
      <option value="">Not recorded</option>
      {METHODS.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
    </select></div>;
}

/**
 * One app payout (build plan M2.7): every attempt to pay it with its state,
 * refunds as separate money in, the supplier's answers, and resends that a
 * second admin approved (decision D9).
 */
export default async function SettlementPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const operator = await requireSession();
  const admin = operator.role === 'admin';
  let data: SettlementDetail;
  try {
    data = await get<SettlementDetail>(`/ops/settlements/${id}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    return <><div className="topbar"><PageHeader title="Settlement" /></div><div className="workspace"><Notice tone="error">
      {error instanceof ApiError ? error.message : 'This settlement could not be loaded.'}</Notice></div></>;
  }
  const next = data.next;
  // Approvals to send money, and approvals to resolve money possibly paid twice (7 October 2026).
  const usable = data.approvals.filter((a) => a.status === 'approved' && !a.used && SEND_KINDS.includes(a.kind));
  const resolvable = data.approvals.filter((a) => a.status === 'approved' && !a.used && RESOLUTION_KINDS.includes(a.kind));
  const pending = data.approvals.filter((a) => a.status === 'pending');
  const needsApproval = !next.blocked && next.approval_kind !== null;
  const hidden = { settlement_id: data.id, idempotency_key: randomUUID() };
  const statusText = data.status === 'cancelled' ? 'Cancelled with its delivery'
    : data.status === 'paid' ? 'Paid' : Number(data.in_flight) > 0 ? 'Sent, debit not confirmed' : 'Not paid';

  return <div className={`workspace ${base.page}`}>
    <div className={base.heading}>
      <div>
        <h1>Payout to {data.supplier_alias || 'supplier'}</h1>
        <p>
          <span className={base.label}>{statusText}</span>{' '}
          {data.order_id ? <Link href={`/orders/${data.order_id}`}>{reference(data.order_id, 'OR')}</Link> : reference(data.order_item_id, 'IT')}
          {' · '}{data.supplier_legal_name}
        </p>
      </div>
      <div className={base.search}>
        <Link href={`/suppliers/${data.supplier_id}`} className="button" data-variant="secondary">Supplier</Link>
        <Link href="/settlements" className="button" data-variant="secondary">All settlements</Link>
      </div>
    </div>

    <section className={styles.stats} aria-label="Payout summary">
      <article className={base.stat}><span>Settlement amount</span><strong>{tzs(data.total_payable)}</strong><small>{tzs(data.supplier_payout_price_per_unit)} × {data.quantity}</small></article>
      <article className={base.stat}><span>Net paid</span><strong data-net-paid>{tzs(data.net_paid)}</strong><small>Debited {tzs(data.debited)} less refunds</small></article>
      <article className={base.stat}><span>Still owed</span><strong>{tzs(data.outstanding)}</strong><small>Amount less net paid</small></article>
      <article className={base.stat}><span>Sent, debit not confirmed</span><strong>{tzs(data.in_flight)}</strong><small>Not money out yet</small></article>
      <article className={base.stat}><span>Refunded</span><strong>{tzs(data.refunded)}</strong><small>Money in, on its own dates</small></article>
      <article className={base.stat}><span>Possibly paid twice</span><strong data-exposure>{tzs(data.exposure)}</strong><small>Until refunded or resolved</small></article>
    </section>

    {Number(data.exposure) > 0 && <p className={styles.danger}>
      {tzs(data.exposure)} may have been paid twice: the supplier says a debited payout never arrived, or more was sent than
      the settlement. Each debited payout stays money out; record a refund on the attempt when money comes back, or, if it
      will not come back, resolve it below with evidence and a second admin&apos;s approval.
    </p>}
    {(Number(data.resolved) > 0 || Number(data.credit_used) > 0 || Number(data.supplier_credit) > 0) && <p className="meta" data-resolved>
      {Number(data.credited) > 0 && `Kept by the supplier as payout credit: ${tzs(data.credited)}. `}
      {Number(data.written_off) > 0 && `Written off as a payout loss: ${tzs(data.written_off)}. `}
      {Number(data.credit_used) > 0 && `Paid from the supplier's payout credit (no money sent): ${tzs(data.credit_used)}. `}
      {Number(data.supplier_credit) > 0 && `The supplier's unused payout credit: ${tzs(data.supplier_credit)}; their next payouts use it first.`}
    </p>}

    {pending.length > 0 && <section className={base.panel}>
      <h2>Waiting for a second admin</h2>
      {pending.map((a) => <div key={a.id} className={styles.approval}>
        <div><b>{APPROVAL_KIND[a.kind]}: {tzs(a.amount)}</b> <span className={styles.meta}>asked by {a.requested_by_name} · {dateTime(a.created_at)}</span></div>
        <div>{a.reason}</div>
        {a.acknowledged && <div className={styles.meta}>Acknowledged that two outflows may exist for this payout.</div>}
        {admin && <div className={styles.actions}>
          {a.requested_by !== operator.id
            ? <ActionForm action={decidePayoutApproval} label="Approve" hidden={{ ...hidden, approval_id: a.id, decision: 'approve' }} layout="row">
                <input name="note" className="input" placeholder="Note (optional)" aria-label="Approval note" />
              </ActionForm>
            : <span className={styles.meta}>You asked for this: another admin must approve it.</span>}
          <ActionForm action={decidePayoutApproval} label={a.requested_by === operator.id ? 'Withdraw' : 'Reject'} variant="secondary"
            hidden={{ ...hidden, approval_id: a.id, decision: 'reject' }} layout="row" />
        </div>}
      </div>)}
    </section>}

    {admin && <section className={base.panel}>
      <h2>{next.resend ? 'Send again' : 'Send the payout'}</h2>
      {next.blocked === 'paid' && <p className="meta">Paid in full. A new payout can be sent only if the supplier reports one
        as not received, a sent one fails, or money comes back.</p>}
      {next.blocked === 'cancelled' && <p className="meta">This payout was cancelled with its order&apos;s delivery.</p>}
      {next.blocked === 'covered_by_credit' && <>
        <p className="meta">The supplier&apos;s payout credit ({tzs(next.credit)}) covers what is owed. No money needs to be sent.</p>
        <ActionForm action={useSupplierCredit} label="Use supplier credit" hidden={hidden} />
      </>}
      {!next.blocked && <>
        {Number(next.credit) > 0 && <p className="meta" data-credit-first>{tzs(next.credit)} of the supplier&apos;s payout credit
          is used first (no money moves); send up to {tzs(next.limit)}.</p>}
        {next.retry_after_failure && <p className="meta">Every earlier attempt failed with evidence (no money left), so this
          retry needs no second admin{Number(next.limit) > Number(data.threshold) ? ` unless it is over ${tzs(data.threshold)}` : ''}.</p>}
        {next.unresolved && <p className={styles.warning}>An earlier payout is not resolved (sent and not confirmed, or the supplier
          says it never arrived). Sending again may mean two outflows. It needs a reason, your acknowledgement and a second admin&apos;s approval.</p>}
        {needsApproval && <details open={!usable.length}>
          <summary>{next.resend ? 'Ask a second admin to approve the resend' : `Ask a second admin to approve (over ${tzs(data.threshold)})`}</summary>
          <ActionForm action={requestPayoutApproval} label="Ask for approval" hidden={hidden}>
            <div className="grid-3">
              <div className="field"><label htmlFor="ask-amount">Amount (TZS)</label><input id="ask-amount" name="amount" className="input" inputMode="decimal" defaultValue={Number(next.limit)} required /></div>
              <div className={`field ${styles.span2}`}><label htmlFor="ask-reason">Reason</label><input id="ask-reason" name="reason" className="input" required minLength={3} placeholder="e.g. Supplier reports nothing arrived on M-Pesa" /></div>
            </div>
            {next.unresolved && <label className={styles.check}><input type="checkbox" name="acknowledge_two_outflows" required />
              I understand two outflows may exist for this payout until the first one is confirmed failed or refunded.</label>}
          </ActionForm>
        </details>}
        {(!needsApproval || usable.length > 0) && <ActionForm action={recordPayoutAttempt} label="Record payout" hidden={hidden}>
          <div className="grid-3">
            {needsApproval && <div className="field"><label htmlFor="approval_id">Approval</label>
              <select id="approval_id" name="approval_id" className="input" required>
                {usable.map((a) => <option key={a.id} value={a.id}>{tzs(a.amount)} · approved by {a.decided_by_name}</option>)}
              </select></div>}
            <div className="field"><label htmlFor="pay-amount">Amount sent (TZS)</label><input id="pay-amount" name="amount" className="input" inputMode="decimal"
              defaultValue={Number(usable[0]?.amount ?? next.limit)} required /><small className="meta">Up to {tzs(next.limit)}</small></div>
            <MethodSelect id="pay-method" />
            <div className="field"><label htmlFor="payment_reference">Reference</label><input id="payment_reference" name="payment_reference" className="input" required minLength={3} /></div>
            <div className="field"><label htmlFor="sent_on">Sent on</label><input id="sent_on" name="sent_on" type="date" className="input" defaultValue={today()} max={today()} required /></div>
            <AccountSelect id="pay-account" label="Paid from account" />
          </div>
          <label className={styles.check}><input type="checkbox" name="debited" />
            The debit is confirmed (statement line or the provider&apos;s message). Leave unticked if it is only sent.</label>
          <div className="field"><label htmlFor="pay-evidence">Evidence</label><input id="pay-evidence" name="evidence" className="input"
            placeholder="e.g. M-Pesa message QAB12XYZ, or statement line 14" /></div>
        </ActionForm>}
      </>}
    </section>}

    {admin && (Number(data.exposure) > 0 || resolvable.length > 0) && <section className={base.panel} data-resolve-panel>
      <h2>Possibly paid twice: resolve</h2>
      <p className="meta">Only when the money will not come back, with evidence. Supplier credit: the supplier received it and
        keeps it; their next payouts use it first. Write-off: it is lost (wrong number, fraud); it becomes an expense
        &ldquo;Payout loss&rdquo; on the day you record it. No money moves either way. A second admin must approve.</p>
      {resolvable.map((a) => <div key={a.id} className={styles.approval}>
        <div><b>{APPROVAL_KIND[a.kind]}: {tzs(a.amount)}</b> <span className={styles.meta}>approved by {a.decided_by_name} · {a.reason}</span></div>
        <ActionForm action={recordPayoutResolution} label={a.kind === 'payout_write_off' ? 'Record write-off' : 'Record supplier credit'}
          hidden={{ ...hidden, approval_id: a.id }} layout="row">
          <input name="resolved_on" type="date" className="input" defaultValue={today()} max={today()} aria-label="Resolution date" required />
        </ActionForm>
      </div>)}
      {Number(data.exposure) > 0 && <details open={!resolvable.length}>
        <summary>Ask a second admin to approve a resolution</summary>
        <ActionForm action={requestPayoutResolution} label="Request resolution" hidden={hidden}>
          <div className="grid-3">
            <div className="field"><label htmlFor="resolve-kind">Resolution</label>
              <select id="resolve-kind" name="kind" className="input" defaultValue="supplier_credit">
                <option value="supplier_credit">Supplier credit: they received it and keep it</option>
                <option value="write_off">Write-off: lost (wrong number, fraud)</option>
              </select></div>
            <div className="field"><label htmlFor="resolve-amount">Amount to resolve (TZS)</label>
              <input id="resolve-amount" name="amount" className="input" inputMode="decimal" defaultValue={Number(data.exposure)} required />
              <small className="meta">Up to {tzs(data.exposure)}</small></div>
            <div className="field"><label htmlFor="resolve-evidence">What shows it</label>
              <input id="resolve-evidence" name="evidence" className="input" required minLength={3} placeholder="e.g. Provider confirms the number belongs to someone else" /></div>
          </div>
        </ActionForm>
      </details>}
    </section>}

    {data.resolutions.length > 0 && <section className={base.panel}>
      <h2>Resolved</h2>
      {data.resolutions.map((r) => <div key={r.id} className={styles.meta} data-resolution={r.kind}>
        {RESOLUTION[r.kind]} {tzs(r.amount)} on {day(r.resolved_on)} · {r.recorded_by} · “{r.evidence}”
      </div>)}
    </section>}

    <section className={base.panel}>
      <h2>Payout attempts</h2>
      {!data.attempts.length && <p className="meta">Nothing sent yet.</p>}
      <div className={styles.attempts}>{data.attempts.map((a) => <Attempt key={a.id} attempt={a} admin={admin} settlementId={data.id} />)}</div>
    </section>

    {data.approvals.some((a) => a.status !== 'pending') && <section className={base.panel}>
      <h2>Approvals</h2>
      {data.approvals.filter((a) => a.status !== 'pending').map((a) => <div key={a.id} className={styles.meta}>
        {APPROVAL_KIND[a.kind]} {tzs(a.amount)}: asked by {a.requested_by_name}, {a.status} by {a.decided_by_name} {dateTime(a.decided_at)}
        {a.used ? ' · used' : a.status === 'approved' ? ' · not used yet' : ''}{a.reason ? ` · “${a.reason}”` : ''}
      </div>)}
    </section>}
  </div>;
}

function Attempt({ attempt: a, admin, settlementId }: { attempt: PayoutAttempt; admin: boolean; settlementId: string }) {
  const hidden = { settlement_id: settlementId, attempt_id: a.id };
  return <article className={styles.attempt} data-state={a.state} data-attempt={a.attempt_no}>
    <div className={styles.attemptHead}>
      <h3>Attempt {a.attempt_no}{a.is_resend ? ' (resend)' : ''} <span className={styles.state} data-state={a.state}>{ATTEMPT_STATE[a.state]}</span></h3>
      <span className={styles.amount}>{tzs(a.amount)}</span>
    </div>
    <dl className={styles.facts}>
      <div><dt>Sent</dt><dd>{day(a.sent_on)} · {a.initiated_by || (a.legacy ? 'before attempts were recorded' : '—')}</dd></div>
      <div><dt>Method and reference</dt><dd>{a.method ? methodLabel(a.method) : 'Not recorded'} · {a.reference || '—'}</dd></div>
      <div><dt>Account</dt><dd>{a.account_name ?? 'No account'}</dd></div>
      {a.state === 'debited' && <div><dt>Debited</dt><dd>{day(a.debited_on)} · {a.debit_evidence}</dd></div>}
      {a.state === 'failed' && <div><dt>Failed</dt><dd>{day(a.failed_on)} · {a.failure_evidence}</dd></div>}
      {a.evidence && a.evidence !== a.debit_evidence && <div><dt>Evidence of sending</dt><dd>{a.evidence}</dd></div>}
      <div><dt>Supplier</dt><dd>{a.supplier_confirmation === 'received' ? `Received · ${dateTime(a.supplier_confirmed_at)}`
        : a.supplier_confirmation === 'not_received' ? `Not received · ${dateTime(a.supplier_confirmed_at)}` : 'No answer yet'}</dd></div>
      {Number(a.refunded) > 0 && <div><dt>Refunded</dt><dd>{tzs(a.refunded)} · kept by the supplier {tzs(a.kept)}</dd></div>}
    </dl>
    {a.answers.filter((x) => x.note).map((x) => <div key={x.created_at} className={styles.meta}>Supplier: “{x.note}”</div>)}
    {a.refunds.map((r) => <div key={r.id} className={styles.meta}>
      Refund {tzs(r.amount)} on {day(r.refunded_on)} · {r.method ? methodLabel(r.method) : 'method not recorded'}{r.reference ? ` · ${r.reference}` : ''} · {r.account_name ?? 'No account'} · {r.evidence}
    </div>)}
    {admin && a.state === 'initiated' && <div className={styles.actions}>
      <details><summary>Mark debited</summary>
        <ActionForm action={markPayoutDebited} label="Mark debited" hidden={hidden}>
          <div className="field"><label htmlFor={`debited-on-${a.id}`}>Debited on</label><input id={`debited-on-${a.id}`} name="debited_on" type="date" className="input" min={a.sent_on} max={today()} defaultValue={today()} required /></div>
          <div className="field"><label htmlFor={`debit-evidence-${a.id}`}>What confirms it</label><input id={`debit-evidence-${a.id}`} name="evidence" className="input" required minLength={3} placeholder="Statement line or provider message" /></div>
        </ActionForm>
      </details>
      <details><summary>Mark failed (no debit)</summary>
        <ActionForm action={markPayoutFailed} label="Mark failed" variant="danger" hidden={hidden}>
          <div className="field"><label htmlFor={`failed-on-${a.id}`}>Failed on</label><input id={`failed-on-${a.id}`} name="failed_on" type="date" className="input" min={a.sent_on} max={today()} defaultValue={today()} required /></div>
          <div className="field"><label htmlFor={`fail-evidence-${a.id}`}>Evidence that no debit happened</label><input id={`fail-evidence-${a.id}`} name="evidence" className="input" required minLength={3} /></div>
        </ActionForm>
      </details>
    </div>}
    {admin && a.state === 'debited' && Number(a.kept) > 0 && <div className={styles.actions}>
      <details><summary>Record a refund (money came back)</summary>
        <ActionForm action={recordPayoutRefund} label="Record refund" hidden={{ ...hidden, idempotency_key: randomUUID() }}>
          <div className="grid-3">
            <div className="field"><label htmlFor={`refund-amount-${a.id}`}>Amount (TZS)</label><input id={`refund-amount-${a.id}`} name="amount" className="input" inputMode="decimal" required /><small className="meta">Up to {tzs(a.kept)}</small></div>
            <div className="field"><label htmlFor={`refunded-on-${a.id}`}>Received on</label><input id={`refunded-on-${a.id}`} name="refunded_on" type="date" className="input" min={a.debited_on ?? undefined} max={today()} defaultValue={today()} required /></div>
            <MethodSelect id={`refund-method-${a.id}`} />
            <div className="field"><label htmlFor={`refund-reference-${a.id}`}>Reference</label><input id={`refund-reference-${a.id}`} name="reference" className="input" /></div>
            <AccountSelect id={`refund-account-${a.id}`} label="Into account" />
          </div>
          <div className="field"><label htmlFor={`refund-evidence-${a.id}`}>Evidence</label><input id={`refund-evidence-${a.id}`} name="evidence" className="input" required minLength={3} placeholder="e.g. Reversal message, statement line" /></div>
        </ActionForm>
      </details>
    </div>}
  </article>;
}
