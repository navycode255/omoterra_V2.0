import Link from 'next/link';
import type { ReactNode } from 'react';
import { EditableCard } from './editable-card';
import { Icon, type IconName } from './icons';

export type SupplierProfile = {
  status: string; public_alias: string; legal_name: string; alternate_phone: string; preferred_contact_method: string;
  region: string; district: string; general_area: string; internal_pickup_address: string; pickup_instructions: string;
  omoterra_pickup: boolean; supplier_transport: boolean; categories: string[]; primary_category: string;
  production_profile: Record<string, { capacity: string; unit: string }>; production_frequency: string; supply_forms: string[];
  evidence_photos: string[]; submitted_at: string | null; approved_at: string | null;
};
export type Batch = {
  id: string; category: string; subtype: string; initial_quantity: string; expected_ready_date: string | null;
  expected_min_weight_kg: string | null; expected_max_weight_kg: string | null; form: string; photos: string[];
  status: string; approved_at: string | null; asking_price_per_unit: string | null;
};
export type Listing = { id: string; listing_status: string };
export type Hold = { id: string; status?: string; created_at?: string };
export type Payout = { id: string; total_payable: string; status: string; created_at: string };

const CATEGORY: Record<string, [label: string, one: string, many: string, image: string]> = {
  broilers: ['Broilers', 'bird', 'birds', 'category_broilers.jpg'], local_chicken: ['Local chicken', 'bird', 'birds', 'category_broilers.jpg'],
  layers: ['Layers', 'bird', 'birds', 'category_eggs.jpg'], eggs: ['Eggs', 'tray', 'trays', 'category_eggs.jpg'],
  goats: ['Goats', 'animal', 'animals', 'category_goats.jpg'], cattle: ['Cattle', 'animal', 'animals', 'category_cow.jpg'],
  chicken_meat: ['Chicken meat', 'kg', 'kg', 'category_broilers.jpg'], beef: ['Beef', 'kg', 'kg', 'category_cow.jpg'],
  goat_meat: ['Goat meat', 'kg', 'kg', 'category_goats.jpg'],
};
const FORMS: Record<string, string> = { live: 'Live', dressed: 'Dressed', chilled: 'Chilled', frozen: 'Frozen' };
const CONTACT: Record<string, string> = { phone: 'Phone call', whatsapp: 'WhatsApp', sms: 'Text message' };
const number = new Intl.NumberFormat('en-US', { maximumFractionDigits: 2 });
const date = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Africa/Dar_es_Salaam' });

const label = (category: string) => CATEGORY[category]?.[0] ?? category;
const units = (category: string, quantity: number) => (quantity === 1 ? CATEGORY[category]?.[1] : CATEGORY[category]?.[2]) ?? '';
const media = (url: string) => `/account/media/${url.split('/').pop()}`;
export const categoryImage = (category: string) => `/images/marketing/${CATEGORY[category]?.[3] ?? 'cattle-herd-v1.webp'}`;

function readiness(value: string | null) {
  if (!value) return '—';
  const days = Math.ceil((new Date(value).getTime() - Date.now()) / 86400000);
  if (days <= 0) return 'Ready now';
  if (days < 14) return `Ready in ${days} day${days === 1 ? '' : 's'}`;
  return `Ready in ${Math.round(days / 7)} weeks`;
}

function Rows({ rows }: { rows: [string, ReactNode][] }) {
  const shown = rows.filter(([, value]) => value !== '' && value != null);
  return <dl className="portal-rows">{shown.map(([key, value]) => <div key={key}><dt>{key}</dt><dd>{value}</dd></div>)}</dl>;
}

function Card({ id, icon, title, children, wide }: { id?: string; icon: IconName; title: string; children: ReactNode; wide?: boolean }) {
  return (
    <section id={id} className={`portal-card${wide ? ' is-wide' : ''}`}>
      <h2><Icon name={icon} />{title}</h2>
      {children}
    </section>
  );
}

// Where the registration is: the supplier must always be able to see that
// Omoterra is still reviewing it, and that nothing is sold until approval.
function Status({ profile, live }: { profile: SupplierProfile; live: number }) {
  const approved = profile.status === 'approved';
  const copy: Record<string, [IconName, string, string]> = {
    new: ['alert', 'Registration not finished', 'Complete your supplier registration so the Omoterra team can review it.'],
    under_review: ['clock', 'Account under review', 'Your account is being reviewed by the Omoterra team. Your stock stays private and cannot be sold until your account is approved. We will contact you once the review is complete.'],
    approved: ['check', 'Account approved', live ? 'Your account is approved and your stock is live for buyers.' : 'Your account is approved. Omoterra will publish your stock to buyers once it is verified.'],
    rejected: ['alert', 'Registration not approved', 'Omoterra could not approve this registration. Contact Omoterra support to find out what to change.'],
    suspended: ['alert', 'Account suspended', 'Your account is paused. Contact Omoterra support for help.'],
  };
  const [icon, title, body] = copy[profile.status] ?? copy.under_review;
  const tone = approved ? 'is-approved' : ['rejected', 'suspended'].includes(profile.status) ? 'is-stopped' : 'is-review';
  const steps: [string, string, 'done' | 'current' | 'todo'][] = [
    ['Submitted', profile.submitted_at ? date.format(new Date(profile.submitted_at)) : 'Not yet', profile.submitted_at ? 'done' : 'current'],
    ['Under review', approved ? 'Complete' : 'By Omoterra team', approved ? 'done' : profile.submitted_at ? 'current' : 'todo'],
    ['Approved', profile.approved_at ? date.format(new Date(profile.approved_at)) : 'Pending', approved ? 'done' : 'todo'],
    ['Go live', live ? 'Live' : 'Pending', live ? 'done' : approved ? 'current' : 'todo'],
  ];
  return (
    <section className={`portal-status ${tone}`} role="status">
      <div className="portal-status-head">
        <span className="portal-status-icon"><Icon name={icon} /></span>
        <div>
          <p className="portal-eyebrow">Account status</p>
          <h2>{title}</h2>
          <p>{body}</p>
          {profile.status === 'new' && <Link className="button button-primary" href="/register/supplier">Complete registration</Link>}
        </div>
      </div>
      {!['rejected', 'suspended', 'new'].includes(profile.status) && (
        <ol className="portal-steps">
          {steps.map(([name, note, state]) => (
            <li key={name} className={`is-${state}`}>
              <span className="portal-step-mark">{state === 'done' ? <Icon name="check" /> : null}</span>
              <b>{name}</b><small>{note}</small>
            </li>
          ))}
        </ol>
      )}
    </section>
  );
}

function Stat({ icon, title, value, locked, note }: { icon: IconName; title: string; value: string; locked: boolean; note?: string }) {
  return (
    <div className="portal-stat">
      <span className="portal-stat-icon"><Icon name={icon} /></span>
      <div>
        <span>{title}</span>
        <strong>{value}{locked && <span className="portal-lock" title="Available after approval"><Icon name="lock" /></span>}</strong>
        {note && <small>{note}</small>}
      </div>
    </div>
  );
}

export function SupplierPanel({ phone, profile, batches, listings, orders, payouts, supportPhone }: {
  phone: string; profile: SupplierProfile; batches: Batch[]; listings: Listing[]; orders: Hold[]; payouts: Payout[]; supportPhone: string;
}) {
  const approved = profile.status === 'approved';
  const live = listings.filter((row) => row.listing_status === 'live').length;
  const unitsUsed = new Set(batches.map((batch) => CATEGORY[batch.category]?.[2]));
  const submitted = batches.reduce((sum, batch) => sum + Number(batch.initial_quantity || 0), 0);
  const stockValue = !batches.length ? '0' : unitsUsed.size === 1 ? number.format(submitted) : `${batches.length}`;
  const stockNote = !batches.length ? 'No batch yet' : unitsUsed.size === 1 ? units(batches[0].category, submitted) : 'batches';
  const paid = payouts.filter((row) => row.status === 'paid').reduce((sum, row) => sum + Number(row.total_payable), 0);
  const products = profile.categories.map((key) => {
    const capacity = profile.production_profile?.[key]?.capacity;
    return capacity ? `${label(key)} (${number.format(Number(capacity))} ${units(key, Number(capacity))} / cycle)` : label(key);
  }).join(', ');
  const digits = supportPhone.replace(/\D/g, '');
  const contact = { alternate_phone: profile.alternate_phone, preferred_contact_method: profile.preferred_contact_method,
    internal_pickup_address: profile.internal_pickup_address, pickup_instructions: profile.pickup_instructions };
  return (
    <>
      <section className="portal-hero" id="overview">
        <div>
          <p>Welcome to Omoterra,</p>
          <h1>{profile.public_alias || profile.legal_name}<span className="portal-leaf"><Icon name="leaf" /></span></h1>
        </div>
        <div className="portal-hero-art" style={{ backgroundImage: `url(${categoryImage(profile.primary_category)})` }} role="img" aria-label={`${label(profile.primary_category)} on a farm`} />
      </section>

      <Status profile={profile} live={live} />

      <div className="portal-stats">
        <Stat icon="box" title="Stock submitted" value={stockValue} note={stockNote} locked={false} />
        <Stat icon="cart" title="Live listings" value={String(live)} locked={!approved} />
        <Stat icon="orders" title="Orders" value={String(orders.length)} locked={!approved} />
        <Stat icon="coins" title="Payouts" value={`TZS ${number.format(paid)}`} locked={!approved} />
      </div>

      <div className="portal-grid" id="profile">
        <EditableCard icon="user" title="Profile" kind="contact" contact={contact}>
          <Rows rows={[['Farm / supplier name', profile.public_alias], ['Legal / full name', profile.legal_name], ['Phone number', phone],
            ['Alternate phone', profile.alternate_phone], ['Preferred contact', CONTACT[profile.preferred_contact_method] ?? profile.preferred_contact_method]]} />
        </EditableCard>
        <Card icon="farm" title="Supply details">
          <Rows rows={[['Main category', label(profile.primary_category)], ['Products', products], ['Production cycle', profile.production_frequency],
            ['Supply type', profile.supply_forms.map((key) => FORMS[key] ?? key).join(', ')],
            ['Transport', [profile.omoterra_pickup && 'Omoterra can collect', profile.supplier_transport && 'Own transport'].filter(Boolean).join(' · ')]]} />
          <p className="portal-note">Farm name, region and products are checked by Omoterra. To change them, <a href="#help">contact support</a>.</p>
        </Card>
        <EditableCard icon="pin" title="Location" kind="pickup" contact={contact}>
          <Rows rows={[['Region', profile.region], ['District', profile.district], ['General area', profile.general_area],
            ['Pickup location', profile.internal_pickup_address], ['Pickup instructions', profile.pickup_instructions]]} />
        </EditableCard>
      </div>

      <Card id="stock" icon="box" title="Submitted stock" wide>
        {batches.length ? (
          <ul className="portal-batches">
            {batches.map((batch) => {
              const quantity = Number(batch.initial_quantity);
              const weight = batch.expected_min_weight_kg || batch.expected_max_weight_kg
                ? [batch.expected_min_weight_kg, batch.expected_max_weight_kg].filter(Boolean).map((kg) => number.format(Number(kg))).join(' – ') + ' kg' : '—';
              const reviewed = !!batch.approved_at;
              return (
                <li key={batch.id}>
                  <span className="portal-batch-photo" style={{ backgroundImage: `url(${batch.photos[0] ? media(batch.photos[0]) : categoryImage(batch.category)})` }} />
                  <div className="portal-batch-name">
                    <b>{label(batch.category)}{batch.subtype && <small> · {batch.subtype}</small>}</b>
                    <span className={`portal-badge ${reviewed ? 'is-approved' : 'is-review'}`}>{reviewed ? (batch.status === 'ready' ? 'Ready' : 'Verified') : 'Awaiting Omoterra review'}</span>
                  </div>
                  <div className="portal-batch-facts">
                    <span><b>{number.format(quantity)} {units(batch.category, quantity)}</b><small>Quantity</small></span>
                    <span><b>{weight}</b><small>Expected weight</small></span>
                    <span><b>{readiness(batch.expected_ready_date)}</b><small>{batch.expected_ready_date ? date.format(new Date(batch.expected_ready_date)) : 'Availability'}</small></span>
                    {batch.asking_price_per_unit && <span><b>TZS {number.format(Number(batch.asking_price_per_unit))}</b><small>Asking price / {CATEGORY[batch.category]?.[1] ?? 'unit'} · {FORMS[batch.form] ?? batch.form}</small></span>}
                  </div>
                </li>
              );
            })}
          </ul>
        ) : <p className="portal-empty">No stock batch submitted yet. Add your production in the Omoterra app.</p>}
        {!!profile.evidence_photos.length && (
          <div className="portal-photos">
            {/* eslint-disable-next-line @next/next/no-img-element -- private photo behind the member cookie, which next/image would not send */}
            {profile.evidence_photos.map((url) => <img key={url} src={media(url)} alt="Farm photo" loading="lazy" />)}
          </div>
        )}
      </Card>

      <div className="portal-grid is-two">
        <Card id="orders" icon="orders" title="Orders">
          <p className="portal-empty">{approved
            ? orders.length ? `You have ${orders.length} order${orders.length === 1 ? '' : 's'}. Manage them in the Omoterra app.` : 'No orders yet. Orders for your live stock appear here.'
            : 'Orders open once the Omoterra team approves your account.'}</p>
        </Card>
        <Card id="payouts" icon="coins" title="Payouts">
          <p className="portal-empty">{approved
            ? payouts.length ? `TZS ${number.format(paid)} paid across ${payouts.filter((row) => row.status === 'paid').length} payout(s).` : 'No payouts yet. Payouts follow completed orders.'
            : 'Payouts start after approval and your first completed order.'}</p>
        </Card>
      </div>

      <Card id="help" icon="help" title="Help & support" wide>
        {digits ? (
          <div className="portal-help">
            <p>Questions about your review? Talk to the Omoterra team.</p>
            <a className="button button-light" href={`tel:+${digits}`}><Icon name="phone" />Call {supportPhone}</a>
            <a className="button button-outline" href={`https://wa.me/${digits}`}><Icon name="chat" />WhatsApp</a>
          </div>
        ) : <p className="portal-empty">The Omoterra team will contact you on {phone} about your review.</p>}
      </Card>
    </>
  );
}
