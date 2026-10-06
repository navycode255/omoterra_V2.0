import Link from 'next/link';
import { notFound } from 'next/navigation';
import { get,ApiError } from '@/lib/api';
import { day,today,type SupplierCollectionStock } from '@/lib/finance';
import type { LpoStockRow } from '@/lib/lpo';
import type { LocationDetail } from '@/lib/locations';
import { tzs } from '@/lib/format';
import { requireSession } from '@/lib/session';
import { Notice } from '@/components/ui';
import { Icons } from '@/components/icons';
import { InfoTip } from '@/components/info-tip';
import { ExpenseWorkspace } from '@/components/finance/expense-workspace';
import { AllocationForm, DailySaleForm, LocationForm } from '@/components/locations/location-forms';
import styles from '@/components/locations/locations.module.css';
const quantities=(values:Record<string,string>)=>Object.entries(values).map(([key,value])=>`${Number(value).toLocaleString('en-US')} ${key.split(':')[1]} · ${key.split(':')[0].replaceAll('_',' ')}`).join('; ')||'—';
export const metadata={title:'Location · Omoterra Operations'};
export default async function Location({params,searchParams}:{params:Promise<{id:string}>;searchParams:Promise<{start?:string;end?:string}>}) {
  const {id}=await params;const query=await searchParams;const now=today();const start=query.start||`${now.slice(0,8)}01`;const end=query.end||now;const operator=await requireSession();const admin=operator.role==='admin';
  let data:LocationDetail;let stock:LpoStockRow[];let collections:SupplierCollectionStock[];let opening:{id:string;description:string;unit:string;on_hand:string}[];
  try{[data,stock,collections,opening]=await Promise.all([get<LocationDetail>(`/ops/locations/${id}?${new URLSearchParams({start,end})}`),get<LpoStockRow[]>('/ops/lpos/stock'),get<SupplierCollectionStock[]>('/ops/supplier-collections/stock'),get<typeof opening>('/ops/location-opening-stock')]);}
  catch(error){if(error instanceof ApiError&&error.status===404)notFound();return <div className={styles.page}><Notice tone="error">{error instanceof ApiError?error.message:'Location could not be loaded.'}</Notice><Link href={`/locations/${id}`}>Reset period</Link></div>;}
  return <div className={`${styles.page} ${styles.locationDetail}`}>
    <Link className={styles.backLink} href="/locations">← All locations</Link><header className={`${styles.heading} ${styles.detailHeading}`}><div><h1>{data.name}</h1><p>{data.address||'Kitchen / operating location'} · {data.active?'Open':'Closed'} · Target {Number(data.daily_target).toLocaleString('en-US')} chickens/day</p></div>
      <form className={styles.filters} action={`/locations/${id}`}><label>Start date<input name="start" type="date" defaultValue={start} max={now} required/></label><label>End date<input name="end" type="date" defaultValue={end} max={now} required/></label><button className="button">Apply period</button></form>
    </header>
    {data.unknown_cost_lines>0&&<Notice>Some sales are missing buying costs. This location’s result is provisional.</Notice>}
    <section className={`${styles.metrics} ${styles.detailMetrics}`} aria-label="Location summary">
      <article><span className={styles.metricIcon}><Icons.wallet size={23}/></span><span>Investment <InfoTip label="About location investment">Assets and other capital recorded through the end of the selected period.</InfoTip></span><strong>{tzs(data.investment)}</strong></article>
      <article><span className={styles.metricIcon}><Icons.chart size={23}/></span><span>Sales</span><strong>{tzs(data.revenue)}</strong><small>{data.sale_count} sales recorded</small></article>
      <article><span className={styles.metricIcon}><Icons.trend size={23}/></span><span>Operating profit <InfoTip label="About operating profit">Profit after stock sold, labour, running costs and losses, before depreciation.</InfoTip></span><strong className={Number(data.profit_before_depreciation)<0?styles.negative:styles.positive}>{tzs(data.profit_before_depreciation)}</strong></article>
      <article><span className={styles.metricIcon}><Icons.coins size={23}/></span><span>Net profit <InfoTip label="About net profit">Profit after depreciation. Period return is profit divided by recorded investment, not an annual return.</InfoTip></span><strong className={Number(data.net_profit)<0?styles.negative:styles.positive}>{tzs(data.net_profit)}</strong><small>Return {data.period_return_pct===null?'—':`${data.period_return_pct}%`}</small></article>
    </section>
    <nav className={styles.detailNav} aria-label="Location sections"><a href="#daily-performance">Performance</a><a href="#location-stock">Stock</a><a href="#location-assets">Assets</a></nav>
    <section id="daily-performance" className={styles.panel}><div className={styles.sectionTitle}><Icons.trend size={22}/><h2>Daily performance</h2><InfoTip label="About daily performance">Stock cost is charged when goods are sold. Allocating stock is an internal transfer. Labour and running costs include unpaid expenses. Dates follow the selected period.</InfoTip></div><p className={styles.periodCaption}>{day(start)} – {day(end)}</p>
      <div className={styles.tableWrap}><table data-phone-native className={styles.table}><thead><tr><th>Day</th><th>Stock allocated</th><th>Quantity sold</th><th>Sales</th><th>Stock cost</th><th>Labour</th><th>Running costs</th><th>Losses</th><th>Depreciation</th><th>Profit</th></tr></thead><tbody>{data.days.map(d=><tr key={d.date}><th>{day(d.date)}</th><td>{quantities(d.allocated)}</td><td>{quantities(d.sold)}</td><td>{tzs(d.revenue)}</td><td>{tzs(d.stock_cost)}</td><td>{tzs(d.labour)}</td><td>{tzs(d.running_costs)}</td><td>{tzs(d.stock_lost)}</td><td>{tzs(d.depreciation)}</td><td className={Number(d.net_profit)<0?styles.negative:styles.positive}>{tzs(d.net_profit)}</td></tr>)}</tbody></table></div>
      {!data.days.length&&<div className={styles.detailEmpty}><Icons.calendar size={30}/><strong>No activity in this period</strong><span>Allocate stock or record a sale to get started.</span></div>}
    </section>
    {data.active&&<div className={styles.grid}>
      <details className={styles.panel}><summary><Icons.box size={20}/>Allocate stock</summary><AllocationForm id={id} now={now} stock={stock} collections={collections} opening={opening} admin={admin}/></details>
      <details className={styles.panel}><summary><Icons.file size={20}/>Record daily sales</summary><DailySaleForm id={id} now={now} allocations={data.allocations}/></details>
      <section className={styles.panel}><div className={styles.sectionTitle}><Icons.wallet size={22}/><h2>Labour &amp; running costs</h2><InfoTip label="About location expenses">Record labour, charcoal, rent, transport or other operating costs for this location.</InfoTip></div><ExpenseWorkspace now={now} saleId="" locationId={id} locationName={data.name}/><p><Link href={`/finance/expenses?${new URLSearchParams({location_id:id,start,end})}`}>View this location’s expenses</Link></p></section>
      <details className={styles.panel}><summary><Icons.truck size={20}/>Return stock / record a loss</summary><LocationForm kind="stock-event" id={id} label="Record stock movement">
        <label>Allocated stock<select name="allocation_id" required><option value="">Choose stock</option>{data.allocations.filter(a=>Number(a.on_hand)>0).map(a=><option key={a.id} value={a.id}>{a.description} · {a.on_hand} {a.unit} left</option>)}</select></label>
        <label>What happened<select name="event_kind"><option value="returned">Returned to central stock</option><option value="lost">Lost / spoiled / not recovered</option></select></label>
        <label>Date<input name="occurred_on" type="date" defaultValue={now} max={now} required/></label><label>Quantity<input name="quantity" type="number" min="0.001" step="0.001" required/></label><label>Reason / condition<input name="note" required minLength={3}/></label>
      </LocationForm></details>
    </div>}
    <section id="location-stock" className={styles.panel}><div className={styles.sectionTitle}><Icons.box size={22}/><h2>Stock at this location · current</h2></div><p>{quantities(data.on_hand)}</p><div className={styles.tableWrap}><table data-phone-native className={styles.table}><thead><tr><th>Allocated</th><th>Product</th><th>Source</th><th>Given</th><th>Sold</th><th>Returned</th><th>Lost</th><th>Remaining</th><th>Cost / unit</th></tr></thead><tbody>{data.allocations.map(a=><tr key={a.id}><td>{day(a.allocated_on)}</td><th>{a.description}<small>{a.unit}</small></th><td>{a.supplier_collection_id?<Link href={`/supplier-collections/${a.supplier_collection_id}`}>Delivery note</Link>:a.lpo_line_id?'LPO receipt':'Opening stock'}</td><td>{a.quantity}</td><td>{a.sold}</td><td>{a.returned_quantity}</td><td>{a.lost}</td><td>{a.on_hand}</td><td>{tzs(a.unit_cost)}</td></tr>)}</tbody></table></div></section>
    <section id="location-assets" className={styles.panel}><div className={styles.sectionTitle}><Icons.home size={22}/><h2>Assets at this location</h2><InfoTip label="About location assets">Asset value is shown at {day(end)}. Monthly depreciation spreads cost less residual value over useful life. Location return reflects the assets working together; profit is not assigned to individual assets.</InfoTip></div>
      {data.assets.map(a=><article key={a.id} className={styles.asset}><h3>{a.name} {a.retired_on&&'· Retired'}</h3><p>Purchased {day(a.purchased_on)} · Cost {tzs(a.cost)} · Useful life {a.useful_months} months · Residual {tzs(a.residual_value)}</p><p>Monthly depreciation {tzs(a.monthly_depreciation)} · Depreciated {tzs(a.accumulated_depreciation)} · Book value {tzs(a.book_value)}</p>{a.notes&&<p>{a.notes}</p>}
        {admin&&!a.retired_on&&<details><summary>Retire asset</summary><LocationForm kind="retire" id={id} label="Retire asset"><input type="hidden" name="asset_id" value={a.id}/><label>Retirement date<input name="retired_on" type="date" min={a.depreciation_start} max={now} defaultValue={now} required/></label><label>Reason<input name="reason" required minLength={3}/></label><p>Depreciation stops on this date. The investment record remains in history.</p></LocationForm></details>}
      </article>)}{!data.assets.length&&<p>No assets registered.</p>}
    </section>
    {admin&&data.active&&<div className={styles.grid}>
      <details className={styles.panel}><summary><Icons.home size={20}/>Register an asset</summary><LocationForm kind="asset" id={id} label="Register asset">
        <label>Asset name<input name="name" minLength={2} required placeholder="BBQ stove"/></label><label>Purchase date<input name="purchased_on" type="date" defaultValue={now} max={now} required/></label>
        <label>Purchase cost (TZS)<input name="cost" type="number" min="0" step="0.01" required/></label><label>Residual value (TZS)<input name="residual_value" type="number" min="0" step="0.01" defaultValue="0" required/></label>
        <label>Useful life (months)<input name="useful_months" type="number" min="1" max="1200" defaultValue="36" required/></label><label>Depreciation starts<input name="depreciation_start" type="date" defaultValue={now} required/></label><label>Notes / serial number<input name="notes"/></label>
        <p>The asset cost is counted as investment once. Depreciation is a non-cash cost included in location and business profit.</p>
      </LocationForm></details>
      <details className={styles.panel}><summary><Icons.coins size={20}/>Record other capital investment</summary><LocationForm kind="investment" id={id} label="Record investment"><label>Date<input name="invested_on" type="date" defaultValue={now} max={now} required/></label><label>What was invested<input name="description" required minLength={2} placeholder="Kitchen fit-out excluding registered assets"/></label><label>Amount (TZS)<input name="amount" type="number" min="0.01" step="0.01" required/></label><p>Exclude costs already registered as assets. Running costs belong under expenses. This is a capital register; record actual payments separately in Finance.</p></LocationForm></details>
    </div>}
    <section className={styles.panel}><h2>Other investment history</h2>{data.investments.map(i=><p key={i.id}>{day(i.invested_on)} · {i.description} · {tzs(i.amount)}</p>)}{!data.investments.length&&<p>No other investment recorded.</p>}</section>
    <section className={styles.panel}><h2>Stock movement history</h2>{data.stock_events.map(e=><p key={e.id}>{day(e.occurred_on)} · {e.kind==='lost'?'Loss':'Returned'} · {e.quantity} · {e.note}</p>)}{!data.stock_events.length&&<p>No returns or losses recorded.</p>}</section>
    {admin&&<details className={styles.panel}><summary><Icons.edit size={20}/>Location settings</summary><LocationForm kind="settings" id={id} label="Save location"><label>Name<input name="name" defaultValue={data.name} minLength={2} required/></label><label>Address<input name="address" defaultValue={data.address}/></label><label>Daily chicken target<input name="daily_target" type="number" min="0" step="1" defaultValue={data.daily_target}/></label><label>Status<select name="active" defaultValue={String(data.active)}><option value="true">Open</option><option value="false">Closed</option></select></label><label>Notes<input name="notes" defaultValue={data.notes}/></label></LocationForm></details>}
  </div>;
}
