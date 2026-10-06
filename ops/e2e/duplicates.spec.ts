import { businessToday, expect, opsApi, seed, signInOperator, test, tzs } from './fixtures';

// M2.4 (F08): a sale line from a delivery note shows the receipt's supplier
// payment status, for information only. M2.6 (F11): a payment with no
// reference that matches an earlier one is refused until staff tick "This is
// a separate payment" and say why.

type Sale = {
  id: string; buyer_profile_id: string; supplier_balance: string;
  items: { stock_source: { invoices: { debt_id: string }[] } | null }[];
  debts: { id: string; direction: string }[];
};

test('A sale line from a delivery note shows the supplier invoice and what is paid on it', async ({ page, context }) => {
  const seeded = seed('operator');
  const api = opsApi(seeded.operator_token);
  const today = businessToday();
  const supplier = await api.post<{ id: string }>('/ops/suppliers', {
    phone: '+255712000792', name: 'Source Farmer', public_alias: 'E2E Source Poultry', legal_name: 'E2E Source Farm Ltd',
    region: 'Pwani', district: 'Kibaha', categories: ['broilers'], primary_category: 'broilers',
    production_profile: { broilers: { capacity: '2000', unit: 'bird', frequency: 'every 6 weeks' } },
    internal_pickup_address: 'Farm road, Kibaha', supply_forms: ['live'], verification: {}, future_batches: [],
  });
  const batch = await api.post<{ id: string }>(`/ops/suppliers/${supplier.id}/batches`, {
    category: 'broilers', initial_quantity: '300', expected_ready_date: today, region: 'Pwani', asking_price_per_unit: '6500',
  });
  const sale = await api.post<Sale>('/ops/sales', {
    new_buyer: { business_name: 'E2E Source Buyer' }, sold_on: today,
    items: [{ category: 'broilers', unit: 'bird', quantity: '20', unit_price: '7000', supplier_id: supplier.id,
      unit_cost: '6500', supplier_batch_id: batch.id, receipt_confirmed: true }],
  });
  const invoice = sale.items[0].stock_source!.invoices[0].debt_id;
  await api.post(`/ops/ledger/suppliers/${supplier.id}/payments`, {
    amount: '50000', paid_on: today, method: 'mpesa', reference: 'QE2ESRC1', debt_ids: [invoice],
  });

  await signInOperator(context, seeded.operator_token);
  await page.goto(`/sales/${sale.id}`);
  const source = page.getByTestId('stock-source');
  await expect(source).toContainText(/Stock from DN-/);
  await expect(source).toContainText('Supplier part paid');
  await expect(source).toContainText(`paid ${tzs(50000)} (balance ${tzs(80000)})`);
  await expect(source.getByRole('link', { name: tzs(130000) })).toHaveAttribute('href', `/finance/debts/${invoice}`);
  // Information only: the sale itself owes no supplier anything.
  expect(Number((await api.get<Sale>(`/ops/sales/${sale.id}`)).supplier_balance)).toBe(0);
  await expect(page.getByText(/I owe /)).toHaveCount(0);
});

test('A possible duplicate payment needs "This is a separate payment" and a reason', async ({ page, context }) => {
  const seeded = seed('operator');
  const api = opsApi(seeded.operator_token);
  const today = businessToday();
  const sell = () => api.post<Sale>('/ops/sales', {
    new_buyer: { business_name: 'Mama Duplicate Hotel', phone: '0754 222 444' }, sold_on: today,
    items: [{ category: 'local_chicken', unit: 'bird', quantity: '2', unit_price: '15000', cost_unknown: true }],
  });
  const first = await sell();
  const second = await sell();
  const owed = (sale: Sale) => sale.debts.find((d) => d.direction === 'receivable')!.id;
  await api.post(`/ops/ledger/debts/${owed(first)}/payments`, { amount: '10000', paid_on: today, method: 'cash' });

  await signInOperator(context, seeded.operator_token);
  await page.goto(`/sales/${second.id}`);
  await page.getByRole('button', { name: 'Record buyer payment' }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByLabel(/Amount \(TZS\)/).fill('10000');
  await dialog.getByRole('button', { name: 'Record money received' }).click();
  await expect(dialog.getByText(/Possible duplicate: payment of TZS 10,000 from Mama Duplicate Hotel/)).toBeVisible();
  // What was typed is still there; tick and explain, then send it again.
  await expect(dialog.getByLabel(/Amount \(TZS\)/)).toHaveValue('10000');
  await dialog.getByLabel('This is a separate payment').check();
  await dialog.getByLabel('Why is it separate?').fill('Two cash payments, one for each order');
  await dialog.getByRole('button', { name: 'Record money received' }).click();
  await expect.poll(async () => Number((await api.get<{ paid_amount: string }>(`/ops/ledger/debts/${owed(second)}`)).paid_amount))
    .toBe(10000);
});

test('Pay supplier: a second cash payment of the same amount on the same day needs a reason', async ({ page, context }) => {
  const seeded = seed('operator');
  const api = opsApi(seeded.operator_token);
  const today = businessToday();
  const supplier = await api.post<{ id: string }>('/ops/suppliers', {
    phone: '+255712000793', name: 'Twice Farmer', public_alias: 'E2E Twice Poultry', legal_name: 'E2E Twice Farm Ltd',
    region: 'Pwani', district: 'Kibaha', categories: ['broilers'], primary_category: 'broilers',
    production_profile: { broilers: { capacity: '2000', unit: 'bird', frequency: 'every 6 weeks' } },
    internal_pickup_address: 'Farm road, Kibaha', supply_forms: ['live'], verification: {}, future_batches: [],
  });
  const invoice = async () => (await api.post<Sale>('/ops/sales', {
    new_buyer: { business_name: 'E2E Twice Buyer' }, sold_on: today,
    items: [{ category: 'broilers', unit: 'bird', quantity: '5', unit_price: '8000', supplier_id: supplier.id, unit_cost: '6000' }],
  })).debts.find((d) => d.direction === 'payable')!.id;
  const first = await invoice();
  const second = await invoice();
  await api.post(`/ops/ledger/suppliers/${supplier.id}/payments`, {
    amount: '30000', paid_on: today, method: 'cash', sms_text: 'Paid cash at the farm', debt_ids: [first],
  });

  await signInOperator(context, seeded.operator_token);
  await page.goto(`/finance/supplier-payments?debt=${second}`);
  const panel = page.locator('#pay');
  await panel.locator('select[name="method"]').selectOption('cash');
  await panel.getByPlaceholder('Paste payment confirmation SMS (optional)').fill('Paid cash for the second order');
  await panel.getByRole('button', { name: 'Record payment' }).click();
  await expect(panel.getByRole('alert')).toContainText(/Possible duplicate: supplier transfer of TZS 30,000 to E2E Twice Farm Ltd/);
  await expect(panel.getByPlaceholder('Paste payment confirmation SMS (optional)')).toHaveValue('Paid cash for the second order');
  await panel.getByLabel('This is a separate payment').check();
  await panel.getByLabel('Why is it separate?').fill('Second order collected the same day');
  await panel.getByRole('button', { name: 'Record payment' }).click();
  await expect(page.getByText('Payment recorded and balances updated.')).toBeVisible();
  expect((await api.get<{ status: string }>(`/ops/ledger/debts/${second}`)).status).toBe('settled');
});
