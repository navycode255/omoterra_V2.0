# Financial strengthening build plan

Plan date: 3 October 2026 (revision 3, after second review). Source: [financial architecture audit](financial-architecture-audit-2026-10-02.md) and [backlog](financial-improvement-backlog.csv) (F01–F17), checked against commit `5aa01a9` plus the uncommitted supplier-list change. Every finding the audit marks *confirmed* still holds in the code.

## Progress

Updated 4 October 2026 (1.6 built, not committed). ✅ done · 🟡 done but waiting on you · 🔄 in progress · ⬜ not started. Everything through 1.5 is committed and pushed (`090d1ee`, `d579d24`). The full backend suite passes in strict mode (373 tests, 0 skipped), and Playwright passes 3/3. **Not yet deployed. GitHub Actions is blocked:** the GitHub account is locked over billing, so CI jobs do not start until that is resolved.

| Item | Status | Evidence / what's left |
|---|---|---|
| 0.1 Automatic test runs | 🟡 | `.github/workflows/ci.yml` is committed. Locally: 373 passed and 0 skipped in strict mode. The Playwright tests build with Turbopack, the same bundler Netlify uses. The 3 stale onboarding tests are fixed, a real 201-status bug is fixed, strict mode now also catches whole-module skips, and `moto` is added for the storage test. **Waiting on you: unlock GitHub billing** so the CI jobs can run. |
| 0.2 Metric dictionary | 🟡 | [finance-metrics.md](finance-metrics.md): 21 metrics with current and target definitions and 18 ranked inconsistencies. Waiting on your sign-off and on D7. |
| 0.3 Exception report | ✅ | `python -m app.finance_exceptions` (read-only, 9 tests). Production baseline: [finance-exceptions-baseline-2026-10-03.md](finance-exceptions-baseline-2026-10-03.md). |
| 0.4 Pagination regression | ✅ | Backend test (66 rows, 18 actionable, 7 pages) and a Playwright click-through of Debts. Stale comments fixed. |
| 0.5 Statement consistency harness | ✅ | Playwright: the staff supplier page, Supplier payments, the Suppliers list and the supplier portal show the same bought, paid and owed figures (`ops/e2e/`). |
| 1.1 F14 Expense totals | ✅ | `total` is the row count again, with `summary` and `by_category` following the same filters. Expenses page uses the shared footer. 30-expense, six-filter test. |
| 1.2 F04 Transfers vs allocations | 🟡 | Committed (`d579d24`), not deployed. Every supplier payment is a transfer. "Move to supplier credit" replaces Reverse, and money out is unchanged. Use credit, refunds (separate inflow, partial allowed) and admin-only entry-error corrections. Pay supplier uses credit first. `python -m app.classify_transfers` handles history item by item, with a dry run. 14 new tests. **Waiting on you:** deploy, then classify Antonia's 19,500. |
| 1.3 F02 Cost states and opening stock | ⬜ | D3 decided (finance owner supplies opening values). Next after 1.7. |
| 1.4 F06 Reasoned debt corrections | 🟡 | Committed (`d579d24`), not deployed. "Reconcile debt" is replaced by four admin-only, reasoned corrections (wrong supplier, duplicate liability, free stock, cost never existed), each writing a `financial_adjustments` row (migration 034). Paid money stays with whoever received it (credit or unresolved); receipt lines are never touched; a sale edit no longer moves a paid supplier debt. D4 confirmed (admins, with a reason). **Waiting on you:** deploy. |
| 1.5 F03 Units on receipts | 🟡 | Committed (`d579d24`), not deployed. Waiting only on deploy. Delivery-note and LPO lines take the receipt's unit and category; a different one is refused (422); fractional birds and animals refused. |
| 1.6 Batch sales become delivery notes | 🟡 | **Built 4 October, not committed or deployed.** A "From batch" line needs "We collected these N birds from … on …" ticked (else 422); the server records a same-day delivery note (origin `sale`, confirmer recorded) whose `batch_receipt` debt is the only supplier liability, and cost paid at the sale is a transfer allocated to it. Cancelling or reducing a sale asks what happened to received goods (never left / returned and accepted back / not recovered); the note and its payable never change. The delivery note page has Correct receipt (never delivered, admin, reason + evidence), Return to supplier (stock down, payable "awaiting supplier credit") and Record supplier credit note (lowers the payable). Migration 035 (`collection_movements`, `supplier_credit_notes`). `python -m app.link_batch_sales` converts history one line at a time after a dry run. Backend 388 passed, 0 skipped (strict); Playwright 4/4 (new `batch-sale.spec.ts`; statement harness extended with a return and credit note). **Waiting on you:** review, commit, deploy backend and ops together, then link the 11 lines (below). |
| 1.7 F01 One reporting layer | ⬜ | Needs D7 |
| M2 to M5 | ⬜ | |

### Where we stopped, and how to resume

**Your actions before the next build session:**
1. ~~Deploy~~ ✅ Backend deployed: production has migrations 032 to 034 (checked 4 October).
2. **Classify Antonia's 19,500** on the server:
   - `python -m app.classify_transfers --dry-run`
   - then `--apply <id> --as credit --evidence "…" --by "Maternus Joshua"`
   - then **Use credit** on her open invoice.
   - The dry run also lists older single payments, which you can wrap into transfers one at a time with `--wrap`.
3. **After deploying 1.6, link the 11 historical supplier lines** (1,040,000) on the server, one at a time:
   - `python -m app.link_batch_sales --dry-run` (changes nothing; keep the output). It proposes each line's batch (oldest open batch of the same product with enough left) and shows the receipt and how the sale-cost debt and its payments map onto it; ambiguous lines are listed as unresolved with the reason.
   - For each proposed line, confirm with whoever collected the birds the real collection date, then `python -m app.link_batch_sales --apply <line id> --batch <batch id> --confirm-received-on <YYYY-MM-DD> --by "Maternus Joshua"` and type the line id to confirm.
   - Run `python -m app.finance_exceptions` afterwards: section 2 (and the new "batch sale lines without a delivery note") should be empty or list only the unresolved lines.
4. **Unlock GitHub billing** so CI runs on every push.
5. ~~Decide D3 and D4~~ ✅ (4 October). Prepare **opening values** for stock held before the system (per batch or product). Decide D7 before M2.5. Sign off [finance-metrics.md](finance-metrics.md).

**Known limits of what is built (handled by later items):**
- A cleared cost shows as 0 margin, not "Provisional", until 1.3.
- "Wrong supplier" corrects a whole debt, not individual lines.
- A payment typed against the wrong supplier is fixed with Wrong supplier → unresolved → classify, then recording the real payment.

**Known limits of 1.6 (handled by M2.1/M2.2):**
- Stock checks are current-state only (R8 without dates): a correction, return or sale never takes more than is on hand now.
- "Not recovered" is a collection movement counted as a stock loss at cost in Profit; there is no investigation workflow yet. Buyer-return condition is free text.
- Returns do not put birds back in the supplier's batch; a receipt correction does.
- A line sold straight from a batch before 1.6 keeps that form when the sale is edited, until it is linked.

**Next build items, in order:**
- 1.3 cost states and opening stock (D3 decided: you supply opening values), after 1.7.
- 1.7 one reporting layer, after D7.
- Then the M1 exit check (the 500/100/20 scenario).

| Decision | Status |
|---|---|
| D1 Finance owner | ✅ Maternus Joshua |
| D2 Sale dates | ✅ Direct on sale date, marketplace on delivery date |
| D5 Mistaken-allocation money | ✅ Supplier credit; refunds only with evidence |
| D4 Who may correct supplier debts | ✅ Admins only, with a reason (confirmed 4 October) |
| D3 Stock held before the system | ✅ The finance owner supplies opening values; recorded as opening stock with no payable (4 October) |
| D6, D7, D8, D9 | ⬜ Open |

## How this plan is organised

- **Five milestones**, each ending in a check you can run, not a date. Do not start a milestone until the previous one's exit check passes. Reports built on unreconciled data amplify errors.
- **Foundations first.** Every item is built only after what it depends on:
  - debt corrections come after the transfer and allocation model;
  - checks on stock as of a past date come after the stock-movement model.
- **Decisions come before code.** Items marked **D** need a decision from the finance owner (whoever signs off the books). They are collected in [Decisions needed](#decisions-needed).
- **Existing data is never changed silently.** Every change to existing records goes through a dry-run report the finance owner approves. Anything without evidence stays *unresolved*: it is never guessed, defaulted or turned into credit.

| Milestone | Backlog items | Size (dev-days) | You can then trust… |
|---|---|---|---|
| M0 Foundations | test runner, metric dictionary, exception report, F13 | 4–5 | that every later change is tested against a real database |
| M1 Correct the actuals | F14, F04, F02, F06, F03 (units), F01 | 17–22 | margins, supplier balances and report headlines, with unknowns clearly flagged |
| M2 Real money and stock | F09, F03 (dates), F05, F08, F07, F11, F12 | 18–24 | cash per account and stock per received lot |
| M3 Close the books | F10, F15 | 14–22, or less with an accounting package | monthly figures that do not change after the month is closed |
| M4 Plan ahead | F16 | 12–16 | a 13-week cash forecast and 12-month plan |
| M5 Assurance (runs alongside M2 onward) | F17 | 6–9 | approvals, consistent snapshots, backups and performance |

Total: roughly 70–95 developer-days. Sizes are for one engineer who knows the codebase and exclude finance-owner review time.

---

## Transaction rules (apply to every milestone)

These are the semantics the code must follow. Each has a test.

| # | Rule |
|---|---|
| R1 | **A payment belongs to whoever actually received it.** Changing which supplier a debt belongs to never makes the new supplier "paid", and never removes money from the original recipient's statement. |
| R2 | **Stock moves only with a physical event.** Every change to received stock needs a recorded, physical event:<br>• Cancelling a buyer sale restores sellable stock **only** when staff confirm the goods never left Omoterra, or were returned by the buyer and accepted back (condition noted). Otherwise the sale is cancelled with the goods recorded as *not recovered*: they stay out of stock as a loss, pending investigation.<br>• Cancelling a buyer sale never touches the supplier's receipt or payable.<br>• Returning goods to a supplier reduces stock when they leave. It reduces the payable **only** through a supplier credit note the supplier has agreed to; until then the return is listed as *awaiting supplier credit*.<br>• A receipt (including one created alongside a sale) exists only when someone confirms the goods were physically received, with date, quantity and the confirmer recorded. |
| R3 | **Outflows are permanent history.** Every confirmed account debit is recorded once and never removed:<br>• A transfer covering several invoices is still one outflow.<br>• A second real transfer (a resend) is a second outflow.<br>• A refund is a **separate dated inflow** (full or partial) and never deletes, reduces or reverses the original outflow.<br>• An *attempt* whose debit is not yet confirmed (no statement line or provider confirmation) is shown as pending exposure, not as a confirmed outflow, until confirmed or proven failed. A proven failure (debit never happened) closes the attempt with its evidence and records no outflow. |
| R4 | **Re-allocation moves no money.** Moving an allocation between invoices changes neither cash nor what the supplier received. Only a recorded refund (with evidence) is money coming back. |
| R5 | **Unknown is not zero.** An unknown cost, account or outcome is stored as unknown, shown as an exception, and blocks any figure that would need it from being presented as final. |
| R6 | **Evidence before classification.** Historical records are reclassified (credit, refund, account, cost) only with evidence. Anything without evidence stays in an *unresolved* bucket that is visible on reports. |
| R7 | **Approval is not evidence.** Approving an exception can let work continue (for example lock a period), but never turns an unknown cost, a missing payment proof or an unreconciled balance into a final figure. Such items stay disclosed, and every report that depends on them stays qualified ("Provisional" or "Includes unresolved items") even inside a locked period. |
| R8 | **No timeline goes negative.** Inserting, back-dating, editing or cancelling any stock movement is accepted only if on-hand stock for every lot stays at or above zero on **every** date from the change onward, not just on the date of the change. |

---

## M0 Foundations (4–5 days)

| # | Work | Detail | Size |
|---|---|---|---|
| 0.1 | Automatic test runs | CI (GitHub Actions or the deploy script) runs `pytest` against a throwaway PostgreSQL service on every push. It fails if any test is skipped; today 66 database tests skip silently. It also runs the frontend type-check, lint and a small Playwright suite (0.5). | 1.5 |
| 0.2 | Metric dictionary | `docs/finance-metrics.md`: for each headline number, its source tables, counted statuses, period date, exclusions, rounding and the drilldown that must add up to it. Signed off by the finance owner. **D1, D2** | 1 |
| 0.3 | Exception report (read-only) | `python -m app.finance_exceptions`, which changes nothing, lists: unknown-cost lines; supplier lines without a batch or receipt; reversed allocations; settlements paid more than once; expenses without a category; batches with no movements. Run it on production and keep the output. | 1–1.5 |
| 0.4 | F13 pagination regression | Backend test: 66 rows with 18 actionable at 10 per page gives 7 pages, each row once. Playwright: click through those 7 pages on Debts and confirm every row appears once. Fix comments that say "all actionable rows are on page 1". | 0.5 |
| 0.5 | Statement consistency harness | Playwright fixture: record a receipt, a sale and a supplier payment, then assert that the staff supplier page, the Supplier payments row and the supplier's own portal statement show the same received, owed and paid figures. Every later milestone extends it. | 0.5 |

**Exit check:** CI is green with zero skipped database tests; the metric dictionary is signed off; the exception report output is recorded.

---

## M1 Correct the actuals (17–22 days)

Build in this order. 1.2 is the foundation for 1.4, and 1.6 needs 1.2 to 1.4.

### 1.1 F14: Expense totals (0.5 day)
- **Change:** `total` stays the row count. Add `summary: {incurred, paid, outstanding}` computed with the same filters as the rows.
- **Test:** category, date, search and status filters together, with the summary equal to all matching rows across every page.

### 1.2 F04: Money moved versus money allocated (5–6 days) **D5**
- **Model:**
  - `SupplierPayment` becomes the **transfer**, the only record that money left an account. Single-invoice payments create a transfer too.
  - `LedgerPayment` stays the **allocation** of a transfer to an invoice.
  - New `transfer_events` record **unapplied credit**, **refunds** (a new dated inflow with evidence) and **re-allocations**.
  - Buyer receipts get the same transfer, allocation and credit structure.
- **Actions:**
  - "Reverse allocation" now moves the amount to unapplied credit on the same transfer and supplier (R1, R4).
  - "Re-allocate" sends that credit to another invoice of the **same** supplier.
  - "Record refund" is the only action that brings money back.
  - "Pay supplier" offers that supplier's unapplied credit first.
- **Historical migration (R6):** reversed allocations are **not** turned into credit automatically. The dry run lists each one, and the finance owner classifies it with evidence as one of:
  - *money still with the supplier*, which becomes credit;
  - *money refunded*, which becomes a refund dated when it was actually received;
  - *entry error, no money moved*, which reduces the transfer, with the evidence kept.

  Unclassified ones stay in an *unresolved allocations* bucket, shown on the supplier statement and the exception page. Antonia's TZS 19,500 is the first case to classify.
- **Statement:** transferred, allocated, unapplied, refunded and unresolved, adding up to the transfer total.
- **Tests:**
  - Invariant: allocated + unapplied + refunded + unresolved = transfer amount for every transfer.
  - Re-allocation leaves cash unchanged.
  - A refund changes cash once.
  - Payment retries under concurrency (two identical requests at once, and the same request retried after a timeout) create one transfer.

### 1.3 F02: Known, unknown and opening stock cost (3 days) **D3**
- **Data:** `sale_items.cost_state` holds `known`, `free` (a known zero, needing approval) or `unknown`. "Stock I already owned" requires a cost or "cost unknown".
- **Opening stock:** a receipt type with a value and **no payable**, for stock paid for before the system existed.
- **Reports (R5):** any period with unknown-cost lines shows its profit as **"Provisional: buying costs incomplete"**, with how many sales and how much revenue are affected. It never shows a minimum, a range or an "at least" figure. The provisional state carries through to the Finance overview, Profit, Sales and any export.
- **Backfill:** lines with a cost stay `known`; lines without one become `unknown`. `free` needs finance-owner approval per line.
- **Tests:**
  - Paying a supplier early does not change margin.
  - An unknown cost is never shown as a final margin.
  - Opening stock creates no payable.

### 1.4 F06: Correcting a supplier debt without erasing cost (2–3 days) **D4**
Depends on 1.2. Each correction writes a `financial_adjustments` row (who, why, before and after) and follows R1:

| Action | Cost of goods | Debt and payments |
|---|---|---|
| **Wrong supplier** | kept | The **full valid obligation** moves to the correct supplier as a new debt for the whole amount. Any money paid against the wrong debt **stays with the supplier who received it** (R1) and is classified as in 1.2 (credit, refund, entry error or unresolved). It never reduces the new debt. Example: on a TZS 100,000 invoice with TZS 40,000 paid to the wrong supplier, the correct supplier is owed TZS 100,000 and the wrong supplier holds TZS 40,000, recorded separately. |
| **Duplicate liability** | kept | Cancelled with a link to the debt it duplicates. Payments on it are classified as in 1.2. |
| **Free / gift stock** | `free` | Cancelled. Admin only, with a reason. |
| **Cost never existed** | `unknown` | Cancelled. The margin becomes provisional (R5). |

- **Scope:** lines linked to a delivery note or LPO are never changed here; they are corrected on the receipt.
- **Tests:**
  - Wrong-supplier fix on 100,000 with 40,000 paid: COGS is unchanged, the correct supplier is owed 100,000, the original supplier shows 40,000 received (credit or unresolved), and cash out is still 40,000.
  - Mixed receipt and direct lines are untouched.
  - Gift stock needs an admin.

### 1.5 F03 part 1: Units on received stock (1 day)
- **Rule:** for delivery-note and LPO lines, the receipt's unit and category are authoritative.
  - Lines **may omit** unit and category, and the server fills them from the receipt.
  - A line that **sends** a different unit or category is **rejected** with a clear message; it is never silently replaced. Selling birds as kg needs a documented conversion (M2.1).
  - Birds and animals must be whole numbers. Dated availability waits for the movement model (M2.2).
- **Tests:** a line with no unit gets the receipt's unit; kg sent against a bird receipt is rejected; 2.5 birds is rejected.

### 1.6 Batch sales become delivery notes (1.5 days)
Corrects the recent `supplier_batch_id` work so that batch sales go through a receipt.
- **Change:** a batch sale line requires the staff member to **confirm physical receipt** ("We collected these N birds from the supplier on DATE"), recording the confirmer. Only then is a same-day delivery note created and consumed, so the supplier payable comes from the receipt. Without the confirmation the line cannot use a batch.
- **Editing or cancelling the sale follows R2:**
  - The delivery note and its payable are never changed by the sale.
  - The birds come back on hand only if staff confirm they never left or were returned and accepted. Otherwise they are recorded as not recovered.
  - Reducing what was received needs "Correct receipt" (the supplier never delivered them, with a reason and evidence), or from M2.1, "Return to supplier", which reduces the payable only after the supplier agrees a credit note.
- **Migration:** existing batch-linked lines are converted only after an approved dry run.
- **Tests:**
  - Sell 20 from a 300 batch: one receipt of 20, one payable, and 280 left with the supplier.
  - A batch line without receipt confirmation is refused.
  - Cancel the sale with "goods never left": the receipt and payable remain, and 20 birds are on hand.
  - Cancel with "not recovered": the receipt and payable remain, there are 0 on hand, and 20 are recorded as a loss pending investigation.
  - Correct the receipt to 0 (never delivered): the payable is cancelled and the batch goes back to 300.
  - Return 20 to the supplier: stock drops, the payable is unchanged and "awaiting supplier credit"; the payable falls only after the agreed credit note.

### 1.7 F01: One reporting layer, same population everywhere (3–4 days) **D1, D2**
- **New module:** `backend/app/reporting.py` with `receivables()`, `payables()`, `revenue()`, `cost_of_goods()` and `cash_movements()`. They cover both the direct ledger and the marketplace (orders, receipts, settlements), with source identifiers and double-count protection.
- **Commitments:** marketplace orders not yet delivered are reported separately.
- **Who uses it:** every finance page reads only from this module.
- **Label:** "Cash in hand" becomes "Recorded net cash movement (unverified)" until M2.3.
- **Tests:**
  - For every metric in the dictionary, the headline equals its drilldown with marketplace-only, direct-only and mixed data.
  - The 0.5 harness passes for staff and supplier views.

**M1 exit check:**
- **Audit scenario passes:** 500 declared; 100 received at 6,500; 20 sold at 7,500; a TZS 200,000 transfer, re-allocated once. Expected: 20,000 margin, 450,000 payable, 80 birds worth 520,000, cash out exactly 200,000, and an unchanged transfer total after re-allocation.
- **Rules R1–R8 each have a passing test.**
- **Unknowns are visible:** every unknown cost and unresolved allocation appears on the exception page and in the relevant report. No period containing them is shown as final.

---

## M2 Real money and stock (18–24 days)

### 2.1 F09: One stock-movement model for received lots (5–6 days)
- **Data:** `lot_movements` per received lot (delivery note, LPO receipt, opening stock), each with an event date and the person confirming it: receive (confirmed), sell, *buyer return accepted*, *sale cancelled, goods never left*, *not recovered / loss*, mortality, return to supplier, receipt correction, count adjustment. On hand is the sum of movements as of any date. Supplier credit notes are separate financial documents linked to return movements (R2).
- **Reuse:** LPO `StockLoss` moves onto this model.
- **Commitments:** reservations link to a commitment instead of `min(reserved, accepted)`.
- **Batch view:** shows registered, reserved, received, sold, lost, returned and left, for staff, the supplier app and the portal.
- **Rule:** a supplier's registered batch is their declaration. It is never counted as Omoterra stock or as guaranteed future supply.
- **Test:** the 500/100/20 scenario, plus 3 dead and 2 returned, reconciles at every date.

### 2.2 F03 part 2: Stock as of the sale date (1.5 days)
- **Change:**
  - A sale cannot be dated before its receipt.
  - Any inserted, back-dated, edited or cancelled movement is accepted only if R8 holds: the lot's on-hand stays at or above zero on every date from the change onward. The check replays the lot's movements in date order inside the same locked transaction.
  - A late entry needs an explicit flag, a reason and an admin, and still must satisfy R8.
  - A supplier advance paid before a sale stays allowed, classified as an advance (an M3.2 account).
- **Tests:**
  - Backdated consumption before the receipt is rejected.
  - Lot of 100 with sales of 60 on 5 Oct and 40 on 10 Oct: inserting a sale of 10 on 3 Oct is rejected, because 10 Oct would go to −10, even though 3 Oct alone has stock.
  - Cancelling a buyer return that later sales relied on is rejected.
  - A late entry with approval that keeps every date non-negative is accepted.
  - Concurrent sales against the same lot cannot oversell.

### 2.3 F05: Money accounts and reconciliation (5–6 days) **D6**
- **Data:** `money_accounts` (cash box, bank, mobile wallet), each with a verified opening balance as at a **cutoff** (end of the day before the start date). New transfers and receipts must name an account.
- **Cutoff rule:**
  - Movements dated on or before the cutoff are already inside the opening balance. They stay visible as history but are **excluded** from that account's running balance and from any balance or forecast built on it, so they are never counted twice.
  - Movements after the cutoff add to the opening balance.
  - A back-dated entry on or before the cutoff does not change the opening balance automatically. It is flagged as a *pre-cutoff adjustment*, which the finance owner either explains (it was already inside the verified balance) or treats as an evidenced restatement of the opening balance.
- **Historical mapping (R6):**
  - The payment method alone never decides the account.
  - The dry run proposes a mapping only where evidence identifies the account (statement line, wallet number, reference format), and the finance owner confirms each one.
  - Everything else stays in an **Unassigned (historical)** bucket. That bucket is visible on the Cash book, excluded from reconciled account balances, and listed as an exception until resolved.
- **Actions:** transfers between accounts (eliminated when combined), fees, cash counts, statement matching with differences listed.
- **Tests:**
  - An internal transfer nets to zero.
  - A cash count difference raises an exception, never a silent adjustment.
  - An unassigned payment never changes a reconciled balance.
  - A movement dated before the cutoff does not change the running balance; a back-dated pre-cutoff entry raises an exception.

### 2.4 F08: Receipt payment status on sales (1 day)
- **Change:** the sale detail links "Stock from DN-…: supplier invoice X, paid Y", without adding to the sale's own supplier balance.

### 2.5 F07: Recognition date (1.5 days) **D7**
- **Data:** `orders.recognized_on`, set at the agreed event. Revenue and cost both use it.
- **Backfill:** from activity timestamps. Orders with ambiguous history stay unresolved.
- **Tests:** an order made in September and delivered in October counts in October; a return or reopen reverses in the period it happens.

### 2.6 F11: Duplicate transfer detection (1 day)
- **Data:** `(provider, account, transaction_id)` is unique when present.
- **No reference:** a possible duplicate (same party, amount and day) needs a reason to override.
- **Test:** the same M-Pesa code entered with a new retry key is blocked.

### 2.7 F12: Payout attempts and controlled resends (2–3 days) **D9**
- **Data:**
  - `settlement_transfers`: one row per attempt with evidence and a state.
    - *Initiated*: sent, but no debit confirmation yet. This is pending exposure, not cash out.
    - *Debited*: confirmed on a statement or by the provider. This is a permanent outflow (R3).
    - *Failed*: evidence that no debit ever happened. No outflow is recorded.
  - Refunds are separate `settlement_refunds` rows (dated inflows, full or partial, with evidence) linked to the attempt. A refund never changes or removes the debited outflow.
  - The settlement's net paid is debited outflows minus refunds. Cash reports show the outflow and the refund on their own dates.
- **Resend controls:**
  - While an earlier attempt is unresolved, a resend needs admin approval from someone other than the requester, a reason, and acknowledgement that two outflows will exist.
  - The resend is limited to the settlement amount.
  - The disputed exposure (money possibly paid twice) is shown separately until resolved.
- **Tests:**
  - Two debited outflows and one partial refund: both outflows stay on their dates, the refund is a separate inflow, and net paid = 2 × amount − refund.
  - An initiated attempt later proven failed records no outflow and keeps its evidence.
  - A resend without approval is refused.
  - A refund larger than the debited outflows is refused.

**M2 exit check:**
- One full week where each money account matches its statement or count, with the unassigned bucket listed.
- The stock scenario with losses and returns reconciles as of every date.
- The resend scenario passes with approvals.
- The 0.5 harness passes with lots and accounts.

---

## M3 Close the books (14–22 days)

### 3.1 F10: Revisions and period close (5–6 days)
- **Revisions:** `financial_revisions` stores before and after, reason, actor, effective date and posting date for sale edits, debt corrections, allocation changes and receipt edits.
- **Periods:** `accounting_periods` can be open, closed or reopened, and reopening needs an admin with a reason.
  - A closed period refuses changes; corrections post in the open period.
  - A period has two independent properties: **locked** (no more edits) and **status**, which is *final* or *qualified*.
  - A period with any unknown cost, unresolved allocation, unassigned payment, pending attempt or unreconciled account may be locked once the finance owner records an exception for each item. It stays **qualified** (R7).
  - Every report covering it shows "Qualified: includes unresolved items", with the list and amounts. Exports and the accounting integration carry the same flag.
  - A period becomes *final* only when its exceptions are actually resolved with evidence. Resolving later posts adjustments in the open period and updates the earlier period's status from qualified to resolved, without editing the locked figures.
- **Tests:**
  - A partly paid sale edit keeps its transfer and evidence.
  - Editing a locked period is refused.
  - A period with an unknown cost can be locked with an approved exception, and its Profit report still shows "Qualified".
  - Approval alone never changes an unknown cost to known.

### 3.2 F15: Chart of accounts and postings (9–16 days, or 4–7 with integration) **D8**
- **Option A (build in):** a finance-approved chart of accounts and balanced journal lines from each economic event, giving a trial balance, P&L and balance sheet.
- **Option B (integrate):** post the same events to the accountant's package (QuickBooks, Xero, Zoho Books or Odoo) through its API and a mapping table.
- **Either option must classify distinctly:**
  - inventory purchase and cost of goods sold;
  - fixed assets with **depreciation** schedules;
  - **prepayments** and accruals;
  - **supplier advances** and **customer advances or deposits**;
  - **credit notes** (supplier and customer);
  - loans, split into principal and interest;
  - **owner funding** and **owner drawings**;
  - bank and mobile fees;
  - tax liabilities, per a separate Tanzanian tax review, as this plan sets no rates.
- **Opening balance sheet at the cutoff:** cash and accounts (M2.3), stock (opening and received lots), open debts, fixed assets at their carrying value, prepayments, advances, loans, owner equity, and any other balance the accountant identifies. Each needs evidence or is listed as an exception. Cash, stock and debts alone are not assumed to be complete.
- **Cutoff for postings:** journal postings start the day after the cutoff. Events on or before it are represented only by the opening balances, never also posted as transactions. The posting job refuses pre-cutoff events, and a test proves that a September sale and its payment do not appear in November's trial balance movements.

**M3 exit check:**
- The first reconciled month is **November 2026**, the first full month after the 1 November cutoff (D6). It is reconciled from verified opening balances plus its own movements, locked, and signed off as *final*, or locked as *qualified* with each remaining exception disclosed.
- October 2026 and earlier are **not** assumed reconciled because November opens from verified balances. They stay historical and qualified unless separately reconciled to statements and counts for that month.

---

## M4 Plan ahead (12–16 days)

### 4.1 F16: 13-week cash forecast and 12-month plan
- **Data:** `forecast_versions` (frozen when published), `forecast_assumptions` (owner, source, effective date, review date) and `forecast_lines`.
- **13-week cash, per account and combined:** `closing = opening reconciled cash + collections + financing inflows − supplier payments − operating payments − payroll − tax payments − capital expenditure − debt service − other outflows`.
  - Opening cash is reconciled cash at the latest reconciliation date only; unassigned or unreconciled money is shown separately, not included. Actual movements up to that date are never also forecast.
  - Collections follow due dates with an expected delay; overdue amounts are shown separately.
  - Financing inflows (loans, owner funding) come in on scheduled dates.
  - Payroll and tax payments follow their schedules.
  - Capital expenditure comes from approved purchases.
  - Committed payments (approved LPOs, payables) are kept separate from discretionary ones.
  - **Each future payment is counted once (deduplication):**
    - Every forecast line carries the `source_id` of the document it comes from. When a later document fulfils an earlier one, the earlier line is replaced, never added to.
    - An approved LPO's undelivered quantity is forecast as a payment. When a delivery is received, that part moves to the resulting payable and leaves the LPO line.
    - A payable already partly paid is forecast at its open balance only.
    - Payroll is forecast in the payroll line. Operating-expense lines exclude payroll categories, and a recorded salary expense replaces the payroll forecast for that period instead of adding to it.
    - Recurring expenses are replaced by actual expense entries for the same period and category.
    - Settlements and marketplace payouts are forecast from open settlements only, not also from their orders.
    - A validation report lists any two lines sharing a `source_id` or overlapping category and period, and the forecast cannot be published while it has entries.
  - Working capital timing: stock purchased now, sold in N days, collected N days later.
  - Output: weekly closing cash, the lowest point, and any funding gap against a reserve you set.
- **12-month operating plan:**
  - Quantities by product and channel, limited by procurement lead times, fulfilment capacity (vehicles, staff, cold chain) and confirmed supply.
  - **Registered supplier batches are possible supply, not guaranteed stock.** They are weighted by each supplier's actual delivery history.
  - Assumptions cover price, landed cost, mortality and yield, delivery cost, fixed costs, capital expenditure, financing and non-cash expenses.
  - Base, downside and upside scenarios.
- **Variance:**
  - Each frozen version is compared with actuals using absolute error and bias. Percentage error is used only where actuals are non-zero.
  - Each variance is explained as price, volume, cost, timing or a one-off.
  - Periods that are still provisional are marked.

**M4 exit check:**
- Opening forecast cash equals reconciled cash.
- Every line traces to an actual or an assumption.
- Roll-forward, scenario and variance-explanation tests pass.
- Double-counting tests pass:
  - An LPO that turns into a delivery and payable is forecast once.
  - A recorded salary expense replaces, not adds to, the payroll line.
  - A partly paid payable is forecast at its balance.
  - Movements before the reconciliation date are not forecast.

---

## M5 Assurance (6–9 days, in parallel from M2)

| Work | Detail |
|---|---|
| Approvals | Configurable thresholds for supplier payments, refunds, gift stock, late entries, resends and period reopening, with the approver different from the requester. **D9** |
| Exception queue | A daily ops page built from 0.3: unknown costs, unresolved allocations, unassigned payments, unreconciled accounts, disputed payouts, stock count differences and late entries. |
| Consistent snapshots | Each finance page gets **one** backend endpoint whose queries all run inside one `REPEATABLE READ READ ONLY` transaction, so cards and tables see one PostgreSQL snapshot. Today a page makes several independent HTTP calls, each its own snapshot. Daily or period-end figures use stored snapshots (`report_snapshots` with the timestamp they were taken) rather than live queries. Test: a write between two queries does not change a page's totals. |
| Concurrency | Tests for concurrent sales on one lot, concurrent payments on one invoice, and retries after timeouts. Profile the global commerce lock before changing it, and keep sale-edit lock ordering. |
| Performance | Remove per-row lookups in supplier balances, party lists and receipt views. |
| Backup and restore | Confirm Neon point-in-time restore and R2 media retention, then run one restore drill into a branch with the recovery time recorded. |

---

## Decisions needed

**Decided 3 October 2026:** D1: Maternus Joshua is the finance owner, with an accountant from M3. D2: direct sales count on the sale date and marketplace orders on the delivery date. D5: money a supplier keeps after a mistaken allocation becomes credit on their next invoice, refunded only with evidence. **Decided 4 October 2026:** D3: the finance owner gives opening values for stock held before the system; they are recorded as opening stock with no payable, and lines still without a cost stay `unknown` until a value is given. D4: admins only, with a reason (the built default).

| # | Decision | Needed by | Suggested default |
|---|---|---|---|
| D1 | Who is the finance owner who signs off definitions, classifications, opening balances and period close? | M0 | You, with an external accountant from M3 |
| D2 | When does a direct sale count, and a marketplace order? | M0 | Direct: sale date. Marketplace: delivery date. |
| D3 | Cost of stock held before the system existed, and what evidence there is | M1.3 | Evidenced cost; otherwise `unknown` |
| D4 | Who may mark stock free or cancel a supplier liability? | M1.4 | Admins only, with a reason |
| D5 | How to treat money a supplier holds after a mistaken allocation, once confirmed: credit or refund | M1.2 | Credit by default; refund only with evidence |
| D6 | The real accounts, and their verified balances at the cutoff | M2.3 | Cutoff end of 31 October 2026; first reconciled month November 2026 |
| D7 | Recognition event for marketplace orders | M2.5 | Delivered |
| D8 | Build accounting in, or integrate a package? | M3 | Integrate, if your accountant uses a package |
| D9 | Approval thresholds and approvers, including for resends | M2.7 / M5 | Over TZS 500,000 or any resend: a second admin |

## Ground rules for every item

1. **Tests first:** each item lands with tests that fail before and pass after, in CI against PostgreSQL. Screen changes also get a Playwright check.
2. **Dry run before touching records:** old against new totals by source, approved by the finance owner, with originals kept and export and rollback files.
3. **Unknown and unresolved stay visible (R5–R7)** and keep reports qualified; they are never forced to balance, and approval never makes them final.
4. **One source of numbers:** after 1.7, finance screens read only from `reporting.py`.
5. **Small releases:** each numbered item ships separately (backend and Netlify together), followed by an exception-report run.

## Suggested first two weeks

| Days | Work |
|---|---|
| 1–2 | 0.1 CI with PostgreSQL and Playwright; 0.4 pagination regression; 0.5 statement harness |
| 3 | 0.2 metric dictionary, then your review (D1, D2) |
| 4 | 0.3 exception report, run on production; 1.1 expense totals |
| 5–10 | 1.2 transfers and allocations (after D5), including the historical classification dry run |
