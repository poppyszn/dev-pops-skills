#!/usr/bin/env bash
# Mechanical checklist for "dockerize a Node API with Postgres". Reads files only;
# never builds or pulls. Usage: check-dockerize.sh <project-dir>
# The checks encode this repo's own defaults, so they favour the skills; read the
# list before reading the score.
set -uo pipefail
dir=${1:?usage: check-dockerize.sh <project-dir>}
cd "$dir"

dockerfiles=$(find . -name 'Dockerfile*' -not -path './node_modules/*' | sort)
composes=$(find . \( -name 'compose*.yml' -o -name 'compose*.yaml' -o -name 'docker-compose*.yml' \) -not -path './node_modules/*' | sort)
[ -n "$dockerfiles" ] || dockerfiles=/dev/null
[ -n "$composes" ] || composes=/dev/null
pass=0; total=0
check() { # name, result(0=pass)
  total=$((total+1))
  if [ "$2" -eq 0 ]; then pass=$((pass+1)); printf '  PASS  %s\n' "$1"; else printf '  FAIL  %s\n' "$1"; fi
}
has() { local pat=$1; shift; grep -qE "$pat" $* 2>/dev/null; }

[ "$dockerfiles" != /dev/null ]; check "a Dockerfile exists" $?
# every FROM names an explicit tag that is not latest (build-stage aliases excluded)
bad=$(grep -hE '^FROM ' $dockerfiles | awk '{print $2}' | grep -vxE "$(grep -hiE '^FROM .* AS ' $dockerfiles | awk '{print tolower($NF)}' | paste -sd'|' - | sed 's/^$/@@none@@/')" | grep -vE ':[A-Za-z0-9._-]+' ; grep -hE '^FROM [^ ]+:latest' $dockerfiles)
[ -z "$bad" ]; check "base images pinned to an explicit non-latest tag" $?
[ "$(cat $dockerfiles | grep -cE '^FROM ')" -ge 2 ]; check "multi-stage build" $?
has '^USER +[^r ]' $dockerfiles; check "runs as a non-root USER" $?
{ has '^HEALTHCHECK' $dockerfiles || has 'healthcheck:' $composes; }; check "the API has a healthcheck" $?
[ -f .dockerignore ] && grep -qE 'node_modules' .dockerignore && grep -qE '^\.env' .dockerignore; check ".dockerignore excludes node_modules and .env" $?
has 'omit=dev|--production|prune|--prod' $dockerfiles; check "dev dependencies kept out of the runtime image" $?
has 'pg_isready' $composes; check "Postgres has a pg_isready healthcheck" $?
has 'service_healthy' $composes; check "dependents wait for service_healthy" $?
has 'migrate' $composes; check "migrations run as their own one-shot step" $?
# secrets: no password with a literal default in compose
! grep -E 'PASSWORD' $composes | grep -qE ':-[^}]+\}|: *[A-Za-z0-9]+ *$'; check "no default password baked into compose" $?
# the database port is not published on all interfaces
! grep -E '^\s*-\s*"?[0-9]+:5432' $composes | grep -vq '127.0.0.1'; check "database port not published on every interface" $?
# a deploy path: a compose file that pulls images instead of building
pull_based() { local f; for f in $composes; do grep -qE "image:.*(ghcr|<)" "$f" && ! grep -qE '^\s*build:' "$f" && return 0; done; return 1; }
pull_based; check "a pull-based compose file for deploying" $?
ok=0
if command -v docker >/dev/null 2>&1 && [ "$composes" != /dev/null ]; then
  tmp=$(mktemp -d); cp -R . "$tmp/p"; [ -f "$tmp/p/.env" ] || { [ -f "$tmp/p/.env.example" ] && cp "$tmp/p/.env.example" "$tmp/p/.env"; }
  for f in $composes; do (cd "$tmp/p" && docker compose --env-file .env -f "$f" config -q >/dev/null 2>&1) && ok=1; done
  rm -rf "$tmp"
fi
[ "$ok" -eq 1 ]; check "at least one compose file passes docker compose config -q (after cp .env.example .env)" $?
echo "  ---- $pass / $total"
