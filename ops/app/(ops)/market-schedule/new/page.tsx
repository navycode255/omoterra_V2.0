import Link from 'next/link';
import { MarketSlotForm } from '@/components/market/market-slot-form';
import { Card, PageHeader } from '@/components/ui';
import { createMarketSlot } from '@/lib/market-actions';
export const metadata = { title: 'Create market · Omoterra Operations' };
export default function NewMarket() { return <><div className="topbar"><PageHeader title="Create market" /></div><div className="workspace"><Card><MarketSlotForm action={createMarketSlot} /></Card><p className="meta"><Link href="/market-schedule">Return to Market Schedule</Link></p></div></>; }
