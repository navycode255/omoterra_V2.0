# Omoterra Operations Dashboard

Internal web dashboard for Omoterra admin/operations staff. It consumes the same
FastAPI backend and PostgreSQL database as the mobile app and holds no business
logic or database of its own.

## Running locally

The backend must be running first:

```bash
cd ..
OMOTERRA_OPS_TOKEN=devtoken123 docker compose up -d db api
docker compose exec api python -m app.manage   # first run only, creates the schema
```

Then:

```bash
cp .env.example .env.local   # fill in the values
npm install
npm run dev
```

## Configuration

| Variable | Purpose |
| --- | --- |
| `OMOTERRA_API_URL` | Base URL of the backend, including `/api/v1` |
| `OMOTERRA_OPS_TOKEN` | Shared operations secret; must match the backend |
| `OMOTERRA_DASHBOARD_PASSPHRASE` | What operators type to sign in |
| `OMOTERRA_DASHBOARD_SECRET` | Random string signing the session cookie |

## How access works

The backend authenticates operations requests with a single shared
`X-Ops-Token` header rather than per-user accounts. That token is read from the
server environment and attached in `lib/api.ts`, which is `server-only` — it is
never sent to the browser and never appears in a client bundle.

Operators sign in with a passphrase, which mints an HTTP-only, signed session
cookie. Every page and every Server Action calls `requireSession()` independently,
because Server Actions are reachable by direct POST regardless of which page
rendered the form.

Listing and collection photos are ops-authenticated on the backend, so they are
proxied through `/media/[id]`, which also requires a dashboard session.

Because access is a shared passphrase rather than individual accounts, the
backend records no per-operator audit trail. Deployment should place both the
backend's `/ops/*` routes and this dashboard behind restricted network access.

## Boundaries this dashboard respects

- Every write goes through the backend's own endpoints, so reservation release,
  transaction locking and idempotency stay server-side. Nothing writes to the
  database directly.
- `customer_status` is never set here. It is derived by the backend from
  `internal_status`, and is shown read-only so operators can see what the buyer
  sees.
- Status transitions offered in the UI mirror the backend's `TRANSITIONS` table.
  The server remains the authority and rejects anything invalid.
- Buyer addresses and identity are shown for delivery coordination but are never
  exposed to suppliers. Supplier legal names and pickup addresses are never
  exposed to buyers.
- Commission is deliberately visible on Settlements and supplier detail — those
  and the supplier's own mobile payout screen are the only places it appears.

## Not built (Phase 2)

Operations Board, Agents module, Sourcing Allocation Workspace, Reports and
Settings are intentionally absent. Sourcing uses a plain list with a manually
maintained `quantity_secured`; conversion draws on a single listing.
