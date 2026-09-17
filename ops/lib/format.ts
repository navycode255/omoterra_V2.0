import type { InternalStatus } from './types';

const CATEGORIES: Record<string, string> = {
  broilers: 'Broilers',
  local_chicken: 'Local chicken',
  goats: 'Goats',
  cattle: 'Cattle',
  chicken_meat: 'Chicken meat',
  beef: 'Beef',
  goat_meat: 'Goat meat',
};

const UNITS: Record<string, string> = { bird: 'bird', animal: 'animal', kg: 'kg' };

export function category(value: string) {
  return CATEGORIES[value] ?? titleCase(value);
}

export function unit(value: string, quantity?: string) {
  const label = UNITS[value] ?? value;
  if (quantity === undefined) return label;
  return Number(quantity) === 1 || label === 'kg' ? label : `${label}s`;
}

export function titleCase(value: string) {
  return value
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

// Quantities arrive as decimal strings such as "12.000". Trailing zeros are
// dropped for display without converting through a float.
export function quantity(value: string | null | undefined) {
  if (value === null || value === undefined) return '—';
  return value.includes('.') ? value.replace(/\.?0+$/, '') : value;
}

export function money(value: string | null | undefined) {
  if (value === null || value === undefined || value === '') return '—';
  const [whole, fraction = ''] = value.split('.');
  const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  return fraction && Number(fraction) !== 0 ? `${grouped}.${fraction.slice(0, 2)}` : grouped;
}

export function tzs(value: string | null | undefined) {
  const amount = money(value);
  return amount === '—' ? amount : `TZS ${amount}`;
}

export function date(value: string | null | undefined) {
  if (!value) return '—';
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return value;
  return parsed.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
}

export function dateTime(value: string | null | undefined) {
  if (!value) return '—';
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return value;
  return parsed.toLocaleString('en-GB', {
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function reference(id: string, prefix: string) {
  return `${prefix}-${id.replace(/-/g, '').slice(0, 6).toUpperCase()}`;
}

// The fixed mapping from the backend specification. customer_status is derived,
// never set directly, and is shown here only so operators can see what the buyer
// sees on their phone.
export const CUSTOMER_STATUS: Record<InternalStatus, string> = {
  requested: 'Confirmed',
  supply_confirmed: 'Confirmed',
  reserved: 'Confirmed',
  pickup_scheduled: 'Preparing',
  collected: 'Preparing',
  quality_checked: 'Preparing',
  in_transit: 'On the way',
  delivered: 'Delivered',
  completed: 'Delivered',
  cancelled: 'Cancelled',
  payment_failed: 'Cancelled',
};

export const PIPELINE: InternalStatus[] = [
  'requested',
  'supply_confirmed',
  'reserved',
  'pickup_scheduled',
  'collected',
  'quality_checked',
  'in_transit',
  'delivered',
  'completed',
];

export type Tone = 'positive' | 'warning' | 'error' | 'neutral';

export function orderTone(status: InternalStatus): Tone {
  if (status === 'cancelled' || status === 'payment_failed') return 'error';
  if (status === 'delivered' || status === 'completed') return 'positive';
  if (status === 'in_transit' || status === 'collected' || status === 'quality_checked') return 'warning';
  return 'neutral';
}

export function paymentTone(status: string): Tone {
  if (status === 'paid') return 'positive';
  if (status === 'failed') return 'error';
  if (status === 'partial') return 'warning';
  return 'neutral';
}

export function listingTone(status: string): Tone {
  if (status === 'live') return 'positive';
  if (status === 'rejected') return 'error';
  if (status === 'pending_review' || status === 'needs_confirmation') return 'warning';
  return 'neutral';
}

// Listing photos are stored as "/media/{id}" and served through the dashboard's
// authenticated proxy rather than hitting the backend directly from the browser.
export function photoUrl(stored: string) {
  return `/media/${stored.replace('/media/', '')}`;
}

// Mirrors the backend's TRANSITIONS table so the dashboard only offers moves the
// server will accept. The server remains the authority; this avoids dead options.
export const TRANSITIONS: Record<InternalStatus, InternalStatus[]> = {
  requested: ['supply_confirmed', 'cancelled', 'payment_failed'],
  reserved: ['supply_confirmed', 'pickup_scheduled', 'cancelled', 'payment_failed'],
  supply_confirmed: ['pickup_scheduled', 'cancelled', 'payment_failed'],
  pickup_scheduled: ['collected', 'cancelled', 'payment_failed'],
  collected: ['quality_checked', 'cancelled', 'payment_failed'],
  quality_checked: ['in_transit', 'cancelled', 'payment_failed'],
  in_transit: ['delivered', 'cancelled', 'payment_failed'],
  delivered: ['completed'],
  completed: [],
  cancelled: [],
  payment_failed: [],
};
