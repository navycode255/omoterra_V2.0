import { expect, seed, signInOperator, test, tzs } from './fixtures';

// M2.1 / F09: Stock lists every received lot with what is on hand on a date;
// a lot's page shows each dated movement with the balance after it. A loss
// and a physical count are movements too, and a count's shortage is stock
// lost at the lot's cost.

test('Stock shows each lot on hand by date, with losses and counts as movements', async ({ page, context }) => {
  const seeded = seed('operator');
  await signInOperator(context, seeded.operator_token);

  // 20 birds of opening stock at 6,000 each.
  await page.goto('/finance/opening-stock');
  await page.getByLabel('Quantity on hand').fill('20');
  await page.getByLabel('Cost per unit (TZS)').fill('6000');
  await page.getByLabel('Evidence or reason for this value').fill('Counted 20 kienyeji at the pen');
  await page.getByRole('button', { name: 'Record opening stock' }).click();
  await expect(page.getByText('Opening stock recorded.')).toBeVisible();

  await page.goto('/stock');
  const lots = page.locator('section', { has: page.getByRole('heading', { name: /^Lots with stock on/ }) });
  const row = lots.locator('tr', { hasText: /OS-/ });
  await expect(row.locator('td[data-label="On hand"]')).toHaveText('20 bird');
  await expect(page.locator('article', { hasText: 'Value on hand' }).locator('strong')).toHaveText(tzs(120_000));

  // Open the lot: one movement so far.
  await row.getByRole('link', { name: /OS-/ }).click();
  await expect(page).toHaveURL(/\/stock\/opening_stock\//);
  const movements = page.locator('section', { has: page.getByRole('heading', { name: 'Movements' }) });
  await expect(movements.locator('tbody tr')).toHaveCount(1);

  // 3 died: on hand 17.
  await page.getByLabel('Quantity (birds)').fill('3');
  await page.getByRole('button', { name: 'Record loss' }).click();
  await expect(movements.locator('tbody tr', { hasText: 'Died' }).locator('td[data-label="On hand after"]')).toHaveText('17');

  // A count finds 15: 2 short, recorded with its evidence.
  await page.getByLabel('Counted (birds)').fill('15');
  await page.getByLabel('Why the records differ, if known').fill('Two missing from the pen');
  await page.getByLabel('Evidence (count sheet, who counted)').fill('Count sheet signed by two staff');
  await page.getByRole('button', { name: 'Record count' }).click();
  const counted = movements.locator('tbody tr', { hasText: 'Stock count difference' });
  await expect(counted.locator('td[data-label="Change"]')).toHaveText('-2');
  await expect(counted.locator('td[data-label="On hand after"]')).toHaveText('15');
  await expect(page.locator('article', { hasText: /^On hand/ }).locator('strong')).toHaveText('15 bird');

  // Back on Stock: 15 now, and nothing before the stock existed.
  await page.goto('/stock');
  await expect(lots.locator('tr', { hasText: /OS-/ }).locator('td[data-label="On hand"]')).toHaveText('15 bird');
  await page.goto('/stock?as_of=2020-01-01');
  await expect(page.getByText(/No stock on hand in lots on/)).toBeVisible();
});
