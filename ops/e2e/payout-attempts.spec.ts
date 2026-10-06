import { expect, memberSession, seed, signInMember, signInOperator, test, tzs } from './fixtures';

// M2.7 (F12, decision D9): a payout is sent (not money out yet), then
// confirmed debited; the supplier reports it never arrived; a resend is
// requested, approved by a second admin (never the requester) and recorded;
// part of the first payout comes back as a refund. Both outflows stay on the
// cash book, the refund is its own money in, and the Settlements page shows
// net paid and the money possibly paid twice.

const AMOUNT = 27_000;
const REFUND = 10_000;

test('Payout attempt, debit, not received, approved resend and refund', async ({ page, context }) => {
  const seeded = seed('payout');
  const id = seeded.settlement_id!;
  await signInOperator(context, seeded.operator_token);

  // The "Send the payout" / "Send again" panel.
  const send = page.locator('section', { has: page.getByRole('heading', { name: /^Send/ }) });

  // 1. Sent, debit not confirmed: in flight, not money out.
  await page.goto(`/settlements/${id}`);
  await send.getByLabel('Reference', { exact: true }).fill('QE2EPAY1');
  await send.getByRole('button', { name: 'Record payout' }).click();
  const first = page.locator('article[data-attempt="1"]');
  await expect(first).toContainText('Sent, debit not confirmed');
  await page.goto('/finance/cash-book');
  const cards = page.locator('section[aria-label="Cash summary"]');
  await expect(cards.locator('a', { hasText: 'Money out' }).locator('strong')).toHaveText(tzs(0));
  await expect(page.locator('[data-in-flight]')).toContainText(`Not included: ${tzs(AMOUNT)}`);

  // 2. The statement shows the debit: now money out.
  await page.goto(`/settlements/${id}`);
  await first.locator('summary', { hasText: 'Mark debited' }).click();
  await first.getByLabel('What confirms it').fill('Statement line 3');
  await first.getByRole('button', { name: 'Mark debited' }).click();
  await expect(first).toContainText('Debited');

  // 3. The supplier, on their own portal, says it never arrived.
  await signInMember(context, memberSession(seeded.supplier_id!));
  await page.goto('/account');
  await expect(page.getByText(`Omoterra sent you ${tzs(AMOUNT)}`)).toBeVisible();
  await page.getByRole('button', { name: 'Not received' }).click();
  await page.getByRole('button', { name: 'Report not received' }).click();
  await expect(page.getByText('You reported this payout as not received')).toBeVisible();

  // 4. A resend is requested: reason and acknowledgement of two outflows.
  await signInOperator(context, seeded.operator_token);
  await page.goto(`/settlements/${id}`);
  await expect(page.getByText('An earlier payout is not resolved')).toBeVisible();
  await page.getByLabel('Reason').fill('Supplier reports nothing arrived on M-Pesa');
  await page.getByLabel(/I understand two outflows may exist/).check();
  await page.getByRole('button', { name: 'Ask for approval' }).click();
  await expect(page.getByText('You asked for this: another admin must approve it.')).toBeVisible();
  // The requester cannot approve it.
  await expect(page.getByRole('button', { name: 'Approve' })).toHaveCount(0);

  // 5. A second admin approves.
  await signInOperator(context, seeded.second_admin_token!);
  await page.goto(`/settlements/${id}`);
  await page.getByRole('button', { name: 'Approve' }).click();
  await expect(page.getByText('Waiting for a second admin')).toHaveCount(0);

  // 6. The resend is recorded with the approval, its debit confirmed.
  await signInOperator(context, seeded.operator_token);
  await page.goto(`/settlements/${id}`);
  await send.getByLabel('Reference', { exact: true }).fill('QE2EPAY2');
  await send.getByLabel(/The debit is confirmed/).check();
  await send.getByLabel('Evidence', { exact: true }).fill('M-Pesa message QE2EPAY2');
  await send.getByRole('button', { name: 'Record payout' }).click();
  const second = page.locator('article[data-attempt="2"]');
  await expect(second).toContainText('Attempt 2 (resend)');
  await expect(second).toContainText('Debited');

  // 7. Part of the first payout comes back: a refund on that attempt.
  await first.locator('summary', { hasText: 'Record a refund' }).click();
  await first.getByLabel('Amount (TZS)').fill(String(REFUND));
  await first.getByLabel('Evidence').fill('Reversal message from M-Pesa');
  await first.getByRole('button', { name: 'Record refund' }).click();
  await expect(first).toContainText(`Refund ${tzs(REFUND)}`);

  // The payout: both outflows stay; net paid = 2 x amount - refund.
  const net = 2 * AMOUNT - REFUND;
  await expect(page.locator('[data-net-paid]')).toHaveText(tzs(net));
  await expect(page.locator('[data-exposure]')).toHaveText(tzs(AMOUNT - REFUND));

  // Settlements: paid to date is net paid; possibly paid twice shown separately.
  await page.goto('/settlements');
  await expect(page.locator('[data-stat="paid"]')).toHaveText(tzs(net));
  await expect(page.locator('[data-stat="exposure"]')).toHaveText(tzs(AMOUNT - REFUND));
  await expect(page.locator('[data-stat="in-flight"]')).toHaveText(tzs(0));

  // Cash book: two outflows and the refund as money in, each its own row.
  await page.goto('/finance/cash-book');
  await expect(cards.locator('a', { hasText: 'Money out' }).locator('strong')).toHaveText(tzs(2 * AMOUNT));
  await expect(cards.locator('a', { hasText: 'Money in' }).locator('strong')).toHaveText(tzs(REFUND));
  await expect(page.locator('tbody tr', { hasText: 'Payout for app order' })).toHaveCount(2);
  await expect(page.locator('tbody tr', { hasText: 'Payout refund, app order' })).toHaveCount(1);
});
