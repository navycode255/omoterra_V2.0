import { businessToday, expect, opsApi, seed, signInOperator, test, tzs } from './fixtures';

// M1.7 / F01: every finance page reads its headlines from one reporting
// layer, so the same figure shows the same value wherever it appears. A sale
// partly paid with its stock owed, an overdue loan and a paid expense; then
// Finance, Debts, Sales, Profit and the Cash book must agree.

const SALE = 150_000; // 10 birds at 15,000
const COST = 100_000; // owed to Mzee Juma
const PAID = 60_000; // cash, by the buyer
const LOAN = 50_000; // overdue since 2020
const EXPENSE = 30_000; // paid in cash
const OWED_TO_ME = SALE - PAID + LOAN;

test('Finance headlines agree on Finance, Debts, Sales, Profit and the Cash book', async ({ page, context }) => {
  const seeded = seed('operator');
  const api = opsApi(seeded.operator_token);
  const today = businessToday();
  await api.post('/ops/sales', {
    new_buyer: { business_name: 'E2E Headline Buyer', phone: '0754 000 888', region: 'dar es salaam' }, sold_on: today,
    items: [{ category: 'local_chicken', unit: 'bird', quantity: '10', unit_price: '15000', supplier_name: 'Mzee Juma', unit_cost: '10000' }],
    payment: { amount: String(PAID), paid_on: today, method: 'cash' },
  });
  await api.post('/ops/ledger/debts', { direction: 'receivable', party_name: 'Juma (driver)', description: 'Advance on salary',
    amount: String(LOAN), incurred_on: today, due_on: '2020-01-01' });
  await api.post('/ops/expenses', { spent_on: today, category: 'labour', description: 'Helpers for chicken prep', amount: String(EXPENSE),
    paid_to: 'Helpers', payment: { amount: String(EXPENSE), paid_on: today, method: 'cash' } });
  await signInOperator(context, seeded.operator_token);

  await page.goto('/finance');
  await expect(page.getByRole('link', { name: 'Money owed to me' }).locator('strong')).toHaveText(tzs(OWED_TO_ME));
  await expect(page.getByRole('link', { name: 'Money I owe' }).locator('strong')).toHaveText(tzs(COST));
  await expect(page.getByRole('link', { name: 'Sales' }).locator('strong')).toHaveText(tzs(SALE));

  await page.goto('/finance/debts');
  const debts = page.locator('section[aria-label="Debt summary"]');
  const card = (label: string) => debts.locator('a', { has: page.locator('span', { hasText: label }) }).locator('strong');
  await expect(card('Owed to me')).toHaveText(tzs(OWED_TO_ME));
  await expect(card('I owe')).toHaveText(tzs(COST));
  await expect(card('Overdue to collect')).toHaveText(tzs(LOAN));
  await expect(card('Overdue to pay')).toHaveText(tzs(0));

  await page.goto('/sales');
  await expect(page.locator('section[aria-label="Sales summary"] article', { hasText: 'Sales total' }).locator('strong')).toHaveText(tzs(SALE));

  await page.goto('/finance/profit');
  const profit = page.locator('section[aria-label="Profit summary"]');
  await expect(profit.locator('article').first().locator('strong')).toHaveText(tzs(SALE));
  await expect(profit.locator('article', { hasText: 'Operating profit' }).locator('strong')).toHaveText(tzs(SALE - COST - EXPENSE));

  // Not a verified cash balance until money accounts exist (M2.3).
  await page.goto('/finance/cash-book');
  const cash = page.locator('section[aria-label="Cash summary"] a', { hasText: 'Recorded net cash movement (unverified)' });
  await expect(cash.locator('strong')).toHaveText(tzs(PAID - EXPENSE));
  await expect(page.getByText('Cash in hand')).toHaveCount(0);
});
