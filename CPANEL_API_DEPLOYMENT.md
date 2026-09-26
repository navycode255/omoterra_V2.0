# Deploy Omoterra Backend to cPanel

This guide deploys the Omoterra FastAPI backend into a cPanel directory named `api`.

## Your cPanel has MariaDB only

The current Omoterra backend requires PostgreSQL. It uses the `psycopg` driver,
PostgreSQL migrations, and PostgreSQL transaction behavior. Do **not** replace
the database URL with a MariaDB URL; the application will not start correctly.

You have two choices:

1. Keep the backend unchanged and use a separate PostgreSQL provider. This is
	the quickest deployment option. Use that provider's host, port, database,
	username, password, and SSL settings in `OMOTERRA_DATABASE_URL`.
2. Migrate the backend from PostgreSQL to MariaDB. This requires code changes,
	a MariaDB driver, new migrations, and testing the inventory locking and
	transaction behavior. It is not a cPanel configuration change.

The rest of this guide assumes option 1. If you only want to use the MariaDB
database included with cPanel, stop here and migrate the backend first.

## Important

Set `OMOTERRA_ENVIRONMENT=live` for a real deployment. In `live` mode the
server also requires a real `OMOTERRA_OTP_SECRET` and `OMOTERRA_OPS_TOKEN`
and refuses to start without them.

OTP delivery is separate from that. `OMOTERRA_SMS_PROVIDER=development` returns
codes in the API response (shown on screen, no SMS cost). To text real codes
through Sema set:

```
OMOTERRA_SMS_PROVIDER=sema
SEMA_API_ID=<API ID from the Sema email / customer panel>   # no OMOTERRA_ prefix,
SEMA_API_PASSWORD=<API password>                            # shared with other apps
OMOTERRA_SEMA_SENDER_ID=<approved sender ID, e.g. OMOTERRA>
OMOTERRA_SEMA_SMS_TYPE=P          # P promotional, T transactional
OMOTERRA_SEMA_URL=https://api.sema.co.tz/api/SendSMS
```

The server refuses to start with `sema` if any of these is missing. Website
members sign in with phone + PIN (no SMS); a code is texted only when they
register or reset a forgotten PIN. The app and staff sign-in still text a code
each time. No payment adapter exists yet, so
`OMOTERRA_PAYMENT_PROVIDER` must stay `disabled`. Buyers can order with
pay-on-delivery; Pay Now is not available.

Your cPanel hosting must support Python 3.9 or newer and cPanel **Setup Python
App** with Passenger. This deployment uses a small ASGI-to-WSGI adapter so
FastAPI can run through cPanel's normal Python application interface; Uvicorn
is not required for the public domain.

## 1. Create or obtain a PostgreSQL database

If your cPanel provides **PostgreSQL Databases**, create:

- Database: `omoterra`
- User: `omoterra_user`
- A strong password

Add the user to the database with all privileges. cPanel may add your account
prefix to these names. Use the final names shown by cPanel.

If cPanel has no PostgreSQL option, create a PostgreSQL database with a managed
provider, VPS, or another server. The database URL will look like this:

```text
postgresql+psycopg://CPANEL_DB_USER:DB_PASSWORD@localhost:5432/CPANEL_DB_NAME
```

## 2. Upload the backend into the `omoterra_backend` directory

Create this directory in your cPanel home directory:

```text
/home/CPANEL_USERNAME/omoterra_backend
```

Upload the contents of this repository directory into it:

```text
omoterra/backend/
```

The result must look like this:

```text
/home/CPANEL_USERNAME/omoterra_backend/app/main.py
/home/CPANEL_USERNAME/omoterra_backend/app/manage.py
/home/CPANEL_USERNAME/omoterra_backend/requirements.lock
/home/CPANEL_USERNAME/omoterra_backend/migrations/001_initial.sql
/home/CPANEL_USERNAME/omoterra_backend/migrations/002_inventory_history.sql
```

Do not upload the local `.venv` directory.

## 3. Create the Python virtual environment

Open **cPanel Terminal** and run:

```bash
cd ~/omoterra_backend
python -m virtualenv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.lock
```

If `virtualenv` is not available, install it for your account first with
`python -m pip install --user virtualenv`. Python 3.10 or newer is preferred,
but the compatibility lock file supports this server's Python 3.9 runtime.

## Never put application files in the document root

Apache parses `.htaccess` as configuration, one line at a time. If a Python
file is ever copied or saved over it, the first line is not a valid
directive and Apache answers **every** request on the subdomain with 500 —
before any application runs. The give-away is that unrelated paths such as
`/.git/config` also return 500 instead of 404, and that restarting the app
changes nothing.

If the subdomain suddenly returns 500 everywhere, check this first:

```bash
head -3 ~/public_html/omoterra/.htaccess
```

It must contain Apache directives. If it contains Python, delete or replace
it.

Keep the application directory (`~/omoterra_backend`) outside the document
root so `.env`, `*.py` and `*.log` can never be served or mistaken for
configuration.

## 4. Create the environment file

From the cPanel Terminal:

```bash
cd ~/omoterra_backend
cp .env.example .env
nano .env
```

Set the values below. Replace every placeholder:

```dotenv
OMOTERRA_ENVIRONMENT=development
OMOTERRA_DATABASE_URL=postgresql+psycopg://CPANEL_DB_USER:DB_PASSWORD@localhost:5432/CPANEL_DB_NAME
OMOTERRA_OPS_TOKEN=PASTE_A_LONG_RANDOM_SECRET_HERE
OMOTERRA_OTP_SECRET=PASTE_ANOTHER_LONG_RANDOM_SECRET_HERE
OMOTERRA_FRESHNESS_HOURS=48
OMOTERRA_RESERVATION_MINUTES=15
OMOTERRA_MEDIA_DIRECTORY=/home/CPANEL_USERNAME/omoterra_backend/media
OMOTERRA_SUPPORT_PHONE=
OMOTERRA_TERMS_TEXT=
OMOTERRA_PRIVACY_TEXT=
# Push notifications through Firebase (leave 'disabled' to use only the
# in-app inbox). The key file is the Firebase service-account JSON; keep it
# outside public_html and outside the app folder, readable only by you.
OMOTERRA_PUSH_PROVIDER=fcm
OMOTERRA_FCM_CREDENTIALS_FILE=/home/CPANEL_USERNAME/secrets/firebase-key.json
# Livestock photos and videos in a private Cloudflare R2 bucket, under the
# livestock/ folder. Leave 'local' to keep files in OMOTERRA_MEDIA_DIRECTORY.
# The bucket stays private: no public access, no r2.dev URL.
OMOTERRA_MEDIA_STORAGE=r2
OMOTERRA_R2_ACCOUNT_ID=
OMOTERRA_R2_ACCESS_KEY_ID=
OMOTERRA_R2_SECRET_ACCESS_KEY=
OMOTERRA_R2_BUCKET_LIVESTOCK=
```

To move to R2: create an R2 API token with **Object Read & Write** on the
livestock bucket only, fill in the four `OMOTERRA_R2_*` values while
`OMOTERRA_MEDIA_STORAGE` is still `local`, then from `~/omoterra_backend`:

```bash
python -m app.storage check     # proves the keys and bucket work
python -m app.storage migrate   # copies existing photos/videos; safe to re-run
```

Then set `OMOTERRA_MEDIA_STORAGE=r2`, restart, and run `migrate` once more to
catch anything uploaded in between. Keep the local media folder for a week
before deleting it.

The API never streams media. After its permission check it answers
`GET /media/{id}` with `{url, expires_at}`: a signed link valid 10 minutes
for photos and 30 minutes for videos. With R2 the phone downloads straight
from Cloudflare; with `local` storage the link points to the API's own
`/media/local/...` route and is signed with `OMOTERRA_OTP_SECRET`, so changing
that secret also invalidates any outstanding media links. Videos upload in
5 MB parts straight to the bucket (`/media/video/uploads`, then
`/media/video/confirm`), under `livestock/pending/` until confirmed.

#### Cloudflare R2 bucket settings (dashboard → R2 → the livestock bucket → Settings)

1. **Keep it private.** Public access stays off: no custom public domain and
   the **r2.dev** subdomain **disabled**. Every read goes through a signed
   link the API hands out after checking permission.
2. **CORS policy** (browsers need it for signed `PUT` uploads; the Android
   app does not, but keep it for the dashboard and any web build):

   ```json
   [
     {
       "AllowedOrigins": ["https://omoterra.co.tz"],
       "AllowedMethods": ["GET", "PUT"],
       "AllowedHeaders": ["content-type", "content-length"],
       "ExposeHeaders": ["ETag"],
       "MaxAgeSeconds": 3600
     }
   ]
   ```

   Add any other dashboard or web-app origin to `AllowedOrigins`. `ETag` must
   be exposed: each uploaded part's ETag is sent back to finish the upload.
3. **Object lifecycle rules:**
   - *Abort incomplete multipart uploads* after **1 day** (whole bucket):
     removes uploads a phone started and never finished.
   - *Delete objects* with prefix `livestock/pending/` after **1 day**:
     removes finished uploads that were never confirmed (for example a file
     that failed the video check). The hourly `reminders-omoterra.sh` cron
     (step 8b) also drops their records.

Upload the Firebase key with **File Manager** into `/home/CPANEL_USERNAME/secrets/`
(create the folder), then protect it:

```bash
chmod 700 ~/secrets
chmod 600 ~/secrets/firebase-key.json
```

If the path is wrong or the file is not a service-account key, the API refuses
to start and says so in the log, so a typo cannot silently turn push off.

Generate secrets with:

```bash
openssl rand -hex 32
```

Run the command twice and use a different result for each secret.

Protect the file:

```bash
chmod 600 .env
mkdir -p media
```

## 5. Database tables are created and updated automatically

There is nothing to run by hand. Every time the API starts (Passenger or
`restart-omoterra.sh`), it applies any new file in `migrations/` that the
database has not had yet, records it in the `schema_migrations` table, and only
then starts serving. On an empty database this builds every table; after an
update it applies just the new migrations.

- If a migration fails it is rolled back completely and the API does **not**
  start. The reason is in `logs/app.log` (uvicorn) or the cPanel error log
  (Passenger). Nothing is left half-applied.
- Several workers starting at once wait for each other; each migration runs once.
- The first time this runs on a database that was migrated by hand, it detects
  which migrations are already in effect and records them without re-running.

To see or apply migrations without restarting:

```bash
cd ~/omoterra_backend
.venv/bin/python -m app.migrations status   # applied / detected / pending
.venv/bin/python -m app.migrations apply
```

Back up the database before deploying an update that adds migrations (on Neon,
create a branch or snapshot first).

Do not use `python -m app.manage` on the live database: it only creates missing
tables and never adds new columns, which is how the schema drifted before.

### Register operations admins

Admins register themselves from the dashboard sign-in screen, using a setup
passphrase kept only in the backend `.env`:

```dotenv
OMOTERRA_ADMIN_SETUP_PASSPHRASE=PASTE_A_LONG_RANDOM_PASSPHRASE_HERE
```

It must be at least 8 characters (`openssl rand -base64 24` makes a good one);
leave it empty to switch admin setup off. Restart the API after setting it.

On the sign-in screen, tap **Admin setup** (small link under the form):

1. Enter the setup passphrase.
2. **If an admin already exists**, enter an existing admin's phone number and
   the code sent to it. The passphrase alone never creates an admin once one
   exists; the new admin is recorded as approved by that admin.
3. Enter the new admin's name and phone, then the code sent to that phone.
   They are signed in as admin and can add staff from **Team → Staff**.

Five wrong passphrases lock admin setup for 15 minutes, and an unfinished setup
expires after 15 minutes.

If the dashboard is unreachable, an admin can still be created on the server:

```bash
.venv/bin/python -m app.operators add +2557XXXXXXXX "Full Name" --admin
```

## 6. Test the API before attaching the domain

Start Uvicorn temporarily:

```bash
cd ~/omoterra_backend
source .venv/bin/activate
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

In another cPanel Terminal, test the health endpoint:

```bash
curl http://127.0.0.1:8000/health
```

Expected response:

```json
{"status":"ok"}
```

Stop the temporary server with `Ctrl+C`.

## 7. Configure the cPanel Python application

Open **Setup Python App** and create an application with:

- Python version: `3.9` or newer
- Application root: `omoterra_backend`
- Application URL: `omoterra.jopex.co.tz`
- Startup file: `passenger_wsgi.py`
- Application entry point: `application`

Configuration comes from `.env` in the application directory. The startup
file loads it explicitly with `override=True`, so `.env` is the single source
of truth: `OMOTERRA_*` variables set in the cPanel environment-variable
section are overridden by it and will not take effect. Edit `.env` instead.

The startup file is a WSGI adapter for the FastAPI app. Do not enter
`app.main:app` in the entry-point field for this Passenger setup.

## 8. Start or restart the application

After saving the Python application settings, restart it from cPanel. If the
host provides a restart file, the command is commonly:

```bash
touch ~/omoterra_backend/tmp/restart.txt
```

Only use that command if the host has configured Passenger to watch that path.
Otherwise use the **Restart** button in **Setup Python App**.

### Manual Uvicorn testing (optional)

The Passenger application is the public service. To test Uvicorn separately,
use the included scripts and port `8011`; it is not needed for the public URL.

The backend includes `restart-omoterra.sh` and `watchdog-omoterra.sh`. Upload
both files into `/home/jopexco/omoterra_backend/`, then run:

```bash
cd ~/omoterra_backend
chmod 750 restart-omoterra.sh watchdog-omoterra.sh
./restart-omoterra.sh
curl http://127.0.0.1:8011/health
```

The watchdog checks the health endpoint and restarts the API only when it is
not responding. Add this cron entry in cPanel **Cron Jobs** to check every five
minutes:

```cron
*/5 * * * * /home/jopexco/omoterra_backend/watchdog-omoterra.sh >/dev/null 2>&1
```

Do not schedule `restart-omoterra.sh` directly every five minutes because that
would unnecessarily restart a healthy API.

## 8b. Scheduled jobs (cron)

Two jobs run from cPanel **Cron Jobs**. Upload the scripts into
`/home/jopexco/omoterra_backend/` and make them executable:

```bash
cd ~/omoterra_backend
chmod 750 watchdog-omoterra.sh reminders-omoterra.sh
./reminders-omoterra.sh && tail -n 3 logs/reminders.log
```

The manual run should log a line like `Stock reminders sent: 0`. Then, in cPanel
open **Cron Jobs → Add New Cron Job** and add each line below (choose
"Common Settings: Once Per Hour" for the reminders, or paste the full line):

| Job | Schedule | Command |
| --- | --- | --- |
| Restart the API if it stops answering | every 5 minutes | `/home/jopexco/omoterra_backend/watchdog-omoterra.sh >/dev/null 2>&1` |
| Remind suppliers to confirm stock | every hour, on the hour | `/home/jopexco/omoterra_backend/reminders-omoterra.sh >/dev/null 2>&1` |

As crontab lines:

```cron
*/5 * * * * /home/jopexco/omoterra_backend/watchdog-omoterra.sh >/dev/null 2>&1
0 * * * * /home/jopexco/omoterra_backend/reminders-omoterra.sh >/dev/null 2>&1
```

The reminder job warns a supplier 6 hours before their stock stops being shown
to buyers (it must be re-confirmed every 48 hours) and again once it has been
hidden. Each listing gets one reminder per confirmation window, so running it
more often, or by hand, never sends duplicates, and a run that is still going
makes the next one skip rather than overlap.

Check it is working in `logs/reminders.log` (one line per run; failures are
logged with `FAILED` and the reason). The log keeps its last 2000 lines.

## 9. Verify the public API

Replace the domain with the API URL configured in cPanel:

```bash
curl https://omoterra.jopex.co.tz/health
```

Open the interactive API documentation in a browser:

```text
https://omoterra.jopex.co.tz/docs
```

The mobile application should use this base URL:

```text
https://omoterra.jopex.co.tz/api/v1
```

## Updating the backend

From cPanel Terminal:

```bash
cd ~/omoterra_backend
source .venv/bin/activate
git pull
pip install -r requirements.lock
```

Then restart the application (step 8). New database migrations are applied
automatically as it starts; confirm with `python -m app.migrations status`.

## Common problems

### `ModuleNotFoundError`

The dependencies were not installed in the application's virtual environment:

```bash
cd ~/omoterra_backend
source .venv/bin/activate
pip install -r requirements.lock
```

### Database connection error

Check all of these:

- The cPanel database name includes the account prefix.
- The cPanel database user includes the account prefix.
- The password is URL-safe, or special characters are URL-encoded.
- The database user has privileges on the database.
- `OMOTERRA_DATABASE_URL` starts with `postgresql+psycopg://`.

### The application does not start

Check that the app entry point is exactly:

```text
app.main:app
```

Then check the cPanel application error log. Also confirm that the selected
Python version matches the virtual environment and that all packages were
installed in the same environment.

### Uploaded images disappear

The backend stores uploads in `OMOTERRA_MEDIA_DIRECTORY`. The directory must
exist and be writable:

```bash
mkdir -p ~/omoterra_backend/media
chmod 750 ~/omoterra_backend/media
```

Back up this directory. It is local hosting storage, not durable managed media
storage.

## Production checklist

Before using this API for real users:

- Complete and test production SMS and payment providers.
- Remove the development-only runtime restriction.
- Use HTTPS and a private, strong operator token.
- Configure database backups and restore testing.
- Configure durable media storage and backups.
- Restrict operator endpoints and review access logs.
- Set real terms, privacy text, and support contact details.
- Set the admin setup passphrase and register the first admin (step 5), and add the cron jobs (step 8b).
- Configure push notifications (step 4) and confirm a test phone receives one.
- Run the backend tests against the cPanel PostgreSQL database.
