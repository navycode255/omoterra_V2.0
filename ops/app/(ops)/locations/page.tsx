import Link from 'next/link';
import { get, ApiError } from '@/lib/api';
import { today, day } from '@/lib/finance';
import { tzs } from '@/lib/format';
import { requireSession } from '@/lib/session';
import type { Performance } from '@/lib/locations';
import { LocationForm } from '@/components/locations/location-forms';
import { Notice } from '@/components/ui';
import styles from '@/components/locations/locations.module.css';
export const metadata={title:'Locations & assets · Omoterra Operations'};
export default async function Locations({searchParams}:{searchParams:Promise<{start?:string;end?:string}>}) {
  const params=await searchParams;const now=today();const start=params.start||`${now.slice(0,8)}01`;const end=params.end||now;
  const operator=await requireSession();let data:{items:Performance[]};
  try{data=await get(`/ops/locations?${new URLSearchParams({start,end})}`);}catch(error){return <div className={styles.page}><h1>Locations &amp; assets</h1><Notice tone="error">{error instanceof ApiError?error.message:'Locations could not be loaded.'}</Notice><Link href="/locations">Reset period</Link></div>;}
  return <div className={styles.page}>
    <header className={styles.heading}><div><h1>Locations &amp; assets</h1><p>Compare kitchen investment, trading and operating profit.</p></div>
      <form className={styles.filters} action="/locations"><label>Start date<input type="date" name="start" defaultValue={start} max={now} required/></label><label>End date<input type="date" name="end" defaultValue={end} max={now} required/></label><button className="button">Apply period</button></form>
    </header>
    <section className={styles.panel}><h2>Location performance · {day(start)} – {day(end)}</h2><p className={styles.muted}>Profit deducts stock sold, labour, running costs, losses and depreciation. Shared costs without a location remain in business profit.</p>
      <div className={styles.tableWrap}><table data-phone-native className={styles.table}><thead><tr><th>Location</th><th>Investment</th><th>Sales</th><th>Stock sold cost</th><th>Labour</th><th>Running costs</th><th>Losses</th><th>Depreciation</th><th>Profit</th><th>Period return</th></tr></thead><tbody>
        {data.items.map(row=><tr key={row.id}><th><Link href={`/locations/${row.id}?${new URLSearchParams({start,end})}`}>{row.name}</Link><small>{row.active?'Open':'Closed'} · target {row.daily_target} chickens/day</small></th><td>{tzs(row.investment)}</td><td>{tzs(row.revenue)}</td><td>{tzs(row.stock_cost)}</td><td>{tzs(row.labour)}</td><td>{tzs(row.running_costs)}</td><td>{tzs(row.stock_lost)}</td><td>{tzs(row.depreciation)}</td><td className={Number(row.net_profit)<0?styles.negative:styles.positive}>{tzs(row.net_profit)}{row.unknown_cost_lines>0&&<small>Provisional costs</small>}</td><td>{row.period_return_pct===null?'—':`${row.period_return_pct}%`}</td></tr>)}
      </tbody></table></div>{!data.items.length&&<p>Add your first location, then register its assets and daily stock.</p>}
      <p className={styles.muted}>Investment is asset purchase cost plus other capital you record, through the period end. Period return is this period’s profit divided by investment; it is not an annual return or cash payback.</p>
    </section>
    {operator.role==='admin'&&<details className={styles.panel}><summary>Add a location</summary><LocationForm kind="location" label="Create location">
      <label>Location name<input name="name" required minLength={2} maxLength={150} placeholder="Kitchen A"/></label><label>Address<input name="address"/></label><label>Daily chicken allocation target<input name="daily_target" type="number" min="0" step="1" defaultValue="20"/></label><label>Notes<input name="notes"/></label>
    </LocationForm></details>}
  </div>;
}
