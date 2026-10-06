import { expect, seed, signInOperator, test } from './fixtures';

// M2.2 (rule R8): a sale of received stock dated more than 3 days back is a
// late entry. The form asks an admin why; the sale is then recorded, and the
// stock it used shows on the lot's history on that date.

const daysAgo = (n: number) => new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Dar_es_Salaam' })
  .format(new Date(Date.now() - n * 86_400_000));

test('A sale dated more than 3 days back asks why, then uses stock on that date', async ({ page, context }) => {
  const seeded = seed('operator');
  await signInOperator(context, seeded.operator_token);

  await page.goto('/finance/opening-stock');
  await page.getByLabel('Quantity on hand').fill('10');
  await page.getByLabel('Cost per unit (TZS)').fill('6000');
  await page.getByLabel('Valued as of').fill(daysAgo(12));
  await page.getByLabel('Evidence or reason for this value').fill('Counted 10 kienyeji at the pen');
  await page.getByRole('button', { name: 'Record opening stock' }).click();
  await expect(page.getByText('Opening stock recorded.')).toBeVisible();

  await page.goto('/sales/new');
  await page.getByText('New buyer', { exact: true }).click();
  await page.getByLabel('Buyer or business name').fill('E2E Late Entry Buyer');
  await page.locator('#qty-1').fill('4');
  await page.locator('#price-1').fill('8000');
  await page.locator('#src-1').selectOption('opening');
  await page.locator('#opening-1').selectOption({ index: 1 });
  await expect(page.getByLabel('Why it is recorded late (admin only)')).toHaveCount(0);
  await page.locator('#sold-on-1').fill(daysAgo(10));
  await page.getByLabel('Why it is recorded late (admin only)').fill('Paper invoice found in the market book');
  await page.getByRole('button', { name: 'Save sale' }).click();
  await expect(page).toHaveURL(/\/sales\/[^/]+\?created=1/);

  // The lot shows the sale on its own date.
  await page.goto('/stock');
  await page.locator('tr', { hasText: /OS-/ }).getByRole('link', { name: /OS-/ }).click();
  const sold = page.locator('section', { has: page.getByRole('heading', { name: 'Movements' }) }).locator('tbody tr', { hasText: 'Sold' });
  await expect(sold.locator('td[data-label="On hand after"]')).toHaveText('6');
});
