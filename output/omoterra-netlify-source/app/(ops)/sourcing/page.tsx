import Link from 'next/link';
import { Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { category, date, quantity, titleCase } from '@/lib/format';

export const metadata = { title: 'Buyer demand · Omoterra Operations' };

type Requirement = {
  id: string; requirement_number: string; buyer_name: string; category: string; product_subtype: string;
  quantity: string; unit_type: string; secured_quantity: string; remaining_quantity: string;
  minimum_weight_kg: string | null; maximum_weight_kg: string | null; weight_or_size_requirement: string;
  needed_by_date: string; delivery_region: string; delivery_area: string; requirement_type: string; status: string;
};

function tone(status: string) {
  if (['fully_matched', 'confirmed', 'fulfilling', 'completed'].includes(status)) return 'positive' as const;
  if (status === 'cancelled') return 'error' as const;
  if (['open', 'partially_matched', 'submitted', 'sourcing'].includes(status)) return 'warning' as const;
  return 'neutral' as const;
}

type BuyerOption = { id: string; business_name: string };
const categories = ['broilers','local_chicken','goats','cattle','chicken_meat','beef','goat_meat','eggs'];

export default async function Sourcing({ searchParams }: { searchParams: Promise<{ status?: string; category?: string; region?: string; buyer_id?: string; requirement_type?: string; needed_from?: string; needed_to?: string }> }) {
  const filters = await searchParams;
  let requests: Requirement[];
  let buyers: BuyerOption[] = [];
  try {
    const query = new URLSearchParams(Object.entries(filters).filter((entry): entry is [string, string] => Boolean(entry[1])));
    [requests, buyers] = await Promise.all([get<Requirement[]>(`/ops/requirements${query.size ? `?${query}` : ''}`), get<BuyerOption[]>('/ops/buyer-crm')]);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Buyer demand" /></div><div className="workspace"><Notice tone="error">{error instanceof ApiError ? error.message : 'Buyer demand could not be loaded.'}</Notice></div></>;
  }
  return <>
    <div className="topbar between">
      <PageHeader title="Buyer demand" subtitle="Requirements, supply matching and fulfillment progress." />
      <Link className="button" href="/sourcing/new">Record demand</Link>
    </div>
    <div className="workspace">
      <form method="get" className="grid-3" style={{ marginBottom: 'var(--s4)', alignItems: 'end' }}>
        <div className="field"><label htmlFor="status">Status</label><select className="input" id="status" name="status" defaultValue={filters.status ?? ''}><option value="">All</option>{['open','partially_matched','fully_matched','confirmed','fulfilling','completed','cancelled'].map((status) => <option key={status} value={status}>{titleCase(status)}</option>)}</select></div>
        <div className="field"><label htmlFor="category">Product</label><select className="input" id="category" name="category" defaultValue={filters.category ?? ''}><option value="">All products</option>{categories.map((item) => <option key={item} value={item}>{category(item)}</option>)}</select></div>
        <div className="field"><label htmlFor="buyer_id">Buyer</label><select className="input" id="buyer_id" name="buyer_id" defaultValue={filters.buyer_id ?? ''}><option value="">All buyers</option>{buyers.map((buyer) => <option key={buyer.id} value={buyer.id}>{buyer.business_name}</option>)}</select></div>
        <div className="field"><label htmlFor="region">Region</label><input className="input" id="region" name="region" defaultValue={filters.region ?? ''} /></div>
        <div className="field"><label htmlFor="requirement_type">Frequency</label><select className="input" id="requirement_type" name="requirement_type" defaultValue={filters.requirement_type ?? ''}><option value="">One-time and recurring</option><option value="one_time">One-time</option><option value="recurring">Recurring</option></select></div>
        <div className="field"><label htmlFor="needed_from">Needed between</label><div className="row"><input className="input" id="needed_from" name="needed_from" type="date" defaultValue={filters.needed_from ?? ''} /><input className="input" name="needed_to" type="date" aria-label="Needed by date upper bound" defaultValue={filters.needed_to ?? ''} /></div></div>
        <div className="row"><button className="button" type="submit">Apply filters</button><Link className="button secondary" href="/sourcing">Clear</Link></div>
      </form>
      <div className="table-wrap">
        {requests.length === 0 ? <Empty>No buyer demand matches these filters.</Empty> : <table>
          <thead><tr><th>Requirement</th><th>Buyer</th><th>Product</th><th className="numeric">Quantity</th><th className="numeric">Secured</th><th className="numeric">Remaining</th><th>Needed by</th><th>Location</th><th>Type</th><th>Status</th></tr></thead>
          <tbody>{requests.map((row) => <tr key={row.id}>
            <td><Link href={`/sourcing/${row.id}`} className="strong">{row.requirement_number}</Link></td>
            <td>{row.buyer_name}</td>
            <td>{category(row.category)}{row.product_subtype && <div className="meta">{row.product_subtype}</div>}</td>
            <td className="numeric">{quantity(row.quantity)} {row.unit_type}</td>
            <td className="numeric">{quantity(row.secured_quantity)}</td>
            <td className="numeric">{quantity(row.remaining_quantity)}</td>
            <td className="small">{date(row.needed_by_date)}</td>
            <td className="small">{row.delivery_region || row.delivery_area}</td>
            <td className="small">{titleCase(row.requirement_type)}</td>
            <td><Status tone={tone(row.status)}>{titleCase(row.status)}</Status></td>
          </tr>)}</tbody>
        </table>}
      </div>
    </div>
  </>;
}
