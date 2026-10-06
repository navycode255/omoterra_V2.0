import { expect, seed, signInOperator, test, tzs } from './fixtures';

// M2.3 / F05: accounts start from a verified opening balance; a payment names
// its account (suggested from the method); a count that differs is listed to
// explain and never changes the balance; a transfer between accounts moves
// money between them only.

const daysAgo = (n: number) => new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Dar_es_Salaam' })
  .format(new Date(Date.now() - n * 86_400_000));

test('Accounts: opening balances, a payment from an account, a count difference and a transfer', async ({ page, context }) => {
  const seeded = seed('operator');
  await signInOperator(context, seeded.operator_token);

  await page.goto('/finance/accounts');
  await expect(page.getByText(/No accounts yet/)).toBeVisible();
  for (const [name, kind, provider, opening] of [['Petty cash', 'cash', '', '100000'], ['M-Pesa till', 'mobile_wallet', 'M-Pesa', '50000']]) {
    await page.getByLabel('Name', { exact: true }).fill(name);
    await page.getByLabel('Kind').selectOption(kind);
    await page.getByLabel('Bank or provider').fill(provider);
    await page.getByLabel('Cutoff (end of day)').fill(daysAgo(3));
    await page.getByLabel('Verified balance then (TZS)').fill(opening);
    await page.getByLabel('Evidence for the balance').fill('Counted by two staff on the cutoff day');
    await page.getByRole('button', { name: 'Set up account' }).click();
    await expect(page.getByRole('link', { name })).toBeVisible();
  }

  // An expense paid in cash: the account picker suggests the cash box.
  await page.goto('/finance/expenses');
  await page.getByRole('button', { name: 'Record expense', exact: true }).first().click();
  await page.getByLabel('What for').fill('Helpers for chicken prep');
  await page.getByLabel('Amount (TZS)').fill('20000');
  const account = page.getByLabel('Paid from account');
  await expect(account.locator('option:checked')).toHaveText('Petty cash');
  await page.getByRole('button', { name: 'Save expense' }).click();
  await expect(page.getByText('Expense saved.')).toBeVisible();

  await page.goto('/finance/accounts');
  await page.getByRole('link', { name: 'Petty cash' }).click();
  const balance = page.locator('article', { hasText: 'Balance today' }).locator('strong');
  await expect(balance).toHaveText(tzs(80_000));
  await expect(page.locator('tbody tr', { hasText: 'Helpers for chicken prep' }).locator('td[data-label="Balance after"]')).toHaveText('80,000');

  // A count that finds 79,000: listed, the balance does not move.
  await page.getByLabel('Balance (TZS)').fill('79000');
  await page.getByLabel('Evidence', { exact: true }).fill('Counted by Asha and Juma at close');
  await page.getByRole('button', { name: 'Record check' }).click();
  const check = page.locator('tbody tr', { hasText: 'Cash count' });
  await expect(check.locator('td[data-label="Difference"]')).toHaveText(tzs(-1_000));
  await expect(balance).toHaveText(tzs(80_000));
  await check.getByText('Explain', { exact: true }).click();
  await check.getByLabel('What explains it').fill('Bus fare paid from the box');
  await check.getByRole('button', { name: 'Save explanation' }).click();
  await expect(check.locator('td[data-label="Explanation"]')).toHaveText('Bus fare paid from the box');

  // 10,000 from the M-Pesa till into the cash box.
  await page.goto('/finance/accounts');
  await page.getByLabel('From', { exact: true }).selectOption({ label: 'M-Pesa till' });
  await page.getByLabel('To', { exact: true }).selectOption({ label: 'Petty cash' });
  await page.getByLabel('Amount (TZS)').fill('10000');
  await page.getByRole('button', { name: 'Record transfer' }).click();
  await expect(page.getByRole('row', { name: /^Petty cash Cash box 90,000 / })).toBeVisible();
  await expect(page.getByRole('row', { name: /^M-Pesa till Mobile wallet M-Pesa 40,000 / })).toBeVisible();
  await expect(page.locator('article', { hasText: 'Recorded balance, all accounts' }).locator('strong')).toHaveText(tzs(130_000));
});
