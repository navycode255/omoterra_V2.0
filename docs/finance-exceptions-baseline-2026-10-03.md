# Finance exception baseline: production, 3 October 2026

Read-only queries equivalent to `python -m app.finance_exceptions` (M0.3), run against the production Neon database (project `still-sea-18164761`). Nothing was changed.

| # | Check | Count | Amount (TZS) | Notes |
|---|---|---|---|---|
| 1 | Active sale lines with no known cost | 1 | 21,000 revenue | SL-837D20E3: 3 complimentary birds from Antonia. Candidate for `free` (M1.3). |
| 2 | Registered-supplier lines with no batch, receipt or LPO | 11 | 1,040,000 cost | Antonia and Awonyisa sales from before batch linking. Fix by an approved link (M1.6 dry run). |
| 2b | Unregistered named-supplier cost lines (context) | 18 | 1,976,800 cost | Mostly "Tegeta Sokoni". Not an exception. |
| 3 | Reversed allocations of supplier transfers | 1 | 19,500 | Antonia's 27 Sep transfer of 650,000 |
| 4 | Transfers not fully allocated | 1 | 19,500 | Same transfer: 630,500 allocated. Under D5 it becomes supplier credit (M1.2 classification). |
| 5 | Settlements not received or paid more than once | 0 | 0 | |
| 7 | Batches with no movement for more than 7 days | 0 | 0 | |
| 8 | Supplier-cost debts cancelled with a reason | 1 | 19,500 | "Tegeta Sokoni" line on SL-837D20E3 (sale edited) |

Payments by method, active (context): received in cash 2,760,000 (27 payments); paid out in cash 2,238,100 (33), bank transfer 650,000 (8 allocations of 1 transfer), M-Pesa 325,000 (3).
