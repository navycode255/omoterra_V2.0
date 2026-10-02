# Finance metric dictionary

Build plan item **M0.2**. Draft, 3 October 2026, read against commit `5aa01a9` plus the uncommitted working tree. Sources: [build plan](financial-build-plan.md) and [audit](financial-architecture-audit-2026-10-02.md) (F01, F05, F07, F14).

This page defines every money or stock headline on the staff (ops) app. For each one it gives:

- **Current**: what the code computes today. Every statement is taken from the code cited.
- **Target**: what it must compute once M1.7 (`backend/app/reporting.py`) and the later milestones are built.

The finance owner signs it off. After M1.7, a figure that is not defined here may not appear on a finance screen. The M1.7 tests check every entry: each headline must equal its drilldown with marketplace-only, direct-only and mixed data.

## Decisions applied

| # | Status | Effect on this dictionary |
|---|---|---|
| D1 | **Decided.** The finance owner is **Maternus Joshua**. An external accountant joins from M3. | Maternus Joshua signs off this dictionary, every reclassification and period close. |
| D2 | **Decided.** A direct sale counts on its **sale date** (`sales.sold_on`). A marketplace order counts on its **delivery date**. | Every revenue, cost-of-goods and margin figure uses these dates. Today marketplace orders are dated by when they were created. That is a confirmed gap (F07), fixed in M2.5. |
| D7 | **Pending.** The exact event that recognises a marketplace order. | Wherever this page says "recognised marketplace order": **DECISION D7, proposed default: the order reaches `delivered`, and the date is the day it reached `delivered`, in Dar es Salaam time.** `completed` does not count again. A return or reopening reverses the order in the period when it happens. |
| D6 | Pending, outside M0. Not one of this item's decisions. | Used only where cash balances are mentioned. Proposed default: cutoff at the end of 31 October 2026. |

## Summary

"Ledger" means `ledger_debts` and `ledger_payments`: direct sales, supplier invoices, delivery notes, LPO receipts, manual debts and expenses. "Marketplace" means app orders: `orders`, `payments`, `payment_receipts` and `settlements`.

| # | Metric | Shown on | Current scope (short) | Target scope (short) | Biggest gap today |
|---|---|---|---|---|---|
| 1 | Owed to me | Finance, Debts | Finance: ledger plus every unpaid marketplace payment. Debts: ledger only | Ledger plus recognised marketplace receivables. Orders not yet delivered shown separately | Same label, two values. The card's drilldown cannot add up |
| 2 | I owe | Finance, Debts | Finance: ledger plus pending settlements. Debts: ledger only | Ledger payables plus pending settlements. Disputed payouts and unapplied credit shown separately | Same as 1 |
| 3 | Overdue | Debts, Finance tables | Owed-to-me overdue **plus** I-owe overdue | Two separate figures, one per direction | Adds money in and money out together |
| 4 | Marketplace receivables | Finance (inside 1), Payments | Unpaid balance on every pending or partial payment, delivered or not | Recognised (delivered) only. Undelivered unpaid orders become "commitments" | Includes pay-now checkouts that have not been paid or delivered |
| 5 | Pending settlements | Settlements, Manage, Suppliers, Finance (inside 2) | `settlements.status = 'pending'` | Pending, plus a separate disputed-exposure figure (D9 / M2.7) | A disputed paid settlement is in neither figure |
| 6 | Sales today / this month | Finance | Direct sales only, by `sold_on` | Direct sales by `sold_on` plus marketplace orders by delivery date | The profit card and sparkline in the same row include the marketplace |
| 7 | Sales total | Sales | Direct sales only | Same population as 6, split by channel | Profit's "Sales" for the same dates is bigger |
| 8 | Received (Sales) / Cash received (Finance) | Sales, Finance | Sales: paid so far, at any date, on the listed sales. Finance: all money in during the period, any method | Two named metrics: "Paid on these sales" and "Collected in period" | Two definitions, and "Cash received" counts every payment method |
| 9 | Buyer owes | Sales | Open receivable balances of the listed sales | Unchanged. Plus a matching marketplace column | — |
| 10 | I owe suppliers (Sales) | Sales | Open payables linked to the listed sales, **including sale-linked expenses** | Supplier stock payables only. Expenses separate. Receipt status shown but not added in (M2.4) | Mislabelled. Leaves out delivery-note and LPO debts (F08) |
| 11 | Cash in hand | Cash book | All-time cash-method ledger payments in minus out | "Recorded net cash movement (unverified)" until M2.3. After that, reconciled balance per account | Not a verified balance (F05). Ignores marketplace cash |
| 12 | Money in / out / net | Cash book, Finance (by method) | Unreversed ledger allocations by `paid_on` | Actual transfers, receipts, refunds and payouts by date (cash_movements) | A reversed allocation drops out although the money left (F04). No marketplace cash |
| 13 | Gross profit | Profit (implied) | Revenue minus direct cost minus marketplace payout cost | Same, with D2 dates and known-cost lines only. Provisional if any cost is unknown | Unknown cost counts as 0 (F02). Wrong period for marketplace (F07) |
| 14 | Net profit | Finance, Profit | Gross minus expenses minus LPO stock lost | Same, plus losses on every lot type (M2.1). Provisional flag | Same as 13 |
| 15 | Stock cost | Profit | `sales.cost_amount` plus payout snapshot × quantity | cost_of_goods(), split known / unknown / free | Same as 13 |
| 16 | Expenses (Profit) / Total spent (Expenses) | Profit, Expenses | Profit: expenses **plus stock lost**. Expenses page: incurred amount, ignoring search | `summary {incurred, paid, outstanding}` with the list's filters. Stock lost shown on its own line | The two pages differ. `total` is overwritten, which breaks paging (F14) |
| 17 | Supplier total owed / due now / overdue | Supplier payments | Open payables with a registered supplier | Same plus pending settlements, labelled by source | Leaves out settlements, but the Suppliers list includes them |
| 18 | Supplier bought / paid / owed | Supplier detail (statement) | Non-cancelled payables of that supplier | Transferred / allocated / unapplied / refunded / unresolved (M1.2), plus marketplace settlements | Transfer header and allocations can differ. Settlements missing |
| 19 | Supplier list paid / owed / birds bought | Suppliers | Ledger paid; ledger owed **plus** pending settlements; mixed-unit quantity | Same figures as 17 and 18; quantity per unit | Differs from the statement and Supplier payments. Adds kg to birds |
| 20 | Batch registered / taken / sold elsewhere / left | Supplier detail | Batch counters | Lot movements (M2.1). The declaration is never counted as stock | The four figures do not add up when birds are reserved |
| 21 | Trading sales / gross margin | Manage | Marketplace orders by created date, including undelivered ones, at ordered quantity | Same population and dates as 6 and 13 | A third definition of "sales" |

---

## Conventions for every metric

### Current conventions

**Business day.** `contracts.business_today()` gives today's date in Africa/Dar_es_Salaam (EAT). Ledger dates (`sold_on`, `incurred_on`, `paid_on`, `due_on`, `received_on`) are plain calendar dates entered by staff. Marketplace timestamps are UTC and converted to EAT only in some places:

- `finance._order_day` and `ops_dashboard` convert to EAT.
- `ops_summary` (`main._today_range`) uses midnight UTC, which is 03:00 EAT.

**Money storage.** Amounts are `Numeric(14,2)` and handled as Python `Decimal`. A line subtotal and a line cost are rounded half-up to 2 decimals (`services.money`), and totals are exact sums of the rounded lines. Exceptions:

- `profit_between` rounds the marketplace cost per day, after multiplying `payout_snapshot` × quantity.
- A settlement rounds per order item.

**Display.** `ops/lib/format.ts::money` **truncates** to 2 decimals and hides a zero fraction. Several cards add values in the browser with floating-point `Number`, then format the result:

- Debts "Overdue";
- Profit "Stock cost" and "Expenses";
- the Finance by-method net;
- supplier detail "pending settlements".

**Snapshots.** Each page makes several independent API calls, so each figure comes from a different database snapshot (F17).

### Target conventions (all metrics)

1. **One source.** Every finance figure comes from `reporting.py`: `receivables()`, `payables()`, `revenue()`, `cost_of_goods()` and `cash_movements()`. Every row carries `source` (ledger or marketplace) and `source_id`. A row reachable from both streams is counted once.
2. **Recognition (D2).**
   - A direct sale counts on `sold_on`.
   - A marketplace order counts on its delivery date. **DECISION D7, proposed default:** the date the order reached `delivered`, in EAT, stored as `orders.recognized_on` (M2.5).
   - Until M2.5 the delivery date is taken from the order's activity log. Orders without a clear delivery entry are listed as *unresolved* and kept out of period revenue (R5, R6).
3. **Commitments are not debts.** A marketplace order that is not yet recognised is reported only under "Commitments", never inside Owed to me, Sales or Profit.
4. **Statuses.**
   - Cancelled sales and debts count for nothing.
   - Reversed allocations do not count as an allocation. From M1.2 the money behind them stays on the transfer as *unapplied* or *unresolved*, never as zero.
   - Settled debts count for history totals but not for balances.
5. **Dates.**
   - "Today" and "this month" use the EAT calendar, everywhere, including `ops_summary`.
   - A period is inclusive of both ends.
   - Balances ("now" figures) use no period. They include every open item, whatever its date.
6. **Rounding.**
   - Round once, half-up to 2 decimals, at line level (a sale line, receipt line or settlement item). Sum exact `Decimal`s after that.
   - Headline and drilldown are compared at stored precision (2 dp).
   - The browser never does money arithmetic: every composite figure (overdue, stock cost with marketplace, expenses with losses) comes from the API.
   - Display rounds half-up instead of truncating.
7. **Provisional and qualified flags (R5, R7).**
   - Any figure that depends on an unknown cost, an unresolved allocation, an unassigned payment or an unresolved recognition date carries `provisional: true`, with the count and amount affected.
   - The UI shows "Provisional: …" next to the figure. It never shows a minimum or range.
8. **Drilldown rule.** Every headline links to a list whose rows, under the **same filters, scope, dates and rounding**, add up exactly to the headline across **all pages** of that list. A preview limited to the top 5 or top 100 must say so and must not be presented as the drilldown.
9. **One snapshot per page (M5).** One endpoint per finance page, read in a single `REPEATABLE READ READ ONLY` transaction.

---

## A. Balances

### 1. Owed to me

- **Shown on:**
  - Finance overview, card "Owed to me". It uses `owed_to_me.total` and links to Debts with the *Owed to me* tab.
  - Finance overview, table "Who owes me" (top 5 parties).
  - Debts page, card "Owed to me". It uses `owed_to_me.ledger`.
  - Sparkline on the Finance card: `trends.owed_to_me`.
- **Current definition** (`finance.finance_summary`, `finance._parties`):
  - Ledger part: the sum of `amount − paid_amount` over `ledger_debts` with `direction = 'receivable'` and `status = 'open'`.
  - Marketplace part: the sum of `payments.amount − payments.received_amount` where `payments.status IN ('pending','partial')` and `orders.internal_status NOT IN ('cancelled','payment_failed')`.
  - Card value = ledger + marketplace.
- **Source tables:** `ledger_debts`, `payments`, `orders`.
- **Counted statuses:**
  - Ledger debts: `open` only (`settled` has no balance; `cancelled` is excluded).
  - Payments: `pending` or `partial`, for any order status except cancelled or failed, **including orders not yet delivered**.
- **Period date:** none. It is a balance now.
- **Exclusions:** cancelled debts; cancelled or failed orders; `failed` payments.
- **Rounding:** exact `Decimal` sum. The UI truncates.
- **Drilldown that must add up:**
  - Today: Debts list, tab `owed_to_me` (`DEBTS` spec). It covers **ledger only**, so it equals the Debts card and not the Finance card.
  - The overview table shows only 5 of up to 100 parties (`debtors[:100]`).
  - The sparkline is ledger only (`finance._trends`) and leaves out cancelled debts' history.
- **Current gaps:**
  - **G1.** Same label, two values. Finance shows ledger plus marketplace; Debts shows ledger only. Clicking the Finance card lands on a list that cannot add up to it (`ops/app/(ops)/finance/page.tsx` against `ops/app/(ops)/finance/debts/page.tsx`; F01).
  - **G2.** The marketplace part includes orders not delivered yet, including pay-now checkouts still waiting for payment (`finance.finance_summary`; F01: commitments mixed with debts).
  - **G3.** The sparkline's last point is the ledger figure, while the card shows ledger plus marketplace.
- **Target** (`reporting.receivables()`):
  - Value: open ledger receivables plus the unpaid balance of **recognised** marketplace orders (D2: delivery date; D7 proposed default: `delivered`).
  - Undelivered unpaid orders are reported as **Commitments: ordered, not delivered**, beside the card, and not added to it.
  - Money a buyer has paid before delivery is a **customer deposit**, shown under commitments. It is not revenue and not a negative receivable.
  - Drilldown: the Debts *Owed to me* tab lists ledger and marketplace rows together, with a Source column, and its total equals the card.
  - Both pages show one figure under one label. The sparkline uses the same population.

### 2. I owe

- **Shown on:**
  - Finance overview, card "I owe" (`i_owe.total`), and table "Who I owe".
  - Debts page, card "I owe" (`i_owe.ledger`).
  - Sparkline `trends.i_owe`.
- **Current definition** (`finance.finance_summary`, `finance._parties`):
  - Ledger part: the sum of `amount − paid_amount` over payables with `status = 'open'`.
  - Marketplace part: the sum of `settlements.total_payable` where `status = 'pending'`.
- **Source tables:** `ledger_debts` (sources `sale_cost`, `batch_receipt`, `lpo`, `manual`, `expense`), `settlements`.
- **Counted statuses:** open debts; pending settlements. A settlement that is `paid` but has `supplier_confirmation = 'not_received'` is **not** counted.
- **Period date:** none. It is a balance now.
- **Exclusions:**
  - Cancelled debts.
  - Reversed allocations. The debt becomes open again, so the owed amount rises even though the money may still be with the supplier (F04).
- **Rounding:** exact sum. The UI truncates.
- **Drilldown that must add up:** the Debts tab `i_owe`, which is ledger only. The Finance card includes settlements, so it does not tie.
- **Current gaps:**
  - **G1** applies here too.
  - **G4.** A disputed payout (paid, "not received") drops out of every payable figure. `pay_settlement` lets it be paid again, but there is no exposure line for it (`main.pay_settlement`; F12).
  - **G5.** A reversed allocation increases "I owe" with no record that the money already left. Paying again can double-pay (`finance.reverse_payment`; F04).
- **Target** (`reporting.payables()`):
  - Value: open ledger payables plus pending settlements.
  - Shown separately, beside the card and not netted against it:
    - **disputed payout exposure**: settlements with an unresolved attempt (M2.7);
    - **supplier credit / unapplied transfers**: money a supplier holds from a reversed or unapplied allocation (M1.2, D5);
    - **unresolved allocations** (R6).
  - Drilldown: the Debts *I owe* tab includes settlement rows, with a Source column, and its total equals the card.

### 3. Overdue

- **Shown on:**
  - Debts page, card "Overdue". The browser adds `owed_to_me.overdue + i_owe.overdue`. The count comes from tab `overdue`.
  - Finance tables, "Overdue" column per party.
- **Current definition:**
  - `finance._parties`: per party, the sum of the balance of open debts with `due_on < business_today()`.
  - The `DEBTS` tab `overdue` uses open debts with `due_on <` the EAT date, in both directions.
- **Source tables:** `ledger_debts`.
- **Counted statuses:** open. Undated debts are never overdue here.
- **Period date:** `due_on` compared with today in EAT.
- **Exclusions:** the marketplace entirely (payments and settlements have no due date).
- **Rounding:** browser floating-point addition, then truncation.
- **Drilldown that must add up:** the Debts tab `overdue`. It mixes both directions, so its rows do add up to the mixed card.
- **Current gaps:**
  - **G6.** One number adds money others owe Omoterra to money Omoterra owes. It answers no business question (`ops/app/(ops)/finance/debts/page.tsx`).
  - **G7.** On Supplier payments, "Due now" counts undated invoices as due, but here they are never overdue. That rule is correct, but it is not stated anywhere (see 17).
- **Target:**
  - Two figures: **Overdue to collect** (receivables) and **Overdue to pay** (payables). Each has its own tab filtered by direction.
  - Marketplace rows have no due date. **Proposed:**
    - A recognised marketplace receivable is due on the delivery date and becomes overdue the next day.
    - A pending settlement is due 7 days after delivery. This needs finance-owner sign-off (D1, Maternus Joshua) as a policy rule, not a code default.
  - Computed in the API, never added up in the browser.

### 4. Marketplace receivables

- **Shown on:**
  - Finance, inside "Owed to me" (`owed_to_me.marketplace`, never shown alone).
  - Payments page: rows and an "outstanding" list.
  - Manage: an attention count, "Buyer payments outstanding" (`ops_summary.attention.payments_pending`, a count of pending or partial payments).
- **Current definition:**
  - The overview figure is described under 1.
  - Payments page rows (`main.ops_payments`): `balance = amount − received_amount` for each payment.
  - The `outstanding` tab is `status IN ('pending','partial')`, for any order status. Unlike the overview, it includes cancelled and failed orders.
- **Source tables:** `payments`, `orders`, `payment_receipts`.
- **How received money is recorded:**
  - Pay-on-delivery: received through `main.reconcile`, which writes a `payment_receipts` row (amount and reference only; no date or method other than `created_at`).
  - Pay-now: received through `apply_provider_confirmation`, which sets `received_amount` and `paid_at` but writes no receipt row.
- **Period date:** none.
- **Exclusions:** the overview leaves out cancelled and failed orders; the Payments list does not.
- **Drilldown:** the Payments list, tab `outstanding`. It is a different population from the overview (it includes cancelled orders), so the two do not tie.
- **Current gaps:**
  - G2.
  - **G8.** The overview and the list filter differently.
  - **G9.** Marketplace money received has no reliable date or method, so it cannot enter the cash book (see 11 and 12).
- **Target:**
  - **Recognised receivable**: the unpaid balance of orders recognised under D2 / D7.
  - **Commitment**: the unpaid balance of orders not yet recognised.
  - Each receipt (pay-now or on delivery) becomes a dated buyer receipt with a method, and later an account (M1.2 transfer structure, M2.3).
  - The Payments list totals use the same filters as the overview.

### 5. Pending settlements

- **Shown on:**
  - Settlements, cards "Pending payouts" (`totals.pending`) and "Paid to date" (`totals.paid`).
  - Manage, KPI "Pending settlements" (`ops_dashboard.kpis.pending_settlements`).
  - Suppliers list, through `owed_total`.
  - Supplier detail, a browser sum of pending settlements.
  - Finance, inside "I owe".
- **Current definition:** the sum of `settlements.total_payable` where `status = 'pending'`. This is in `main.ops_settlements`, `main.ops_dashboard` and `main.ops_summary`. A settlement is created when the order is delivered (`services.advance`). Its total is accepted quantity × `payout_snapshot`, rounded per item.
- **Source tables:** `settlements`.
- **Counted statuses:** `pending`. "Paid to date" sums `status = 'paid'`, including settlements the supplier says never arrived.
- **Period date:** none. "Paid to date" is all time.
- **Drilldown:** Settlements, tab `pending`. The page's "due" list also merges `not_received` rows into the action list, but they are not in the card.
- **Current gaps:**
  - G4.
  - **G10.** "Paid to date" counts a disputed payout as paid. A resend overwrites `paid_at` and `payment_reference`, so the first outflow leaves no record (`main.pay_settlement`; F12).
- **Target:**
  - **Pending** = settlements with no debited attempt.
  - **Disputed exposure** = settlements with a disputed or unresolved attempt, shown separately.
  - **Paid (net)** = debited outflows minus refunds (M2.7), each counted on its own date in cash movements.
  - Every page uses the same three figures.

---

## B. Sales

### 6. Sales today / Sales this month (Finance overview)

- **Shown on:** the Finance card "Sales today" or "Sales this month" (`today.sales` / `month.sales`), with a "Cash received" sub-line (see 8) and the `trends.revenue` sparkline.
- **Current definition** (`finance._sold`): the sum of `sales.total_amount` where `sales.status = 'active'` and `sold_on = today`, or `sold_on >= month start`.
- **Source tables:** `sales`.
- **Counted statuses:** `active`.
- **Period date:** `sold_on`. The month figure has no upper bound, so a sale dated in the future this month would count.
- **Exclusions:** cancelled sales, and **all marketplace orders**.
- **Rounding:** an exact sum of line subtotals rounded half-up.
- **Drilldown:** the card links to `/sales` with no dates, so the Sales page defaults to the current month (see 7).
- **Current gaps:**
  - **G11.** In the same card row, "Profit this month" and the revenue sparkline include delivered marketplace orders, but the sales figure does not (`finance.finance_summary` against `finance.profit_between`; F01).
- **Target** (`reporting.revenue()`):
  - Direct sales by `sold_on` plus recognised marketplace orders by delivery date (D2; D7 proposed default: `delivered`).
  - Shows the split "direct X · marketplace Y".
  - Must equal Profit "Sales" and the Sales page for the same dates.

### 7. Sales total (Sales page)

- **Shown on:** Sales, card "Sales total" with a count. The period defaults to this month and can be "all dates".
- **Current definition** (`finance._sales_summary`): the sum of `sales.total_amount` over active sales matching the date range on `sold_on`, the buyer filter and the search `q`, across every status tab.
- **Source tables:** `sales`, `sale_items` (for search).
- **Counted statuses:** active.
- **Period date:** `sold_on`.
- **Exclusions:** cancelled sales; the marketplace.
- **Drilldown:** the Sales list under the same filters. The list's *Cancelled* tab rows are not in the total, which is correct but not labelled.
- **Current gaps:**
  - G11.
  - **G12.** On Profit, each day's row links to `/sales?start=d&end=d`. That list has no marketplace rows, so it cannot explain the day's revenue.
- **Target:** the same population as 6. The Sales list either includes recognised marketplace orders as rows (source "App order") or shows a separate marketplace sub-list whose total, added to the direct total, equals the card.

### 8. Received (Sales) and Cash received (Finance)

- **Shown on:**
  - Sales card "Received" (`summary.received`), with "% received".
  - Finance Sales card sub-line "Cash received" (`today.money_in` / `month.money_in`).
- **Current definitions:**
  - Sales "Received" (`finance._sales_summary`): the sum of `paid_amount` on non-cancelled receivables of the listed sales. It is cumulative to now: money received after the period, for a sale inside the period, counts.
  - Finance "Cash received" (`finance._paid('receivable', paid_on …)`): the sum of unreversed `ledger_payments` against **any** receivable (sales, manual debts and old sales alike) with `paid_on` in the period, **by any method**.
- **Source tables:** `ledger_debts`, `ledger_payments`.
- **Exclusions:** reversed payments; marketplace receipts in both cases.
- **Current gaps:**
  - **G13.** Two definitions behind the same idea. The label "Cash received" suggests the cash method but counts M-Pesa, bank and every other method.
- **Target:**
  - **Paid on these sales** (Sales page): payments allocated to the listed sales' receivables, dated up to the period end. Its label says "to date" when the end is today.
  - **Collected in period** (Finance): all buyer receipts in the period from `cash_movements()`, both ledger and marketplace, by receipt date, with a method split.
  - Neither is called "cash" unless it is filtered to cash accounts (M2.3).

### 9. Buyer owes (Sales page)

- **Current definition** (`finance._sales_summary`): the sum of `amount − paid_amount` over non-cancelled receivables linked to the listed sales, with a count of sales that still owe.
- **Period date:** the sale's `sold_on` (the balance is as of now).
- **Drilldown:** the Sales list column "Buyer owes" (`sale_view.balance`), which adds up under the same filters.
- **Gaps:** none in isolation. It differs from "Owed to me" by design (only sales in the range; no manual debts). The label should say so.
- **Target:** unchanged for direct sales, plus a marketplace column once marketplace rows join the list (7).

### 10. I owe suppliers (Sales page)

- **Shown on:** Sales card "I owe suppliers" (`summary.supplier_owed`) and the list column "Supplier owed" (`sale_view.supplier_balance`).
- **Current definition** (`finance._sales_summary` `owed('payable')`): the sum of `amount − paid_amount` over **every** non-cancelled payable with `sale_id` among the listed sales.
- **Current gaps:**
  - **G14.** It includes **sale-linked expenses** (`source = 'expense'` with a `sale_id`, from `finance.create_expense`), such as transport or labour, under the label "suppliers".
  - **G15.** It leaves out stock that came from a delivery note or LPO. Those debts belong to the receipt, so a sale of received stock shows 0 owed even when the receipt is unpaid (F08, `finance.sale_view`).
- **Target:**
  - "Owed to suppliers for this sale": payables with `source = 'sale_cost'` only.
  - Sale-linked expenses are shown as "Unpaid sale expenses".
  - The receipt's payment status is shown per line ("Stock from DN-…: invoice X, paid Y", M2.4) and is never added to the sale's figure.

---

## C. Cash

### 11. Cash in hand (Cash book)

- **Shown on:** Cash book, card "Cash in hand".
- **Current definition** (`finance._cash_totals`): the sum of unreversed `ledger_payments` with `method = 'cash'` against receivables, minus the same against payables. It is **all time** and ignores the page's dates, method and search.
- **Source tables:** `ledger_payments`, `ledger_debts`.
- **Exclusions:**
  - non-cash methods;
  - reversed allocations;
  - marketplace receipts;
  - settlement payouts (they have no method);
  - opening balance, cash counts, bank deposits and withdrawals between accounts.
- **Drilldown:** none. Filtering the Cash book to method = cash and "all dates" gives a net that should match, but nothing links there.
- **Current gaps:**
  - **G16.** This is not a verified balance. There is no opening balance or count, and a reversed cash allocation makes cash look higher even when the money really left (F05, F04).
- **Target:**
  - Until M2.3: renamed **"Recorded net cash movement (unverified)"**, with its scope stated ("cash-method entries since records began; excludes app orders").
  - From M2.3: **reconciled balance per money account** = verified opening balance at the cutoff (DECISION D6, proposed default: end of 31 October 2026) plus movements after the cutoff.
  - The *Unassigned (historical)* bucket is shown separately, outside the balance.
  - Drilldown: account statement lines.

### 12. Money in / Money out / Net for period (Cash book) and Money by method (Finance)

- **Shown on:**
  - Cash book cards "Money in", "Money out" and "Net for period".
  - Finance table "Money by method", with an all-time total row.
- **Current definition:**
  - `finance._cash_totals`: the sum of unreversed `ledger_payments.amount` joined to the debt direction (receivable = in, payable = out), filtered by `paid_on` in the range, the method and the search. Net = in − out.
  - `finance.finance_summary.by_method` is the same, all time, grouped by method.
- **Period date:** `ledger_payments.paid_on`. The default is the current month.
- **Exclusions:** reversed allocations; marketplace receipts; settlement payouts.
- **Rounding:** exact. The Finance net is computed in the browser.
- **Drilldown:** the Cash book list, tab `in` or `out`, under the same filters. The *Reversed* tab rows are not in the totals.
- **Current gaps:**
  - **G17.** "Money out" counts **allocations**, not transfers. One supplier transfer (`supplier_payments`) is split into several rows. If an allocation is reversed, the outflow disappears, although the supplier still holds the money (F04, `finance.reverse_payment`).
  - **G18.** No marketplace money appears at all, so a business paid through the app shows less money in than it received (F01).
- **Target** (`reporting.cash_movements()`):
  - Outflows are **transfers** (`supplier_payments`, expense and other payments, settlement debited attempts), once each, on their date.
  - Inflows are buyer receipts (ledger and marketplace) and refunds, each a separate dated inflow (R3).
  - Re-allocations move no money (R4).
  - Pending attempts are shown as exposure, not as outflow.
  - Internal transfers between accounts net to zero (M2.3).
  - The Cash book list shows transfers with their allocations nested, so its rows add up to the card.

---

## D. Profit

### 13. Gross profit, and 15. Stock cost

- **Shown on:**
  - Profit, card "Stock cost" = `stock_cost + marketplace_cost`, added in the browser.
  - The day-by-day "Stock cost" column.
  - Gross profit is in the API (`gross_profit`) but is not shown as its own card.
- **Current definition** (`finance.profit_between`):
  - Direct: `sales.total_amount` and `sales.cost_amount` for active sales grouped by `sold_on`.
  - `cost_amount` is the sum of `sale_items.cost_total`, where a missing cost becomes 0 (`create_sale` and `update_sale`: `item.cost_total or ZERO`).
  - Marketplace revenue: `orders.total_amount` for orders with `internal_status IN ('delivered','completed')`, grouped by the **order creation date** in EAT (`_order_day`).
  - Marketplace cost: `order_items.payout_snapshot × coalesce(order_items.actual_quantity, order_items.quantity)`, rounded per day.
  - Gross = revenue − direct cost − marketplace cost.
- **Source tables:** `sales`, `sale_items`, `orders`, `order_items`.
- **Counted statuses:** sale `active`; order `delivered` or `completed`.
- **Period date:** direct sales by `sold_on`; marketplace orders by `created_at` (EAT).
- **Exclusions:** cancelled sales; undelivered or cancelled orders.
- **Drilldown:** the Profit day-by-day table, whose rows add up to the cards. Each day's link to the Sales list shows only direct sales.
- **Current gaps:**
  - **G19.** An unknown buying cost counts as 0, which overstates margin (F02).
  - **G20.** Cancelling a `sale_cost` debt clears the matching item costs and recalculates `cost_amount`, which raises profit (F06, `finance.cancel_debt`).
  - **G21.** A marketplace order is dated by creation, not delivery. An order made in September and delivered in October lands in September, and only after delivery, so a closed month changes (F07).
  - **G22.** Marketplace cost falls back to the **ordered** quantity when the item has no `actual_quantity`, while the settlement uses `order.actual_quantity` (`services.advance`). Cost and payable can then differ. The cost is also rounded per day, not per item.
- **Target** (`reporting.cost_of_goods()`):
  - Revenue as in 6.
  - Cost of goods:
    - direct lines whose `cost_state` is `known` or `free` (M1.3);
    - marketplace items = the **settlement amount** of the recognised items, so cost ties to the payable;
    - every sale of a received lot at its lot cost.
  - Recognised on the same date as its revenue (D2; D7 proposed default: `delivered`).
  - Any unknown-cost line makes the period's gross and net profit **"Provisional: buying costs incomplete"**, with the number of sales and the revenue affected (R5).
  - Debt corrections never erase cost (M1.4).
  - The Stock cost card is split into "direct / marketplace", computed by the API.

### 14. Net profit

- **Shown on:**
  - Finance card "Profit today" or "Profit this month" (`profit_today.net_profit` / `profit_month.net_profit`) and its sparkline.
  - Profit card "Net profit" or "Net loss", and the day table.
- **Current definition** (`finance.profit_between`): gross profit − expenses − stock lost.
  - **Expenses:** the sum of `ledger_debts.amount` with `source = 'expense'` and status other than cancelled, by `incurred_on`. That is accrual: unpaid expenses count.
  - **Stock lost:** the sum of `stock_losses.quantity × unit_cost` where not cancelled, by `lost_on`. Only LPO stock can be recorded as lost.
- **Exclusions:**
  - Manual debts (loans and similar), which is correct.
  - Losses or mortality on delivery-note stock, which has no loss path (F09).
  - Supplier-batch birds sold directly.
- **Current gaps:**
  - G19 to G21.
  - **G23.** Net profit is not complete accounting (F15). There is no depreciation, prepayments or loan interest split. It is an operating result.
- **Target:**
  - Gross profit − operating expenses (accrual, by `incurred_on`) − stock losses on **every** lot type (M2.1), with the provisional flag carried through.
  - Labelled **"Operating profit"** until M3.2 classifications exist.
  - Profit today and this month on Finance must equal the Profit page for the same dates.

### 16. Expenses (Profit card) and Total spent (Expenses page)

- **Shown on:**
  - Profit card "Expenses" = `expenses + stock_lost`, added in the browser. It links to the Expenses page.
  - Expenses page card "Total spent" (`body.total`) and the category breakdown.
- **Current definitions:**
  - Profit: as described in 14.
  - Expenses page (`finance.expenses`):
    - rows are `source = 'expense'` debts filtered by date (`incurred_on`), category and `sale_id`, plus paging search, status tab and order;
    - `by_category` sums `amount`, `paid_amount` and `amount − paid_amount` for non-cancelled rows under date, category and sale filters **only**;
    - `body['total']` is then **overwritten** with the money sum.
- **Current gaps:**
  - **G24.** `total` is the row count in every other list. Here it is replaced by money, so the page cannot compute pages and guesses from `items.length` (`ops/app/(ops)/finance/expenses/page.tsx`; F14).
  - **G25.** Search and status filters change the rows but not the total.
  - **G26.** "Total spent" includes unpaid expenses: it is the amount incurred, not spent.
  - **G27.** The Profit card adds stock lost, then links to an Expenses page whose total leaves it out, so the two never match when there were losses.
- **Target** (M1.1):
  - `total` stays the row count.
  - `summary {incurred, paid, outstanding}` uses exactly the row filters, across every page.
  - The card reads "Incurred", with "paid" and "still owed" beside it.
  - The Profit card shows "Expenses" and "Stock lost" as separate figures. Each links to a list that adds up to it.

### 21. Trading sales / gross margin (Manage dashboard)

- **Shown on:** Manage, "Sales" and "Gross margin" for the chosen period (`ops_dashboard.trading`).
- **Current definition** (`main.ops_dashboard`):
  - Orders with `created_at` in the period (EAT) and status other than cancelled or payment-failed. That **includes orders not yet delivered**.
  - Sales = the sum of `total_amount`.
  - Margin = the sum of `(unit_price − payout_snapshot) × quantity` at the **ordered** quantity.
  - `ops_summary.sales_today` and `gross_margin_today` work the same way but use a UTC day. They are not currently displayed.
- **Current gaps:**
  - **G28.** A third definition of "sales": marketplace only, by creation date, including commitments, with margin at ordered rather than accepted quantity. It is called "Sales" on the same app where Finance and Profit use other definitions (F01).
- **Target:** reads `revenue()` and `cost_of_goods()` for the period, with the same values as Profit. Or, if Manage is meant to show order intake, it is renamed **"Orders placed (value)"**, with no margin figure.

---

## E. Suppliers

### 17. Supplier payments: Total owed / Due now / Overdue / Suppliers with open balances

- **Shown on:** the Supplier payments cards and the per-supplier "Amount owed" column.
- **Current definition** (`finance.supplier_balances`):
  - Payables with `status = 'open'` and `supplier_id IS NOT NULL`, grouped by supplier.
  - `owed` = the sum of balances.
  - `due_now` = the balance of open invoices with `due_on IS NULL` or `due_on <= today`. It includes overdue invoices.
  - `overdue` = the balance with `due_on < today`.
  - The summary is computed before the search and state filters, so it covers the whole set. That is intended and stated in the docstring.
- **Exclusions:**
  - Payables to unregistered parties (`party_kind = 'other'`).
  - Expenses.
  - **Marketplace settlements.**
- **Drilldown:** the supplier rows, all states and every page. They add up to the cards when no filter is applied.
- **Current gaps:**
  - **G29.** This "Total owed" leaves out pending settlements. The Suppliers list's "Owed" (19) includes them, so the same supplier shows two different owed amounts.
  - "Due now" includes "Overdue", which is consistent but should say "including overdue".
- **Target:**
  - `payables()` filtered to registered suppliers.
  - Ledger invoices and pending settlements, each row with its source.
  - Disputed payouts and unapplied credit shown per supplier, not netted.
  - "Due now (incl. overdue)" labelled explicitly.
  - The same per-supplier owed figure as 18, 19 and the supplier portal (0.5 harness).

### 18. Supplier statement: Bought from them / Paid to them / Still owed

- **Shown on:** Supplier detail, the statement block (`components/finance/supplier-statement.tsx`).
- **Current definition** (`finance.supplier_statement`):
  - Payables of the supplier with status other than cancelled.
  - `bought` = the sum of `amount`.
  - `paid` = the sum of `paid_amount`.
  - `owed` = the sum of balances.
  - Payment history lists:
    - each `supplier_payments` transfer at its full `amount`, with `allocated` = its unreversed allocations;
    - each single unreversed allocation made without a transfer.
- **Exclusions:** cancelled debts; reversed allocations; **marketplace settlements**.
- **Drilldown:** the debts table, which adds up to bought, paid and owed. The payment history adds up to `paid` only when every transfer is fully allocated.
- **Current gaps:**
  - **G30.** When an allocation is reversed, "Paid to them" falls while the history still shows the transfer as "X of Y sent". The statement never says where the difference is (F04).
  - **G31.** App-order payouts to the same supplier are not on the statement.
- **Target** (M1.2):
  - **Bought** = valid obligations, ledger and settlements.
  - **Transferred** = actual transfers, minus refunds.
  - **Allocated**, **Unapplied credit**, **Refunded**, **Unresolved**.
  - Invariant: allocated + unapplied + refunded + unresolved = transferred, for each transfer.
  - **Owed** = bought − allocated.
  - Identical figures on the staff page, the Supplier payments row and the supplier portal (0.5 harness).

### 19. Suppliers list: Paid / Owed / Birds bought / batches and birds left

- **Shown on:** the Suppliers directory table (`components/supplier-directory.tsx`).
- **Current definition** (`main._supplier_activity`):
  - `paid_total` = the sum of `paid_amount` on that supplier's non-cancelled payables.
  - `owed_total` = the sum of open balances **plus** pending settlements.
  - `birds_bought` = the quantity on active direct-sale lines from this supplier with no delivery note and no LPO, plus the accepted quantity on non-cancelled delivery notes.
  - `birds_left` = the sum of `available_to_commit` over open batches.
- **Current gaps:**
  - G29.
  - **G32.** "Paid" here is allocations to ledger debts, but "Owed" adds settlements. Paid settlements are never added to "Paid", so paid + owed means nothing.
  - **G33.** "Birds bought" adds every unit together (kg and birds) and leaves out LPO receipts, although LPO debts are in Paid and Owed.
  - "Birds left" is the supplier's declaration, not Omoterra stock.
- **Target:**
  - Paid and Owed come from the same function as 17 and 18, so they are identical.
  - Quantity bought is shown **per unit**, from received lots (delivery notes, LPO receipts, opening stock; M2.1).
  - "Birds left" is renamed **"Declared by supplier, not received"** and never counted as stock or guaranteed supply (M2.1 rule).

### Supplier detail: pending settlements line

The line comes from a browser sum of the supplier's settlements with `status = 'pending'`. It has the same scope as 5 and the same gap (disputed payouts are missing). **Target:** read from the API, using the definition in 5.

---

## F. Batch stock

### 20. Registered / Taken by Omoterra / Sold elsewhere / Left in the batch

- **Shown on:** Supplier detail, the batch cards. `batch_stock.batch_breakdown` is also returned by sold-elsewhere and close actions.
- **Current definition** (`batch_stock.batch_breakdown`; the `SupplierBatch.available_to_commit` property):
  - **Registered:** `supplier_batches.current_quantity`. This is not `initial_quantity`: verification overwrites it (`main.verify_supplier_batch`), converting demand into an order subtracts from it, and cancelling the order adds it back (`services.advance`).
  - **Taken by Omoterra:** `sold_quantity`. Accepting a delivery note adds to it (`receive_supplier_stock`), and so does a direct batch sale line (`take_from_batch`). It falls when such a sale is edited or cancelled (`return_to_batch`).
  - Sub-line: "received on notes" (a browser sum of active delivery notes' accepted quantity) and "sold straight to buyers" (`sold_direct`, from active sale lines with `supplier_batch_id`).
  - **Sold elsewhere:** `externally_sold_quantity`.
  - **Left:** `max(0, current − reserved − sold − externally_sold)`. Reserved birds appear as a note under Left, not as their own figure.
- **Units:** the batch's unit (birds for poultry). Fractions are refused for birds when receiving.
- **Drilldown:**
  - delivery notes listed under the batch;
  - "sold elsewhere" history;
  - **no list** of the direct sale lines.
- **Current gaps:**
  - **G34.** Registered ≠ taken + sold elsewhere + left whenever any birds are reserved. The progress bar has no reserved segment.
  - **G35.** A direct batch sale counts as "taken" with no delivery note, so no receipt or payable is created from the receipt. Its payable comes from the sale's cost line, if one was entered (F09; fixed by M1.6).
  - Cancelling a sale returns the birds to the *supplier's* batch, not to Omoterra stock (R2 conflict; M1.6).
  - **G36.** Delivery-note stock has no loss or return path (F09). There is also no endpoint to cancel a delivery note, although the queries filter on `cancelled_at`.
- **Target** (M2.1, `lot_movements`):
  - **Declared** (the supplier's registered batch: never Omoterra stock);
  - **Reserved**;
  - **Received** (confirmed delivery notes, including M1.6 same-day receipts);
  - **Sold**, **Lost**, **Returned to supplier**;
  - **On hand** = received − sold − lost − returned, as of any date (R8);
  - **Not received, left with supplier** = declared − reserved − received − sold elsewhere.
  - Both identities shown, for staff, the supplier app and the portal.

---

## Inconsistencies found, ranked by impact

Impact is how likely the figure is to lead to a wrong money decision, such as paying twice, believing the business is profitable, or spending cash that is not there.

| Rank | Gap | Where (file:function) | Why it matters | Fixed by |
|---|---|---|---|---|
| 1 | **G17 / G5 / G30.** Reversing an allocation removes the outflow from Money out, Cash in hand and "Paid to them", and reopens the debt, although the money really left. | `backend/app/finance.py:reverse_payment`, `_cash_totals`, `supplier_statement` | Staff may pay the supplier again. Cash looks higher than it is. | M1.2 (D5) |
| 2 | **G19 / G20.** An unknown cost counts as 0, and cancelling a supplier debt clears real item cost. | `finance.py:create_sale`, `update_sale` (`cost_total or ZERO`), `cancel_debt` | Margin and net profit are overstated. A debt correction can raise profit. | M1.3 (D3), M1.4 (D4) |
| 3 | **G16.** "Cash in hand" is all-time cash-method entries in minus out, with no opening balance, count, marketplace money or transfers. | `finance.py:_cash_totals` | Read as money available to spend; it is not. | M1.7 relabel, M2.3 (D6) |
| 4 | **G1 / G2.** "Owed to me" and "I owe" have two values under the same label. The Finance card adds marketplace money (including undelivered pay-now checkouts) that its drilldown never shows. | `finance.py:finance_summary`; `ops/app/(ops)/finance/page.tsx` against `finance/debts/page.tsx` | The headline cannot be explained or chased. Commitments are counted as debts. | M1.7 (D2, D7) |
| 5 | **G4 / G10.** A disputed payout (paid, "not received") is in no payable figure. A resend overwrites the first payment, and "Paid to date" counts it as paid. | `main.py:pay_settlement`, `ops_settlements` | Double-payment exposure is invisible. | M2.7 (D9) |
| 6 | **G11 / G28 / G12.** Three definitions of "sales": Finance and Sales are direct only, Profit is direct plus delivered marketplace orders, Manage is marketplace orders created including undelivered. | `finance.py:_sold`, `_sales_summary`, `profit_between`; `main.py:ops_dashboard` | The same month shows different sales on different pages. Profit cannot be traced to a sales list. | M1.7 (D2) |
| 7 | **G21.** Marketplace revenue and cost are dated by order creation, not delivery. | `finance.py:_order_day`, `profit_between` | Past months change after delivery; revenue lands in the wrong period. | M2.5 (D2 decided; D7 pending) |
| 8 | **G29 / G32 / G31.** Supplier owed has three scopes: Supplier payments (ledger only), Suppliers list (ledger plus pending settlements, "Paid" ledger only) and statement (ledger only). | `finance.py:supplier_balances`, `supplier_statement`; `main.py:_supplier_activity` | The same supplier shows different balances, which disputes and the portal will expose. | M1.7, 0.5 harness |
| 9 | **G14 / G15.** Sales "I owe suppliers" includes sale-linked expenses and leaves out delivery-note and LPO payables. | `finance.py:_sales_summary`, `sale_view` | A zero supplier balance on a sale does not mean the stock is paid for. | M2.4, M1.7 |
| 10 | **G6.** Debts "Overdue" adds receivables and payables together. | `ops/app/(ops)/finance/debts/page.tsx` | A meaningless figure on a collections and payments screen. | M1.7 |
| 11 | **G18 / G9.** No marketplace money in the cash book. Marketplace receipts have no date or method, and pay-now receipts have no receipt row. | `finance.py:_cash_totals`, `finance_summary.by_method`; `main.py:reconcile`, `apply_provider_confirmation` | Money in is understated, and app income cannot be reconciled. | M1.2 (buyer receipts), M1.7, M2.3 |
| 12 | **G24 / G25 / G27.** The expenses total overwrites the row count, ignores search and status, and the Profit "Expenses" card adds stock lost while linking to a page without it. | `finance.py:expenses`; `ops/app/(ops)/finance/profit/page.tsx` | Paging is broken and the totals do not match between pages. | M1.1 |
| 13 | **G13.** "Cash received" counts every payment method. Sales "Received" includes payments after the period. | `finance.py:_paid`, `_sales_summary` | Misleading labels; the two "received" figures never match. | M1.7 |
| 14 | **G22.** Marketplace cost uses the ordered quantity when an item has no accepted quantity, while the settlement uses the order's accepted quantity. Cost is rounded per day. | `finance.py:profit_between`; `services.py:advance` | Cost can differ from the payable for the same order. | M1.7 |
| 15 | **G34 / G35 / G36.** Batch figures do not add up when birds are reserved. Direct batch sales bypass a receipt. Delivery-note stock has no loss, return or cancellation path. | `batch_stock.py:batch_breakdown`, `take_from_batch`, `return_to_batch` | Stock and supplier payable can disagree, and declared stock reads like stock on hand. | M1.6, M2.1 |
| 16 | **G33.** "Birds bought" adds kg and birds and leaves out LPO receipts. | `main.py:_supplier_activity` | A wrong supplier volume figure. | M2.1 |
| 17 | **G8.** The marketplace overview excludes cancelled and failed orders, but the Payments *outstanding* tab includes them. | `finance.py:finance_summary` against `paging.py:PAYMENTS` | Small differences that are hard to explain. | M1.7 |
| 18 | Day boundaries and display: `ops_summary` uses a UTC midnight day. The UI truncates instead of rounding, and several cards add money in the browser with floating point. | `main.py:_today_range`; `ops/lib/format.ts:money`; Debts, Profit and Finance pages | Off-by-one-day and off-by-a-cent differences against the drilldowns. | M1.7 conventions |

## Sign-off

| Role | Name | Date | Decision |
|---|---|---|---|
| Finance owner (D1) | Maternus Joshua | | Approve / approve with changes |
| Engineering | | | |

Open item before sign-off: **D7**, the exact recognition event for marketplace orders. The proposed default is `delivered`, dated the day the order reached `delivered` in EAT. Every target above that mentions marketplace revenue, cost, receivables or commitments depends on it.
