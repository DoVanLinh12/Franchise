#!/bin/sh

set -eu

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS public.schema_migrations (
    version text PRIMARY KEY,
    applied_at timestamptz NOT NULL DEFAULT now()
);
SQL

for migration_file in /migrations/*.sql; do
  migration_name="$(basename "$migration_file")"
  already_applied="$(
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At \
      -c "SELECT 1 FROM public.schema_migrations WHERE version = '$migration_name'"
  )"

  if [ "$already_applied" = "1" ]; then
    echo "Skipping $migration_name (already applied)"
    continue
  fi

  echo "Applying $migration_name"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
BEGIN;
\i $migration_file
INSERT INTO public.schema_migrations (version) VALUES ('$migration_name');
COMMIT;
SQL
done
