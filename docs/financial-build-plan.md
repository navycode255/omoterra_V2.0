# Financial strengthening build plan

Plan date: 3 October 2026 (revision 3, after second review). Source: [financial architecture audit](financial-architecture-audit-2026-10-02.md) and [backlog](financial-improvement-backlog.csv) (F01–F17), checked against commit `5aa01a9` plus the uncommitted supplier-list change. Every finding the audit marks *confirmed* still holds in the code.

## Progress

Updated 4 October 2026 (1.3 built, not committed). ✅ done · 🟡 done but waiting on you · 🔄 in progress · ⬜ not started. Everything through 1.5 is committed and pushed (`090d1ee`, `d579d24`). The full backend suite passes in strict mode (373 tests, 0 skipped), and Playwright passes 3/3. **Not yet deployed. GitHub Actions is blocked:** the GitHub account is locked over billing, so CI jobs do not start until that is resolved.

| Item | Status | Evidence / what's left |
|---|---|---|
| 0.1 Automatic test runs | 🟡 | `.github/workflows/ci.yml` is committed. Locally: 373 passed and 0 skipped in strict mode. The Playwright tests build with Turbopack, the same bundler Netlify uses. The 3 stale onboarding tests are fixed, a real 201-status bug is fixed, strict mode now also catches whole-module skips, and `moto` is added for the storage test. **Waiting on you: unlock GitHub billing** so the CI jobs can run. |
| 0.2 Metric dictionary | 🟡 | [finance-metrics.md](finance-metrics.md): 21 metrics with current and target definitions and 18 ranked inconsistencies. Waiting on your sign-off and on D7. |
| 0.3 Exception report | ✅ | `python -m app.finance_exceptions` (read-only, 9 tests). Production baseline: [finance-exceptions-baseline-2026-10-03.md](finance-exceptions-baseline-2026-10-03.md). |
| 0.4 Pagination regression | ✅ | Backend test (66 rows, 18 actionable, 7 pages) and a Playwright click-through of Debts. Stale comments fixed. |
| 0.5 Statement consistency harness | ✅ | Playwright: the staff supplier page, Supplier payments, the Suppliers list and the supplier portal show the same bought, paid and owed figures (`ops/e2e/`). |
| 1.1 F14 Expense totals | ✅ | `total` is the row count again, with `summary` and `by_category` following the same filters. Expenses page uses the shared footer. 30-expense, six-filter test. |
| 1.2 F04 Transfers vs allocations | 🟡 | Committed (`d579d24`), not deployed. Every supplier payment is a transfer. "Move to supplier credit" replaces Reverse, and money out is unchanged. Use credit, refunds (separate inflow, partial allowed) and admin-only entry-error corrections. Pay supplier uses credit first. `python -m app.classify_transfers` handles history item by item, with a dry run. 14 new tests. **Waiting on you:** deploy, then classify Antonia's 19,500. |
| 1.3 F02 Cost states and opening stock | 🟡 | **Built 4 October, not committed or deployed.** `sale_items.cost_state` (known / free / unknown) and opening stock (`opening_stock`, no payable) in migration 038 (`backend/app/opening_stock.py`). "Stock I already owned" needs a cost, opening stock, or "Cost unknown" ticked (else 422). An unknown line adds nothing to cost of goods; any period with one shows profit as **"Provisional: buying costs incomplete"** with the sales and revenue affected, on Finance, Profit, Sales, Reports, the PDF and the CSV; a sale's margin shows "cost unknown". Free is admin-only with a reason (debt correction, or on the sale line). An admin gives an unknown line a cost later on its sale page (opening stock, evidenced cost or free), writing a `cost_resolved` adjustment. New page Finance → Opening stock (button on the Finance overview) lists entries and unknown-cost lines. Backfill: cost > 0 known; 0 with a recorded free-stock correction free; everything else unknown. Backend 424 passed, 0 skipped (strict; new `tests/test_cost_states.py`, 12 tests); Playwright 7/7 (new `cost-states.spec.ts`; the uncommitted location spec is the other new one). **Waiting on you:** review, commit, deploy backend and ops together, then enter opening values and resolve SL-837D20E3 (below). |
| 1.4 F06 Reasoned debt corrections | 🟡 | Committed (`d579d24`), not deployed. "Reconcile debt" is replaced by four admin-only, reasoned corrections (wrong supplier, duplicate liability, free stock, cost never existed), each writing a `financial_adjustments` row (migration 034). Paid money stays with whoever received it (credit or unresolved); receipt lines are never touched; a sale edit no longer moves a paid supplier debt. D4 confirmed (admins, with a reason). **Waiting on you:** deploy. |
| 1.5 F03 Units on receipts | 🟡 | Committed (`d579d24`), not deployed. Waiting only on deploy. Delivery-note and LPO lines take the receipt's unit and category; a different one is refused (422); fractional birds and animals refused. |
| 1.6 Batch sales become delivery notes | 🟡 | **Built 4 October, not committed or deployed.** A "From batch" line needs "We collected these N birds from … on …" ticked (else 422); the server records a same-day delivery note (origin `sale`, confirmer recorded) whose `batch_receipt` debt is the only supplier liability, and cost paid at the sale is a transfer allocated to it. Cancelling or reducing a sale asks what happened to received goods (never left / returned and accepted back / not recovered); the note and its payable never change. The delivery note page has Correct receipt (never delivered, admin, reason + evidence), Return to supplier (stock down, payable "awaiting supplier credit") and Record supplier credit note (lowers the payable). Migration 035 (`collection_movements`, `supplier_credit_notes`). `python -m app.link_batch_sales` converts history one line at a time after a dry run. Backend 388 passed, 0 skipped (strict); Playwright 4/4 (new `batch-sale.spec.ts`; statement harness extended with a return and credit note). **Waiting on you:** review, commit, deploy backend and ops together, then link the 11 lines (below). |
| 1.7 F01 One reporting layer | 🟡 | **Built 4 October; committed (`6141ac8`), not deployed.** Needs D1 and D2 (both decided). `backend/app/reporting.py` (receivables, payables, commitments, revenue, cost_of_goods, expenses, stock_lost, profit, cash_movements, supplier_totals, stock_on_hand); every row carries its source table and id and is counted once. Finance overview, Profit, Cash book, Debts, Supplier payments, Sales, Reports, Suppliers list, Settlements and the portal invoice totals read it; `GET /ops/finance/rows` is the drilldown. App orders count on their delivery date; undelivered ones are commitments; "Cash in hand" is now "Recorded net cash movement (unverified)". New `tests/test_reporting.py` (headline = drilldown for direct, app and mixed data; double counting; D2; M1 exit scenario passes). Backend 403 passed, 0 skipped (strict); Playwright 5/5 (new `finance-headlines.spec.ts`). **Waiting on you:** commit the e2e selector fix, deploy backend and ops together; finance-owner points in the 1.7 report (app-order overdue rule, supplier figures without app payouts). |
| M1 exit check | 🟡 | **Code side passes (5 October).** Backend 424 passed, 0 skipped (strict); `tsc` and lint clean; Playwright 7/7. Audit scenario: `test_reporting.py::test_m1_exit_scenario`. Rules: see [M1 exit check: rule coverage](#m1-exit-check-rule-coverage). Gap fixed: unresolved supplier transfer money was only on each supplier's statement; Finance overview and Debts now show "Unresolved supplier money" beside I owe (test in `test_historical_reversal_stays_unresolved_until_classified`). **Waiting on you:** commit 1.3 and this, deploy, then the data steps below (opening values, SL-837D20E3, Antonia's 19,500, the 11 batch lines) and a clean `python -m app.finance_exceptions` run on production. |
| 1.7 follow-ups (finance owner, 5 October) | 🟡 | Built, not committed or deployed. **Overdue app orders:** a buyer owes on the delivery day and is overdue from the next; a payout is due 7 days after delivery (`reporting.PAYOUT_DAYS`). **Manage → Trading:** Sales and Gross margin are now the Finance figures (direct by sale date, app orders by delivery date; margin hidden while provisional); "Orders" renamed "Orders placed". **Disputed payouts:** stay money out (R3); the Cash book's Money out now says how much of it suppliers say never arrived. **Supplier screens:** pending app payouts stay beside "Owed", not added in (decided: they are paid through Settlements, not Supplier payments, so adding them would invite paying twice). |
| 2.1 F09 One stock-movement model | 🟡 | **Built 5 October, not committed or deployed.** Decision: a lot's movements are read from the records that already hold each physical event (`backend/app/lots.py`), not copied into a second table, so no screen can disagree with them. Lots: delivery notes, LPO lines, opening stock. Kinds: received, receipt correction, sold, buyer return accepted, sale cancelled (never left, history only), not recovered, died, lost, returned to supplier, to/from a kitchen, count adjustment. On hand on any date is the sum up to that date; the delivery note, LPO line and opening stock figures are now computed from it. New in migration 039: `lot_adjustments` (admin stock counts with evidence; opening stock losses) and `commitment_fulfilments` (a delivery note names the buyer allocation or market reservation it fills; receiving more than the unreserved birds without naming one is refused, and cancelling a reservation releases only what is outstanding). R8 check (`lots.first_negative`) on counts, losses and cancellations: refused if any later day would end below zero. Batch view `flow` (registered, reserved, received, sold, lost, returned, at Omoterra, left with the supplier) for staff, the supplier app and the portal. New pages: **Stock** (`/stock`, every lot on hand on a chosen date, from Finance) and each lot's history (`/stock/{lot}/{id}`, with count and loss forms). Backend 433 passed, 0 skipped (strict; new `tests/test_lots.py`, 8 tests including the 500/100/20 + 3 dead + 2 returned scenario reconciling on every date); Playwright 10/10 (new `stock-lots.spec.ts`); Flutter analyze clean. **Waiting on you:** review, commit, deploy backend, ops and the app together. |
| 2.2 F03 Stock as of the sale date | 🟡 | **Built 5 October, not committed or deployed.** `lots.StockGuard` replays each lot a change touches, by date, inside the same transaction (lot rows locked by whoever takes the stock): refused if any day ends below zero or further below zero than before (old negative history never blocks unrelated work), and stock cannot be used before it was received. Applied to new and edited sales, delivery-note losses, returns and receipt corrections, LPO losses and receipt cancellations, moves to kitchens, counts, opening stock losses and cancelling either. **Late entry:** a sale of received stock, a loss or a return dated more than **3 days** back needs an admin and a reason (window set by the finance owner on 6 October; `lots.LATE_ENTRY_DAYS`) (`late_entries`, migration 040); the forms ask for it. Backend 440 passed, 0 skipped (new `tests/test_stock_dates.py`, 7 tests, the three dated ones fail with the check switched off); Playwright 11/11 (new `late-entry.spec.ts`). **Waiting on you:** review, commit, deploy. |
| 2.3 F05 Money accounts and reconciliation | 🟡 | **Built 5 October, not committed or deployed.** `backend/app/accounts.py`, migration 041. **Accounts** (`money_accounts`): kind, provider, number, and the opening balance verified at the end of the cutoff day with its evidence; set up by an admin on **Finance → Accounts**. **Which account** (`account_assignments`, keyed by the cash book row's own table and id): every new money entry names its account once any account exists (payments, supplier transfers, refunds, app receipts, payouts, sale and expense payments; the forms suggest the account that fits the method); before that it stays unassigned. **Unassigned (historical)** rows count in no balance, show on the cash book (filter "No account") and in the exception report; an admin assigns each with evidence on Finance → Accounts, or `python -m app.classify_accounts --dry-run` proposes only where the record itself identifies the account (its number in the reference, or an M-Pesa code with one M-Pesa wallet), then `--apply`. **Cutoff:** rows dated on or before it are inside the opening balance; one entered after setup is a pre-cutoff adjustment until explained ("already inside") or restated (counts). **Transfers between accounts** net to zero; **fees** are money out and an expense (Profit). **Checks:** a cash count or statement balance at the end of a day; a difference is listed to explain, never adjusted; "reconciled through" is the last matching or explained check. Backend 446 passed, 0 skipped (new `tests/test_accounts.py`, 6 tests: transfer nets to zero, count difference is an exception, unassigned never changes a balance, pre-cutoff, dry run); Playwright 12/12 (new `accounts.spec.ts`). **Waiting on you (D6):** set up Petty cash, Bank, M-Pesa and the Selcom wallet with their verified balances at the cutoff, then assign recorded money after the cutoff. |
| 2.4 F08 Receipt payment status on sales | 🟡 | **Built 6 October, not committed or deployed.** The sale detail API gives each line that sold received stock a `stock_source` (`finance.stock_sources`): the delivery note, LPO (one invoice per receipt that brought the line in) or opening stock it came from, each receipt invoice with amount, paid (split into paid by transfer and paid from supplier credit), balance and status, the overall state (not paid / part paid / paid / no supplier invoice) and the supplier's unapplied credit. The sale page shows "Stock from DN-…: Supplier part paid · Supplier invoice TZS …, paid TZS … (balance TZS …)" with links to the note or LPO and the invoice; opening stock shows "Opening stock OS-… (no supplier invoice)". Information only: the sale's total, cost, margin, buyer balance and own supplier balance never include it (R1). New `tests/test_sale_stock_sources.py` (4 tests: figures unchanged through unpaid, part paid, credit applied and paid; LPO with two receipts; opening stock; a line with no receipt). Backend 464 passed, 0 skipped (strict, with 2.6); `tsc` and lint clean. |
| 2.6 F11 Duplicate transfer detection | 🟡 | **Built 6 October, not committed or deployed.** `backend/app/duplicates.py`, migration 043. **Identity:** (provider = payment method, account = money account or none, reference trimmed, spaces removed, upper-cased). `money_references` claims each reference once, with a partial unique index while the claim is live, so the database itself refuses a second one; the API also treats an unknown provider (app receipts and payouts) or an unassigned row as matching any, and its 409 names the earlier record ("Reference QAB12XYZ (M-Pesa) is already recorded: supplier transfer of TZS 30,000 to … on …"). Claimed: standalone ledger payments (sales, expenses, Record payment), supplier transfers, supplier refunds, customer payments, app receipts and app payouts (a resend keeps the first reference's claim). Not claimed: allocations, account fees (they carry the code of the transaction they were charged on), transfers between own accounts and provider-confirmed pay-now payments (already unique). A payment reversed as an entry error releases its reference; transfers, refunds and payouts never do (R3). **No reference:** a payment with the same party, amount, day and direction as a counted one is refused ("Possible duplicate: …") unless sent with "This is a separate payment" and a reason; `duplicate_overrides` keeps who and why (Record payment, Pay supplier, Receive customer payment, refunds). Every payment form (dashboard forms and the Pay supplier panel) shows the tick box and reason after that answer and keeps what was typed. Retries with the same retry key replay as before. **History:** 043 claims only the earliest record of each identity, so existing duplicates never fail it; the later ones keep counting and are listed in the exception report ("Transaction references recorded more than once"); overrides are listed as context. New `tests/test_duplicates.py` (8 tests); Playwright `duplicates.spec.ts` (3 tests: the 2.4 sale line, a buyer payment on a sale and Pay supplier, each refused then overridden). Backend 464 passed, 0 skipped (strict); `tsc` and lint clean; Playwright 13 of 16 pass, including the 3 new ones. The 3 failing (`finance-headlines`, `customer-payment`, `cost-states`) fail on screens changed by other uncommitted work (the Finance overview cards, the Receive customer payment list and the sale page's "More actions" dialog), not on these items; their selectors need updating with that work. |
| 2.5 F07 Recognition date (+ staff buyer orders) | 🟡 | **Built 6 October, not committed or deployed.** Migration 044, `backend/app/recognition.py`, `backend/app/buyer_orders.py`. **App orders:** `orders.recognized_on` (Dar es Salaam business day) is set when an order is marked delivered; revenue and its cost (payouts) both read it instead of the activity log. **Reopen or return** (new admin action "Reverse this delivery" on the order page, `POST /ops/orders/{id}/reverse-delivery`): the order keeps counting in the period it was delivered; an append-only `order_recognition_reversals` row takes the same revenue and cost out on the reversal day, so an earlier period never changes. Reopen = not really delivered: back to in transit, hold re-confirmed, stock sale reversed, payout cancelled; delivered again it is recognised again on the new day and the payout is pending again. Return = buyer sent the goods back: order cancelled, goods back on the supplier's listing, payout cancelled. Refused once a payout is paid; a return is refused while the buyer has paid anything (no app refund path yet). **Backfill:** 044 dates delivered orders whose history is unambiguous; the rest stay unresolved (out of every period) and are listed in the exception report ("Delivered app orders with no recognition date") and by `python -m app.recognition --dry-run`. **Staff buyer orders** (`buyer_orders`, lines, `buyer_order_payments`): Sales → Buyer orders (`/sales/orders`: list 10 a page with tabs and search, form, detail, edit, cancel with a reason). A commitment until delivered (Finance overview and Sales show "Orders not delivered"); no sale, no receivable, no stock. A deposit is money in (account and reference claimed as usual), held for the buyer; it can be given back (a dated money out) or voided by an admin; cancel is refused while one is held. **Mark delivered** opens the sale form filled in from the order and records the sale through the normal sale path dated the delivery day (cost states, batch collection confirmation, R8, late entry all apply); each held deposit becomes a payment on the sale with its own date, method, reference and account (counted once in the cash book). Sale ↔ order linked both ways. Backend 475 passed, 0 skipped (strict; new `tests/test_recognition.py` 5, `tests/test_buyer_orders.py` 5, and a staff-orders case in `test_every_headline_equals_its_drilldown`); `tsc` and lint clean; Playwright 17/17 (new `buyer-orders.spec.ts`; `customer-payment.spec.ts` now waits for the customer list before clicking, it raced the debts list behind it). |
| 2.7, M3 to M5 | ⬜ | |

### Where we stopped, and how to resume

**Your actions before the next build session:**
- **After deploying 2.5 (migration 044):** the migration dates every delivered app order whose history is unambiguous (one Dar es Salaam day in its "Delivered" entries, not before the order and not in the future). Then on the server:
  - `python -m app.recognition --dry-run` (changes nothing; keep the output). It lists each delivered order left unresolved with the reason (no dated delivery, conflicting days, unreadable time, delivered before it was created) and the suggested day if the history gives one; and any stored day that differs from the history.
  - For each, find the evidence (delivery note, buyer confirmation, driver's SMS), then `python -m app.recognition --apply <order id> --on <YYYY-MM-DD> --evidence "…" --by "Maternus Joshua"` and type the order id to confirm.
  - `python -m app.finance_exceptions`: "Delivered app orders with no recognition date" should then be empty.
0. **After deploying 1.3 (migration 038), opening values and unknown costs** (Maternus Joshua, as admin):
   - Before deploying, keep the read-only exception report: `python -m app.finance_exceptions` (section 1 lists unknown-cost lines; production had 1, SL-837D20E3). After 038 the same section reads `cost_state`; it should list the same line.
   - **Opening stock:** Finance → Opening stock → Record opening stock. One entry per product and unit you held before the system: quantity on hand, cost per unit *or* total value, the date it is valued as of, who gave the value, and the evidence (count, purchase receipts, M-Pesa statement). No supplier debt is opened. A mistaken entry is cancelled there with a reason while nothing is sold from it.
   - **Sales from opening stock:** on New sale, choose "Opening stock (held before the system)" and the entry; the margin is known. "Stock I already owned" now needs a cost or "Cost unknown".
   - **SL-837D20E3** (3 complimentary birds from Antonia, TZS 21,000): open the sale, and under the line choose **Free (it cost nothing)** with a reason such as "Complimentary birds from Antonia, confirmed by …". If they were in fact your own stock, choose **Sold from opening stock** (record the opening stock first) or **An evidenced cost**. Each writes a financial adjustment with the line before and after.
   - Finance → Opening stock → "Sale lines with an unknown buying cost" lists every line still provisional; Profit shows its figure again once none remain in the period.
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
5. ~~Decide D3 and D4~~ ✅ (4 October). Prepare **opening values** for stock held before the system (per batch or product). ~~Decide D7~~ ✅ (5 and 6 October). Sign off [finance-metrics.md](finance-metrics.md).

**Known limits of what is built (handled by later items):**
- "Wrong supplier" corrects a whole debt, not individual lines.
- A payment typed against the wrong supplier is fixed with Wrong supplier → unresolved → classify, then recording the real payment.

**Known limits of 1.6 (handled by M2.1/M2.2):**
- Stock checks are current-state only (R8 without dates): a correction, return or sale never takes more than is on hand now.
- "Not recovered" is a collection movement counted as a stock loss at cost in Profit; there is no investigation workflow yet. Buyer-return condition is free text.
- Returns do not put birds back in the supplier's batch; a receipt correction does.
- A line sold straight from a batch before 1.6 keeps that form when the sale is edited, until it is linked.

**Known limits of 1.3 (handled by M2.1/M2.2):**
- Opening stock is checked against what is on hand now, not as of the sale date: a sale dated before the opening stock's "valued as of" date is accepted (R8 with dates is M2.2).
- Opening stock is not yet a lot for kitchen allocations (Locations keep their own typed-cost opening stock); it joins the lot model in M2.1.
- An evidenced cost given to an unknown line opens no supplier debt; if a supplier is still owed, record that debt separately.

**Next build items, in order:**
- ~~The M1 exit check (code side)~~ ✅ 5 October. M2 starts once the production data steps above are done and the exception report shows nothing unexplained.
- ~~M2.1 F09: one stock-movement model for received lots~~ 🟡 built 5 October (above).
- ~~M2.2 F03 part 2: stock as of the sale date~~ 🟡 built 5 October (above).
- ~~M2.3 F05: money accounts and reconciliation~~ 🟡 built 5 October (above). Using it needs D6: the verified balance of Petty cash, Bank, M-Pesa and the Selcom wallet at the cutoff (suggested end of 31 October 2026).
- ~~M2.4 F08: receipt payment status on sales~~ 🟡 built 6 October (above).
- ~~M2.6 F11: duplicate transfer detection~~ 🟡 built 6 October (above). After deploying 043, run `python -m app.finance_exceptions` and explain each "Transaction references recorded more than once" group against the statement.
- ~~M2.5 F07: recognition date, with staff buyer orders~~ 🟡 built 6 October (above).
- **Next: M2.7 F12: payout attempts and controlled resends (D9).**

**Known limits of 2.5:**
- Cancelling a direct sale (including one delivered from a buyer order) still removes it from its own sale date, as before; only app orders reverse in the period it happens. Restating closed periods for direct sales is M3.1 (F10).
- An app order is recognised on the day staff mark it delivered (no separate delivery date field); a late marking is corrected with `--apply` only while unresolved.
- A return of an app order puts the goods back on the supplier's listing; it is refused while the buyer has paid anything or a payout is paid.
- A deposit is given back whole (no part refunds); a buyer order's deposit cannot move to another order.

**Known limits of 2.4 and 2.6:**
- A sale line shows its receipt's whole invoice, not a share of it per bird sold (the receipt's payable is never split across sales).
- A payment proved only by a pasted SMS or a receipt image has no reference, so it is checked as a possible duplicate (party, amount, day), not by its code.
- An app receipt or payout records no provider, so its reference blocks the same code under any method; the database index covers the exact (provider, account, reference) and the API covers the rest.

**Known limits of 2.3:**
- Statements are checked by their closing balance per day, not line by line (no statement import yet).
- Pay-now payments confirmed by the provider arrive without an account and wait in Unassigned.
- A payout re-sent after "not received" is still one row: its account follows the latest transfer until payout attempts (M2.7).
- The cash book's "Recorded net cash movement (unverified)" card stays until the accounts are set up and reconciled; account balances are on Finance → Accounts.

**Known limits of 2.1 (handled by M2.2 or later):**
- ~~Stock checks were current-state only~~: dated since M2.2.
- A receipt correction is dated the day it is made: the goods leave stock from then, not from the receipt date.
- On LPO stock, a cancelled sale whose goods never left or were returned records no event (the sale stops counting), and "not recovered" is a stock loss dated the day it was recorded.
- Correcting a delivery note that filled a reservation does not put the reservation back; record it again if the buyer still needs the birds.
- A partly filled buyer allocation cannot become an app order; sell the received birds from the delivery note.

| Decision | Status |
|---|---|
| D1 Finance owner | ✅ Maternus Joshua |
| D2 Sale dates | ✅ Direct on sale date, marketplace on delivery date |
| D5 Mistaken-allocation money | ✅ Supplier credit; refunds only with evidence |
| D4 Who may correct supplier debts | ✅ Admins only, with a reason (confirmed 4 October) |
| D3 Stock held before the system | ✅ The finance owner supplies opening values; recorded as opening stock with no payable (4 October) |
| D6 Money accounts | 🟡 Accounts named (5 October): Petty cash, Bank, M-Pesa, Selcom wallet. **Still needed:** each one's verified balance at the cutoff (suggested end of 31 October 2026) |
| D7 Recognition event | ✅ Delivered (5 October). Staff-recorded buyer orders before delivery confirmed 6 October: a commitment until delivered, then a sale on its delivery day (M2.5) |
| D9 Approvals | ✅ (6 October) Any payout resend, or any payment over TZS 500,000, needs approval from a second admin (not the requester) |
| Duplicate references | ✅ (6 October) Mobile-money codes (M-Pesa, Airtel Money, Mixx by Yas, HaloPesa) are unique per provider whichever account; bank and other references per account. The no-reference check stays on Record payment, Pay supplier, customer payments and refunds only (not expenses or sale-time payments) |
| Late-entry window | ✅ (6 October) 3 days: stock records dated more than 3 days back need an admin and a reason |
| D8 | ⬜ Open |

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

### M1 exit check: rule coverage

Checked 5 October 2026. Each rule's M1 scope has a passing test; the parts that need M2 or M3 models are listed with the item that adds their test.

| Rule | Passing tests (backend unless noted) | Still to come |
|---|---|---|
| R1 Payment stays with its receiver | `test_debt_corrections::test_wrong_supplier_moves_the_whole_obligation_and_payment_stays_with_receiver`, `test_transfers::test_a_payment_typed_with_the_sale_stays_with_its_supplier_when_corrected`, `test_batch_sales::test_correcting_a_paid_receipt_keeps_the_money_with_the_supplier`; Playwright `debt-corrections.spec.ts` | |
| R2 Stock moves only with a physical event | `test_batch_sales`: receipt confirmation required, cancel never left / not recovered, buyer return needs condition, return to supplier awaits a credit note | Lot movements per date (M2.1) |
| R3 Outflows are permanent | `test_transfers::test_reversal_moves_money_to_supplier_credit_and_cash_is_unchanged`, `test_refund_is_a_separate_inflow_partial_allowed_never_more_than_credit`, `test_two_identical_pay_requests_and_a_retry_create_one_transfer` | Unconfirmed payout attempts (M2.7) |
| R4 Re-allocation moves no money | `test_transfers::test_reallocating_credit_moves_no_money`, `test_reporting::test_m1_exit_scenario` | |
| R5 Unknown is not zero | `test_cost_states::test_an_unknown_cost_is_never_a_final_margin`, `test_debt_corrections::test_cost_never_existed_is_unknown_not_zero`; Playwright `cost-states.spec.ts` | |
| R6 Evidence before classification | `test_transfers::test_historical_reversal_stays_unresolved_until_classified`, `test_migration_032_leaves_history_unresolved`, `test_link_batch_sales::test_unresolved_lines_are_listed_with_their_reason` | Account mapping (M2.3) |
| R7 Approval is not evidence | `test_cost_states::test_an_evidenced_cost_needs_evidence_and_opens_no_debt`, `test_free_needs_an_admin_and_a_reason` (an admin's "cost never existed" leaves the line unknown and profit provisional) | Locked periods stay qualified (M3.1) |
| R8 No timeline goes negative | Current stock: `test_batch_sales::test_cannot_sell_more_than_is_left_or_from_another_suppliers_batch`, `test_delivery_losses::test_cannot_lose_more_than_is_on_hand_or_before_receipt`, `test_inventory_history::test_two_simultaneous_sales_cannot_oversell`, opening stock never below zero (`test_cost_states`). Every date (M2.2): `test_stock_dates` (back-dated sale, moved sale, undone buyer return, dated loss, late entry, concurrent sales), `test_lots::test_r8_no_change_leaves_any_later_day_below_zero` | |

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
- **Decided (5 October):** an order counts as a sale when it is delivered, for app orders and for orders staff record on a buyer's behalf.
- **Confirmed addition (6 October):** staff record a buyer order taken by phone or in person (buyer, items, agreed price, expected delivery day) without the buyer using the app. Until delivered it is a commitment: not a sale, not owed, no stock taken. "Mark delivered" turns it into a direct sale dated the delivery day, taking stock and cost then.
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
