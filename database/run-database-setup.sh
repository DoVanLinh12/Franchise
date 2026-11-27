#!/bin/sh

set -eu

schema_exists="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -Atc \
  "SELECT to_regclass('app.users') IS NOT NULL")"

if [ "$schema_exists" != "t" ]; then
  echo "Creating database tables from the canonical schema"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -1 -f /schema/001_create_all_tables.sql
else
  echo "Application tables already exist; skipping table creation"
fi

for procedure_file in /procedures/*.sql; do
  echo "Applying $(basename "$procedure_file")"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -1 -f "$procedure_file"
done

echo "Database setup completed"
