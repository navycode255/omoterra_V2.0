import { expect, opsApi, seed, signInOperator, test, tzs } from './fixtures';

// One amount from a customer, entered once, pays their oldest debt first and
// the rest goes on the next. The cash book shows one payment, not one per debt.

const daysAgo = (n: number) => new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Dar_es_Salaam' })
  .format(new Date(Date.now() - n * 86_400_000));

type Sale = { buyer_profile_id: string; debts: { id: string; direction: string }[] };

test('One customer payment clears the oldest debt first and is one cash book row', async ({ page, context }) => {
  const seeded = seed('operator');
  await signInOperator(context, seeded.operator_token);
  const api = opsApi(seeded.operator_token);
  const sell = (price: string, days: number) => api.post<Sale>('/ops/sales', {
    new_buyer: { business_name: 'Mama Neema Hotel', phone: '0754 222 333' }, sold_on: daysAgo(days),
    items: [{ category: 'local_chicken', unit: 'bird', quantity: '1', unit_price: price, cost_unknown: true }],
  });
  const older = await sell('20000', 3);
  const newer = await sell('30000', 1);
  const owed = (sale: Sale) => sale.debts.find((d) => d.direction === 'receivable')!.id;

  await page.goto('/finance/debts');
  await page.getByRole('link', { name: 'Receive customer payment' }).click();
  // Wait for the customer list: the debts list behind it also names the buyer.
  await expect(page).toHaveURL(/\/finance\/debts\/receive/);
  await page.getByRole('link', { name: 'Mama Neema Hotel' }).click();
  await expect(page.getByLabel(/Amount received/)).toBeVisible();
  await page.getByLabel(/Amount received/).fill('35000');

  // The preview: the older debt is paid off, 15,000 goes on the newer one.
  const rows = page.locator('table').last().locator('tbody tr');
  await expect(rows.nth(0)).toContainText('Paid off');
  await expect(rows.nth(1)).toContainText(tzs(15000));
  await page.getByLabel('Transaction reference').fill('QK7A1');
  await page.getByRole('button', { name: 'Record payment' }).click();
  await expect(page.getByText('Payment recorded.')).toBeVisible();
  await expect(page.locator('tr', { hasText: 'Mama Neema Hotel' })).toContainText(tzs(15000));

  const detail = (id: string) => api.get<{ status: string; balance: string }>(`/ops/ledger/debts/${id}`);
  expect((await detail(owed(older))).status).toBe('settled');
  expect(Number((await detail(owed(newer))).balance)).toBe(15000);

  await page.goto('/finance/cash-book');
  const book = page.locator('tbody tr', { hasText: 'Mama Neema Hotel' });
  await expect(book).toHaveCount(1);
  await expect(book).toContainText('Customer payment over 2 debts');
  await expect(book).toContainText('QK7A1');
});
