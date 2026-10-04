'use client';
import { useEffect, useState } from 'react';
import type { FinancialReport } from '@/lib/reports';
import { expenseLabel } from '@/lib/finance';
import styles from './reports.module.css';
import { Busy } from '@/components/spinner';
import { createReportPdf, prepareReportDocument, ReportDocument } from './report-document';
const amount = (value: string | number | null) => value === null ? 'Not available' : `TZS ${Number(value).toLocaleString('en-TZ', { maximumFractionDigits: 2 })}`;
const month = (value: string | null) => value ? new Date(`${value}T00:00:00Z`).toLocaleDateString('en-GB', { month: 'short', year: 'numeric', timeZone: 'UTC' }) : 'Not reached within 12 months';
const label = (value: string) => value.replaceAll('_', ' ');

function save(name: string, contents: string, type: string) {
  const url = URL.createObjectURL(new Blob([contents], { type }));
  const link = document.createElement('a'); link.href = url; link.download = name; link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
// Quote every field and neutralise spreadsheet formulas in text fields.
function csvCell(value: unknown) {
  let text = value == null ? '' : String(value);
  if (/^[\s]*[=+@\-]/.test(text) && !/^-?\d+(\.\d+)?$/.test(text)) text = `'${text}`;
  return `"${text.replaceAll('"', '""')}"`;
}
function downloadCsv(report: FinancialReport) {
  const rows: unknown[][] = [['Omoterra financial report', 'Provisional recorded activity'], ['Generated (UTC)', report.generated_at], ['Model', report.model_version], ['From', report.actual.start, 'To', report.actual.end], [], ['Metric', 'Selected period (TZS)', 'Previous equal-length period (TZS)']];
  for (const key of ['revenue', 'stock_cost', 'marketplace_cost', 'expenses', 'stock_lost', 'net_profit'] as const) rows.push([key, report.actual[key], report.previous[key]]);
  rows.push([], ['Daily recorded activity'], ['Date', 'Revenue', 'Stock cost', 'Marketplace cost', 'Expenses', 'Losses', 'Recorded operating result']);
  for (const d of report.actual.days) rows.push([d.date, d.revenue, d.stock_cost, d.marketplace_cost, d.expenses, d.stock_lost, d.net_profit]);
  rows.push([], ['Direct-sale product performance'], ['Product', 'Revenue', 'Known cost', 'Gross margin (blank if unknown)', 'Uncosted lines']);
  for (const p of report.products) rows.push([p.category, p.revenue, p.known_cost, p.gross_margin, p.unknown_lines]);
  rows.push([], ['Forecast assumptions']);
  for (const [key, value] of Object.entries(report.assumptions)) rows.push([key, value]);
  rows.push(['Forecast methodology', report.methodology_url]);
  for (const s of report.forecast?.scenarios ?? []) {
    rows.push([], [s.name], ['Monthly break-even revenue', report.forecast?.monthly_break_even_revenue], ['First operating break-even month', s.first_break_even_month ?? 'Not reached'], ['Investment earnings recovery month', report.assumptions.investment === null ? 'Not supplied' : s.investment_recovery_month ?? 'Not reached'], ['Month', 'Revenue', 'Variable cost', 'Fixed cost', 'Operating earnings', 'Cumulative earnings']);
    for (const m of s.months) rows.push([m.month, m.revenue, m.variable_cost, m.fixed_cost, m.operating_earnings, m.cumulative_earnings]);
  }
  rows.push([], ['Forecast blockers']); report.forecast_blockers.forEach(v => rows.push([v]));
  rows.push([], ['Recommendations', 'Evidence', 'Next action']); report.suggestions.forEach(s => rows.push([s.title, s.evidence, s.action]));
  rows.push([], ['Scope and limitations']); report.limitations.forEach(v => rows.push([v]));
  save(`omoterra-financial-report-${report.actual.start}-${report.actual.end}.csv`, '\uFEFF' + rows.map(r => r.map(csvCell).join(',')).join('\r\n'), 'text/csv;charset=utf-8');
}

// Builds the A4 report as a PDF file in the browser, so it downloads the same
// way on phones and computers. Print stays available on larger screens.
function PdfButton({ report }: { report: FinancialReport }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [ready, setReady] = useState<{ url: string; file: File; shareable: boolean } | null>(null);
  useEffect(() => () => { if (ready) URL.revokeObjectURL(ready.url); }, [ready]);
  const name = `Omoterra-Financial-Report-${report.actual.start}-to-${report.actual.end}`;
  async function download() {
    setBusy(true); setError('');
    try {
      const blob = await createReportPdf(`Omoterra financial performance report ${report.actual.start} to ${report.actual.end}`);
      const file = new File([blob], `${name}.pdf`, { type: 'application/pdf' });
      const url = URL.createObjectURL(blob);
      setReady({ url, file, shareable: Boolean(navigator.canShare?.({ files: [file] })) });
      // Keep a real link available for a fresh tap when a phone blocks the automatic download.
      const link = document.createElement('a');
      link.href = url; link.download = file.name;
      document.body.append(link); link.click(); link.remove();
    }
    catch { setError('The PDF could not be created on this device. Please try again, or use Download CSV.'); }
    finally { setBusy(false); }
  }
  async function share() {
    if (!ready) return;
    try { await navigator.share({ files: [ready.file], title: 'Omoterra financial report' }); }
    catch (error) { if (!(error instanceof DOMException && error.name === 'AbortError')) setError('Use Download PDF or Open PDF to save this report.'); }
  }
  function print() {
    const previous = document.title;
    document.title = name;
    window.addEventListener('afterprint', () => { document.title = previous; }, { once: true });
    window.print();
  }
  return <>
    <button type="button" className={styles.printButton} onClick={print} disabled={busy} onPointerEnter={() => void prepareReportDocument()}>Print</button>
    {ready ? <>
      <a className={styles.primary} href={ready.url} download={ready.file.name}>Download PDF</a>
      <a href={ready.url} target="_blank" rel="noopener">Open PDF</a>
      {ready.shareable && <button type="button" onClick={share}>Save / share PDF</button>}
    </> : <button type="button" className={styles.primary} onClick={download} disabled={busy} aria-busy={busy}>{busy ? <Busy>Preparing PDF…</Busy> : 'Download PDF'}</button>}
    {ready && <p className={styles.pdfStatus} role="status">PDF ready. Tap Download PDF to save it, or Open PDF to use your browser’s save options.</p>}
    {error && <p className={styles.pdfError} role="alert">{error}</p>}
  </>;
}

export function FinancialReports({ report, today }: { report: FinancialReport; today: string }) {
  const [scenario, setScenario] = useState(1);
  const a = report.actual;
  const selected = report.forecast?.scenarios[scenario];
  const max = Math.max(1, ...(selected?.months.map(m => Math.abs(Number(m.operating_earnings))) ?? []));
  // The A4 document sits beside the screen report, so the screen styles (.report h2, p…) never reach it.
  return <><div className={styles.report} data-financial-report>
    <header className={styles.heading}><div><p className={styles.eyebrow}>OMOTERRA / BUSINESS PERFORMANCE</p><h1>Financial reports</h1><p>{a.start} — {a.end} · TZS · Generated {new Date(report.generated_at).toLocaleString('en-GB', { timeZone: 'Africa/Dar_es_Salaam' })} EAT</p></div>
      <div className={styles.actions}><button onClick={() => downloadCsv(report)}>Download CSV</button><button onClick={() => save(`omoterra-report-${a.end}.json`, JSON.stringify(report, null, 2), 'application/json')}>Save snapshot</button><PdfButton key={report.generated_at} report={report}/></div>
    </header>
    <form className={`${styles.panel} ${styles.controls}`} action="/finance/reports" method="get">
      <div className={styles.sectionHeading}><div><h2>Period & planning assumptions</h2><p>Historical results stay separate from your editable scenario.</p></div></div>
      <div className={styles.fields}>
        <label>Report from<input type="date" name="start" defaultValue={a.start} max={today} required/></label>
        <label>Report to<input type="date" name="end" defaultValue={a.end} max={today} required/></label>
        <label>Monthly fixed costs (TZS)<input type="number" name="fixed" min="0" max="1000000000000" step="0.01" defaultValue={report.assumptions.fixed ?? ''} placeholder="Rent, salaries, overhead"/></label>
        <label>Other variable costs (% of sales)<input type="number" name="variable_pct" min="0" max="100" step="0.01" defaultValue={report.assumptions.variable_pct ?? ''} placeholder="Delivery, packaging, fees"/></label>
        <label>Monthly sales growth (%)<input type="number" name="growth_pct" min="-50" max="50" step="0.01" defaultValue={report.assumptions.growth_pct}/></label>
        <label>Unrecovered investment (TZS)<input type="number" name="investment" min="0" max="1000000000000" step="0.01" defaultValue={report.assumptions.investment ?? ''} placeholder="Optional; not inferred"/></label>
      </div>
      <p className={styles.help}>Stock costs and recorded losses come from history. Split all other operating costs between fixed and variable inputs—do not include them twice. Include costs missing from your records. Growth defaults to 0%; the first forecast covers the next full month after the report end month.</p>
      <div className={styles.formFooter}><label className={styles.check}><input type="checkbox" name="reviewed" value="true" defaultChecked={report.assumptions.reviewed}/>I reviewed the source costs, expense split, growth assumption and available capacity.</label><button className={styles.primary}>Generate report</button></div>
    </form>
    <aside className={styles.notice}><strong>Provisional management report</strong><span>{report.unknown_cost_lines ? `${report.unknown_cost_lines} sale lines have missing costs. ` : ''}Recorded operating results are not reconciled cash or final net income. Review the scope notes before investing.</span></aside>
    <section className={styles.metrics} aria-label="Recorded performance">
      <article><span>Recorded revenue</span><strong>{amount(a.revenue)}</strong><small>Previous period: {amount(report.previous.revenue)}</small></article>
      <article><span>Stock cost</span><strong>{amount(a.cost_of_goods)}</strong><small>{report.unknown_cost_lines ? 'Incomplete buying costs' : 'Recorded cost of stock sold'}</small></article>
      <article><span>Expenses & recorded losses</span><strong>{amount(a.expenses_and_losses)}</strong><small>Includes unpaid expense obligations</small></article>
      <article data-tone={Number(a.net_profit) < 0 ? 'negative' : 'positive'}><span>Recorded operating result</span><strong>{amount(a.net_profit)}</strong><small>Provisional · {report.history_days} days / {report.active_sales_days} selling days</small></article>
    </section>
    <section className={styles.panel}><div className={styles.sectionHeading}><div><p className={styles.eyebrow}>LOOKING AHEAD</p><h2>Earnings & break-even</h2></div>{report.forecast && <div className={styles.tabs}>{report.forecast.scenarios.map((s, i) => <button key={s.name} aria-pressed={scenario === i} onClick={() => setScenario(i)}>{s.name}</button>)}</div>}</div>
      {!report.forecast || !selected ? <div className={styles.empty}><h3>Forecast needs a reliable starting point</h3><ul>{report.forecast_blockers.map(v => <li key={v}>{v}</li>)}</ul><p>Your recorded results remain available above and in the downloads.</p></div> : <>
        <p className={styles.scenarioName}>{selected.name} · Conditional scenario, not a guaranteed outcome</p>
        <div className={styles.metrics}>
          <article><span>Monthly break-even sales</span><strong>{amount(report.forecast.monthly_break_even_revenue)}</strong><small>{report.forecast.monthly_break_even_revenue === null ? 'Costs consume all contribution; more sales alone will not fix this.' : `${report.forecast.contribution_pct}% contribution after variable costs`}</small></article>
          <article><span>First operating break-even month</span><strong>{month(selected.first_break_even_month)}</strong><small>Monthly earnings ≥ 0 under this scenario</small></article>
          <article><span>12-month operating earnings</span><strong>{amount(selected.total_earnings)}</strong><small>Before tax and financing; excludes cash timing</small></article>
          <article><span>Investment earnings recovery</span><strong>{report.assumptions.investment === null ? 'Enter an investment amount' : month(selected.investment_recovery_month)}</strong><small>Cumulative earnings threshold, not cash payback</small></article>
        </div>
        <div className={styles.chart} aria-label="Projected monthly operating earnings; exact values in the table below">{selected.months.map(m => <div key={m.month}><span className={styles.bar} data-negative={Number(m.operating_earnings) < 0} style={{ height: `${Math.max(2, Math.abs(Number(m.operating_earnings)) / max * 110)}px` }}/><small>{month(m.month)}</small></div>)}</div>
        <p className={styles.help}>Bar height shows magnitude; red indicates a loss. Scenarios assume unchanged prices and product mix. They do not model seasonality.</p>
        <div className={styles.tableWrap}><table><thead><tr><th>Month</th><th>Sales</th><th>Variable costs</th><th>Fixed costs</th><th>Operating earnings</th><th>Cumulative earnings</th></tr></thead><tbody>{selected.months.map(m => <tr key={m.month}><th>{month(m.month)}</th><td>{amount(m.revenue)}</td><td>{amount(m.variable_cost)}</td><td>{amount(m.fixed_cost)}</td><td>{amount(m.operating_earnings)}</td><td>{amount(m.cumulative_earnings)}</td></tr>)}</tbody></table></div>
      </>}
    </section>
    <section className={styles.panel}><h2>Where to improve & grow</h2><p>Recommendations are tied to recorded evidence. Growth candidates still require a cash and capacity review.</p><div className={styles.insights}>{report.suggestions.map(s => <article key={s.title}><span className={styles.eyebrow}>{s.priority}</span><h3>{s.title}</h3><p><strong>{s.evidence}</strong></p><p>{s.action}</p></article>)}</div></section>
    <div className={styles.columns}><section className={styles.panel}><h2>Product performance</h2><p>Direct sales only · margins before shared operating costs</p><div className={styles.tableWrap}><table><thead><tr><th>Product</th><th>Revenue</th><th>Gross margin</th></tr></thead><tbody>{report.products.map(p => <tr key={p.category}><th>{label(p.category)}<small>{p.lines} sale lines</small></th><td>{amount(p.revenue)}</td><td>{p.gross_margin === null ? `Unknown (${p.unknown_lines} uncosted)` : amount(p.gross_margin)}</td></tr>)}</tbody></table></div>{!report.products.length && <p>No direct sales in this period.</p>}</section>
      <section className={styles.panel}><h2>Recorded expenses</h2><div className={styles.tableWrap}><table><thead><tr><th>Category</th><th>Amount</th></tr></thead><tbody>{a.expenses_by_category.map(e => <tr key={e.category}><th>{expenseLabel(e.category)}</th><td>{amount(e.amount)}</td></tr>)}</tbody></table></div>{!a.expenses_by_category.length && <p>No expenses recorded. This does not establish zero operating costs.</p>}</section></div>
    <section className={styles.panel}><h2>Report basis & assumptions</h2><p>Model: {report.model_version} · Prior comparison: {report.previous.start} — {report.previous.end}</p><p>Monthly fixed costs: {amount(report.assumptions.fixed)} · Other variable costs: {report.assumptions.variable_pct ?? 'Not supplied'}% · Monthly growth: {report.assumptions.growth_pct}% · Unrecovered investment: {amount(report.assumptions.investment)}</p><ul>{report.limitations.map(v => <li key={v}>{v}</li>)}</ul><p>Break-even sales = fixed costs ÷ contribution margin ratio. <a href={report.methodology_url} target="_blank" rel="noreferrer">SBA methodology</a>. Revenue baseline uses every calendar day in the selected period, including days without sales.</p><p>CSV contains every daily row and all three scenarios. Save snapshot preserves the exact data and assumptions used to generate this report. Download PDF saves the seven-page management report as a file on any device.</p></section>
  </div>
    <ReportDocument report={report}/>
  </>;
}
