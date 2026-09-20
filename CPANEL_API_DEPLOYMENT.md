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

OTP delivery stays separate from that: keep `OMOTERRA_SMS_PROVIDER=development`
so verification codes are returned in the API response instead of being sent
by SMS. That is deliberate and currently the only supported value — no SMS
provider adapter exists yet, and neither does a payment one, so
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
```

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

## 5. Create the database tables

Run the initializer once:

```bash
cd ~/omoterra_backend
source .venv/bin/activate
python -m app.manage
```

Expected output:

```text
Omoterra development schema created.
```

Do not run the initializer repeatedly on a live database. Do not use it together
with the SQL migrations on the same empty database.

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
python -m app.manage
```

Only run `python -m app.manage` when the database schema must be initialized or
updated. Restart the cPanel Python application after updating the code.

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
- Run the backend tests against the cPanel PostgreSQL database.
