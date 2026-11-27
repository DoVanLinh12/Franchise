#!/usr/bin/env bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

usage() {
  cat <<'EOF'
Usage: bash scripts/dev.sh <command> [arguments]

Commands:
  up                 Start the lightweight development stack
  full-up            Start the stack with Celery worker and MailHog
  infra-up           Start only PostgreSQL and Redis
  down               Stop application containers
  logs               Follow application logs
  api-logs           Follow API logs
  frontend-logs      Follow frontend logs
  config             Validate application Compose configuration
  db-setup           Create the schema and install feature procedures/functions
  db-migrate         Alias for db-setup
  db-test            Run Stored Procedure integration tests
  db-seed            Seed realistic local business data (2,500+ revenues)
  test               Run backend tests in the backend test container
  coverage           Run backend tests with coverage
  postman-test        Run the Postman collection and save its JUnit report
EOF
}

command_name="${1:-}"

case "$command_name" in
  up)
    docker compose up --build -d
    ;;
  full-up)
    docker compose --profile full up --build -d
    ;;
  infra-up)
    docker compose up -d postgres redis
    ;;
  down)
    docker compose --profile full down
    ;;
  logs)
    docker compose --profile full logs -f
    ;;
  api-logs)
    docker compose logs -f api
    ;;
  frontend-logs)
    docker compose logs -f frontend
    ;;
  config)
    docker compose --profile full --profile test --profile tools config --quiet
    ;;
  db-setup|db-migrate)
    docker compose run --rm database-setup
    ;;
  db-test)
    docker compose run --rm database-setup
    docker compose --profile test run --rm database-test
    ;;
  db-seed)
    docker compose run --rm database-setup
    docker compose --profile tools run --rm seed
    ;;
  test)
    docker compose --profile test run --rm backend-test
    ;;
  coverage)
    docker compose --profile test run --rm backend-test \
      python -m pytest --cov=app --cov-report=term-missing
    ;;
  postman-test)
    mkdir -p reports/postman
    docker compose --profile test run --rm postman
    ;;
  *)
    usage
    exit 2
    ;;
esac
