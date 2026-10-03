import { businessToday, expect, opsApi, seed, signInOperator, test } from './fixtures';

// M1.4: a sale's supplier debt is corrected for a reason, not "reconciled"
// away. Wrong supplier on a TZS 100,000 invoice with 40,000 already paid:
// the correct supplier is owed 100,000, the 40,000 stays with the supplier
// who received it as credit, money out and the buying cost do not change.

type Debt = { id: string; direction: string; status: string; supplier_id: string | null; amount: string; paid_amount: string };
type Sale = { id: string; cost_amount: string; debts: Debt[] };

const supplierBody = (phone: string, name: string) => ({
  phone, name, public_alias: `${name} Poultry`, legal_name: `${name} Ltd`, region: 'Pwani', district: 'Kibaha',
  categories: ['broilers'], primary_category: 'broilers',
  production_profile: { broilers: { capacity: '2000', unit: 'bird', frequency: 'every 6 weeks' } },
  internal_pickup_address: 'Farm road, Kibaha', supply_forms: ['live'], verification: {}, future_batches: [],
});

test('Wrong supplier moves the whole debt and keeps the payment with whoever received it', async ({ page, context }) => {
  const seeded = seed('operator');
  const api = opsApi(seeded.operator_token);
  const today = businessToday();
  const wrong = await api.post<{ id: string }>('/ops/suppliers', supplierBody('+255712000781', 'Wrong Farmer'));
  const right = await api.post<{ id: string }>('/ops/suppliers', supplierBody('+255712000782', 'Right Farmer'));
  const sale = await api.post<Sale>('/ops/sales', {
    new_buyer: { business_name: 'E2E Correction Shop', phone: '0754 000 781', region: 'dar es salaam' }, sold_on: today,
    items: [{ category: 'broilers', unit: 'bird', quantity: '10', unit_price: '13000', supplier_id: wrong.id, unit_cost: '10000' }],
  });
  const debt = sale.debts.find((row) => row.direction === 'payable')!;
  await api.post(`/ops/ledger/suppliers/${wrong.id}/payments`, {
    amount: '40000', paid_on: today, method: 'mpesa', reference: 'E2E-WRONG-1', debt_ids: [debt.id],
  });

  await signInOperator(context, seeded.operator_token);
  await page.goto(`/finance/debts/${debt.id}`);
  const card = page.locator('.card', { has: page.getByRole('heading', { name: 'Correct this supplier debt' }) });
  await expect(card).toBeVisible();
  for (const action of ['Wrong supplier', 'Duplicate liability', 'Free or gift stock', 'Cost never existed']) {
    await expect(card.locator('summary', { hasText: action })).toBeVisible();
  }
  await card.locator('summary', { hasText: 'Wrong supplier' }).click();
  await card.getByLabel('Correct registered supplier').selectOption({ label: 'Right Farmer Ltd · Right Farmer Poultry' });
  await card.getByLabel(/has the money: keep it as their credit/).check();
  await card.locator('#wrong-supplier-reason').fill('Birds came from Right Farmer');
  page.once('dialog', (dialog) => dialog.accept());
  await card.getByRole('button', { name: 'Move to the correct supplier' }).click();

  await expect(page.getByText('Cancelled', { exact: false }).first()).toBeVisible();
  const corrections = page.locator('.card', { has: page.getByRole('heading', { name: 'Corrections' }) });
  await expect(corrections).toContainText('Wrong supplier: Birds came from Right Farmer');

  const after = await api.get<Sale>(`/ops/sales/${sale.id}`);
  expect(Number(after.cost_amount)).toBe(100_000);
  const owed = after.debts.find((row) => row.direction === 'payable' && row.status === 'open')!;
  expect([owed.supplier_id, Number(owed.amount), Number(owed.paid_amount)]).toEqual([right.id, 100_000, 0]);
  const statement = await api.get<{ transferred: string; credit: string; owed: string }>(`/ops/ledger/suppliers/${wrong.id}/statement`);
  expect([Number(statement.transferred), Number(statement.credit), Number(statement.owed)]).toEqual([40_000, 40_000, 0]);

  // The corrected supplier's debt links back to the correction.
  await corrections.getByRole('link', { name: 'this debt' }).click();
  await expect(page).toHaveURL(new RegExp(`/finance/debts/${owed.id}$`));
  await expect(page.locator('.card', { has: page.getByRole('heading', { name: 'Corrections' }) })).toContainText('Moved here from');
});
