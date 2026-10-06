# Dashboard end-to-end tests (Playwright)

One command from `ops/`:

```sh
npm run test:e2e
```

It starts everything itself and stops it afterwards:

1. **Backend**: `e2e/harness.py serve` drops and recreates the database in
   `OMOTERRA_E2E_DATABASE_URL` (default
   `postgresql+psycopg://omoterra:omoterra@localhost:55432/omoterra_e2e`, the
   local docker Postgres), builds the schema from the models and runs
   `uvicorn app.main:app` on port 18765. It refuses any database that is not
   local or whose name does not contain `e2e`, and pins SMS, push, payments
   and media storage to their offline settings.
2. **Dashboard**: `next build` then `next start` on port 13765, with
   `OMOTERRA_API_URL` and `OMOTERRA_OPS_TOKEN` pointing at that backend (they
   override `.env.local`). Webpack is used because Turbopack fails on the
   symlinked `node_modules` here.
3. **Tests** (one worker): each test empties every table and signs in an admin
   operator straight in the database (`harness.py seed`), sets the
   `omoterra_operator` cookie, records its data through the real `/ops` API
   and checks the screens.

| Spec | Checks |
|---|---|
| `debts-pagination.spec.ts` | M0.4 / F13: 66 debts, 18 open, 10 a page: 7 pages on Finance > Debts, every debt once, open ones first. |
| `supplier-statement.spec.ts` | M0.5 + M1.6: a delivery note, a sale from the supplier's batch (confirmed collection: a same-day delivery note), a transfer, then a return to the supplier whose credit note is recorded on the delivery-note page; the staff supplier page ("Money with this supplier"), the Supplier payments row, the Suppliers list and the supplier's own portal (Payouts) show the same bought / paid / owed. |
| `batch-sale.spec.ts` | M1.6 / F09: on New sale, a line from a supplier batch needs "We collected these 20 birds from … on …" ticked; saving records a same-day delivery note (no sale-cost debt); cancelling asks what happened to the goods, and "never left" puts the 20 back on hand on the note while its payable stays. |
| `cost-states.spec.ts` | M1.3 / F02: a sale of own stock with "Cost unknown" makes Profit show "Provisional: buying costs incomplete" with 1 sale affected; opening stock recorded on Finance → Opening stock and sold from on New sale gives a known margin (20,000); giving the unknown line a cost from that opening stock on its sale page makes Profit show its figure again. |
| `debt-corrections.spec.ts` | M1.4 / F06: a sale's supplier debt shows the four reasoned corrections; "Wrong supplier" on 100,000 with 40,000 paid leaves the correct supplier owed 100,000, the wrong one holding 40,000 credit, and the buying cost unchanged; both debts link to the correction. |
| `payout-attempts.spec.ts` | M2.7 / F12 (D9): a payout sent (not money out), marked debited, reported not received by the supplier on the portal, resent after a second admin's approval (the requester cannot approve), then part refunded: net paid 44,000, possibly paid twice 17,000, both outflows and the refund on the cash book. Uses `harness.py seed payout`. |

Needs: a running Postgres the user can create databases on, the backend
virtualenv (`backend/.venv`, or set `OMOTERRA_E2E_PYTHON`), and Chromium for
Playwright (`npx playwright install chromium` once).

Useful settings:

- `OMOTERRA_E2E_SKIP_BUILD=1` reuses the last `next build` (fast reruns).
- `OMOTERRA_E2E_API_PORT`, `OMOTERRA_E2E_WEB_PORT` change the ports.
- `npx playwright test e2e/debts-pagination.spec.ts` runs one spec;
  `npx playwright show-trace test-results/.../trace.zip` opens a failure trace.

CI (`.github/workflows/ci.yml`) runs the same command against a PostgreSQL
service. Later finance milestones extend `supplier-statement.spec.ts` with
their own events (refunds, credit notes, returns) and the figures that must
agree.
