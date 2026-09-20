#!/bin/bash
set -u

APP_DIR="/home/jopexco/omoterra_backend"
PORT="8011"
PID_FILE="$APP_DIR/logs/app.pid"
LOG_FILE="$APP_DIR/logs/app.log"

cd "$APP_DIR" || exit 1
mkdir -p "$APP_DIR/logs" "$APP_DIR/media"

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
        exit 0
    fi
    sleep 1
done

echo "Omoterra API process $pid is running but /health did not answer on port $PORT." >&2
echo "The app most likely failed during startup. Last lines of $LOG_FILE:" >&2
tail -n 30 "$LOG_FILE" >&2
exit 1
