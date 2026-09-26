# Plan: high-priority usability gaps

Status: **all four phases built, not yet deployed** (written 2026-09-25, built 2026-09-26;
Swahili copy awaits native review; see each phase's status block). Each phase ships on its own.

These four gaps came out of the usability review. Each one affects every user
as soon as real volume arrives. Order of work: **4 → 3 → 2 → 1**. The media move
(4) goes first because the R2 buckets are being created now and it changes how
photos load everywhere; the dashboard paging (3) protects money and is small;
search (2) and Swahili (1) touch the most screens and are done last so they
build on the final shape of those screens.

| # | Gap | Who it hurts | Size |
|---|-----|--------------|------|
| 4 | Photos re-download on every view; 60 MB video uploads can't resume | Rural buyers and suppliers on mobile data | Large |
| 3 | Dashboard lists cut off at the newest 100 | Operations, and suppliers waiting on payouts | Medium |
| 2 | Search only matches the English category name | Buyers | Medium |
| 1 | Most screens and all server messages are English only | Swahili-speaking suppliers and buyers | Large |

---

## Phase 4 — Media on Cloudflare R2

**Status: built, not deployed (2026-09-26).** Code and tests are in place;
switching production to R2 waits on the bucket settings and credentials.
- Done: settings and validation, `app/storage.py` (`LocalStorage` /
  `R2Storage`, `python -m app.storage check|migrate` — the migrate command
  lives there rather than in `app.media`), signed `{url, expires_at}` from
  `GET /media/{id}` and `GET /ops/media/{id}` (LocalStorage signs an HMAC link
  to `/media/local/…`), resumable video upload (`POST /media/video/uploads`,
  `GET …/uploads/{id}`, `POST …/{id}/parts`, `POST …/{id}/complete`,
  `POST /media/video/confirm`; migration 016 `media_uploads`), dashboard
  proxy following the link, app disk cache by media id with permission
  re-checked on every view, 5 MB part upload with per-part retry and a
  Resume button.
- Photos still upload through the API (for the EXIF/GPS strip); only videos
  go straight to the bucket.
- Left to do: bucket settings in the Cloudflare dashboard and
  `OMOTERRA_R2_*` on cPanel (CPANEL_API_DEPLOYMENT.md §4), then `check`,
  `migrate`, switch `OMOTERRA_MEDIA_STORAGE=r2`, and the two "Done when"
  checks on a real phone (open a listing twice; toggle data mid-upload).
  The R2 tests run against a moto mock, not a real bucket.

### Today
- Photos and videos are files in `OMOTERRA_MEDIA_DIRECTORY` on the cPanel
  server (`backend/app/media.py`), served by `GET /media/{id}` after a
  per-request permission check (owner, or a buyer viewing a live listing).
- The app never stores private photos on the phone (`ProductImage` in
  `mobile/lib/shared/widgets/components.dart` uses memory only), so every
  screen visit downloads them again.
- Video uploads go through the API in one request; a dropped connection
  restarts the whole upload.
- Media shares the server's disk and has no backup.

### Target
- Files live in a **private** R2 bucket. The API never streams file bytes; it
  checks permission and answers with a short-lived **signed URL** (for example
  10 minutes) that the phone downloads from Cloudflare directly.
- Uploads go straight from the phone to R2 with a **signed upload URL**.
  Videos use **multipart upload** so a dropped connection resumes from the last
  finished part instead of from zero.
- The phone keeps a disk cache keyed by media id, so a photo is downloaded
  once. The cache holds only media the user may see, and it is cleared on
  sign-out and account deletion.

### Steps
1. **Settings and client.** Add `OMOTERRA_MEDIA_STORAGE` (`local` | `r2`),
   `OMOTERRA_R2_ACCOUNT_ID`, `OMOTERRA_R2_BUCKET`, `OMOTERRA_R2_ACCESS_KEY_ID`,
   `OMOTERRA_R2_SECRET_ACCESS_KEY`. Add `boto3` to requirements. Validate at
   startup like the push settings: wrong or missing values stop the server
   with a clear message.
2. **Storage interface** in `media.py`: `put`, `signed_get`, `signed_put`,
   `start_multipart` / `sign_part` / `complete_multipart`, `delete`.
   `LocalStorage` keeps today's behaviour so development and tests need no R2;
   `R2Storage` implements it with S3 calls to
   `https://<account>.r2.cloudflarestorage.com`.
3. **Photos.** Keep the server-side re-encode (it strips GPS and EXIF, which
   protects supplier privacy): the photo is still uploaded to the API, cleaned,
   then written to R2. `GET /media/{id}` returns `{url, expires_at}`
   instead of bytes. The dashboard's `/media/[id]` proxy follows the same URL.
4. **Videos.** New endpoints to start, sign parts, and complete a multipart
   upload into a pending object, then `POST /media/video/confirm`, which checks
   the object's size and container signature (as `video_type()` does today)
   before recording the `MediaAsset`. Unconfirmed uploads are deleted by an
   R2 lifecycle rule after 1 day.
5. **App.**
   - Read signed URLs.
   - Add a disk cache (`flutter_cache_manager` with a custom key = media id,
     since signed URLs change every time).
   - Upload videos in 5 MB parts with retry per part, and show resumable
     progress.
   - Clear the cache in `SessionNotifier.logout()`.
6. **Migrate existing files.** A one-off command,
   `python -m app.media migrate-to-r2`, copies every file in the media folder
   to R2, verifies it, and only then marks the asset as stored in R2. It is
   safe to re-run. Keep the local files until a week of clean running, then
   delete them.
7. **Bucket settings (Cloudflare dashboard):**
   - Keep the bucket private, with no public access and no `r2.dev` URL.
   - Add a CORS rule allowing `PUT` from the app and dashboard origins.
   - Add a lifecycle rule for abandoned multipart uploads.

### Done when
- Opening the same listing twice downloads its photos once.
- A 60 MB video upload survives turning mobile data off and on mid-upload.
- A buyer cannot fetch an unapproved listing's photo, even with an old
  signed URL (it expires) or a guessed id (the API refuses to sign it).
- The existing permission tests pass unchanged against `LocalStorage`, and the
  same suite runs against R2 when test credentials are present.

### Decisions (confirmed)
- Signed URL lifetime: 10 minutes for photos, 30 for video.
- Buyers' phones may cache approved listing photos on disk: yes; unapproved
  or rejected media is never cached (the app drops a cached copy as soon as
  the server refuses to sign it).

---

## Phase 3 — Dashboard lists that never hide work

**Status: done (2026-09-26), not yet deployed.** As built:
- One contract, one helper (`backend/app/paging.py`): every ops list takes
  `?status=&q=&page=&page_size=` (default 50, capped at 100; `page` from 1)
  and answers `{items, total, page, page_size, actionable, counts}`.
  `actionable` counts the rows that need action; `counts` is each status
  tab's row count under the same search, from the database.
- Rows that need action are never paged: all of them come first on page 1,
  most urgent (oldest) first, and paging applies only to the history behind
  them. History pages = ceil((total − actionable) / page_size). What needs
  action: unpaid settlements; orders not delivered, completed, cancelled or
  failed; pending or partial payments; stock pending review or needing
  reconfirmation; open demand (not completed, cancelled or converted); new
  business opportunities; suppliers under review.
- Lists on the contract: `/ops/orders`, `/ops/settlements` (also `totals`
  of pending and paid payouts, and each row's supplier alias, legal name and
  order id), `/ops/payments`, `/ops/listings`, `/ops/requests`,
  `/ops/requirements` (keeps its category, region, buyer, frequency and date
  filters), `/ops/business-opportunities`, `/ops/suppliers`, `/ops/buyers`,
  `/ops/buyer-crm` (CRM records and buyer app accounts paged together in
  SQL) and `/ops/ratings`. New detail routes `GET /ops/listings/{id}` and
  `GET /ops/business-opportunities/{id}` replace fetching the whole list to
  find one row.
- `q` matches the order reference (`OR-3F2A9C`, an id prefix), supplier
  alias, legal name or phone, buyer name, phone or CRM business name,
  category label and region, with `ILIKE`. Migration
  `017_ops_list_search.sql` adds `pg_trgm` trigram indexes on those name,
  phone and region columns, prefix indexes for references, and
  `(status, created_at)` indexes for the action queues.
- Dashboard: `ops/components/list-controls.tsx` (`<ListControls>`: status
  tabs with database counts, search box, the table, total and "N need
  action", page buttons) on Orders, Settlements, Payments, Supply,
  Suppliers, Buyers, Sourcing, Ratings and Business Opportunities. Filters
  live in the URL (`?status=&q=&page=`). Default tab is All, which shows the
  actionable rows first. The dashboard home's attention links use the new
  `status` values. Supplier columns still sort, within the page.
- Sidebar badges and alerts are unchanged: they count from `/ops/summary`
  and `/ops/alerts`, in the database.
- The mobile admin app calls none of these routes.
- Tests: `backend/tests/test_ops_paging.py` (500 orders and 300 settlements:
  the oldest unpaid settlement is first on page 1; searching the supplier's
  alias, legal name, category or reference finds all 100 of their orders;
  orders in progress never paged away; page-size cap; every list speaks the
  contract; stock awaiting review leads Supply).
- Not moved: `/ops/batches` (limit 300) and `/ops/audit` are not on the
  pages this phase covers.

### Today
`/ops/orders`, `/ops/settlements`, `/ops/listings`, `/ops/requests` and
`/ops/business-opportunities` return only the newest 100 rows (see
`backend/app/main.py`). Only the dashboard home, Orders, Supply and Sourcing
pages have any search or filter.

### Target
Nothing that needs action ever falls off a list, and every list can be
searched and paged.

### Steps
1. **One paging contract** for every ops list:
   - Requests take `?status=&q=&page=&page_size=` (page size capped at 100).
   - Responses are `{items, total, page, page_size}`.
   - The default view of an action list (unpaid settlements, orders in
     progress, listings awaiting review) always contains **all** actionable
     rows first. Paging applies only to history.
2. **Search** (`q`): order reference, supplier alias or legal name, buyer
   name or phone, category, region. Use `ILIKE` on indexed columns now; move
   to PostgreSQL full-text search only if it becomes slow.
3. **Dashboard:** a shared `<ListControls>` component (search box, status tabs,
   page buttons, total count) on Orders, Settlements, Payments, Supply,
   Suppliers, Buyers, Sourcing and Ratings. Filters live in the URL so a
   filtered view can be shared or bookmarked.
4. **Counts:** sidebar badges and the new alerts already count from the
   database, not the page, so they stay correct.

### Done when
With 500 orders and 300 settlements in a test database, the oldest unpaid
settlement appears on the first page of Settlements, and searching a
supplier's name finds all of their orders.

---

## Phase 2 — Search buyers can actually use

**Status: done (2026-09-26), not yet deployed.** As built:
- `GET /listings` (`backend/app/main.py`, helpers in `backend/app/search.py`):
  `q` is split into words; each word must match the category (English and
  Swahili synonyms, phrases like "nyama ya mbuzi", partly typed words), the
  region, or the breed / cut spec (`breed_type`, `breed`, `cut_type`). Filters
  run in SQL: `category`, `region` (contains), `min_price`, `max_price`,
  `ready_by` (ISO date), `condition` (live, dressed, chilled, frozen),
  `min_weight` / `max_weight` (overlap with the listing's weight or range).
  Buyer visibility is unchanged.
- Paging: send `page_size` (1–50) and the answer is
  `{"items": [...], "next_cursor": "…" | null}`; pass `next_cursor` back as
  `cursor`. The cursor is on `(created_at, id)`, newest first. Without
  `page_size` the old plain list (`limit`) still answers, for apps already
  installed.
- Migration `018_listing_search.sql` adds a partial index for the live feed.
- App: Explore sends the search after a 400 ms pause, `ListingFeed` loads 20
  at a time and the next page near the end of the scroll, no phone-side
  filtering. No results shows "No stock for 'X' right now" and Request
  Supply, which opens prefilled (`/request?q=…&category=…`).
- Tests: `backend/tests/test_search.py` (216-listing marketplace; "kuku",
  "Pwani", "Kuroiler", filters, paging; one unit test per synonym word) and
  `mobile/test/explore_search_test.dart` (debounce, empty state, load more).

### Today
`mobile/lib/features/buyer/listing_feed.dart` downloads the newest 50 listings
and filters them on the phone by the **English category label**. "kuku",
"mbuzi" and region names find nothing. The backend `q` parameter also only
matches the category key.

### Target
Type a product in English or Swahili, a region, or a breed, and get matching
stock from the whole marketplace, newest first, loading more as you scroll.

### Steps
1. **Backend search** in `GET /listings`:
   - Match `q` against the category (through an English and Swahili synonym
     table), region, and the listing's breed or type spec.
   - Move every Explore filter to the server: region, maximum price, ready by,
     condition, weight range.
   - Add paging (`page`, `page_size`, or a cursor on `created_at, id`).
2. **Synonyms** in one place (`backend/app/search.py`), for example:
   `kuku`/`chicken` → broilers, local chicken, layers, chicken meat; `mbuzi`
   → goats, goat meat; `ng'ombe` → cattle, beef; `mayai` → eggs; `nyama` →
   all meat. Unit tests cover each word.
3. **App:** send the query to the server with a short debounce and load more on
   scroll. Remove the phone-side filtering. The empty state keeps its "Request
   Supply" action, and prefills the request with what the buyer searched for.
4. **No results:** show "No stock for 'X' right now" plus the request button,
   and never an empty grid.

### Done when
Searching "kuku", "Pwani" or "Kuroiler" returns the right listings from a
database of 200+ listings, and a filter change reloads from the server.

---

## Phase 1 — Swahili everywhere

**Backend status: built (2026-09-26), not deployed; the Swahili is a first
draft awaiting review (step 4).** As built:
- `backend/app/i18n.py`: `t(key, lang, **values)`, the `EN` and `SW`
  catalogues (319 keys each), and `M(key, **values)`, a message that reads as
  its English text (so existing callers and tests are unchanged) and is
  translated when the response is written. Unknown languages and keys missing
  from `SW` fall back to English.
- Errors: every `s.fail(...)` and every former `raise HTTPException(...)` in
  `auth`, `media`, `video` and `search` now takes a key
  (`fail('err.order_not_found', 404)`); `contracts.py` validators raise
  `ValueError(M('err.…'))`. `LanguageMiddleware` records `Accept-Language`
  per request, `auth.current_user` records the user's saved `language`, which
  wins. Exception handlers render the detail in that language; the JSON shape
  (`{"detail": "…"}`, or pydantic's list for 422s) is unchanged. English
  validation messages keep pydantic's "Value error, " prefix; Swahili ones are
  the message alone. `/ops/` and `/mobile-admin/` always answer in English
  (the admin app matches "turned off" in one of them).
- Notifications: `notify(db, user, role, kind, M('notify.…', …), link, extra)`
  writes the title and body in the recipient's `users.language`, so inbox and
  push match. Categories are translated (`category.*`: kuku wa nyama, mbuzi,
  ng'ombe, …).
- Tests: `backend/tests/test_i18n.py` (catalogue parity and placeholders, every
  `fail`/`error`/`notify`/validator uses a catalogue key, Swahili notification
  and push text, Swahili errors by saved language and by `Accept-Language`,
  Swahili validation message, staff paths stay English).
- Not translated yet: pydantic's own messages (e.g. "Field required"), order
  activity labels stored in `orders.activity` ("Order confirmed", …), and any
  text the server returns outside `detail`.

**Mobile status: built (2026-09-26), not released; the Swahili is a first
draft awaiting review (step 4).** As built:
- `mobile/lib/core/l10n/strings.dart` holds every screen's copy: about 870
  English/Swahili pairs, plus `label()` / `status()` / `unit()` for the codes
  the API sends (categories, statuses, units, forms, weekdays, buyer and
  business types — 144 codes) and `date()` with Swahili month names. A header
  comment flags it for review before release. Widgets without a `WidgetRef`
  use `context.s`.
- Extracted in the planned order: supplier, account, staff (admin), shared
  widgets, buyer, sign-in, then the app shell (bottom navigation, role
  switcher) and the push snackbar. Includes dialogs, snackbars, tooltips,
  hints, labels, validation messages and screen-reader labels. Region names
  stay as the API values; Zanzibar and Pemba regions show their Swahili names.
- Every request sends `Accept-Language` (`ApiRepository(language: …)`, read on
  each request). Switching language when signed in also saves it on the
  profile (`SessionController.setLanguage`), since the saved language wins on
  the server; saving Profile & language keeps the phone's choice in step.
- Error copy no longer matches English words in server messages: `ApiFailure`
  carries a `FailureKind` (offline, session expired, unavailable, …) and the
  HTTP `status`; a 404 with Omoterra's reason shows that (translated) reason,
  FastAPI's bare "Not Found" and 5xx get the app's own translated copy.
- Guard: `mobile/test/l10n_guard_test.dart` fails on a literal with letters in
  `Text(…)`, hint/label/tooltip/title/message arguments, `OmoterraButton`,
  `EmptyState`, `SectionHeader`, `ApiFailure`, `FormFieldSpec` titles, across
  `lib/features`, `lib/shared`, `lib/core/routing` and
  `lib/core/notifications`, with an allow-list for Omoterra, WhatsApp, TZS,
  kg, the `OMT-` reference prefix and the OpenStreetMap credit.
- Tests: `mobile/test/swahili_screens_test.dart` renders supplier
  registration, add stock, a supplier order and the rating card with
  `Strings('sw')`, and checks the `Accept-Language` header and that a
  signed-in language switch is saved. All 159 mobile tests pass;
  `flutter analyze` is clean.
- Still English: the offline design preview's fixture messages
  (`LocalRepository`), and text the server sends outside `detail` (see above).

### Today
- The app has a translation helper (`mobile/lib/core/l10n/strings.dart`,
  `_t(en, sw)`), but only 12 of 32 screen files use it. Most of the supplier
  side, account screens, ratings, farm location, video and notifications are
  hardcoded English.
- The backend never reads `users.language`, so every error message and
  notification is English.

### Target
A user who chose Kiswahili sees Kiswahili on every screen, in every error, and
in every push and inbox message.

### Steps
1. **Extract** every user-visible string in the app into `Strings`, one feature
   folder per change, in this order: supplier (home, stock, add stock, orders,
   payouts, demand, reviews), account (registration wizard, profile, delete,
   support), shared widgets (farm location, video, photos, ratings, support
   contact), buyer screens not yet covered, then notifications and the inbox.
2. **Guard against regressions:** a test that fails when a `Text('…')` literal
   with letters appears in `lib/features` or `lib/shared` outside `strings.dart`,
   with an allow-list for brand names.
3. **Backend messages:** introduce `app/i18n.py` with `t(key, lang, **values)`
   and Swahili and English catalogues.
   - `notify()` renders the title and body in the recipient's language when it
     is created, so the inbox and push match the phone.
   - Errors raised with `s.fail()` get message keys, translated from the
     request's user or an `Accept-Language` header the app sends.
4. **Review:** a Swahili speaker on the team reviews the catalogue before
   release (farming terms especially). Machine translation is only a first
   draft.
5. **Test:** widget tests render key screens with `Strings('sw')`, and backend
   tests check a Swahili user's notification text.

### Done when
With the app set to Kiswahili, a walk through registration, adding stock,
getting an order, confirming stock and rating shows no English except brand
names, and the notifications arrive in Kiswahili.

---

## Not in this plan
SMS delivery and mobile-money payments stay out of scope, as agreed. They are
still required before a public launch.
