# Omoterra Operations Dashboard

Public Omoterra website and protected operations dashboard for Omoterra staff. It consumes the same
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

## Production configuration

Deploy this Next.js app at `https://omoterra.jopex.co.tz`. The public landing page is `/`; operators sign in at `/sign-in` and manage the platform at `/manage`. Configure these
values in the hosting provider's server environment, not in browser-side
variables:

```dotenv
OMOTERRA_API_URL=https://omoterra.jopex.co.tz/api/v1
OMOTERRA_APP_URL=https://omoterra.jopex.co.tz
OMOTERRA_OPS_TOKEN=<same value as the backend>
```

Admins register from the sign-in screen: **Admin setup** asks for the setup
passphrase (`OMOTERRA_ADMIN_SETUP_PASSPHRASE` in the backend `.env`), then, if an
admin already exists, that admin's phone code, then the new admin's own phone
code. Admins add everyone else from **Team → Staff**. See the backend's
`CPANEL_API_DEPLOYMENT.md` (step 5).

After deployment, verify that `https://omoterra.jopex.co.tz/health` responds
successfully, then build and start the dashboard:

```bash
npm run build
npm run start
```

For the current cPanel host, the backend already uses port `8011` and the public domain. The included `.htaccess` routes `/api/*` and `/health` to FastAPI on `127.0.0.1:8011`, then routes website and operations pages to Next.js on `127.0.0.1:3000`. Install this combined file in the domain document root only when the Next.js process is ready; do not layer it with the backend catch-all `.htaccess`. The host must allow `mod_rewrite`, `mod_proxy`, and `mod_proxy_http`. If cPanel manages Node directly, configure equivalent path routing with Passenger instead.

The homepage is public. Dashboard routes remain protected by the operator session. The dashboard calls the backend from Next.js server code and adds the
`X-Ops-Token` header there. Do not rename these to `NEXT_PUBLIC_*` variables:
the operations token must never be sent to the browser.

## Configuration

| Variable | Purpose |
| --- | --- |
| `OMOTERRA_API_URL` | Base URL of the backend, including `/api/v1` |
| `OMOTERRA_OPS_TOKEN` | The dashboard server's backend credential; must match the backend |

## How access works

Each operator has their own account. They sign in with their phone number and a
one-time code; the backend issues them a session token, kept in an HTTP-only
cookie. Every backend call carries two headers, both added in `lib/api.ts`
(`server-only`): `X-Ops-Token`, the dashboard server's own credential, which
never reaches the browser, and `X-Operator-Session`, which identifies the person.
Every page and every Server Action calls `requireSession()` independently,
because Server Actions are reachable by direct POST regardless of which page
rendered the form.

Admins additionally manage staff and record supplier payouts. Every change is
written to an audit trail (Team → Activity) in the same transaction as the
change itself, and supplier approvals and suspensions are recorded under the
operator's name. Removing someone signs them out immediately.

Listing and collection photos are ops-authenticated on the backend, so they are
proxied through `/media/[id]`, which also requires a dashboard session.

Deployment should still place the backend's `/ops/*` routes behind restricted
network access where the host allows it.

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
