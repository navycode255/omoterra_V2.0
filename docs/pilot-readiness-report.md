# Omoterra pilot-readiness report

**Prepared:** 23 September 2026  
**Decision:** **Not ready for an unsupervised public pilot.** A small, invited, staff-supervised pilot can be considered after the must-pass checks below, using manual cash-on-delivery and clear disclosure that OTP is in development mode. No software deployment can guarantee that nothing will go wrong; the goal is to limit exposure, catch failures quickly, and have a recovery plan.

## What the app does today

Omoterra is a Flutter Android marketplace backed by a FastAPI service and PostgreSQL. The mobile app is a client of the API; business records and transaction rules belong on the server/database. The operations dashboard is a separate web application and is required for important fulfillment work.

- **Sign-in and accounts:** phone-number OTP; profile, region and language preference; buyer and supplier capabilities. A new account can select one or both capabilities. In the current workspace, changing to a missing capability starts a registration flow, and the backend adds it only after the required details are submitted. Switching between already registered roles is supported.
- **Buyer:** browse currently available, approved stock; reserve a quantity for checkout; select a saved delivery address and requested date; place an order using Pay on Delivery; view order status and cancel when the backend allows it. Buyers can also submit supply requests and business-opportunity leads.
- **Supplier:** submit stock and photos, maintain inventory, record additions/corrections/external sales, and view orders and payouts. Stock is not visible to buyers until an operator reviews and approves it. Suppliers must provide private legal and pickup details.
- **Omoterra operations:** approve or reject listings and set public prices; coordinate order pickup, quality checks and delivery; record cash receipts; reconcile supplier settlements; and follow up on sourcing/business requests. Delivery completion and payment reconciliation are separate steps. Supplier payouts are recorded by an operator; the app does not transfer money.
- **Database safeguards:** the backend uses PostgreSQL transactions and inventory locking, time-limited checkout holds, idempotency keys for important writes, and server-side status transitions. The documented defaults are 15-minute holds and stock reconfirmation every 48 hours.

See [operator workflow](operator-workflow.md) for the detailed manual process.

## What is not ready for production use

1. **OTP is not private or production authentication yet.** The API is configured for development SMS and returns the verification code in its response; the app displays it. No SMS is sent. Anyone with access to the app response can see the code. Do not treat this as production-grade identity verification or use it for an open public launch.
2. **Online payments are not available.** Only Pay on Delivery is enabled. There is no live mobile-money/card payment integration, verified provider callback, or automatic refund process. Do not advertise Pay Now or collect payment credentials.
3. **Fulfillment requires active staff.** The app does not dispatch drivers, automatically contact parties, or move orders through delivery. Operators must use the dashboard/API and complete each status, receipt and settlement step. There is no real-time push update; users see changes when they refresh/reopen the relevant screen.
4. **Legal/support details need real values.** The API configuration previously checked for the hosted service reported empty support phone, terms and privacy text. Supply approved contact information and policies before onboarding real customers.
5. **Language coverage is incomplete.** Language selection now comes before registration and persists, but much of the app copy is still English. Review and complete Swahili translation before positioning this as a fully localized Tanzania pilot.
6. **Deployment state is not the same as workspace state.** The account-role endpoint and app changes in this workspace must be deployed/rebuilt before the live app can use them. Earlier checks showed the hosted API health/config endpoints responding, but the config reported `environment: development`. Recheck the actual server after deployment.
7. **Operational security and continuity must be verified.** The operations setup uses a shared token/passphrase rather than individual operator accounts, so per-person auditability is limited. Restrict operator access, protect secrets, confirm HTTPS, and verify database and uploaded-media backups plus a restore procedure. The media implementation uses filesystem storage; confirm that this host's media directory is durable and included in backups.

Other V1 limits documented by the project include one-listing sourcing conversion, no sourcing allocation workspace, no pagination beyond the fetched listing page, and no automated refunds.

## Must-pass checklist before inviting pilot buyers/suppliers

### 1. Confirm the release that will actually run

- Deploy the current backend code, including `POST /api/v1/account/register-role`, then restart the service.
- Build and install a fresh Android build with the production API base URL. Do not use `LOCAL_PREVIEW` or an old debug APK for the pilot.
- From the installed app/device, verify the configured API host is reachable over HTTPS. On the server, check `/health` and `/api/v1/config`; record the response and confirm it matches the intended pilot mode.
- Confirm the deployed database is PostgreSQL, the schema/migrations are current, and the API process uses the intended database. Never test with production customer records as seed data.

### 2. Decide and disclose the pilot authentication/payment model

- If the SMS provider is not integrated, keep the pilot invite-only and staff-supervised, and tell participants the OTP is a development code displayed in the app. Do not describe it as an SMS verification sent to their phone.
- Keep Pay on Delivery as the only payment method. Define who receives cash, when staff records it, how the buyer gets a receipt, and who resolves a mismatch.
- Do not set the backend to live mode merely to hide the development code: production startup is intended to fail until the required secret and operator token are set, and the SMS adapter itself is not implemented.

### 3. Validate a complete happy path with test accounts

Use a controlled test listing and test participants, and have an operator present:

1. Choose English and Swahili before signup; complete buyer-only signup, supplier-only signup, and one account with both roles.
2. From a single-role account, attempt the other role. Confirm it asks for registration details, does not silently grant access, and only switches after backend success.
3. Complete supplier pickup details; submit stock and photos; verify it remains hidden from buyers until approved.
4. Approve the listing with a public alias and explicit buyer/payout prices. Verify the buyer cannot see the supplier's legal name or private pickup address.
5. As buyer, create/select an address, reserve a valid quantity, complete checkout before the hold expires, and confirm the order appears for buyer, supplier and operator.
6. As operator, move the order through the documented sequence. At quality check, verify accepted plus rejected quantity equals the reserved quantity. At delivery, verify accepted quantity is sold, rejected quantity returns to stock, the buyer total uses accepted quantity, and exactly one settlement is created.
7. Record one or more cash receipts; verify partial payment cannot complete the order, duplicate references/overpayment are rejected, and completion is allowed only when paid in full. Record supplier payout only after it is actually made.
8. Test expired holds, duplicate retries, unavailable stock, cancellation, invalid status changes, network interruption/retry, and a failed photo upload. Confirm errors are clear and no duplicate order/receipt is created.
9. Repeat the full path once on a physical Android phone using mobile data and once on Wi-Fi. Verify the app can recover after closing/reopening and that the greeting disappears at two minutes after sign-in.

### 4. Prepare people and recovery

- Name a pilot lead, one operator responsible for listing review, one order/fulfillment owner, and a support contact. Have a backup person who can cover each critical role.
- Set daily order and supplier capacity limits. Start with a small participant list and a small number of approved listings.
- Agree how buyers/suppliers report a problem, how quickly staff responds, how an order is paused/cancelled, and how cash discrepancies are handled.
- Take a database backup and media backup before the pilot; test restoring them to a separate environment. Keep a simple incident log and review unresolved orders/payments daily.

## Verification performed for this report

The current workspace passed Flutter static analysis and the full Flutter test suite (**71 tests passed**). Backend Python files compile. Backend pytest could not be run in this environment because pytest is not installed in the active Python environment; PostgreSQL integration tests and a live end-to-end deployment test were not run here. The project documentation records earlier PostgreSQL integration coverage, but that is not a substitute for testing the current deployed server/database.

## Pilot recommendation

Proceed only as a **closed, supervised Pay-on-Delivery pilot** after the release, security, backup/restore and full-order checks above pass. Keep staff available to manually manage every fulfillment step. Pause onboarding and new orders if OTP access, stock balances, order status, receipts, privacy, or database/media availability behave unexpectedly. For an open or unsupervised pilot, first integrate and verify real SMS delivery, strengthen operator access/auditing, complete support/legal information and Swahili copy, and perform the backend integration tests against a disposable PostgreSQL database.
