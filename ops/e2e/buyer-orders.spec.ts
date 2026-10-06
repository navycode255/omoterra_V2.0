import { businessToday, expect, opsApi, seed, signInOperator, test, tzs } from './fixtures';

// M2.5 (F07, D7): an order staff take for a buyer by phone is a commitment
// until delivered; "Mark delivered" turns it into a sale dated the delivery
// day, with the deposit on it.

function dayBefore(value: string) {
  const [y, m, d] = value.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d - 1)).toISOString().slice(0, 10);
}

test('A buyer order is a commitment until marked delivered, then a sale on its delivery day', async ({ page, context }) => {
  const seeded = seed('operator');
  const api = opsApi(seeded.operator_token);
  const today = businessToday();
  const yesterday = dayBefore(today);
  await signInOperator(context, seeded.operator_token);

  // Record the order taken by phone, with a deposit.
  await page.goto('/sales/orders/new');
  const form = page.locator('[data-buyer-order-form]');
  await form.getByText('New buyer', { exact: true }).click();
  await form.getByLabel('Buyer or business name').fill('E2E Hoteli ya Order');
  await form.getByLabel('Date ordered').fill(dayBefore(yesterday));
  await form.getByLabel('Product').selectOption('broilers');
  await form.getByLabel('Quantity').fill('5');
  await form.getByLabel('Agreed price per unit (TZS)').fill('12000');
  await form.getByLabel('Deposit paid now (optional, TZS)').fill('20000');
  await form.getByRole('button', { name: 'Save order' }).click();
  await expect(page).toHaveURL(/\/sales\/orders\/[0-9a-f-]+\?created=1/);
  await expect(page.getByRole('note')).toContainText('Not delivered yet: not a sale');
  const orderNumber = (await page.locator('h1').first().textContent())!.trim();
  expect(orderNumber).toMatch(/^BO-/);

  // A commitment: listed as not delivered, nothing in sales or owed.
  await page.goto('/sales/orders?status=open');
  const row = page.locator('[data-buyer-orders-table] tbody tr', { hasText: orderNumber });
  await expect(row).toContainText('Not delivered');
  await expect(row).toContainText(tzs(60000));
  await expect(page.getByText(tzs(20000)).first()).toBeVisible();
  const summary = await api.get<{ owed_to_me: { total: string }; today: { sales: string }; commitments: { ledger: string } }>('/ops/finance/summary');
  expect(Number(summary.owed_to_me.total)).toBe(0);
  expect(Number(summary.today.sales)).toBe(0);
  expect(Number(summary.commitments.ledger)).toBe(60000);
  await page.goto('/finance');
  await expect(page.locator('[data-commitments-link]')).toContainText(`Orders not delivered: ${tzs(60000)}`);

  // Mark delivered yesterday: the sale form, filled in from the order.
  await page.goto('/sales/orders?status=open');
  await page.getByRole('link', { name: orderNumber, exact: true }).click();
  await page.getByRole('link', { name: 'Mark delivered' }).click();
  await expect(page.locator('[data-order-buyer]')).toContainText('E2E Hoteli ya Order');
  await expect(page.getByLabel('Quantity')).toHaveValue('5');
  await page.getByLabel('Date delivered').fill(yesterday);
  await page.getByLabel('Buying cost per unit (TZS)').fill('8000');
  await page.getByRole('button', { name: 'Mark delivered and save sale' }).click();
  await expect(page).toHaveURL(/\/sales\/[0-9a-f-]+\?created=1/);
  await expect(page.locator('[data-from-order]')).toContainText(orderNumber);

  // In Sales on the delivery day, with the deposit received; not today.
  await page.goto(`/sales?start=${yesterday}&end=${yesterday}`);
  const sale = page.locator('[data-sales-table] tbody tr', { hasText: 'E2E Hoteli ya Order' });
  await expect(sale).toHaveCount(1);
  await expect(sale).toContainText(tzs(60000));
  await expect(sale).toContainText(tzs(20000));
  await page.goto(`/sales?start=${today}&end=${today}`);
  await expect(page.locator('[data-sales-table] tbody tr', { hasText: 'E2E Hoteli ya Order' })).toHaveCount(0);
  const after = await api.get<{ commitments: { ledger: string } }>('/ops/finance/summary');
  expect(Number(after.commitments.ledger)).toBe(0);
});
