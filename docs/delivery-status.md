# Delivery status

This is a functional development implementation of the first V1 delivery, not a pilot-release claim.

## Delivered

The architecture proposal was written before implementation. The Flutter Android project includes the requested foundation and principal buyer/supplier flows, secure session storage, role-aware routing, generated buyer domain models, the specified visual palette, bundled Manrope, and repository-mediated networking. Stock and reference photos upload through the backend; metadata is removed and access is owner/approval scoped. The backend includes the complete requested entity schema, an initial SQL migration, operator endpoints, and transactionally enforced inventory/payment/settlement logic.

Pricing uses Decimal on the server and decimal strings across the API. Buyer totals use immutable order-item unit-price snapshots. Supplier settlements use accepted quantity and the payout snapshot, with commission subtracted only once. Partial-payment receipts have independent references and are retained in an audit table. Public and private response shapes are separate explicit allowlists.

Reservations are individually tracked. PostgreSQL transaction-scoped advisory locking serializes commerce mutations; row locks and database constraints add protection. This intentionally serializes more work than a high-throughput system would, appropriate for the initial operator-managed volume. Expiry is evaluated during related reads and writes; no scheduler runs. Stale supply is filtered in SQL before buyer serialization. Confirmed order holds do not expire.

## Verification

Latest measured results: **28 PostgreSQL tests passed; 5 Flutter tests passed; Flutter analysis clean; debug Android APK built.**

- PostgreSQL integration coverage: concurrent oversell prevention, hold expiry/release, order retry conflicts, immutable prices, cancellation/payment failure, accepted-quantity settlement math, role and address isolation, stock freshness, OTP attempt persistence/single use, media metadata/authorization, sourcing conversion, partial receipts, operator collection-photo privacy and stock approval.
- Flutter: role-guard and model tests, read-only fixture transaction rejection, small-screen/enlarged-text usability, cancellation tracker; static analysis and debug Android compilation.
- Android debug artifact: `mobile/build/app/outputs/flutter-apk/app-debug.apk`, compiled with emulator API URL `http://10.0.2.2:8000/api/v1`. It requires the running backend. No demo stock or successful transactions are manufactured.
- No physical-device/end-to-end network acceptance or live provider payment has been performed. No production deployment was attempted.

## Remaining before a pilot release

1. **SMS authentication:** implement the chosen delivery provider, production abuse/rate controls and operational monitoring. Development OTP returns the code explicitly. Production startup is deliberately blocked.
2. **Payments:** choose and integrate a real provider before enabling Pay Now. Callback processing has a verified-provider seam and idempotency tests; the HTTP webhook currently rejects callbacks because no real verifier is configured. Pay on Delivery is implemented, including operator receipt reconciliation. Automated refunds are not implemented.
3. **Deployment:** provision PostgreSQL/backups, HTTPS, secrets, durable media storage and restricted operator access. Local media storage is implemented with a Docker volume, not a configured managed storage service. Configure release signing; debug signing is not used for release builds.
4. **Product copy:** supply Omoterra's actual support contact, terms and privacy text through configuration. No legal policies or contact details were invented.
5. **Localization and UX acceptance:** language preference and locale scaffolding exist, but application copy remains English. Complete reviewed Swahili translations, broader device/accessibility checks and final visual polish. Some supplementary API payloads still use repository-owned JSON maps rather than generated Dart models.
6. **Scope limits to review:** sourcing conversion currently uses one listing; allocation tables exist without allocation UI. Explore filters operate on the fetched supply page (50 by default); pagination is not implemented. Orders refresh when reopened or via list refresh, not realtime push. Quantity confirmation creates a server hold; merely typing an unfinished quantity does not send repeated holds.

The separate Ops web dashboard is not included in this mobile/backend task. [operator-workflow.md](operator-workflow.md) documents the existing backend operator workflow.
