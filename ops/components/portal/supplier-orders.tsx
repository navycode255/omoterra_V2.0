import { Fold } from './fold';
import { Icon } from './icons';
import { PayoutConfirm } from './payout-confirm';
import { categoryImage, date, label, number, tzs, units } from './supplier-format';

// GET /supplier/orders and /supplier/payouts (backend main.supplier_hold and
// main.supplier_payout): the supplier's part of each order, never the buyer.
export type Step = { key: string; done: boolean; at: string | null; note: unknown };
export type PayoutRow = {
  id: string; quantity: string; total_payable: string; status: 'pending' | 'paid'; paid_at: string | null;
  payment_reference: string | null; created_at: string; supplier_confirmation: 'received' | 'not_received' | null;
  supplier_confirmed_at: string | null; category: string | null; reference: string | null; order_hold_id: string | null;
};
export type SupplierOrder = {
  id: string; reference: string; category: string; unit_type: string; quantity: string; created_at: string;
  stage: string; steps: Step[]; accepted_quantity: string | null; rejected_quantity: string | null;
  buyer_payment: string | null; expected_collection_date: string | null; settlements: PayoutRow[];
};

const STAGE: Record<string, [text: string, tone: 'progress' | 'review' | 'approved' | 'stopped']> = {
  reserved: ['Buyer is checking out', 'progress'],
  confirmed: ['Order confirmed · collection to be scheduled', 'progress'],
  collection_scheduled: ['Collection scheduled', 'progress'],
  collected: ['Collected and checked', 'progress'],
  in_transit: ['On the way to the buyer', 'progress'],
  awaiting_buyer_payment: ['Delivered · waiting for buyer payment', 'review'],
  awaiting_payout: ['Buyer paid · your payout is being prepared', 'review'],
  confirm_payout: ['Payout sent · please confirm', 'review'],
  payout_disputed: ['Payout reported not received', 'stopped'],
  payout_confirmed: ['Completed · payout received', 'approved'],
  cancelled: ['Cancelled', 'stopped'],
};
const STEP: Record<string, string> = {
  ordered: 'Order placed', collection_scheduled: 'Collection scheduled', collected: 'Collected and checked',
  in_transit: 'On the way to the buyer', delivered: 'Delivered to the buyer', buyer_paid: 'Buyer paid Omoterra',
  payout_sent: 'Omoterra sent your payout', payout_confirmed: 'You confirmed you received it',
};

const when = (value: string | null) => (value ? date.format(new Date(value)) : '');
const amount = (category: string, value: string) => `${number.format(Number(value))} ${units(category, Number(value))}`;

export function StageBadge({ stage }: { stage: string }) {
  const [text, tone] = STAGE[stage] ?? [stage, 'progress'];
  return <span className={`portal-badge is-${tone}`}>{text}</span>;
}

function stepNote(order: SupplierOrder, step: Step) {
  if (step.key === 'collection_scheduled' && order.expected_collection_date) return `Collection on ${when(order.expected_collection_date)}`;
  if (step.key === 'collected' && order.accepted_quantity != null) {
    const rejected = Number(order.rejected_quantity ?? 0);
    return `${amount(order.category, order.accepted_quantity)} accepted${rejected ? ` · ${amount(order.category, String(rejected))} not accepted` : ''}`;
  }
  const payout = order.settlements[0];
  if (step.key === 'payout_sent' && payout?.paid_at) return `${tzs(payout.total_payable)}${payout.payment_reference ? ` · Ref ${payout.payment_reference}` : ''}`;
  return '';
}

// One payout the supplier still has to answer about, or one they reported.
export function PayoutPrompt({ payout }: { payout: PayoutRow }) {
  const disputed = payout.supplier_confirmation === 'not_received';
  return (
    <div className={`portal-payout-prompt${disputed ? ' is-disputed' : ''}`}>
      <span className="portal-payout-icon"><Icon name="coins" /></span>
      <div>
        <b>{disputed ? 'You reported this payout as not received' : `Omoterra sent you ${tzs(payout.total_payable)}`}</b>
        <p>
          {payout.category ? `${label(payout.category)} · ` : ''}{payout.reference ? `Order ${payout.reference} · ` : ''}
          Sent {when(payout.paid_at)}{payout.payment_reference ? ` · Ref ${payout.payment_reference}` : ''}
        </p>
        <p className="portal-muted">{disputed
          ? 'Omoterra has been alerted and will check the transfer with you. Tell us here once the money arrives.'
          : 'Check your account, then confirm. We keep this record for both of us.'}</p>
        <PayoutConfirm id={payout.id} disputed={disputed} />
      </div>
    </div>
  );
}

export function OrderList({ orders }: { orders: SupplierOrder[] }) {
  return (
    <ul className="portal-batches portal-orders">
      {orders.map((order) => {
        const current = order.steps.find((step) => !step.done)?.key;
        const payout = order.settlements[0];
        return (
          <Fold key={order.id} as="li" className="portal-batch" always head={<>
            <span className="portal-batch-photo" style={{ backgroundImage: `url(${categoryImage(order.category)})` }} />
            <span className="portal-batch-name">
              <b>{label(order.category)}<small> · Order {order.reference}</small></b>
              <span className="portal-batch-meta">{amount(order.category, order.quantity)} · {when(order.created_at)}</span>
              <StageBadge stage={order.stage} />
            </span>
          </>}>
            {order.steps.length ? (
              <ol className="portal-timeline">
                {order.steps.map((step) => {
                  const state = step.done ? 'done' : order.stage !== 'cancelled' && step.key === current ? 'current' : 'todo';
                  const note = stepNote(order, step);
                  return (
                    <li key={step.key} className={`is-${state}`}>
                      <span className="portal-timeline-mark">{step.done && <Icon name="check" />}</span>
                      <div><b>{STEP[step.key] ?? step.key}</b>{(note || step.at) && <small>{[note, when(step.at)].filter(Boolean).join(' · ')}</small>}</div>
                    </li>
                  );
                })}
              </ol>
            ) : <p className="portal-empty">A buyer is completing checkout for this stock. It becomes an order once they confirm.</p>}
            {payout && (payout.status === 'paid' && payout.supplier_confirmation !== 'received'
              ? <PayoutPrompt payout={payout} />
              : <p className="portal-note">Payout {tzs(payout.total_payable)} · {payout.supplier_confirmation === 'received'
                ? `you confirmed receipt on ${when(payout.supplier_confirmed_at)}` : 'not sent yet'}</p>)}
          </Fold>
        );
      })}
    </ul>
  );
}

export function PayoutList({ payouts }: { payouts: PayoutRow[] }) {
  const state = (row: PayoutRow): [string, string] => row.status === 'pending' ? ['Not sent yet', 'progress']
    : row.supplier_confirmation === 'received' ? [`Received · ${when(row.supplier_confirmed_at)}`, 'approved']
    : row.supplier_confirmation === 'not_received' ? ['Reported not received', 'stopped'] : ['Sent · please confirm', 'review'];
  return (
    <ul className="portal-payouts">
      {payouts.map((row) => {
        const [text, tone] = state(row);
        return (
          <li key={row.id}>
            <div><b>{tzs(row.total_payable)}</b><small>{[row.category && label(row.category), row.reference && `Order ${row.reference}`, row.payment_reference && `Ref ${row.payment_reference}`].filter(Boolean).join(' · ')}</small></div>
            <span className={`portal-badge is-${tone}`}>{text}</span>
          </li>
        );
      })}
    </ul>
  );
}
