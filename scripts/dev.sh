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
  db-migrate         Apply pending SQL migrations
  db-test            Run Stored Procedure integration tests
  db-seed            Seed realistic local business data (2,500+ revenues)
  db-reset           Delete local business data and load a fresh realistic dataset
  test               Run backend tests in the backend test container
  coverage           Run backend tests with coverage
  postman-test        Run the Postman collection and save its JUnit report
  jenkins-up         Build and start Jenkins with its Docker daemon
  jenkins-down       Stop Jenkins
  jenkins-logs       Follow Jenkins logs
  jenkins-password   Print the initial Jenkins unlock password
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
  db-migrate)
    docker compose --profile tools run --rm migrate
    ;;
  db-test)
    docker compose --profile tools run --rm migrate
    docker compose --profile test run --rm database-test
    ;;
  db-seed)
    docker compose --profile tools run --rm migrate
    docker compose --profile tools run --rm seed
    ;;
  db-reset)
    docker compose up -d postgres redis
    docker compose --profile tools run --rm migrate
    docker compose exec -T postgres \
      psql -v ON_ERROR_STOP=1 \
      -U "${POSTGRES_USER:-franchise}" \
      -d "${POSTGRES_DB:-franchise}" \
      < database/reset-local-data.sql
    docker compose --profile tools run --rm seed
    docker compose exec -T redis redis-cli FLUSHDB
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
  jenkins-up)
    docker compose -f infrastructure/jenkins/compose.yml up --build -d
    ;;
  jenkins-down)
    docker compose -f infrastructure/jenkins/compose.yml down
    ;;
  jenkins-logs)
    docker compose -f infrastructure/jenkins/compose.yml logs -f jenkins
    ;;
  jenkins-password)
    docker exec franchise-jenkins \
      cat /var/jenkins_home/secrets/initialAdminPassword
    ;;
  *)
    usage
    exit 2
    ;;
esac
