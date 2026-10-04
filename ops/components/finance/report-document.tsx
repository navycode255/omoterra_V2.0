// The downloadable financial report: nine A4 pages laid out to match the
// Omoterra editorial report design. Hidden on screen; it is the only thing
// printed from /finance/reports, so "Save as PDF" produces this document.
/* eslint-disable @next/next/no-img-element -- print needs plain, eagerly loaded images */
import { Inter } from 'next/font/google';
import type { ReactNode } from 'react';
import type { FinancialReport } from '@/lib/reports';
import { expenseLabel } from '@/lib/finance';
import styles from './report-document.module.css';

const inter = Inter({ subsets: ['latin'], variable: '--font-report' });

const COVER = '/images/reports/cover.jpg';
const LOGO = '/images/marketing/logo.png';
const MIN_HISTORY_DAYS = 60;
const MIN_SELLING_DAYS = 10;
const MAX_EXPENSE_ROWS = 6;
const EXPENSE_COLORS = ['#063c2b', '#0d6b47', '#4f8a6c', '#82ad96', '#adcbbb', '#d0e1d6'];

/** Fonts and images are only fetched once the document is shown, which is too late for print. */
export async function prepareReportDocument() {
  await Promise.all([
    ...['400', '500', '600', '700', '800', '900'].map((weight) => document.fonts.load(`${weight} 16px ${inter.style.fontFamily}`)),
    ...[COVER, LOGO].map((src) => { const image = new Image(); image.src = src; return image.decode().catch(() => undefined); }),
  ]);
}

/** Draws each A4 page to an image and returns one PDF file. Unlike the
 * print dialog this works on phones, where window.print() is missing or
 * blocked once the tap is no longer the direct cause. */
export async function createReportPdf(title: string): Promise<Blob> {
  const root = document.querySelector<HTMLElement>('[data-print-document]');
  if (!root) throw new Error('The report document is not on this page.');
  const [{ default: html2canvas }, { jsPDF }] = await Promise.all([import('html2canvas-pro'), import('jspdf'), prepareReportDocument()]);
  root.setAttribute('data-capturing', '');
  try {
    const pdf = new jsPDF({ unit: 'mm', format: 'a4', compress: true });
    const pages = [...root.querySelectorAll<HTMLElement>(':scope > section')];
    if (!pages.length) throw new Error('The report has no pages.');
    for (const [index, page] of pages.entries()) {
      // Use a smaller canvas on phones to keep peak memory and file size manageable.
      const canvas = await html2canvas(page, {
        scale: window.matchMedia('(max-width: 600px)').matches ? 1.5 : 2,
        windowWidth: Math.max(page.scrollWidth, 800), windowHeight: Math.max(page.scrollHeight, 1123),
        scrollX: 0, scrollY: 0, useCORS: true, backgroundColor: '#ffffff', logging: false,
      });
      if (index) pdf.addPage();
      pdf.addImage(canvas.toDataURL('image/jpeg', 0.9), 'JPEG', 0, 0, 210, 297, undefined, 'FAST');
      canvas.width = canvas.height = 0;
    }
    pdf.setProperties({ title, author: 'Omoterra Operations', creator: 'Omoterra Operations' });
    return pdf.output('blob');
  } finally {
    root.removeAttribute('data-capturing');
  }
}

const num = (value: string | number | null | undefined) => Number(value ?? 0);
const tzs = (value: number) => `TZS ${Math.round(value).toLocaleString('en-US')}`;
const compact = (value: number) => Math.abs(value) >= 1_000_000 ? `TZS ${(value / 1_000_000).toFixed(2)}M` : tzs(value);
const pct = (part: number, whole: number) => whole ? `${(part / whole * 100).toFixed(1)}%` : '—';
const plural = (count: number, word: string) => `${count} ${word}${count === 1 ? '' : 's'}`;
const title = (value: string) => value.replace(/(^|[\s/(-])([a-z])/g, (_, gap: string, letter: string) => gap + letter.toUpperCase());
const product = (category: string) => title(category.replaceAll('_', ' '));
function day(value: string, style: 'short' | 'long' = 'short') {
  return new Date(`${value.slice(0, 10)}T00:00:00Z`).toLocaleDateString('en-GB', { day: '2-digit', month: style, year: 'numeric', timeZone: 'UTC' });
}
const span = (start: string, end: string) => `${day(start)} - ${day(end)}`;
const month = (value: string | null) => value ? new Date(`${value}T00:00:00Z`).toLocaleDateString('en-GB', { month: 'short', year: 'numeric', timeZone: 'UTC' }) : 'Not within 12 months';

function Page({ section, number, heading, subtitle, children }: { section: string; number: number; heading: string; subtitle: string; children: ReactNode }) {
  const page = String(number).padStart(2, '0');
  return <section className={styles.page}>
    <header className={styles.header}>
      <img src={LOGO} alt="Omoterra" className={styles.headerLogo}/>
      <div className={styles.headerMeta}><span>{section}</span><b>{page}</b></div>
    </header>
    <h2 className={styles.title}>{heading}</h2>
    <p className={styles.subtitle}>{subtitle}</p>
    {children}
    <footer className={styles.footer}><span>Omoterra • Financial performance report</span><b>{page}</b></footer>
  </section>;
}

function Note({ label, children, top }: { label: string; children: ReactNode; top: string }) {
  return <div className={styles.note} style={{ top }}><span className={styles.noteLabel}>{label}</span><p>{children}</p></div>;
}

type Action = { title: string; detail: string; step: string };

function analyse(report: FinancialReport) {
  const a = report.actual;
  const revenue = num(a.revenue);
  const stock = num(a.cost_of_goods);
  const expenseRows = a.expenses_by_category.map((row) => ({ label: title(expenseLabel(row.category)), key: row.category, amount: num(row.amount) }));
  if (num(a.stock_lost) > 0) expenseRows.push({ label: 'Recorded Stock Losses', key: 'stock_lost', amount: num(a.stock_lost) });
  expenseRows.sort((x, y) => y.amount - x.amount);
  if (expenseRows.length > MAX_EXPENSE_ROWS) {
    const rest = expenseRows.splice(MAX_EXPENSE_ROWS - 1);
    expenseRows.push({ label: 'All Other Categories', key: 'rest', amount: rest.reduce((sum, row) => sum + row.amount, 0) });
  }
  const expenses = num(a.expenses_and_losses);
  const result = num(a.net_profit);
  const unknown = report.unknown_cost_lines;
  const historyShort = report.history_days < MIN_HISTORY_DAYS;
  const sellingShort = report.active_sales_days < MIN_SELLING_DAYS;
  const stale = (Date.parse(report.generated_at) - Date.parse(`${a.end}T00:00:00Z`)) / 86_400_000 > 32;

  const blockers: string[] = [];
  if (unknown) blockers.push(`${unknown} missing buying cost${unknown === 1 ? '' : 's'}`);
  if (report.assumptions.fixed === null) blockers.push('Fixed costs not supplied');
  if (report.assumptions.variable_pct === null) blockers.push('Other variable costs not supplied');
  if (report.assumptions.fixed !== null && report.assumptions.variable_pct !== null && !report.assumptions.reviewed) blockers.push('Assumptions not yet reviewed');
  if (revenue <= 0) blockers.push('No positive sales baseline');
  if (a.unresolved_marketplace.count > 0) blockers.push('App deliveries without a date');
  if (stale) blockers.push('Period ended over a month ago');
  if (historyShort) blockers.push(`Only ${plural(report.history_days, 'day')} of history`);
  if (sellingShort) blockers.push(`Only ${plural(report.active_sales_days, 'selling day')}`);

  const unlocks: string[] = [];
  if (unknown || report.assumptions.fixed === null || report.assumptions.variable_pct === null) unlocks.push('Complete costs');
  if (blockers.length) unlocks.push('Reconcile cash');
  if (report.assumptions.fixed !== null && report.assumptions.variable_pct !== null && !report.assumptions.reviewed) unlocks.push('Review the assumptions');
  if (a.unresolved_marketplace.count > 0) unlocks.push('Confirm app delivery dates');
  if (stale) unlocks.push('Choose a recent period');
  if (historyShort || sellingShort || revenue <= 0) unlocks.push('Build repeat-demand history');

  const actions: Action[] = [];
  if (unknown) actions.push({ title: 'Complete costs', step: 'Costs', detail: unknown === 1 ? 'Match the uncosted sale line to its supplier receipt.' : `Match the ${unknown} uncosted sale lines to their supplier receipts.` });
  for (const row of report.products.filter((p) => p.gross_margin !== null && num(p.gross_margin) < 0)) {
    actions.push({ title: `Review ${product(row.category).toLowerCase()} pricing`, step: 'Pricing', detail: 'Check buying price, selling price and unit quantities before buying more.' });
  }
  const top = expenseRows.find((row) => row.key !== 'stock_lost' && row.key !== 'rest');
  if (top) actions.push({ title: `Review ${top.label.toLowerCase()}`, step: top.label.split(' ')[0], detail: `Compare supplier quotes and ${top.label.toLowerCase()} cost per fulfilled order.` });
  if (num(a.stock_lost) > 0) actions.push({ title: 'Investigate losses', step: 'Losses', detail: 'Find the causes before investing in handling, vet care or storage.' });
  if (sellingShort) actions.push({ title: 'Build sales depth', step: 'Sales', detail: `Reach at least ${MIN_SELLING_DAYS} selling days before relying on forecasts.` });
  if (historyShort) actions.push({ title: 'Extend the history', step: 'History', detail: `Collect at least ${MIN_HISTORY_DAYS} days of records before forecasting.` });
  if (report.assumptions.fixed === null || report.assumptions.variable_pct === null) actions.push({ title: 'Enter planning costs', step: 'Planning', detail: 'Add monthly fixed and other variable costs, then review them.' });
  if (report.forecast) actions.push({ title: 'Test growth in steps', step: 'Growth', detail: 'Set a capped trial budget and check repeat demand before scaling.' });
  const shown = actions.slice(0, 3);
  const sequence = [...new Set([...shown.slice(0, 2).map((x) => x.step), 'Cash', report.forecast ? 'Growth' : 'Forecast'])].slice(0, 4);

  return { a, revenue, stock, expenses, expenseRows, result, unknown, historyShort, sellingShort, blockers, unlocks, actions: shown, sequence };
}

export function ReportDocument({ report }: { report: FinancialReport }) {
  const d = analyse(report);
  const { a, revenue, stock, expenses, result, unknown } = d;
  const stockShare = revenue ? stock / revenue : 0;
  const uncosted = unknown === 1 ? 'One sale line is still missing its buying cost' : `${unknown} sale lines are still missing their buying cost`;

  const snapshotText = revenue <= 0 ? 'No sales were recorded in this period, so there is no revenue to measure costs against.'
    : stockShare >= 0.85 ? 'The business recorded meaningful sales during the period, but most of that revenue was absorbed by stock cost.'
    : result >= 0 ? 'Sales covered stock cost and recorded expenses, leaving a positive operating result for the period.'
    : 'Sales covered stock cost, but recorded expenses pushed the operating result below zero.';
  const viewText = (result < 0 ? 'Recorded revenue is below stock cost plus operating expenses.' : 'Recorded revenue covers stock cost and operating expenses.')
    + (unknown ? ` ${uncosted}, so the current result should remain provisional.` : result < 0 ? ' Review pricing and cost discipline before committing new capital.' : ' Reconcile cash before treating this as final profit.');

  // Stacked bar against revenue. Expenses get a block only when they fit in what stock cost leaves.
  const stockWidth = revenue ? Math.min(100, stock / revenue * 100) : 0;
  const expenseWidth = revenue && stock + expenses <= revenue ? expenses / revenue * 100 : 0;

  const topExpense = d.expenseRows[0];
  const maxExpense = Math.max(1, ...d.expenseRows.map((row) => row.amount));
  const reviewText = !topExpense ? 'No expenses were recorded in this period. That does not establish zero operating costs; check that every expense has been captured.'
    : topExpense.key === 'transport' ? 'Transport is the largest recorded cost. Compare route efficiency, supplier quotes and transport cost per fulfilled order before deciding whether the spending is excessive.'
    : `${topExpense.label} is the largest recorded cost. Compare supplier quotes and cost per fulfilled order before deciding whether the spending is excessive.`;

  const productRevenue = report.products.reduce((sum, p) => sum + num(p.revenue), 0);
  const productCost = report.products.reduce((sum, p) => sum + num(p.known_cost), 0);
  const productLines = report.products.reduce((sum, p) => sum + p.lines, 0);
  const chartMax = Math.max(1, productRevenue, productCost);
  const grossMargin = productRevenue - productCost;

  const historyFill = Math.min(1, report.history_days / MIN_HISTORY_DAYS);
  const sellingFill = Math.min(1, report.active_sales_days / MIN_SELLING_DAYS);
  const conclusion = report.forecast ? 'The screening rules are met. Treat the scenarios as conditional, not as guaranteed outcomes.'
    : d.historyShort && d.sellingShort ? 'Neither the history length nor the sales-day depth is sufficient yet.'
    : d.historyShort ? 'Selling activity is regular, but the history is still too short.'
    : d.sellingShort ? 'The history is long enough, but sales-day depth is not.'
    : 'Activity depth is sufficient. Complete the remaining inputs to unlock a forecast.';
  const base = report.forecast?.scenarios[1] ?? report.forecast?.scenarios[0];

  const recordedGross = num(a.gross_profit);
  const transport = num(a.expenses_by_category.find((row) => row.category === 'transport')?.amount);
  const transportGap = recordedGross - transport;
  const transportText = unknown ? 'Buying costs are incomplete, so this comparison remains provisional. Complete the missing costs before relying on the gap.'
    : revenue <= 0 ? 'No revenue was recorded. Transport remains a recorded expense and is included in the operating result.'
    : recordedGross < 0 ? 'Stock cost already exceeded revenue before transport. Review buying costs and selling prices alongside delivery costs.'
    : transportGap < 0 ? 'Transport exceeded recorded gross profit. Transport alone would have made the period negative, before other expenses.'
    : transport === 0 ? 'No transport expense was recorded. Check that delivery costs have been captured before treating this as zero transport cost.'
    : 'Recorded gross profit covered transport. The remaining gap must still cover other expenses and recorded losses.';
  const allocationBase = Math.max(revenue, stock + expenses, 1);
  const overrun = Math.max(0, stock + expenses - revenue);
  const positiveResult = Math.max(0, result);
  let donutOffset = 0;

  const count = ['No', 'One', 'Two', 'Three'][d.actions.length];
  const takeaway = unknown ? 'Do not invest from incomplete margin data. Cleaner source data, tighter cost discipline and more repeat sales are the priority.'
    : result < 0 ? 'The business is running at a recorded loss. Fix pricing and cost discipline before committing new capital.'
    : report.forecast ? 'The evidence supports careful planning. Grow in capped steps and keep reconciling cash as you go.'
    : 'Results are positive but not yet forecast-ready. Keep records complete and build repeat sales before investing.';
  const generated = report.generated_at.slice(0, 10);

  return <div className={`${styles.document} ${inter.variable}`} data-print-document aria-hidden="true">
    <section className={`${styles.page} ${styles.cover}`}>
      <img src={COVER} alt="" className={styles.coverArt}/>
      <img src={LOGO} alt="Omoterra" className={styles.coverLogo}/>
      <div className={styles.coverMeta}><b>Omoterra Operations</b><span>Confidential • Management use</span></div>
      <h1 className={styles.coverHeading}>Financial performance report</h1>
      <p className={styles.coverDates}>{day(a.start)} — {day(a.end)}</p>
      <div className={styles.coverTitle}>Financial<br/>performance<br/>report</div>
      <span className={styles.coverRule}/>
      <p className={styles.coverLead}>A clear management view of revenue, stock cost, expenses, operating result and financial readiness.</p>
      <span className={styles.coverYear}>{a.end.slice(0, 4)}</span>
      <span className={styles.coverKind}>Management report</span>
      <dl className={styles.coverFacts}>
        <div><dt>Prepared for</dt><dd>Omoterra Management</dd></div>
        <div><dt>Generated</dt><dd>{day(generated, 'long')}</dd></div>
        <div><dt>Currency</dt><dd>TZS</dd></div>
      </dl>
      <span className={styles.coverTagline}>Where Markets Meet Supply.</span>
      <span className={styles.coverSite}>omoterra.co.tz</span>
    </section>

    <Page section="Financial snapshot" number={2} heading="Financial Snapshot" subtitle={span(a.start, a.end)}>
      <div className={styles.hero} style={{ top: '67mm' }}><strong>{compact(revenue)}</strong><span>Recorded revenue</span><p>{snapshotText}</p></div>
      <div className={styles.figures}>
        <div><span>Stock cost</span><b>{compact(stock)}</b><small>{pct(stock, revenue)} of revenue</small></div>
        <div><span>Recorded expenses</span><b>{compact(expenses)}</b><small>{pct(expenses, revenue)} of revenue</small></div>
        <div><span>Operating result</span><b>{compact(result)}</b><small>Recorded margin: {pct(result, revenue)}</small></div>
      </div>
      <div className={styles.split} style={{ top: '135mm' }}>
        <h3>Where revenue went</h3><p>Each block is proportional to recorded revenue.</p>
        <div className={styles.stack}><i style={{ width: `${stockWidth}%` }}/><i style={{ width: `${expenseWidth}%` }}/></div>
        <div className={styles.legend}>
          <span><b>Stock cost</b><em>{pct(stock, revenue)}</em></span>
          <span><b>Expenses</b><em>{pct(expenses, revenue)}</em></span>
          <span><b>Result</b><em>{pct(result, revenue)}</em></span>
        </div>
      </div>
      <Note label="Management view" top="189mm">{viewText}</Note>
      <div className={styles.stats} style={{ top: '235.5mm' }}>
        <div><span>Status</span><b>{unknown ? 'Provisional' : 'Fully costed'}</b><small>{unknown ? plural(unknown, 'uncosted sale line') : 'Not yet reconciled to cash'}</small></div>
        <div><span>Activity window</span><b>{plural(report.history_days, 'day')}</b><small>{plural(report.active_sales_days, 'selling day')}</small></div>
      </div>
    </Page>

    <Page section="Cost structure" number={3} heading="Cost Structure" subtitle="Recorded operating expenses">
      <div className={styles.hero} style={{ top: '67mm' }}><strong className={styles.heroSmaller}>{compact(expenses)}</strong><span>Total recorded expenses</span></div>
      {topExpense && expenses > 0 && <div className={styles.share}><strong>{Math.round(topExpense.amount / expenses * 100)}%</strong><b>of all recorded expenses</b><span>came from {topExpense.label.toLowerCase()}.</span></div>}
      <div className={styles.bars}>
        {d.expenseRows.map((row, index) => <div key={row.key}>
          <span><b>{row.label}</b><small>{tzs(row.amount)}</small></span>
          <i><em data-lead={index === 0 || undefined} style={{ width: `${Math.max(3, row.amount / maxExpense * 100)}%` }}/></i>
        </div>)}
        {!d.expenseRows.length && <p className={styles.empty}>No expenses recorded in this period.</p>}
      </div>
      <Note label="What to review" top="203.5mm">{reviewText}</Note>
    </Page>

    <Page section="Financial overview" number={4} heading="Financial Overview" subtitle="Revenue, costs and recorded operating result">
      <div className={styles.overviewRevenue}><span>Recorded revenue</span><strong>{compact(revenue)}</strong><p>Total sales recorded in the selected period.</p></div>
      <div className={styles.overviewFigures}>
        <div><span>Stock cost</span><b>{compact(stock)}</b><small>{pct(stock, revenue)} of revenue</small></div>
        <div><span>Expenses &amp; losses</span><b>{compact(expenses)}</b><small>{pct(expenses, revenue)} of revenue</small></div>
        <div><span>Operating result</span><b>{compact(result)}</b><small>Margin {pct(result, revenue)}</small></div>
      </div>
      <div className={styles.allocation}>
        <h3>Where revenue went</h3>
        <p>{revenue > 0 ? 'Cost shares are measured against recorded revenue.' : 'No revenue recorded; revenue shares are unavailable.'}</p>
        <div className={styles.allocationTrack}>
          <i style={{ width: `${stock / allocationBase * 100}%`, background: 'var(--forest)' }}/>
          <i style={{ width: `${expenses / allocationBase * 100}%`, background: 'var(--sage)' }}/>
          {positiveResult > 0 && <i style={{ width: `${positiveResult / allocationBase * 100}%`, background: '#adcbbb' }}/>}
          {overrun > 0 && <span className={styles.overrun} style={{ left: `${Math.max(0, revenue) / allocationBase * 100}%` }}/>}
        </div>
        <div className={styles.allocationLegend}>
          <div><span>Stock cost</span><b>{pct(stock, revenue)}</b></div>
          <div><span>Expenses &amp; losses</span><b>{pct(expenses, revenue)}</b></div>
          <div><span>{overrun > 0 ? 'Overrun / loss' : 'Operating result'}</span><b>{pct(overrun > 0 ? overrun : result, revenue)}</b><small>{overrun > 0 ? 'Beyond recorded revenue' : 'After recorded costs'}</small></div>
        </div>
      </div>
      <Note label="Management view" top="205mm">{viewText}</Note>
      <div className={styles.stats} style={{ top: '250mm' }}>
        <div><span>Status</span><b>{unknown ? 'Provisional' : 'Fully costed'}</b><small>{unknown ? plural(unknown, 'uncosted sale line') : 'Not yet reconciled to cash'}</small></div>
        <div><span>Activity window</span><b>{plural(report.history_days, 'day')}</b><small>{plural(report.active_sales_days, 'selling day')}</small></div>
      </div>
    </Page>

    <Page section="Expense breakdown" number={5} heading="Expense Breakdown" subtitle="Recorded operating expenses and losses">
      <div className={styles.donut}>
        <svg viewBox="0 0 120 120" aria-label="Expense shares">
          <circle cx="60" cy="60" r="47" fill="none" stroke="#e2e3df" strokeWidth="20"/>
          {expenses > 0 && d.expenseRows.map((row, index) => {
            const share = Math.max(0, row.amount) / expenses * 100;
            const offset = donutOffset; donutOffset += share;
            return <circle key={row.key} cx="60" cy="60" r="47" fill="none" stroke={EXPENSE_COLORS[index]} strokeWidth="20" pathLength="100" strokeDasharray={`${share} ${100 - share}`} strokeDashoffset={-offset} transform="rotate(-90 60 60)"/>;
          })}
        </svg>
        <div><span>TZS</span><b>{Math.round(expenses).toLocaleString('en-US')}</b><small>Expenses &amp; losses</small></div>
      </div>
      <div className={styles.expenseLegend}>
        {d.expenseRows.map((row, index) => <div key={row.key}><i style={{ background: EXPENSE_COLORS[index] }}/><span><b>{row.label}</b><small>{tzs(row.amount)}</small></span><strong>{pct(row.amount, expenses)}</strong></div>)}
        {!d.expenseRows.length && <p className={styles.empty}>No expenses recorded.</p>}
      </div>
      <div className={styles.transportComparison}>
        <h3>Transport vs gross profit</h3>
        <div>
          <span><small>{unknown ? 'Gross profit (provisional)' : 'Recorded gross profit'}</small><b>{tzs(recordedGross)}</b></span>
          <span><small>Transport</small><b>{tzs(transport)}</b></span>
          <span><small>{unknown ? 'Gap (provisional)' : 'Remaining after transport'}</small><b>{tzs(transportGap)}</b></span>
        </div>
      </div>
      <Note label="Management view" top="220mm">{transportText}</Note>
    </Page>

    <Page section="Sales economics" number={6} heading="Sales Economics" subtitle={`Direct sales only${report.products.length ? ` • ${report.products.map((p) => product(p.category)).join(', ')}` : ''}`}>
      <div className={styles.hero} style={{ top: '68mm' }}><strong>{productLines}</strong><span>Sale lines</span></div>
      <div className={styles.subHero}><strong>{compact(productRevenue)}</strong><span>recorded revenue</span></div>
      <div className={styles.chart}>
        <h3>Revenue vs stock cost</h3>
        <div className={styles.chartArea}>
          {[['Revenue', productRevenue, 'revenue'], ['Stock cost', productCost, 'cost']].map(([label, value, tone]) => <div key={label as string} className={styles.column} data-tone={tone}>
            <b>{compact(value as number)}</b>
            <i style={{ height: `${Math.max(1, (value as number) / chartMax * 57.5)}mm` }}/>
            <span>{label}</span>
          </div>)}
        </div>
      </div>
      <div className={styles.margin}>
        <span className={styles.rule}/>
        <span className={styles.statLabel}>Gross margin</span>
        {unknown ? <>
          <b>Not available</b>
          <em>{unknown === 1 ? '1 sale line has no recorded buying cost.' : `${unknown} sale lines have no recorded buying cost.`}</em>
          <p>Until that source cost is recorded, the apparent product margin should not be used for expansion or pricing decisions.</p>
        </> : <>
          <b>{compact(grossMargin)}</b>
          <em>{pct(grossMargin, productRevenue)} of direct-sale revenue</em>
          <p>Before shared operating costs. Weigh it against recorded expenses before making pricing or expansion decisions.</p>
        </>}
      </div>
      <div className={styles.stats} data-size="small" style={{ top: '241.5mm' }}>
        <div><span>Stock cost / revenue</span><b>{pct(stock, revenue)}</b></div>
        <div><span>Recorded operating margin</span><b>{pct(result, revenue)}</b></div>
      </div>
    </Page>

    <Page section="Forecast readiness" number={7} heading="Forecast Readiness" subtitle="Is there enough evidence to rely on a forecast?">
      <div className={styles.circleDark}>
        {report.forecast ? <><h3>What supports<br/>the forecast</h3><ul>
          <li>{plural(report.history_days, 'day')} of history</li><li>{plural(report.active_sales_days, 'selling day')}</li>
          <li>Fixed costs {tzs(num(report.assumptions.fixed))} / month</li><li>Other variable costs {report.assumptions.variable_pct}%</li>
        </ul></> : <><h3>What blocks<br/>reliable forecasting</h3><ul>{d.blockers.map((v) => <li key={v}>{v}</li>)}</ul></>}
      </div>
      <div className={styles.circleLight}>
        {report.forecast && base ? <><h3>{base.name} outlook</h3><ul>
          <li>Break-even sales {report.forecast.monthly_break_even_revenue === null ? 'not reachable' : `${compact(num(report.forecast.monthly_break_even_revenue))} / month`}</li>
          <li>First break-even: {month(base.first_break_even_month)}</li>
          <li>12-month earnings {compact(num(base.total_earnings))}</li>
        </ul></> : <><h3>What unlocks it</h3><ul>{d.unlocks.map((v) => <li key={v}>{v}</li>)}</ul></>}
      </div>
      <div className={styles.checks}>
        <h3>Screening checks</h3>
        <div><span>History length</span><b>{plural(report.history_days, 'day')}</b><i><em data-met={historyFill >= 1 || undefined} style={{ width: `${historyFill * 100}%` }}/><small>minimum {MIN_HISTORY_DAYS}</small></i></div>
        <div><span>Selling days</span><b>{plural(report.active_sales_days, 'day')}</b><i><em data-met={sellingFill >= 1 || undefined} style={{ width: `${sellingFill * 100}%` }}/><small>minimum {MIN_SELLING_DAYS}</small></i></div>
      </div>
      <Note label="Conclusion" top="255.5mm">{conclusion}</Note>
    </Page>

    <Page section="Management actions" number={8} heading="What To Do Next" subtitle={`${count} action${d.actions.length === 1 ? '' : 's'} will make the next report materially more reliable.`}>
      <ol className={styles.actions}>
        {d.actions.map((action, index) => <li key={action.title}><strong>{String(index + 1).padStart(2, '0')}</strong><div><b>{action.title}</b><span>{action.detail}</span></div></li>)}
      </ol>
      <div className={styles.sequence}>
        <h3>Management sequence</h3>
        <ol>{d.sequence.map((step, index) => <li key={step}><i/><b>{['Now', 'Next', 'Then', 'After'][index]}</b><span>{step}</span></li>)}</ol>
      </div>
      <Note label="Management takeaway" top="239mm">{takeaway}</Note>
    </Page>

    <Page section="Report basis" number={9} heading="Report Basis" subtitle="How the numbers in this report should be interpreted.">
      <div className={styles.basis}>
        <div><b>Revenue</b><p>Active direct sales and delivered/completed marketplace orders under the existing reporting policy.</p></div>
        <div><b>Expenses</b><p>Recorded expense debts and LPO stock losses. Depreciation, tax, financing and some collection losses are not comprehensively captured.</p></div>
        <div><b>Product analysis</b><p>Direct sales only. Unknown costs are not shown as final product margin.</p></div>
        <div><b>Forecasts</b><p>Operating scenarios, not cash forecasts. They assume stable prices, product mix, cost ratios and sufficient supply and delivery capacity.</p></div>
      </div>
      <div className={styles.model}>
        <h3>Model &amp; assumptions</h3>
        <dl>
          <div><dt>Model</dt><dd>{report.model_version}</dd></div>
          <div><dt>Prior comparison</dt><dd>{span(report.previous.start, report.previous.end)}</dd></div>
          <div><dt>Monthly fixed costs</dt><dd>{report.assumptions.fixed === null ? 'Not available' : tzs(num(report.assumptions.fixed))}</dd></div>
          <div><dt>Other variable costs</dt><dd>{report.assumptions.variable_pct === null ? 'Not supplied' : `${num(report.assumptions.variable_pct)}%`}</dd></div>
          <div><dt>Monthly growth</dt><dd>{num(report.assumptions.growth_pct)}%</dd></div>
          <div><dt>Unrecovered investment</dt><dd>{report.assumptions.investment === null ? 'Not available' : tzs(num(report.assumptions.investment))}</dd></div>
        </dl>
        <p>Break-even sales = fixed costs ÷ contribution margin ratio.</p>
        <p>Generated from Omoterra Operations records on {day(generated)}.</p>
      </div>
    </Page>
  </div>;
}
