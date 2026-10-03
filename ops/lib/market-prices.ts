// Weight-banded market prices (backend/app/market_prices.py). Shared by the
// ops admin pages and the supplier portal, so keep it free of server-only code.

export type PriceBand = {
  label: string;
  min_weight_kg: string | null;
  max_weight_kg: string | null;
  price_per_unit: string;
  previous_price: string | null;
};
export type PriceListStatus = 'current' | 'scheduled' | 'superseded' | 'withdrawn';
export type PriceList = {
  id: string; category: string; unit_type: string; effective_from: string; published_at: string; note: string;
  status: PriceListStatus; bands: PriceBand[]; gaps: { from_kg: string; to_kg: string }[];
  published_by?: string; withdrawn_at?: string | null; withdrawn_by?: string; withdraw_reason?: string;
};
export type PriceBoard = { category: string; unit_type: string; current: PriceList | null; upcoming: PriceList[] };
export type OpsPrices = { today: string; can_publish: boolean; categories: PriceBoard[] };
export type PriceHistory = { items: PriceList[]; total: number; page: number; page_size: number; actionable: number };

export const PRICE_CATEGORIES = ['broilers', 'local_chicken', 'layers', 'goats', 'cattle', 'chicken_meat', 'beef', 'goat_meat', 'eggs'] as const;
export const PRICE_UNITS: Record<string, string> = {
  broilers: 'bird', local_chicken: 'bird', layers: 'bird', goats: 'animal', cattle: 'animal',
  chicken_meat: 'kg', beef: 'kg', goat_meat: 'kg', eggs: 'tray',
};

export const kg = (value: string | number) => `${Number(value).toFixed(2)} kg`;
export const shillings = (value: string | number) => `TZS ${Math.round(Number(value)).toLocaleString('en-US')}`;

/** A band in words: min is included, max is not. */
export function weightRange(band: { min_weight_kg: string | null; max_weight_kg: string | null }) {
  const { min_weight_kg: min, max_weight_kg: max } = band;
  if (min && max) return `${Number(min).toFixed(2)} – ${kg(max)}`;
  if (min) return `${kg(min)} and above`;
  if (max) return `Below ${kg(max)}`;
  return 'All weights';
}

/** Heaviest band first: suppliers read the ladder from the top price down. */
export const heaviestFirst = (bands: PriceBand[]) => [...bands].reverse();

export function priceChange(band: PriceBand) {
  if (band.previous_price === null) return null;
  const change = Number(band.price_per_unit) - Number(band.previous_price);
  return change === 0 ? null : change;
}

// ---- editor checks, mirroring contracts.MarketPriceListInput ---------------------

export type DraftBand = { key: string; label: string; min: string; max: string; price: string };

const value = (text: string) => text.trim() === '' ? null : Number(text);

export function checkLadder(bands: DraftBand[]) {
  const errors: string[] = [];
  const parsed = bands.map((band) => ({ ...band, from: value(band.min), to: value(band.max), amount: value(band.price) }));
  parsed.forEach((band, index) => {
    const name = band.label.trim() || `Band ${index + 1}`;
    if (band.amount === null || !Number.isFinite(band.amount) || band.amount <= 0) errors.push(`${name}: enter a price above zero.`);
    if ([band.from, band.to].some((x) => x !== null && (!Number.isFinite(x) || x < 0 || x > 2000))) errors.push(`${name}: weights must be between 0 and 2,000 kg.`);
    else if (band.from !== null && band.to !== null && band.from >= band.to) errors.push(`${name}: "from" must be lighter than "to".`);
    if (band.to === 0) errors.push(`${name}: "to" must be above 0 kg.`);
  });
  if (parsed.length > 1 && parsed.some((band) => band.from === null && band.to === null)) errors.push('With more than one price, every band needs a weight range.');
  const ordered = [...parsed].sort((a, b) => (a.from ?? -1) - (b.from ?? -1));
  const gaps: string[] = [];
  for (let i = 1; i < ordered.length; i++) {
    const lower = ordered[i - 1], upper = ordered[i];
    if (lower.to === null || upper.from === null || lower.to > upper.from) {
      errors.push(`${lower.label.trim() || 'A band'} and ${upper.label.trim() || 'another band'} overlap. Each weight can only have one price.`);
    } else if (lower.to < upper.from) gaps.push(`${lower.to.toFixed(2)} – ${upper.from.toFixed(2)} kg`);
  }
  return { errors: [...new Set(errors)], gaps, ordered };
}
