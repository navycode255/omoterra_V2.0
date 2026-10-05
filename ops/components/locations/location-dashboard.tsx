'use client';

import Link from 'next/link';
import { useRef, useState } from 'react';
import { Icons } from '@/components/icons';
import { InfoTip } from '@/components/info-tip';
import { LocationForm } from './location-forms';
import { tzs } from '@/lib/format';
import type { Performance } from '@/lib/locations';
import styles from './locations.module.css';

export function LocationDashboard({ items, start, end, period, admin, now }: { items: Performance[]; start: string; end: string; period: string; admin: boolean; now: string }) {
  const [search, setSearch] = useState('');
  const dialog = useRef<HTMLDialogElement>(null);
  const rows = items.filter(row => row.name.toLocaleLowerCase().includes(search.trim().toLocaleLowerCase()));
  const addButton = () => <button type="button" className={styles.addButton} onClick={() => dialog.current?.showModal()}><span className={styles.plus}><Icons.plus size={17}/></span>Add a location</button>;
  return <>
    <div className={styles.toolbar}>
      <form className={styles.filters} action="/locations"><label>Start date<input type="date" name="start" defaultValue={start} max={now} required/></label><label>End date<input type="date" name="end" defaultValue={end} max={now} required/></label><span className={styles.filterDivider}/><button className={styles.addButton}>Apply period</button></form>
      {admin && addButton()}
    </div>
    <section className={`${styles.panel} ${styles.performance}`} aria-labelledby="location-performance">
      <div className={styles.panelHeading}><div><h2 id="location-performance">Location performance</h2><p>{period}</p></div><label className={styles.search}><Icons.search size={20}/><input type="search" aria-label="Search locations" placeholder="Search locations..." value={search} onChange={event => setSearch(event.target.value)}/></label></div>
      <div className={styles.tableWrap}><table data-phone-native className={`${styles.table} ${styles.performanceTable}`}><thead><tr>
        <th>Location</th><th>Investment <InfoTip label="About investment">Asset purchase cost plus other recorded capital, through the period end.</InfoTip></th><th>Sales</th><th>Stock sold cost</th><th>Labour</th><th>Running costs <InfoTip label="About running costs">Operating costs attributed to this location. Shared costs remain in business profit.</InfoTip></th><th>Losses <InfoTip label="About losses">Buying cost of stock lost at this location.</InfoTip></th><th>Depreciation</th><th>Profit</th><th>Return <InfoTip label="About period return">This period’s profit divided by investment; this is not an annual return or cash payback.</InfoTip></th><th>Actions</th>
      </tr></thead><tbody>{rows.map(row => <tr key={row.id}>
        <th><Link href={`/locations/${row.id}?${new URLSearchParams({start,end})}`}>{row.name}</Link><small>{row.active?'Open':'Closed'} · target {row.daily_target} chickens/day</small></th><td>{tzs(row.investment)}</td><td>{tzs(row.revenue)}</td><td>{tzs(row.stock_cost)}</td><td>{tzs(row.labour)}</td><td>{tzs(row.running_costs)}</td><td>{tzs(row.stock_lost)}</td><td>{tzs(row.depreciation)}</td><td className={Number(row.net_profit)<0?styles.negative:styles.positive}>{tzs(row.net_profit)}{row.unknown_cost_lines>0&&<small>Provisional costs</small>}</td><td>{row.period_return_pct===null?'—':`${row.period_return_pct}%`}</td><td><Link href={`/locations/${row.id}?${new URLSearchParams({start,end})}`} aria-label={`View ${row.name}`}>View</Link></td>
      </tr>)}</tbody></table></div>
      {!rows.length && <div className={styles.empty}>
        <svg className={styles.emptyIllustration} viewBox="0 0 180 150" fill="none" aria-hidden="true"><path d="M158 72c12 39-10 65-62 64S21 119 22 85 48 25 86 24s66 14 72 48Z" fill="#edf5f1"/><path d="M17 73h25v25H17zM115 27h15v23h-15z" fill="#edf5f1"/><g stroke="#8db5a6" strokeWidth="4" strokeLinejoin="round"><path d="m45 69 45-20 45 20H45ZM51 70v61m78-61v61M36 131h108"/><path d="M68 112h22v19H68zM90 112h22v19H90zM79 93h21v19H79z" fill="#c9dfd5"/><path d="M79 113v7m22-7v7M89 94v7"/></g></svg>
        <h3>{items.length?'No matching locations':'No locations yet'}</h3><p>{items.length?'Try searching for a different location.':'Add your first location to start tracking performance, assets and stock.'}</p>
        {admin && !items.length && addButton()}
      </div>}
    </section>
    {admin && <dialog ref={dialog} className={styles.locationDialog} aria-labelledby="add-location-title" onClick={event => { if(event.target===event.currentTarget) dialog.current?.close(); }}><div className={styles.dialogHeading}><h2 id="add-location-title">Add a location</h2><button type="button" aria-label="Close" onClick={() => dialog.current?.close()}><Icons.close/></button></div><LocationForm kind="location" label="Create location" onSaved={() => dialog.current?.close()}><label>Location name<input name="name" required minLength={2} maxLength={150} placeholder="Kitchen A"/></label><label>Address<input name="address"/></label><label>Daily chicken allocation target<input name="daily_target" type="number" min="0" step="1" defaultValue="20"/></label><label>Notes<input name="notes"/></label></LocationForm></dialog>}
  </>;
}
