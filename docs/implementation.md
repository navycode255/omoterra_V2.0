# Omoterra V1 delivery plan

## Project structure
`backend/app/`: configuration, SQLAlchemy domain tables, Pydantic contracts, authentication, transactional commerce services, payment provider boundary and FastAPI routes. `backend/tests/`: accounting, isolation, freshness, idempotency and PostgreSQL concurrency tests.

`mobile/lib/app/`: composition. `core/{api,auth,errors,routing,theme,utils}/`: Dio client, secure session, error translation, GoRouter guards, tokens and formatting. `features/{authentication,buyer,supplier,account}/`: repository-backed screens. `shared/{models,widgets}/`: immutable API contracts and shared presentation. No networking in widgets.

## Navigation
`/welcome → /phone → /otp → /setup`; setup collects roles, buyer type, name, region and language. Authenticated role switch selects `/buyer` or `/supplier`.

Buyer shell: `/buyer`, `/explore`, `/orders`, `/account`. Detail routes: `/listing/:id → /checkout/:reservationId → /order/:id`; `/request → /requests/:id`; `/business → /business/:type → /business/:type/request`; `/addresses`.

Supplier shell: `/supplier`, `/stock`, `/supplier-orders`, `/account`. Detail routes: `/stock/new`, `/stock/:id`, `/supplier-orders/:id`, `/payouts`, `/payouts/:id`. Availability confirmation is a bottom sheet. Agent/admin have no mobile routes.

## Domain and public contracts
Persist User, SupplierProfile, Address, Listing, StockReservation, Order, OrderItem, SourcingRequest, SourcingRequestAllocation (schema only), Settlement, Payment and BusinessOpportunity. Add OTP challenges and revocable sessions, idempotency records, and order activity where needed for correctness. Money uses decimal database columns and decimal JSON strings; quantities use decimal with whole-unit validation for birds/animals.

Separate buyer listing/order contracts from supplier stock/reservation/payout contracts. Never serialize ORM objects directly. Buyer listing cards exclude supplier identity; detail exposes only approved alias and region. Supplier contracts exclude buyer identifiers, addresses and buyer pricing. Order status is mapped server-side.

## Design tokens
Forest #123D2D; pressed #0B2E21; soft #EEF5F0; pale #F5F8F6; background #FAFBF9; text #17201B; secondary #657069; muted #909A94; border #E3E9E5; positive #267A52; warning #B87822; error #B94747. Manrope, 8pt spacing, 20px page inset, 16px cards, 14px fields, 54px buttons. Material 3 with subtle status text, content-shaped loading placeholders, accessible labels and reduced-motion transitions.

## API boundaries and assumptions
Versioned REST `/api/v1`; opaque bearer sessions stored securely. OTP length, TTL, resend interval, freshness interval and reservation TTL are environment-configured. Local OTP delivery is explicitly development-only; production startup must reject development authentication/payment providers. Production integrations require credentials and provider-specific signature verification before launch.

All commerce writes are server-authoritative. PostgreSQL row locks serialize inventory changes, database checks enforce nonnegative inventory, unique idempotency records prevent duplicate operations. Active holds become confirmed holds linked to one order; confirmed quantities remain reserved until fulfilment completes. Cancellation/payment failure releases those exact holds; delivery moves reserved to sold once. Request conversions use the same service. Settlement quantity uses accepted quantity, with asking/payout snapshots captured at order time.

No scheduler: expire relevant active holds and hide stale listings during reads and checkout. Confirmed order holds do not expire. Supplier reconfirmation cannot approve pending/rejected stock. Existing holds cannot buy stale/paused stock. Saved addresses are owner-scoped; orders retain a delivery snapshot so editing/deleting an address cannot change fulfilment.

Ops endpoints are backend-only, separately authenticated with a configured secret for the initial operator; no dashboard is included. Ops explicitly supplies buyer pricing, reconciles delivery payments, manages fulfilment and settlements. Production deployment should put these endpoints behind restricted network access. SMS/payment vendors are not specified: expose clear boundaries and never pretend payments succeeded. Media uses configurable local storage with authenticated reads, image re-encoding and owner checks; deployment must provide durable storage. Initial mobile development may use an explicitly selected read-only fixture repository; transactional actions require a live API.

## Implementation phases
1. Foundation: contracts, database schema, theme, HTTP/session/routing and shared UI.
2. Authentication: phone OTP, onboarding and capabilities.
3. Buyer commerce: fresh inventory, holds, checkout, idempotent orders and tracking.
4. Sourcing: independent request submission/detail and ops conversion.
5. Supplier: profile, stock review/freshness, collection views and payouts.
6. Business: static guides and authenticated setup-plan leads.
7. Verification/polish: critical PostgreSQL tests, Flutter analysis/tests, failure handling, accessibility and integration readiness documentation.

Pilot release requires real OTP delivery, durable media storage, device verification and operator acceptance. Pay Now additionally requires a real payment adapter; Pay on Delivery can remain the sole enabled method. PostgreSQL integration tests are part of the delivery checks. A scaffold or passing unit suite alone is not release approval.
