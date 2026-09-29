import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { PortalShell, type NavItem, type Notice } from '@/components/portal/portal-shell';
import { MarketReserve } from '@/components/portal/market-reserve';
import { MarketCancel } from '@/components/portal/market-cancel';
import { Icon } from '@/components/portal/icons';
import { categoryImage, date, label, number, units } from '@/components/portal/supplier-format';
import { MEMBER_COOKIE } from '@/lib/member-cookie';
import type { MarketReservation, MarketSlot } from '@/lib/market';
import { call, PublicApiError } from '@/lib/public-api';

export const metadata = { title: 'Market Schedule · Omoterra' };
type Member = { phone: string; name: string; roles: string[] };
type Profile = { public_alias: string; legal_name: string; evidence_photos: string[] };
const nav: NavItem[] = [{ href: '/account', label: 'Dashboard', icon: 'home' }, { href: '/account/market-schedule', label: 'Market', icon: 'calendar' }, { href: '/account?view=stock', label: 'Stock', icon: 'box' }, { href: '/account?view=orders', label: 'Orders', icon: 'orders' }, { href: '/account?view=payouts', label: 'Payouts', icon: 'coins' }, { href: '/account?view=profile', label: 'Profile', icon: 'user' }];
const statusText: Record<string, string> = { requested: 'Reservation under review', approved: 'Market reserved', rejected: 'Reservation not approved', cancelled: 'Reservation cancelled', completed: 'Delivered' };
export default async function SupplierMarketSchedule({ searchParams }: { searchParams: Promise<{ requested?: string; cancelled?: string }> }) {
  const token = (await cookies()).get(MEMBER_COOKIE)?.value; if (!token) redirect('/login');
  let member: Member; try { member = await call('/me', { token }); } catch (error) { if (error instanceof PublicApiError && error.status === 401) redirect('/login'); throw error; }
  if (!member.roles.includes('supplier')) redirect('/account');
  const soft = <T,>(promise: Promise<T>, fallback: T) => promise.catch(() => fallback);
  const [profile, slots, reservations, inbox] = await Promise.all([
    soft(call<Profile | null>('/supplier/profile', { token }), null), soft(call<MarketSlot[]>('/market-schedule', { token }), []),
    soft(call<MarketReservation[]>('/supplier/market-reservations', { token }), []),
    soft(call<{ unread: number; items: Notice[] }>('/notifications', { token }), { unread: 0, items: [] }),
  ]);
  const { requested, cancelled } = await searchParams;
  const available = slots.filter((slot) => slot.reservations_open && !slot.my_reservation);
  const full = slots.filter((slot) => !slot.reservations_open && slot.status === 'full');
  return <PortalShell name={profile?.public_alias || profile?.legal_name || member.name || member.phone} subtitle="Supplier account" avatar={profile?.evidence_photos?.[0] ? `/account/media/${profile.evidence_photos[0].split('/').pop()}` : null} nav={nav} notices={inbox.items} unread={inbox.unread} activeHref="/account/market-schedule">
    <section className="market-page-head"><div><p>Plan production around real demand</p><h1>Market Schedule</h1></div><Icon name="calendar" /></section>
    {requested && <p className="portal-notice">Reservation submitted for review.</p>}{cancelled && <p className="portal-notice">Reservation cancelled.</p>}
    <div className="market-page-grid"><section><h2 className="portal-section-title">Upcoming demand</h2>
      {available.length ? <div className="market-opportunities">{available.map((slot) => <article key={slot.id} className="market-opportunity"><time><b>{new Date(slot.delivery_date).toLocaleDateString('en-GB', { day: '2-digit', timeZone: 'UTC' })}</b><span>{new Date(slot.delivery_date).toLocaleDateString('en-GB', { month: 'short', timeZone: 'UTC' }).toUpperCase()}</span></time><span className="market-opportunity-photo" style={{ backgroundImage: `url(${categoryImage(slot.category)})` }} /><div className="market-opportunity-main"><h3>{label(slot.category)}</h3><strong>{number.format(Number(slot.remaining_quantity))} {units(slot.category, Number(slot.remaining_quantity))} available</strong><p>{slot.minimum_weight_kg ? `${slot.minimum_weight_kg}–${slot.maximum_weight_kg ?? slot.minimum_weight_kg} kg` : ''}{slot.price_per_unit ? `${slot.minimum_weight_kg ? ' · ' : ''}TZS ${number.format(Number(slot.price_per_unit))} / ${slot.unit_type}` : ''}</p><small>{slot.collection_method === 'omoterra_collects' ? 'Omoterra collects' : 'Supplier delivers'}{slot.region ? ` · ${slot.region}` : ''}</small></div><MarketReserve slot={slot} /></article>)}</div> : <div className="portal-card"><h3>No markets scheduled yet</h3><p className="portal-empty">We’ll show upcoming supply opportunities here.</p></div>}
      {!!full.length && <div className="market-full-list">{full.map((slot, index) => <article key={slot.id}><span>{date.format(new Date(slot.delivery_date))} · {label(slot.category)}</span><b>Fully booked</b>{available[index] && <a href={`#market-${available[index].id}`}>Next available: {date.format(new Date(available[index].delivery_date))}</a>}</article>)}</div>}
    </section><aside><h2 className="portal-section-title">My commitments</h2>{reservations.length ? <div className="market-commitments">{reservations.map((row) => <details key={row.id}><summary><time>{date.format(new Date(row.slot.delivery_date))}</time><b>{number.format(Number(row.quantity_approved ?? row.quantity_requested))} {label(row.slot.category)}</b><span className={`market-state is-${row.status}`}>{statusText[row.status] ?? row.status}</span></summary><dl><div><dt>Requested</dt><dd>{number.format(Number(row.quantity_requested))}</dd></div><div><dt>Approved</dt><dd>{row.quantity_approved ? number.format(Number(row.quantity_approved)) : 'Pending'}</dd></div><div><dt>Production</dt><dd>{row.production_choice === 'planned' ? 'Planned batch' : 'Existing batch'}</dd></div><div><dt>Collection</dt><dd>{row.slot.collection_method === 'omoterra_collects' ? 'Omoterra collection' : 'Supplier delivery'}</dd></div>{row.rejection_reason && <div><dt>Reason</dt><dd>{row.rejection_reason}</dd></div>}</dl>{['requested','approved'].includes(row.status) && new Date(row.slot.reservation_deadline) >= new Date(new Date().toISOString().slice(0, 10)) && <MarketCancel id={row.id} />}</details>)}</div> : <div className="portal-card"><h3>No reservations yet</h3><p className="portal-empty">Reserve an upcoming market when you’re ready to plan your next batch.</p></div>}</aside></div>
  </PortalShell>;
}
