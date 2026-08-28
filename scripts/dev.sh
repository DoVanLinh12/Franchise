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
  config             Validate application Compose configuration
  test               Run backend tests in the API container
  coverage           Run backend tests with coverage
  migration <name>   Generate an Alembic migration
  migrate            Apply all Alembic migrations
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
  config)
    docker compose --profile full config --quiet
    ;;
  test)
    docker compose exec api pytest
    ;;
  coverage)
    docker compose exec api pytest --cov=app --cov-report=term-missing
    ;;
  migration)
    migration_name="${2:-}"
    if [[ -z "$migration_name" ]]; then
      echo "Migration name is required." >&2
      usage
      exit 2
    fi
    docker compose run --rm api alembic revision --autogenerate -m "$migration_name"
    ;;
  migrate)
    docker compose run --rm api alembic upgrade head
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
