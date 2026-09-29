import Link from 'next/link';
import { Empty, Notice, PageHeader, Status } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import { category, date, quantity, tzs } from '@/lib/format';
import type { MarketSlot } from '@/lib/market';

export const metadata = { title: 'Market Schedule · Omoterra Operations' };
const tone = (status: string) => status === 'open' ? 'positive' : status === 'cancelled' ? 'error' : status === 'full' ? 'warning' : 'neutral';
export default async function MarketSchedule() {
  let slots: MarketSlot[];
  try { slots = await get<MarketSlot[]>('/ops/market-slots'); }
  catch (error) { return <><div className="topbar"><PageHeader title="Market Schedule" /></div><div className="workspace"><Notice tone="error">{error instanceof ApiError ? error.message : 'Markets could not be loaded.'}</Notice></div></>; }
  return <><div className="topbar between"><PageHeader title="Market Schedule" /><Link className="button" href="/market-schedule/new">Create market</Link></div>
    <div className="workspace"><div className="market-ops-grid">{slots.length ? slots.map((slot) => <Link className="card market-ops-card" href={`/market-schedule/${slot.id}`} key={slot.id}>
      <div className="between"><strong>{category(slot.category)}</strong><Status tone={tone(slot.status)}>{slot.status === 'full' ? 'Fully booked' : slot.status}</Status></div>
      <b className="market-ops-date">{date(slot.delivery_date)}</b>
      <div className="market-capacity"><span><b>{quantity(slot.quantity_required)}</b><small>required</small></span><span><b>{quantity(slot.committed_quantity)}</b><small>committed</small></span><span><b>{quantity(slot.remaining_quantity)}</b><small>remaining</small></span></div>
      <p className="meta">{slot.supplier_count} {slot.supplier_count === 1 ? 'supplier' : 'suppliers'} · deadline {date(slot.reservation_deadline)}{slot.price_per_unit ? ` · ${tzs(slot.price_per_unit)} / ${slot.unit_type}` : ''}</p>
    </Link>) : <Empty>No markets scheduled yet.</Empty>}</div></div></>;
}
