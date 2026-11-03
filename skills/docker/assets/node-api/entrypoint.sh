#!/bin/sh
set -e

case "$1" in
  migrate)
    # Retry on connection failure: on a fresh volume, Postgres's own
    # entrypoint starts a temporary server for initdb, stops it, then
    # starts the real one — pg_isready can catch the temp server's brief
    # "ready" window and report the container healthy right as it's
    # about to restart for real, so compose.yml's `depends_on:
    # condition: service_healthy` isn't a hard guarantee here. Confirmed
    # with a live repro (fresh volume, `docker compose up`): migrate hit
    # ECONNREFUSED once even though postgres already reported Healthy.
    # Retrying the migration itself is more robust than trying to
    # perfect the healthcheck.
    attempt=1
    max_attempts=10
    until node node_modules/typeorm/cli.js migration:run -d dist/typeorm-cli.config.js; do
      if [ "$attempt" -ge "$max_attempts" ]; then
        echo "migrate: giving up after $attempt attempts" >&2
        exit 1
      fi
      echo "migrate: attempt $attempt failed, retrying in 3s..." >&2
      attempt=$((attempt + 1))
      sleep 3
    done
    exit 0
    ;;
  seed)
    exec node dist/src/seed.js
    ;;
  start|"")
    exec node dist/src/main.js
    ;;
  *)
    exec "$@"
    ;;
esac
