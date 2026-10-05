import type { ProfitReport } from './finance';
export type ForecastMonth = { month: string; revenue: string; variable_cost: string; fixed_cost: string; operating_earnings: string; cumulative_earnings: string };
export type FinancialReport = {
  generated_at: string; model_version: string; actual: ProfitReport; previous: ProfitReport;
  history_days: number; active_sales_days: number; unknown_cost_lines: number;
  /** Rule R5: any unknown buying cost leaves the result "Provisional: buying costs incomplete". */
  provisional: boolean; provisional_label: string | null; unknown_cost: { lines: number; sales: number; revenue: string };
  products: { category: string; revenue: string; known_cost: string; gross_margin: string | null; unknown_lines: number; lines: number }[];
  limitations: string[]; forecast_blockers: string[];
  forecast: null | { contribution_pct: string; monthly_break_even_revenue: string | null;
    scenarios: { name: string; sales_factor: string; months: ForecastMonth[]; first_break_even_month: string | null; investment_recovery_month: string | null; total_earnings: string }[] };
  suggestions: { title: string; evidence: string; action: string; priority: string }[];
  assumptions: { fixed: string | null; variable_pct: string | null; growth_pct: string; investment: string | null; reviewed: boolean };
  methodology_url: string;
};
