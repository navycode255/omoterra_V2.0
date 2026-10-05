import Link from 'next/link';
import { get, ApiError } from '@/lib/api';
import { today, day } from '@/lib/finance';
import { requireSession } from '@/lib/session';
import type { Performance } from '@/lib/locations';
import { LocationDashboard } from '@/components/locations/location-dashboard';
import { Notice } from '@/components/ui';
import styles from '@/components/locations/locations.module.css';
export const metadata={title:'Locations & assets · Omoterra Operations'};
export default async function Locations({searchParams}:{searchParams:Promise<{start?:string;end?:string}>}) {
  const params=await searchParams;const now=today();const start=params.start||`${now.slice(0,8)}01`;const end=params.end||now;
  const operator=await requireSession();let data:{items:Performance[]};
  try{data=await get(`/ops/locations?${new URLSearchParams({start,end})}`);}catch(error){return <div className={styles.page}><h1>Locations &amp; assets</h1><Notice tone="error">{error instanceof ApiError?error.message:'Locations could not be loaded.'}</Notice><Link href="/locations">Reset period</Link></div>;}
  return <div className={`${styles.page} ${styles.dashboard}`}>
    <header className={styles.hero}><div><h1>Locations &amp; assets</h1><p>Compare kitchen investment, trading and operating profit.</p></div></header>
    <div className={styles.dashboardContent}><LocationDashboard items={data.items} start={start} end={end} period={`${day(start)} – ${day(end)}`} admin={operator.role==='admin'} now={now}/></div>
  </div>;
}
