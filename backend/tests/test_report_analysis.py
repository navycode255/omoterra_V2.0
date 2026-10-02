from datetime import date
from decimal import Decimal as D
import pytest
from app.report_analysis import project


def run(**changes):
    args = dict(revenue=D('300000'), stock_cost=D('180000'), losses=D('0'), days=30,
        end=date(2026, 9, 30), fixed=D('50000'), variable_pct=D('10'),
        growth_pct=D('0'), investment=None)
    return project(**(args | changes))


def test_contribution_and_break_even_include_other_variable_costs():
    r = run()
    assert r['contribution_pct'] == D('30')
    assert r['monthly_break_even_revenue'] == D('166666.67')
    first = r['scenarios'][1]['months'][0]
    assert first['revenue'] == D('310000')  # October has 31 days.
    assert first['operating_earnings'] == D('43000')
    assert first['revenue'] - first['variable_cost'] - first['fixed_cost'] == first['operating_earnings']


def test_negative_margin_has_no_break_even_and_no_recovery():
    r = run(stock_cost=D('330000'), investment=D('100'))
    assert r['monthly_break_even_revenue'] is None
    assert r['scenarios'][1]['first_break_even_month'] is None
    assert r['scenarios'][1]['investment_recovery_month'] is None


def test_earnings_recovery_is_cumulative_and_optional():
    assert run()['scenarios'][1]['investment_recovery_month'] is None
    r = run(investment=D('80000'))['scenarios'][1]
    assert r['investment_recovery_month'] == '2026-11-01'
    assert r['total_earnings'] == sum(m['operating_earnings'] for m in r['months'])


def test_scenarios_have_fixed_overhead_and_different_sales():
    r = run()['scenarios']
    assert r[0]['months'][0]['revenue'] == D('248000')
    assert r[2]['months'][0]['revenue'] == D('372000')
    assert {s['months'][0]['fixed_cost'] for s in r} == {D('50000')}


def test_calendar_rolls_across_year_and_leap_february():
    r = run(end=date(2027, 12, 31))['scenarios'][1]['months']
    assert r[0]['month'] == '2028-01-01'
    assert r[1]['revenue'] == D('290000')


def test_growth_compounds_and_losses_reduce_contribution():
    r = run(growth_pct=D('10'), losses=D('30000'))
    assert r['contribution_pct'] == D('20')
    assert r['scenarios'][1]['months'][0]['revenue'] == D('341000')
    assert r['scenarios'][1]['months'][1]['revenue'] == D('363000')


@pytest.mark.parametrize('values', [dict(revenue=D('0')), dict(growth_pct=D('51')),
    dict(fixed=D('-1')), dict(variable_pct=D('101')), dict(investment=D('-1')), dict(fixed=D('NaN'))])
def test_invalid_assumptions(values):
    with pytest.raises(ValueError):
        run(**values)
