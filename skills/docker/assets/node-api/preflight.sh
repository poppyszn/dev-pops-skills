#!/usr/bin/env bash
# Blocking checks that run on the host before a production deploy touches
# anything. Copy to docker/production/preflight.sh; the deploy runs it from the
# checked-out commit, in this directory:
#
#   cd docker/production && bash ./preflight.sh "api store"
#
# The argument is the space-separated list of services being deployed, so checks
# for one service only run when it is part of the deploy. The checks grep for
# exact, non-secret lines and never print the file or any rendered secret.
#
# Exit status: 0 = every check passed; 1 = at least one failed (all are reported).
set -uo pipefail

DEPLOY_APPS="${1:-}"
ENV_FILE="${ENV_FILE:-.env}"
failed=0

fail() {
  echo "Preflight failed: $1" >&2
  failed=1
}

# require_line KEY=value: the line must be present exactly (trailing blanks allowed).
require_line() {
  grep -qxE "$(printf '%s' "$1" | sed 's/[][\.*^$/]/\\&/g')[[:space:]]*" "$ENV_FILE" || fail "$ENV_FILE must declare $1."
}

# forbid_pattern REGEX WHY: no line may match the extended regex.
forbid_pattern() {
  if grep -Eq "$1" "$ENV_FILE"; then
    fail "$2"
  fi
}

# deploys_app NAME: true when NAME is in the list of services being deployed.
deploys_app() {
  case " $DEPLOY_APPS " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

if [ ! -f "$ENV_FILE" ]; then
  echo "Preflight failed: $PWD/$ENV_FILE is missing. Create it from .env.example on the host." >&2
  exit 1
fi

# ---------------------------------------------------------------- generic checks
require_line "NODE_ENV=production"
forbid_pattern '^[A-Za-z0-9_]+=.*<[a-z][^>]*>' "$ENV_FILE still contains <placeholder> values from .env.example."

# ---------------------------------------------------------------- project checks
# One line per rule that must never be wrong in production. Examples:
#
#   require_line "DEPLOYMENT_STAGE=production"
#   forbid_pattern '^FEATURE_SANDBOX=true' "the sandbox feature cannot be on in production."
#   deploys_app store && require_line "STORE_CATALOG_SOURCE=api"

# ---------------------------------------------------------------- render check
# Silent: fails on an interpolation error (an unset ${VAR:?} or a bad value)
# without printing anything the file contains.
if ! docker compose --env-file "$ENV_FILE" config --quiet 2>/dev/null; then
  fail "docker compose could not render the stack with $ENV_FILE (run 'docker compose --env-file $ENV_FILE config' on the host to see why)."
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi
echo "Preflight passed."
