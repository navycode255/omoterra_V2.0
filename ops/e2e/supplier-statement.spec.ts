import { businessToday, expect, memberSession, opsApi, seed, signInMember, signInOperator, test, tzs } from './fixtures';

// M0.5 statement-consistency harness. One supplier: stock received on a
// delivery note, a sale costed from their batch and one transfer to them.
// Every screen that shows money with this supplier must agree on what was
// bought, paid and is still owed. Later milestones extend this scenario.

const RECEIVED = { quantity: 50, unitCost: 6000 }; // delivery note: 300,000
const SOLD = { quantity: 20, unitCost: 6500, unitPrice: 7000 }; // sale cost: 130,000
const PAID = 200_000;
const BOUGHT = RECEIVED.quantity * RECEIVED.unitCost + SOLD.quantity * SOLD.unitCost;
const OWED = BOUGHT - PAID;

type Statement = { bought: string; paid: string; owed: string };

test('Supplier money agrees on the supplier page, Supplier payments, the supplier list and the portal', async ({ page, context }) => {
  const seeded = seed('operator');
  const api = opsApi(seeded.operator_token);
  const today = businessToday();
  const readyOn = new Date(Date.now() + 7 * 86_400_000).toISOString().slice(0, 10);

  const supplier = await api.post<{ id: string }>('/ops/suppliers', {
    phone: '+255712000777', name: 'Statement Farmer', public_alias: 'E2E Statement Poultry', legal_name: 'E2E Statement Farm Ltd',
    region: 'Pwani', district: 'Kibaha', categories: ['broilers'], primary_category: 'broilers',
    production_profile: { broilers: { capacity: '2000', unit: 'bird', frequency: 'every 6 weeks' } },
    internal_pickup_address: 'Farm road, Kibaha', supply_forms: ['live'], verification: {}, future_batches: [],
  });
  const batch = await api.post<{ id: string }>(`/ops/suppliers/${supplier.id}/batches`, {
    category: 'broilers', initial_quantity: '300', expected_ready_date: readyOn, region: 'Pwani', asking_price_per_unit: '6500',
  });
  await api.post(`/ops/suppliers/${supplier.id}/collections`, {
    batch_id: batch.id, received_on: today, delivered_quantity: String(RECEIVED.quantity),
    accepted_quantity: String(RECEIVED.quantity), unit_cost: String(RECEIVED.unitCost),
  });
  await api.post('/ops/sales', {
    new_buyer: { business_name: 'E2E Buyer Shop', phone: '0754 000 777', region: 'dar es salaam' }, sold_on: today,
    items: [{ category: 'broilers', unit: 'bird', quantity: String(SOLD.quantity), unit_price: String(SOLD.unitPrice),
      supplier_id: supplier.id, unit_cost: String(SOLD.unitCost), supplier_batch_id: batch.id }],
  });
  await api.post(`/ops/ledger/suppliers/${supplier.id}/payments`, {
    amount: String(PAID), paid_on: today, method: 'mpesa', reference: 'E2E-TRANSFER-1',
  });

  // The backend's own statement is the reference every screen must match.
  const statement = await api.get<Statement>(`/ops/ledger/suppliers/${supplier.id}/statement`);
  expect([Number(statement.bought), Number(statement.paid), Number(statement.owed)]).toEqual([BOUGHT, PAID, OWED]);

  await signInOperator(context, seeded.operator_token);

  // 1. Staff supplier page, "Money with this supplier".
  await page.goto(`/suppliers/${supplier.id}`);
  const money = page.locator('section#money');
  await expect(money.getByRole('heading', { name: 'Money with this supplier' })).toBeVisible();
  const stat = (label: string) => money.locator('.stat', { has: page.locator('.stat-label', { hasText: label }) }).locator('.stat-value');
  await expect(stat('Bought from them')).toHaveText(tzs(BOUGHT));
  await expect(stat('Paid to them')).toHaveText(tzs(PAID));
  await expect(stat('Still owed')).toHaveText(tzs(OWED));

  // 2. Finance > Supplier payments, the supplier's balance row. It shows what
  // is owed and the last payment (the only one here), not the amount bought.
  await page.goto('/finance/supplier-payments');
  const balance = page.locator('table tbody tr', { has: page.getByRole('link', { name: 'E2E Statement Farm Ltd' }) });
  await expect(balance).toHaveCount(1);
  await expect(balance.locator('td[data-label^="Amount owed"]')).toHaveText(OWED.toLocaleString('en-US'));
  await expect(balance.locator('td[data-label^="Last payment"] small')).toHaveText(tzs(PAID));

  // 3. Suppliers list: paid and owed (bought is their sum).
  await page.goto('/suppliers');
  const listed = page.locator('table.supplier-table tbody tr', { has: page.getByRole('link', { name: 'E2E Statement Poultry', exact: true }) });
  await expect(listed).toHaveCount(1);
  const cells = listed.locator('td.money');
  await expect(cells.nth(0)).toHaveText(tzs(PAID));
  await expect(cells.nth(1)).toHaveText(tzs(OWED));

  // 4. The supplier's own portal, Payouts.
  await signInMember(context, memberSession(supplier.id));
  await page.goto('/account?view=payouts');
  const summary = page.locator('section.portal-payment-summary');
  await expect(summary.locator('span', { hasText: 'Total paid' }).locator('b')).toHaveText(tzs(PAID));
  await expect(summary.locator('span', { hasText: 'Owed to you' }).locator('b')).toHaveText(tzs(OWED));
});
