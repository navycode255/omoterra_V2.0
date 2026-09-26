#!/bin/bash
set -u

APP_DIR="/home/jopexco/omoterra_backend"
PORT="8011"
PID_FILE="$APP_DIR/logs/app.pid"
LOG_FILE="$APP_DIR/logs/app.log"

cd "$APP_DIR" || exit 1
mkdir -p "$APP_DIR/logs" "$APP_DIR/media"

# Without .env the app starts on development defaults — localhost database,
# placeholder OTP secret, empty ops token — and still answers /health, so a
# missing file looks like a working deployment. Refuse rather than serve a
# server that is silently pointed at the wrong database.
# app/config.py reads .env from beside the app or from the account home one
# level up, so both count as configured.
if [ ! -f "$APP_DIR/.env" ] && [ ! -f "$(dirname "$APP_DIR")/.env" ] \
        && [ -z "${OMOTERRA_DATABASE_URL:-}" ]; then
    echo "Refusing to start: no .env at $APP_DIR/.env or" >&2
    echo "$(dirname "$APP_DIR")/.env, and OMOTERRA_DATABASE_URL is not set," >&2
    echo "so the app would run on development defaults against a localhost" >&2
    echo "database. Create one with: cp .env.example .env && nano .env" >&2
    exit 1
fi

# Stop the recorded process, if it is still running.
if [ -f "$PID_FILE" ]; then
    pid="$(cat "$PID_FILE")"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        for i in $(seq 1 10); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.5
        done
        kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
fi

# Clean up only this application's Uvicorn processes if a PID file drifted.
pkill -f "$APP_DIR/.venv/bin/uvicorn app.main:app" 2>/dev/null || true
sleep 1

# Start the API in the background.
nohup "$APP_DIR/.venv/bin/uvicorn" app.main:app \
    --host 127.0.0.1 \
    --port "$PORT" \
    >> "$LOG_FILE" 2>&1 &

pid="$!"
echo "$pid" > "$PID_FILE"
sleep 2

if ! kill -0 "$pid" 2>/dev/null; then
    echo "Omoterra API failed to start. Check $LOG_FILE" >&2
    rm -f "$PID_FILE"
    exit 1
fi

# A live process is not a working app: uvicorn stays up when the app fails
# to import, so the health endpoint is what actually decides.
for _ in $(seq 1 10); do
    if curl -fsS -m 2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
        echo "Omoterra API started with PID: $pid on port $PORT (health OK)"
        # A present .env does not prove the app read it. /config reports the
        # environment it actually resolved, so a config that silently fell
        # back to development defaults is caught here rather than in
        # production.
        env_name=$(curl -fsS -m 2 "http://127.0.0.1:$PORT/api/v1/config" \
            2>/dev/null | sed -n 's/.*"environment":"\([a-z]*\)".*/\1/p')
        if [ "$env_name" = "development" ]; then
            echo "" >&2
            echo "WARNING: the app reports environment=development." >&2
            echo "It is using built-in defaults (localhost database," >&2
            echo "placeholder OTP secret), not your production config." >&2
            echo "Check that .env is readable and sets" >&2
            echo "OMOTERRA_ENVIRONMENT=live and OMOTERRA_DATABASE_URL." >&2
        elif [ -n "$env_name" ]; then
            echo "Environment: $env_name"
        fi
        # Staff sign-in from the app needs OMOTERRA_MOBILE_ADMIN_PASSPHRASE.
        if curl -sS -m 2 "http://127.0.0.1:$PORT/api/v1/mobile-admin/me" 2>/dev/null \
                | grep -q 'turned off'; then
            echo "Staff sign-in (mobile admin): OFF — set OMOTERRA_MOBILE_ADMIN_PASSPHRASE in .env"
        else
            echo "Staff sign-in (mobile admin): ON"
        fi
        exit 0
    fi
    sleep 1
done

echo "Omoterra API process $pid is running but /health did not answer on port $PORT." >&2
echo "The app most likely failed during startup. Last lines of $LOG_FILE:" >&2
tail -n 30 "$LOG_FILE" >&2
exit 1
