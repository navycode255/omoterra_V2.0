#!/usr/bin/env bash
# Runs Omoterra on this machine only, never touching production:
#   database  Postgres from compose.yaml (`db`), data kept in a docker volume
#   API       http://127.0.0.1:8020/api/v1  (reloads when backend/app changes)
#   website   http://localhost:3100         (public site, /register, dashboard)
# SMS codes are shown on screen (development SMS provider). Ctrl+C stops the
# API and website; the database keeps running (`docker compose stop db`).
set -euo pipefail
cd "$(dirname "$0")/.."

API_PORT=${API_PORT:-8020}
WEB_PORT=${WEB_PORT:-3100}
# compose.yaml requires a token even when only the database starts.
export OMOTERRA_OPS_TOKEN=${OMOTERRA_OPS_TOKEN:-local-dev-ops-token}

docker compose up -d --wait db

trap 'kill 0' EXIT
(
  cd backend
  OMOTERRA_DATABASE_URL=postgresql+psycopg://omoterra:omoterra@127.0.0.1:55432/omoterra \
  OMOTERRA_ADMIN_SETUP_PASSPHRASE=${OMOTERRA_ADMIN_SETUP_PASSPHRASE:-local-admin-setup} \
    .venv/bin/python -m uvicorn app.main:app --reload --reload-dir app --port "$API_PORT"
) &
(
  cd ops
  # Set here, these override ops/.env.local, which may point at production.
  OMOTERRA_API_URL=http://127.0.0.1:$API_PORT/api/v1 OMOTERRA_APP_URL=http://localhost:$WEB_PORT \
    npx next dev -p "$WEB_PORT"
) &
wait
