#!/bin/bash
set -u

APP_DIR="/home/jopexco/omoterra_backend"
HEALTH_URL="http://127.0.0.1:8011/health"
LOG_FILE="$APP_DIR/logs/watchdog.log"
PYTHON_BIN="$APP_DIR/.venv/bin/python"

mkdir -p "$APP_DIR/logs"

if "$PYTHON_BIN" - "$HEALTH_URL" <<'PY' >/dev/null 2>&1
import sys
from urllib.request import urlopen

with urlopen(sys.argv[1], timeout=10) as response:
    if response.status != 200:
        raise SystemExit(1)
PY
then
    exit 0
fi

printf '%s API health check failed; restarting\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
exec "$APP_DIR/restart-omoterra.sh"
