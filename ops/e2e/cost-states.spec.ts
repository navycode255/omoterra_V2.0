import { expect, seed, signInOperator, test, tzs } from './fixtures';

// M1.3 / F02 (rule R5): a sale of own stock with "Cost unknown" makes Profit
// "Provisional: buying costs incomplete" (no figure). Opening stock recorded
// at the finance owner's value sells at a known cost, and giving the unknown
// line a cost from it makes Profit final again.

const PROVISIONAL = 'Provisional: buying costs incomplete';

test('Unknown cost makes Profit provisional; opening stock gives a known margin', async ({ page, context }) => {
  const seeded = seed('operator');
  await signInOperator(context, seeded.operator_token);

  // Own stock: the form needs a cost, opening stock, or "Cost unknown".
  await page.goto('/sales/new');
  await page.getByText('New buyer', { exact: true }).click();
  await page.getByLabel('Buyer or business name').fill('E2E Unknown Cost Buyer');
  await page.locator('#qty-1').fill('3');
  await page.locator('#price-1').fill('7000');
  await expect(page.locator('#src-1')).toHaveValue('own');
  await page.getByLabel('Cost unknown').check();
  await expect(page.getByText('Provisional: cost unknown')).toBeVisible();
  await page.getByRole('button', { name: 'Save sale' }).click();
  await expect(page).toHaveURL(/\/sales\/[^/]+\?created=1/);
  const unknownSale = page.url().split('?')[0];
  await expect(page.getByText('Provisional: cost unknown').first()).toBeVisible();

  await page.goto('/finance/profit');
  const profit = page.locator('section[aria-label="Profit summary"]');
  await expect(profit.locator('article', { hasText: 'Operating profit' }).locator('strong')).toHaveText(PROVISIONAL);
  await expect(profit.getByText(`1 sale · ${tzs(21_000)} revenue affected`)).toBeVisible();

  // Opening stock: 50 birds valued at 6,000 each, no supplier debt.
  await page.goto('/finance/opening-stock');
  await page.getByLabel('Quantity on hand').fill('50');
  await page.getByLabel('Cost per unit (TZS)').fill('6000');
  await page.getByLabel('Evidence or reason for this value').fill('Counted 50 kienyeji on 1 Oct; bought at 6,000 each');
  await page.getByRole('button', { name: 'Record opening stock' }).click();
  await expect(page.getByText('Opening stock recorded.')).toBeVisible();
  const entries = page.locator('section', { has: page.getByRole('heading', { name: 'Opening stock entries' }) });
  await expect(entries.getByText(/^OS-/)).toBeVisible();
  await expect(page.locator('article', { hasText: 'Value recorded' }).locator('strong')).toHaveText(tzs(300_000));

  // Sell 10 from it: a known margin of 10 x (8,000 - 6,000).
  await page.goto('/sales/new');
  await page.getByText('New buyer', { exact: true }).click();
  await page.getByLabel('Buyer or business name').fill('E2E Opening Stock Buyer');
  await page.locator('#qty-1').fill('10');
  await page.locator('#price-1').fill('8000');
  await page.locator('#src-1').selectOption('opening');
  await page.locator('#opening-1').selectOption({ index: 1 });
  await page.getByRole('button', { name: 'Save sale' }).click();
  await expect(page).toHaveURL(/\/sales\/[^/]+\?created=1/);
  const summary = page.locator('section', { has: page.getByRole('heading', { name: 'Sale summary' }) });
  await expect(summary.locator('div', { hasText: /^Margin before expenses/ }).locator('dd')).toHaveText(tzs(20_000));
  await expect(page.getByRole('link', { name: /^Opening stock OS-/ })).toBeVisible();

  // Give the unknown line its cost from the same opening stock.
  await page.goto(unknownSale);
  await page.getByLabel('Opening stock', { exact: true }).selectOption({ index: 1 });
  await page.getByLabel('Reason').first().fill('These were from the counted pen');
  await page.getByRole('button', { name: 'Give this line its cost' }).click();
  await expect(summary.locator('div', { hasText: /^Margin before expenses/ }).locator('dd')).toHaveText(tzs(3_000));

  // Nothing unknown left: Profit shows its figure again.
  await page.goto('/finance/profit');
  await expect(profit.locator('article', { hasText: 'Operating profit' }).locator('strong')).toHaveText(tzs(23_000));
});
