'use client';

import { useState } from 'react';

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const MONTH_NAMES = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

// Round the axis up to a clean step so ticks read 0 / 20 / 40 / 60 / 80.
function axis(max: number) {
  if (max <= 4) return { top: 4, step: 1 };
  const rough = max / 4;
  const magnitude = 10 ** Math.floor(Math.log10(rough));
  const step = [1, 2, 2.5, 5, 10].map((n) => n * magnitude).find((n) => n >= rough) ?? rough;
  return { top: Math.ceil(max / step) * step, step };
}

export function SupplyTrendChart({ months, year, currentMonth }: { months: number[]; year: number; currentMonth: number | null }) {
  const [hover, setHover] = useState<number | null>(null);
  const { top, step } = axis(Math.max(...months, 0));
  const ticks = Array.from({ length: Math.round(top / step) + 1 }, (_, i) => i * step);
  const total = months.reduce((sum, value) => sum + value, 0);

  return <figure className="trend-chart">
    <div className="trend-plot" onMouseLeave={() => setHover(null)}>
      <div className="trend-ticks" aria-hidden="true">{ticks.slice().reverse().map((tick) => <span key={tick}>{tick}</span>)}</div>
      <div className="trend-area">
        {ticks.map((tick) => <i key={tick} className="trend-grid" style={{ bottom: `${(tick / top) * 100}%` }}/>)}
        <div className="trend-bars">
          {months.map((value, index) => {
            const future = currentMonth !== null && index > currentMonth;
            return <button key={MONTHS[index]} type="button" className="trend-slot" data-active={hover === index} data-future={future}
              onMouseEnter={() => setHover(index)} onFocus={() => setHover(index)} onBlur={() => setHover(null)}
              aria-label={`${MONTH_NAMES[index]} ${year}: ${value} ${value === 1 ? 'supply' : 'supplies'} recorded`}>
              <span className="trend-bar" style={{ height: value ? `max(${(value / top) * 100}%, 3px)` : 0 }}/>
              {hover === index && <span className="chart-tooltip" role="status"><span><strong>{value}</strong> {value === 1 ? 'supply' : 'supplies'}</span><small>{MONTH_NAMES[index]} {year}</small></span>}
            </button>;
          })}
        </div>
      </div>
    </div>
    <div className="trend-months" aria-hidden="true">{MONTHS.map((month) => <span key={month}>{month}</span>)}</div>
    <figcaption className="sr-only">{total} supplies recorded in {year}.</figcaption>
  </figure>;
}

const SEGMENTS = [
  { key: 'live', label: 'Live', color: '#0b6b47', hint: 'Approved and open to buyers' },
  { key: 'pending', label: 'Pending', color: '#b87700', hint: 'Awaiting Omoterra review' },
  { key: 'completed', label: 'Completed', color: '#3f6fa8', hint: 'Fully supplied' },
] as const;

export function BatchDonut({ counts }: { counts: Record<'live' | 'pending' | 'completed', number> }) {
  const [hover, setHover] = useState<string | null>(null);
  const total = SEGMENTS.reduce((sum, segment) => sum + counts[segment.key], 0);
  const radius = 42;
  const circumference = 2 * Math.PI * radius;
  const gap = total > 1 && SEGMENTS.filter((segment) => counts[segment.key]).length > 1 ? 2 : 0;
  let offset = 0;
  const active = SEGMENTS.find((segment) => segment.key === hover);

  return <div className="donut-wrap">
    <div className="donut" onMouseLeave={() => setHover(null)}>
      <svg viewBox="0 0 100 100" role="img" aria-label={`${total} production batches: ${SEGMENTS.map((s) => `${counts[s.key]} ${s.label.toLowerCase()}`).join(', ')}`}>
        <circle cx="50" cy="50" r={radius} fill="none" stroke="#edf1ee" strokeWidth="13"/>
        {total > 0 && SEGMENTS.map((segment) => {
          const value = counts[segment.key];
          if (!value) return null;
          const length = (value / total) * circumference;
          const dash = Math.max(length - gap, 0.5);
          const element = <circle key={segment.key} cx="50" cy="50" r={radius} fill="none" stroke={segment.color} strokeWidth={hover === segment.key ? 15 : 13}
            strokeDasharray={`${dash} ${circumference - dash}`} strokeDashoffset={-offset - gap / 2} transform="rotate(-90 50 50)"
            onMouseEnter={() => setHover(segment.key)} className="donut-segment" data-dim={hover !== null && hover !== segment.key}/>;
          offset += length;
          return element;
        })}
      </svg>
      <div className="donut-center">{active
        ? <><strong>{counts[active.key]}</strong><span>{active.label}</span></>
        : <><strong>{total}</strong><span>Total</span></>}</div>
    </div>
    <ul className="donut-legend">
      {SEGMENTS.map((segment) => <li key={segment.key} onMouseEnter={() => setHover(segment.key)} onMouseLeave={() => setHover(null)} data-active={hover === segment.key} title={segment.hint}>
        <i style={{ background: segment.color }}/><span>{segment.label}<small>{segment.hint}</small></span><strong>{counts[segment.key]}</strong>
      </li>)}
    </ul>
  </div>;
}
