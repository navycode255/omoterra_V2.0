"""Deterministic operating scenarios. No inferred growth or cash-payback claims."""
from calendar import monthrange
from datetime import date
from decimal import Decimal, ROUND_HALF_UP

ZERO = Decimal('0')
HUNDRED = Decimal('100')


def money(value):
    return value.quantize(Decimal('.01'), rounding=ROUND_HALF_UP)


def next_month(day):
    return date(day.year + (day.month == 12), day.month % 12 + 1, 1)


def project(*, revenue, stock_cost, losses, days, end, fixed, variable_pct,
            growth_pct, investment, months=12):
    """Other variable costs exclude stock/loss costs already derived from history.

    All months are full calendar months after the report end month. Growth is
    monthly sales-volume growth at constant prices/mix; variable costs scale
    with revenue. Recovery is cumulative operating earnings, never cash ROI.
    """
    values = [revenue, stock_cost, losses, fixed, variable_pct, growth_pct]
    if not all(v.is_finite() for v in values) or (investment is not None and not investment.is_finite()):
        raise ValueError('Inputs must be finite.')
    if revenue <= 0 or days <= 0 or min(stock_cost, losses, fixed, variable_pct) < 0:
        raise ValueError('A positive revenue baseline and nonnegative costs are required.')
    if not 0 <= variable_pct <= 100 or not -50 <= growth_pct <= 50 or not 1 <= months <= 24:
        raise ValueError('Assumptions outside supported bounds.')
    if investment is not None and investment < 0:
        raise ValueError('Investment cannot be negative.')
    ratio = (stock_cost + losses) / revenue + variable_pct / HUNDRED
    contribution = 1 - ratio
    break_even = money(fixed / contribution) if contribution > 0 else (ZERO if contribution == 0 and fixed == 0 else None)
    daily = revenue / Decimal(days)
    scenarios = []
    # These are explicitly illustrative sales sensitivities, not probabilities.
    for label, factor in [('Lower sales (-20%)', Decimal('.8')), ('Base case', Decimal('1')), ('Higher sales (+20%)', Decimal('1.2'))]:
        rows, cumulative, first_positive, recovery = [], ZERO, None, None
        period = next_month(end)
        for index in range(months):
            sales = money(daily * monthrange(period.year, period.month)[1] * factor * (1 + growth_pct / HUNDRED) ** (index + 1))
            variable = money(sales * ratio)
            earnings = sales - variable - money(fixed)
            cumulative += earnings
            if first_positive is None and earnings >= 0:
                first_positive = period.isoformat()
            if investment is not None and recovery is None and cumulative >= investment:
                recovery = period.isoformat()
            rows.append({'month': period.isoformat(), 'revenue': sales, 'variable_cost': variable,
                         'fixed_cost': money(fixed), 'operating_earnings': earnings, 'cumulative_earnings': cumulative})
            period = next_month(period)
        scenarios.append({'name': label, 'sales_factor': factor, 'months': rows,
                          'first_break_even_month': first_positive, 'investment_recovery_month': recovery,
                          'total_earnings': cumulative})
    return {'contribution_pct': money(contribution * 100), 'monthly_break_even_revenue': break_even,
            'scenarios': scenarios}
