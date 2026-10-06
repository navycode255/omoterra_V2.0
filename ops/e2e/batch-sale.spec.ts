import { businessToday, expect, opsApi, seed, signInOperator, test } from './fixtures';

// M1.6 / F09: a sale from a supplier batch needs "We collected these birds"
// confirmed, records a same-day delivery note the line sells from, and
// cancelling the sale asks what happened to the goods (rule R2).

type Note = { id: string; on_hand: string; sold: string; payable: { amount: string; status: string } | null };
type Sale = { id: string; items: { supplier_collection_id: string | null }[]; debts: { direction: string }[] };

test('A batch sale is confirmed as collected, becomes a delivery note, and its cancellation asks about the goods', async ({ page, context }) => {
  const seeded = seed('operator');
  const api = opsApi(seeded.operator_token);
  const today = businessToday();
  const supplier = await api.post<{ id: string }>('/ops/suppliers', {
    phone: '+255712000791', name: 'Batch Farmer', public_alias: 'E2E Batch Poultry', legal_name: 'E2E Batch Farm Ltd',
    region: 'Pwani', district: 'Kibaha', categories: ['broilers'], primary_category: 'broilers',
    production_profile: { broilers: { capacity: '2000', unit: 'bird', frequency: 'every 6 weeks' } },
    internal_pickup_address: 'Farm road, Kibaha', supply_forms: ['live'], verification: {}, future_batches: [],
  });
  await api.post(`/ops/suppliers/${supplier.id}/batches`, {
    category: 'broilers', initial_quantity: '300', expected_ready_date: today, region: 'Pwani', asking_price_per_unit: '6500',
  });

  await signInOperator(context, seeded.operator_token);
  await page.goto('/sales/new');
  await page.getByText('New buyer', { exact: true }).click();
  await page.getByLabel('Buyer or business name').fill('E2E Batch Buyer');
  await page.locator('#cat-1').selectOption('broilers');
  await page.locator('#qty-1').fill('20');
  await page.locator('#price-1').fill('7000');
  await page.locator('#src-1').selectOption('supplier');
  await page.locator('#sup-1').selectOption(supplier.id);
  await expect(page.locator('#batch-1')).not.toHaveValue('');
  const confirm = page.getByLabel(/We collected these 20 birds from E2E Batch Farm Ltd on/);
  await expect(confirm).toBeVisible();
  // Without the confirmation the browser does not submit.
  await page.getByRole('button', { name: 'Save sale' }).click();
  await expect(page).toHaveURL(/\/sales\/new/);
  await confirm.check();
  await page.getByRole('button', { name: 'Save sale' }).click();
  await expect(page).toHaveURL(/\/sales\/[^/]+\?created=1/);

  const saleId = new URL(page.url()).pathname.split('/').pop()!;
  const sale = await api.get<Sale>(`/ops/sales/${saleId}`);
  const noteId = sale.items[0].supplier_collection_id!;
  expect(noteId).toBeTruthy();
  expect(sale.debts.map((debt) => debt.direction)).toEqual(['receivable']);
  await expect(page.getByRole('link', { name: 'Delivery note' })).toHaveAttribute('href', `/supplier-collections/${noteId}`);

  // Cancel: the goods never left, so they are back on hand on the note.
  await page.getByRole('button', { name: 'More actions', exact: true }).click();
  await page.locator('#reason').fill('Buyer did not collect');
  await page.getByLabel('They never left Omoterra: back on hand').check();
  page.once('dialog', (dialog) => dialog.accept());
  await page.getByRole('button', { name: 'Cancel sale' }).click();
  await expect(page.getByText(/Received goods: they never left omoterra/)).toBeVisible();

  const note = await api.get<Note>(`/ops/supplier-collections/${noteId}`);
  expect([Number(note.on_hand), Number(note.sold), Number(note.payable!.amount), note.payable!.status]).toEqual([20, 0, 130_000, 'open']);
  await page.goto(`/supplier-collections/${noteId}`);
  await expect(page.getByText('Sale cancelled or reduced: goods never left (back on hand)')).toBeVisible();
  await expect(page.getByText('Collected and sold the same day')).toBeVisible();
});
