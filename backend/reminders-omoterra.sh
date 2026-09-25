#!/bin/bash
# Hourly job: reminds suppliers to confirm stock before it is hidden from
# buyers (see app/reminders.py). Scheduled from cPanel Cron Jobs:
#
#   0 * * * * /home/jopexco/omoterra_backend/reminders-omoterra.sh >/dev/null 2>&1
#
# Safe to run by hand at any time; each listing gets one reminder per
# confirmation window however often this runs.
set -u

APP_DIR="/home/jopexco/omoterra_backend"
LOG_FILE="$APP_DIR/logs/reminders.log"
LOCK_FILE="$APP_DIR/logs/reminders.lock"
PYTHON_BIN="$APP_DIR/.venv/bin/python"

cd "$APP_DIR" || exit 1
mkdir -p "$APP_DIR/logs"

stamp() { date '+%Y-%m-%d %H:%M:%S'; }

# A slow run (a stalled push, a slow database) must not overlap the next one.
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "$(stamp) previous run still going; skipped" >> "$LOG_FILE"
    exit 0
fi

# Same refusal as restart-omoterra.sh: without .env this would run against
# development defaults instead of the production database.
if [ ! -f "$APP_DIR/.env" ] && [ ! -f "$(dirname "$APP_DIR")/.env" ] \
        && [ -z "${OMOTERRA_DATABASE_URL:-}" ]; then
    echo "$(stamp) FAILED: no .env found; not running" >> "$LOG_FILE"
    exit 1
fi

output="$("$PYTHON_BIN" -m app.reminders 2>&1)"
status=$?
if [ $status -eq 0 ]; then
    echo "$(stamp) $output" >> "$LOG_FILE"
else
    { echo "$(stamp) FAILED (exit $status):"; echo "$output"; } >> "$LOG_FILE"
fi

# Keep the log small: the last 2000 lines are plenty to see recent runs.
if [ "$(wc -l < "$LOG_FILE")" -gt 2000 ]; then
    tail -n 2000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi
exit $status
