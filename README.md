# Omoterra

First delivery of the V1 Flutter mobile app and FastAPI/PostgreSQL backend. The architecture proposal, navigation, domain contracts, design tokens and implementation phases are in [docs/implementation.md](docs/implementation.md).

## Run the backend

Requires Python 3.9+ and PostgreSQL 16+.

```bash
cd backend
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.lock
cp .env.example .env
# Configure the database URL and operator secret in .env.
python -m app.manage
uvicorn app.main:app --reload --host 0.0.0.0
```

The explicit development initializer creates the current schema; it is not run during API startup. For a new database, use that initializer or apply migrations `001_initial.sql` through `004_supplier_onboarding.sql` in order. For an existing database already at migration 003, first back up the database, then apply `004_supplier_onboarding.sql`; it adds supplier fields in place, backfills region/category/status from current account and listing data, and preserves existing supplier and batch records. If the database is at migrations 001 and 002, apply migration 003 first, then 004. Do not apply migrations 003 or 004 to a new database already created with the updated initializer. Apply the migration before deploying the API version that reads the new supplier fields.

Docker alternative, from this directory:

```bash
export OMOTERRA_OPS_TOKEN="$(openssl rand -hex 32)"
docker compose up -d --build
# Once the database is healthy:
docker compose exec api python -m app.manage
```

API documentation: `http://localhost:8000/docs`. All mobile endpoints are under `/api/v1`. Development OTPs are returned in the challenge response and visibly identified as development codes in the app. No default user, stock or successful payments are silently created.

## Run Android

```bash
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define=API_BASE_URL=https://omoterra.jopex.co.tz/api/v1
```

The URL above is for an Android emulator. A physical device needs a reachable development machine address. Production URLs are never compiled as defaults. Cleartext traffic is allowed only in the debug Android manifest. The read-only local repository is available through `LOCAL_PREVIEW=true` for isolated widget development; it cannot authenticate or transact.

## Implemented

- Riverpod, GoRouter role guards, Dio repository boundary, secure sessions, generated immutable buyer API models, bundled Manrope and Material 3 design tokens.
- Phone/OTP setup; buyer/supplier capabilities; profile, language preference and delivery-address management.
- Fresh inventory browsing, listing details, individually tracked checkout holds, one-listing orders, order tracking and cancellation API.
- Supplier setup on first stock submission, category-specific stock wizard, review boundary, separate stock corrections, receipts, sales history/reversals, reconfirmation, collection views and payouts.
- Buyer CRM and recurring demand, supplier production batches and offers, reviewed multi-supplier allocations, collection verification, and conversion into the existing pay-on-delivery order and settlement pipeline.
- Photo uploads with metadata removal, owner checks and approval-gated buyer visibility; ops-only collection evidence.
- Partial-payment receipts and supplier settlement reconciliation with persistent references.
- PostgreSQL transaction/advisory locks plus inventory constraints, scoped retry keys, price/payout snapshots, explicit customer status mapping, exact reservation release and settlement linkage.
- Operator dashboard for demand, batch verification, buyer CRM, multi-supplier sourcing, fulfillment progress, payment reconciliation, and supplier settlement.
- Fail-closed payment provider boundary and callback verification seam. Pay on Delivery is the only enabled checkout method.

## Verify

```bash
cd backend
# Use a disposable UTF-8 PostgreSQL database; tests create and remove their own isolated schema.
OMOTERRA_TEST_DATABASE_URL=postgresql+psycopg://USER:PASSWORD@localhost/DATABASE pytest -q
cd ../mobile
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=https://omoterra.jopex.co.tz/api/v1
```

See [docs/delivery-status.md](docs/delivery-status.md) for measured verification and remaining pilot work. This delivery is not production-ready; production startup is intentionally blocked until the missing integrations are implemented.

## Local browser preview

The optional web target serves the same Flutter app for local inspection without an Android emulator. Build it, initialize a local database as above, then serve the frontend and API from the same origin:

```bash
cd mobile
flutter build web --no-web-resources-cdn --dart-define=API_BASE_URL=http://localhost:8080/api/v1
cd ../backend
# Set OMOTERRA_DATABASE_URL for your local database.
.venv/bin/uvicorn app.dev:app --host 127.0.0.1 --port 8080
```

Open `http://localhost:8080`. `app.dev` is development-only. Signup displays the development verification code; it does not send an SMS. New local databases contain no listings until a supplier submits stock and an operator approves it.

The current local testing account and updated screen walkthrough are documented in [docs/stock-history.md](docs/stock-history.md). To reuse the existing API on port 8010 and its uploaded images, start the preview with `OMOTERRA_DEV_API_UPSTREAM=http://127.0.0.1:8010`.
