import Link from 'next/link';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { PortalShell, type NavItem, type Notice } from '@/components/portal/portal-shell';
import { Icon } from '@/components/portal/icons';
import { SupplierPanel, type Batch, type Hold, type Listing, type Payout, type SupplierProfile } from '@/components/portal/supplier-panel';
import { MEMBER_COOKIE } from '@/lib/member-cookie';
import { call, PublicApiError } from '@/lib/public-api';

export const metadata = { title: 'Your account · Omoterra' };

type Member = { phone: string; name: string; region: string; roles: string[]; buyer_type: string | null };

const buyerTypes: Record<string, string> = {
  personal: 'Personal / household', restaurant: 'Restaurant', butchery: 'Butchery', hotel: 'Hotel',
  retailer: 'Retailer', caterer: 'Caterer', other: 'Other business',
};
const supplierNav: NavItem[] = [
  { href: '#overview', label: 'Dashboard', icon: 'home' }, { href: '#profile', label: 'My profile', icon: 'user' },
  { href: '#stock', label: 'Stock', icon: 'box' }, { href: '#orders', label: 'Orders', icon: 'orders' },
  { href: '#payouts', label: 'Payouts', icon: 'coins' }, { href: '#help', label: 'Help & support', icon: 'help' },
];
const buyerNav: NavItem[] = [
  { href: '#overview', label: 'Dashboard', icon: 'home' }, { href: '#help', label: 'Help & support', icon: 'help' },
];

// Sections load on their own: one failing call shows an empty section, not an error page.
const soft = <T,>(request: Promise<T>, fallback: T) => request.catch(() => fallback);

export default async function Account({ searchParams }: { searchParams: Promise<{ pin?: string }> }) {
  const token = (await cookies()).get(MEMBER_COOKIE)?.value;
  if (!token) redirect('/login');
  let member: Member;
  try {
    member = await call<Member>('/me', { token });
  } catch (error) {
    if (error instanceof PublicApiError && error.status === 401) redirect('/login');
    throw error;
  }
  const supplierRole = member.roles.includes('supplier');
  const [config, inbox, profile, batches, listings, orders, payouts] = await Promise.all([
    soft(call<{ support_phone: string }>('/config'), { support_phone: '' }),
    soft(call<{ unread: number; items: Notice[] }>('/notifications', { token }), { unread: 0, items: [] }),
    supplierRole ? soft(call<SupplierProfile | null>('/supplier/profile', { token }), null) : null,
    supplierRole ? soft(call<Batch[]>('/supplier/batches', { token }), []) : [],
    supplierRole ? soft(call<Listing[]>('/supplier/stock', { token }), []) : [],
    supplierRole ? soft(call<Hold[]>('/supplier/orders', { token }), []) : [],
    supplierRole ? soft(call<Payout[]>('/supplier/payouts', { token }), []) : [],
  ]);
  const { pin } = await searchParams;
  const photo = profile?.evidence_photos[0];
  const buyer = member.roles.includes('buyer');

  return (
    <PortalShell
      name={profile?.public_alias || member.name || member.phone}
      subtitle={profile ? 'Supplier account' : buyer ? 'Buyer account' : 'Omoterra account'}
      avatar={photo ? `/account/media/${photo.split('/').pop()}` : null}
      nav={profile ? supplierNav : buyerNav} notices={inbox.items} unread={inbox.unread}>
      {pin === 'changed' && <p className="portal-notice" role="status">Your PIN has been changed.</p>}
      {profile ? (
        <SupplierPanel phone={member.phone} profile={profile} batches={batches} listings={listings} orders={orders}
          payouts={payouts} supportPhone={config.support_phone} />
      ) : (
        <>
          <section className="portal-hero" id="overview">
            <div><p>Welcome to Omoterra,</p><h1>{member.name || member.phone}<span className="portal-leaf"><Icon name="leaf" /></span></h1></div>
            <div className="portal-hero-art" style={{ backgroundImage: 'url(/images/marketing/cattle-herd-v1.webp)' }} role="img" aria-label="Cattle on a farm" />
          </section>
          {buyer ? (
            <section className="portal-card is-wide">
              <h2><Icon name="cart" />Buyer account</h2>
              <dl className="portal-rows">
                <div><dt>Status</dt><dd><span className="portal-badge is-approved">Active</span></dd></div>
                <div><dt>Phone number</dt><dd>{member.phone}</dd></div>
                {member.region && <div><dt>Region</dt><dd>{member.region}</dd></div>}
                {member.buyer_type && <div><dt>Buyer type</dt><dd>{buyerTypes[member.buyer_type] ?? member.buyer_type}</dd></div>}
              </dl>
              <p className="portal-empty">Buy livestock and request supply in the Omoterra app.</p>
            </section>
          ) : (
            <div className="join-choices">
              <Link className="join-choice-card" href="/register/buyer"><strong>Register as Buyer</strong><span>Buy livestock and request supply</span></Link>
              <Link className="join-choice-card" href="/register/supplier"><strong>Register as Supplier</strong><span>Sell your livestock through Omoterra</span></Link>
            </div>
          )}
          <section className="portal-card is-wide" id="help">
            <h2><Icon name="help" />Help & support</h2>
            <p className="portal-empty">{config.support_phone ? `Call or WhatsApp Omoterra on ${config.support_phone}.` : `Omoterra will contact you on ${member.phone}.`}</p>
          </section>
        </>
      )}
    </PortalShell>
  );
}
