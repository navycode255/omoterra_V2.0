import { devices } from '@playwright/test';
import { businessToday, expect, opsApi, seed, signInOperator, test } from './fixtures';

// The financial report PDF is drawn in the browser, so it must also build on
// a phone (Chrome on Android), not only on a desktop.
test.use({ ...devices['Pixel 7'] });

test('Financial report PDF downloads on a phone', async ({ page, context }) => {
  const seeded = seed('operator');
  const today = businessToday();
  await opsApi(seeded.operator_token).post('/ops/sales', {
    new_buyer: { business_name: 'E2E PDF Buyer', phone: '0754 000 777', region: 'dar es salaam' }, sold_on: today,
    items: [{ category: 'local_chicken', unit: 'bird', quantity: '4', unit_price: '15000', supplier_name: 'Mzee Juma', unit_cost: '10000' }],
    payment: { amount: '60000', paid_on: today, method: 'cash' },
  });
  await signInOperator(context, seeded.operator_token);
  const errors: string[] = [];
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()); });
  page.on('pageerror', (error) => errors.push(error.message));

  await page.goto('/finance/reports');
  const download = page.waitForEvent('download', { timeout: 60_000 });
  await page.getByRole('button', { name: 'Download PDF' }).click();
  const file = await download.catch(() => null);
  expect(errors, errors.join('\n')).toEqual([]);
  expect(file?.suggestedFilename()).toMatch(/^Omoterra-Financial-Report-.*\.pdf$/);
  await expect(page.getByText('The PDF could not be created')).toHaveCount(0);
  // Nine A4 pages, each drawn as an image.
  const pdf = (await import('node:fs')).readFileSync(await file!.path());
  expect(pdf.subarray(0, 5).toString()).toBe('%PDF-');
  expect(pdf.toString('latin1').match(/\/Type \/Page\b/g)?.length).toBe(9);
});

test('Financial report PDF still downloads when a font fails to load', async ({ page, context }) => {
  const seeded = seed('operator');
  await signInOperator(context, seeded.operator_token);
  // A weak mobile connection: every web font request fails.
  await page.route(/\.woff2?$/, (route) => route.abort('internetdisconnected'));
  await page.goto('/finance/reports');
  const download = page.waitForEvent('download', { timeout: 60_000 });
  await page.getByRole('button', { name: 'Download PDF' }).click();
  expect((await download).suggestedFilename()).toMatch(/\.pdf$/);
});
