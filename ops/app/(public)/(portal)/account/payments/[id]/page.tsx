/* eslint-disable @next/next/no-img-element -- receipt is served by an authenticated route */
import { cookies } from 'next/headers';
import { notFound, redirect } from 'next/navigation';
import { PortalShell, type NavItem, type Notice } from '@/components/portal/portal-shell';
import { Icon } from '@/components/portal/icons';
import type { SupplierInvoices } from '@/components/portal/supplier-orders';
import { tzs } from '@/components/portal/supplier-format';
import { MEMBER_COOKIE } from '@/lib/member-cookie';
import { call, PublicApiError } from '@/lib/public-api';

export const metadata = { title: 'Payment details · Omoterra' };
type Member = { phone: string; name: string; roles: string[] };
type Profile = { public_alias: string; legal_name: string; evidence_photos: string[]; payout_methods: string[] };
const nav: NavItem[] = [
  { href: '/account', label: 'Dashboard', icon: 'home' }, { href: '/account/market-schedule', label: 'Market', icon: 'calendar' },
  { href: '/account?view=stock', label: 'Stock', icon: 'box' }, { href: '/account?view=orders', label: 'Orders', icon: 'orders' },
  { href: '/account?view=payouts', label: 'Payouts', icon: 'coins' }, { href: '/account?view=profile', label: 'Profile', icon: 'user' },
];
const methodName = (value: string) => ({ cash: 'Cash', mpesa: 'M-Pesa', airtel_money: 'Airtel Money', tigo_pesa: 'Tigo Pesa', bank_transfer: 'Bank transfer', cheque: 'Cheque', other: 'Other' }[value] ?? value.replaceAll('_', ' '));
const shownDate = (value: string) => new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Africa/Dar_es_Salaam' }).format(new Date(value));

export default async function PaymentDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const token = (await cookies()).get(MEMBER_COOKIE)?.value;
  if (!token) redirect('/login');
  let member: Member;
  try { member = await call<Member>('/me', { token }); }
  catch (error) { if (error instanceof PublicApiError && error.status === 401) redirect('/login'); throw error; }
  if (!member.roles.includes('supplier')) redirect('/account');
  const soft = <T,>(promise: Promise<T>, fallback: T) => promise.catch(() => fallback);
  const [profile, invoices, inbox] = await Promise.all([
    soft(call<Profile | null>('/supplier/profile', { token }), null),
    soft(call<SupplierInvoices>('/supplier/invoices', { token }), { pending_total: '0', paid_total: '0', invoices: [] }),
    soft(call<{ unread: number; items: Notice[] }>('/notifications', { token }), { unread: 0, items: [] }),
  ]);
  const invoice = invoices.invoices.find((row) => row.payments.some((payment) => payment.supplier_payment_id === id));
  const payment = invoice?.payments.find((row) => row.supplier_payment_id === id);
  if (!invoice || !payment) notFound();
  const avatar = profile?.evidence_photos?.[0] ? `/account/media/${profile.evidence_photos[0].split('/').pop()}` : null;
  return <PortalShell name={profile?.public_alias || profile?.legal_name || member.name || member.phone} subtitle="Supplier account" avatar={avatar}
    nav={nav} notices={inbox.items} unread={inbox.unread} activeHref="/account?view=payouts">
    <div className="portal-payment-detail-head"><a href="/account?view=payouts" aria-label="Back to payouts">‹</a><span>Payment details</span></div>
    <section className="portal-payment-amount">
      <strong>{tzs(payment.amount)}</strong><span>{shownDate(payment.paid_on)}</span><b><Icon name="check" />Paid</b>
      <div><small>Invoice amount</small><strong>{tzs(invoice.amount)}</strong></div>
    </section>
    <section className="portal-payment-detail-card">
      <h1><span className="portal-stat-icon"><Icon name="coins" /></span>{methodName(payment.method)}</h1>
      <dl>
        <div><dt>Reference number</dt><dd>{payment.reference || '—'}</dd></div>
        <div><dt>Date</dt><dd>{shownDate(payment.paid_on)}</dd></div>
        <div><dt>Amount</dt><dd>{tzs(payment.amount)}</dd></div>
        <div><dt>Payment method</dt><dd>{methodName(payment.method)}</dd></div>
        <div><dt>Invoice</dt><dd>{invoice.description}</dd></div>
      </dl>
      {payment.sms_text && <div className="portal-payment-sms"><b>Payment message</b><p>{payment.sms_text}</p></div>}
      {payment.has_receipt && <><div className="portal-receipt-preview"><img src={`/account/payment-receipt/${id}`} alt="Payment receipt" /></div><a className="button button-outline portal-proof-button" href={`/account/payment-receipt/${id}`} target="_blank" rel="noreferrer"><Icon name="check" />View proof</a></>}
    </section>
  </PortalShell>;
}
