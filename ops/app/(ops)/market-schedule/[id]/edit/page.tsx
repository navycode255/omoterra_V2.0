import { notFound } from 'next/navigation';
import { MarketSlotForm } from '@/components/market/market-slot-form';
import { Card, PageHeader } from '@/components/ui';
import { ApiError, get } from '@/lib/api';
import type { MarketSlot } from '@/lib/market';
import { editMarketSlot } from '@/lib/market-actions';
export default async function EditMarket({ params }: { params: Promise<{ id: string }> }) { const { id } = await params; let slot: MarketSlot; try { slot = await get(`/ops/market-slots/${id}`); } catch (error) { if (error instanceof ApiError && error.status === 404) notFound(); throw error; } return <><div className="topbar"><PageHeader title="Edit market" /></div><div className="workspace"><Card><MarketSlotForm action={editMarketSlot} slot={slot} /></Card></div></>; }
