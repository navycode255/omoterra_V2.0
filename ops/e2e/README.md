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
2. **Dashboard**: `next build --webpack` then `next start` on port 13765, with
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
| `supplier-statement.spec.ts` | M0.5: a delivery note, a sale costed from the supplier's batch and a transfer; the staff supplier page ("Money with this supplier"), the Supplier payments row, the Suppliers list and the supplier's own portal (Payouts) show the same bought / paid / owed. |

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
