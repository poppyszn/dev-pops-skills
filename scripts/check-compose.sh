#!/usr/bin/env bash
# `docker compose config -q` for every compose file the skills ship. Renders and
# validates only: no image is pulled and nothing is started. Each file is checked
# in a scratch copy of its directory with a `.env` made from the nearest
# `.env.example` (or `env.production.example` for the production file, else an empty file), because the templates expect that file to exist.
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
command -v docker >/dev/null || { echo "docker not found" >&2; exit 2; }
status=0; n=0
while IFS= read -r f; do
  n=$((n+1)); dir=$(dirname "$f"); tmp=$(mktemp -d)
  # copy the project root the file lives in (the nearest ancestor holding .env.example, else its own dir)
  proj=$dir; while [ "$proj" != "$root/skills" ] && [ ! -f "$proj/.env.example" ] && [ "$proj" != "/" ]; do proj=$(dirname "$proj"); done
  [ -f "$proj/.env.example" ] || proj=$dir
  cp -R "$proj/." "$tmp/" 2>/dev/null
  if [ ! -f "$tmp/.env" ]; then
    if [ -f "$tmp/.env.example" ]; then cp "$tmp/.env.example" "$tmp/.env"
    elif [[ "$f" == *production* && -f "$tmp/env.production.example" ]]; then cp "$tmp/env.production.example" "$tmp/.env"
    else : > "$tmp/.env"; fi
  fi
  rel=${f#"$proj"/}
  if out=$(cd "$tmp" && docker compose --env-file .env -f "$rel" config -q 2>&1); then
    echo "ok    ${f#"$root"/}"
  else
    echo "FAIL  ${f#"$root"/}"; echo "$out" | head -4 | sed 's/^/      /'; status=1
  fi
  rm -rf "$tmp"
done < <(find "$root/skills" -path '*/assets/*' \( -name 'compose*.yml' -o -name 'compose*.yaml' -o -name 'docker-compose*.yml' \) | sort)
echo "$n compose file(s) checked"
exit $status
