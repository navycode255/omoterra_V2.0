import { expect, seed, signInOperator, test } from './fixtures';

// M0.4 / F13: rows that need action come first, but they are paged with the
// history behind them. 66 debts, 18 of them open, at 10 a page: 7 pages,
// every debt exactly once, and the 18 open ones on pages 1 and 2.
test('Debts: clicking through every page shows each debt exactly once', async ({ page, context }) => {
  const seeded = seed('debts');
  await signInOperator(context, seeded.operator_token);

  await page.goto('/finance/debts');
  const pager = page.getByRole('navigation', { name: 'Debt pages' });
  await expect(pager.getByRole('link', { name: '7', exact: true })).toBeVisible();
  await expect(pager.getByRole('link', { name: '8', exact: true })).toHaveCount(0);

  const seen: string[] = [];
  const openSeen: string[] = [];
  let pages = 0;
  for (;;) {
    pages += 1;
    expect(pages, 'more pages than expected').toBeLessThanOrEqual(7);
    await expect(pager.locator('[aria-current="page"]')).toHaveText(String(pages));
    const rows = page.locator('table tbody tr');
    const count = await rows.count();
    expect(count, `rows on page ${pages}`).toBe(pages < 7 ? 10 : 6);
    const first = (pages - 1) * 10 + 1;
    await expect(page.getByText(`Showing ${first} – ${first + count - 1} of 66`)).toBeVisible();
    for (let index = 0; index < count; index += 1) {
      const row = rows.nth(index);
      const name = (await row.locator('td[data-label="Who"] a').first().innerText()).trim();
      seen.push(name);
      const status = (await row.locator('td[data-label="Status"]').innerText()).trim();
      if (status !== 'Settled' && status !== 'Cancelled') openSeen.push(name);
    }
    const next = pager.getByRole('link', { name: 'Next ›' });
    if (!(await next.count())) break;
    await Promise.all([page.waitForURL(`**/finance/debts?page=${pages + 1}`), next.click()]);
  }

  expect(pages).toBe(7);
  expect(seen).toHaveLength(66);
  expect(new Set(seen).size).toBe(66);
  expect(new Set(seen)).toEqual(new Set(seeded.debts!.map((debt) => debt.name)));
  // Rows needing action come first: the 18 open debts fill page 1 and the
  // start of page 2, before any settled or cancelled history.
  const expectedOpen = seeded.debts!.filter((debt) => debt.status === 'open').map((debt) => debt.name);
  expect(new Set(openSeen)).toEqual(new Set(expectedOpen));
  expect(new Set(seen.slice(0, 18))).toEqual(new Set(expectedOpen));
});
