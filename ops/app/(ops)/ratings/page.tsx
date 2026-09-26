import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { dateTime, reference } from '@/lib/format';
import { setRatingHidden } from '@/lib/actions';
import { requireSession } from '@/lib/session';
import { ListControls } from '@/components/list-controls';
import { listPath, type ListParams, type Page } from '@/lib/paging';
import type { RatingRow } from '@/lib/types';

export const metadata = { title: 'Ratings · Omoterra Operations' };

function Stars({ value }: { value: number }) {
  return <span aria-label={`${value} of 5 stars`} style={{ color: '#e8a317', letterSpacing: 1 }}>
    {'★'.repeat(value)}<span style={{ color: '#d6dcd8' }}>{'★'.repeat(5 - value)}</span>
  </span>;
}

const TABS = [
  { key: '', label: 'All' },
  { key: 'visible', label: 'Counting' },
  { key: 'hidden', label: 'Hidden' },
];

export default async function Ratings({ searchParams }: { searchParams: Promise<ListParams> }) {
  await requireSession();
  const params = await searchParams;
  let data: Page<RatingRow>;
  try { data = await get<Page<RatingRow>>(listPath('/ops/ratings', params)); }
  catch (error) { return <><div className="topbar"><PageHeader title="Ratings" /></div><div className="workspace"><Notice tone="error">{error instanceof ApiError ? error.message : 'Ratings could not be loaded.'}</Notice></div></>; }
  return <>
    <div className="topbar"><PageHeader title="Ratings" info="Buyer ratings of delivered orders. Buyers only see a supplier's average; comments stay with Omoterra and the supplier, who never sees the buyer. Hide a rating that is abusive or mistaken and it stops counting." /></div>
    <div className="workspace">
      <ListControls path="/ratings" params={params} data={data} tabs={TABS} noun={['rating', 'ratings']}
        placeholder="Search comment, buyer, supplier or order reference">
      <div className="table-wrap">{data.items.length === 0 ? <Empty>No ratings in this view.</Empty> : <table>
        <thead><tr><th>When</th><th>Rating</th><th>Comment</th><th>Buyer</th><th>Supplier</th><th>Order</th><th /></tr></thead>
        <tbody>{data.items.map((row) => <tr key={row.id} style={row.hidden ? { opacity: .55 } : undefined}>
          <td>{dateTime(row.created_at)}</td>
          <td><Stars value={row.stars} /></td>
          <td>{row.comment || <span className="meta">No comment</span>}</td>
          <td>{row.buyer_name || '—'}</td>
          <td>{row.suppliers.map((s) => <div key={s.id}><Link href={`/suppliers/${s.id}`}>{s.name}</Link></div>)}</td>
          <td><Link href={`/orders/${row.order_id}`}>{reference(row.order_id, 'ORD')}</Link></td>
          <td>{row.hidden
            ? <div className="stack"><Status>Hidden{row.hidden_by ? ` by ${row.hidden_by}` : ''}</Status>
                <ActionForm action={setRatingHidden} layout="row" variant="secondary" label="Show again" hidden={{ id: row.id, hidden: 'false' }} /></div>
            : <ActionForm action={setRatingHidden} layout="row" variant="danger" label="Hide"
                confirm="Hide this rating? It will stop counting toward the supplier's reputation." hidden={{ id: row.id, hidden: 'true' }} />}</td>
        </tr>)}</tbody>
      </table>}</div>
      </ListControls>
    </div>
  </>;
}
