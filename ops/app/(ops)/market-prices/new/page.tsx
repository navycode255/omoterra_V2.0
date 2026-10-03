import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { Notice, PageHeader } from '@/components/ui';
import { PriceEditor } from '@/components/market-prices/price-editor';
import { ApiError, get } from '@/lib/api';
import { PRICE_CATEGORIES, type OpsPrices, type PriceBand } from '@/lib/market-prices';
import { param, type ListParams } from '@/lib/paging';

export const metadata = { title: 'Update market prices · Omoterra Operations' };

export default async function NewMarketPrices({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  let prices: OpsPrices;
  try { prices = await get<OpsPrices>('/ops/market-prices'); }
  catch (error) {
    return <><div className="topbar"><PageHeader title="Update market prices"/></div><div className="workspace"><Notice tone="error">{error instanceof ApiError ? error.message : 'Market prices could not be loaded.'}</Notice></div></>;
  }
  if (!prices.can_publish) {
    return <><div className="topbar"><PageHeader title="Update market prices"/></div><div className="workspace"><Notice>Only admins can publish market prices.</Notice><Link className="button" data-variant="secondary" href="/market-prices">Back to market prices</Link></div></>;
  }
  const requested = param(params, 'category');
  const initial = PRICE_CATEGORIES.includes(requested as never) ? requested : 'broilers';
  // The editor starts from the newest prices, scheduled or live.
  const current: Record<string, PriceBand[]> = Object.fromEntries(prices.categories
    .map((row) => [row.category, (row.upcoming.at(-1) ?? row.current)?.bands ?? []]));
  const max = new Date(`${prices.today}T00:00:00Z`);
  max.setUTCDate(max.getUTCDate() + 90);
  return <>
    <div className="topbar"><PageHeader title="Update market prices" subtitle="Set what Omoterra pays for each weight. Suppliers see these prices on their dashboard."/></div>
    <div className="workspace">
      <PriceEditor initialCategory={initial} current={current} today={prices.today} maxDate={max.toISOString().slice(0, 10)} formKey={randomUUID()}/>
    </div>
  </>;
}
