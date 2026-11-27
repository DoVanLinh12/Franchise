#!/bin/sh

set -eu

# Load sample data only into an empty database, so restarting the stack never
# duplicates or overwrites real data.
user_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -Atc "SELECT count(*) FROM app.users")"
if [ "$user_count" != "0" ]; then
  echo "Database already has data; skipping seed"
  exit 0
fi
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f /database/seed.sql
