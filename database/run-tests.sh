#!/bin/sh

set -eu

for test_file in /tests/*.sql; do
  echo "Running $(basename "$test_file")"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$test_file"
done
