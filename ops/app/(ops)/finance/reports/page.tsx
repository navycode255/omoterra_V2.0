import { get, ApiError } from '@/lib/api';
import { Notice, PageHeader } from '@/components/ui';
import { today } from '@/lib/finance';
import { param, type ListParams } from '@/lib/paging';
import type { FinancialReport } from '@/lib/reports';
import { FinancialReports } from '@/components/finance/reports';
export const metadata = { title: 'Financial reports · Omoterra Operations' };
export default async function Reports({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  const end = today();
  const start = new Date(`${end}T00:00:00Z`);
  start.setUTCDate(start.getUTCDate() - 89);
  const query = new URLSearchParams({ start: param(params, 'start') || start.toISOString().slice(0, 10), end: param(params, 'end') || end });
  for (const key of ['fixed', 'variable_pct', 'growth_pct', 'investment', 'reviewed']) {
    const value = param(params, key); if (value) query.set(key, value);
  }
  try {
    const report = await get<FinancialReport>(`/ops/finance/reports?${query}`);
    return <FinancialReports key={query.toString()} report={report} today={end}/>;
  } catch (error) {
    return <div className="workspace"><PageHeader title="Financial reports"/><Notice tone="error">{error instanceof ApiError ? error.message : 'The report could not be loaded. Please try again.'}</Notice><a className="button" href="/finance/reports">Reset report filters</a></div>;
  }
}
