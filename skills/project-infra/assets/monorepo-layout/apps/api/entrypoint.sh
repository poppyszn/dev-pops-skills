#!/bin/sh
set -e

case "$1" in
  migrate)
    # Retry on connection failure — see the docker skill's references/node-api.md,
    # "How the pieces fit together" for why (fresh-volume Postgres
    # restart race, confirmed with a live repro).
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
    exec node dist/seed.js
    ;;
  start|"")
    exec node dist/main.js
    ;;
  *)
    exec "$@"
    ;;
esac
