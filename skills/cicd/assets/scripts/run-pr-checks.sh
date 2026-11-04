#!/usr/bin/env bash
# Run every check for every affected app in one job, several apps at a time,
# and write a Markdown summary of what passed and what failed.
#
#   scripts/run-pr-checks.sh api web        # the apps detect-affected.sh printed
#   scripts/run-pr-checks.sh                # nothing affected: a "nothing to check" summary
#
# Each check is an npm script run in the app's workspace (npm run -w). An app
# without that script shows "—" (skipped), not a failure. Exit 1 when any check
# failed, so the job fails; the summary says which.
#
# Env: CHECKS_PARALLEL (apps at once, default 2: a hosted runner for a private
# repo has 2 CPUs), CHECKS_OUT (log dir, default .checks), CHECKS_SUMMARY
# (default $CHECKS_OUT/summary.md), CHECKS_SHA (commit shown in the summary).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SELF="$ROOT_DIR/scripts/$(basename "${BASH_SOURCE[0]}")"
cd "$ROOT_DIR"

APPS_DIR="<APPS_DIR>"      # e.g. apps
CHECKS=(build lint test)   # npm script names, in the order they run per app

OUT="${CHECKS_OUT:-.checks}"
SUMMARY="${CHECKS_SUMMARY:-$OUT/summary.md}"
PARALLEL="${CHECKS_PARALLEL:-2}"

has_script() { # <app> <script>
  node -e 'const p=require(process.argv[1]);process.exit(p.scripts&&p.scripts[process.argv[2]]?0:1)' \
    "$ROOT_DIR/$APPS_DIR/$1/package.json" "$2"
}

# One app, every check in order. Runs in its own process (see --target below),
# so parallel apps never share shell state. Each check leaves <check>.log and
# <check>.result ("pass|fail|skip <seconds>") in $OUT/<app>/.
check_target() {
  local app="$1" dir="$OUT/$1" check start status
  mkdir -p "$dir"
  for check in "${CHECKS[@]}"; do
    if ! has_script "$app" "$check"; then
      echo "skip 0" >"$dir/$check.result"
      continue
    fi
    start=$(date +%s)
    # CHECK_TARGET lets test setup name per-app resources (e.g. a Testcontainers
    # container name), so parallel apps on one Docker daemon don't collide.
    if CHECK_TARGET="$app" npm run --silent -w "$APPS_DIR/$app" "$check" >"$dir/$check.log" 2>&1; then
      status=pass
    else
      status=fail
    fi
    echo "$status $(($(date +%s) - start))" >"$dir/$check.result"
    echo "$app $check: $status"
  done
}

if [ "${1:-}" = --target ]; then
  check_target "$2"
  exit 0
fi

mkdir -p "$OUT" "$(dirname "$SUMMARY")"
sha="${CHECKS_SHA:-$(git rev-parse HEAD)}"

if [ "$#" -eq 0 ]; then
  # shellcheck disable=SC2016 # the backticks are Markdown, not a command
  printf '## ✅ PR checks: nothing to check\n\nNo app changed in `%s`.\n' "$sha" >"$SUMMARY"
  exit 0
fi

started=$(date +%s)
# Re-invoke this script per app: xargs -P can only run commands, not functions.
printf '%s\n' "$@" | xargs -P "$PARALLEL" -I{} bash "$SELF" --target {}

icon() { case "$1" in pass) echo "✅ ${2}s" ;; fail) echo "❌ ${2}s" ;; *) echo "—" ;; esac; }

failed=0 rows="" details=""
for app in "$@"; do
  row="| \`$app\` |"
  for check in "${CHECKS[@]}"; do
    read -r status secs <"$OUT/$app/$check.result" || status=missing
    row="$row $(icon "$status" "${secs:-0}") |"
    if [ "$status" = fail ]; then
      failed=$((failed + 1))
      # The last lines of the log, with the checkout path stripped and long
      # lines cut, so the excerpt fits a PR comment.
      excerpt=$(tail -n 60 "$OUT/$app/$check.log" | sed "s|$ROOT_DIR/||g" | cut -c1-300)
      details="$details
<details><summary><code>$app</code> $check</summary>

\`\`\`
$excerpt
\`\`\`

</details>
"
    fi
  done
  rows="$rows$row
"
done

header="| App |"
divider="|---|"
for check in "${CHECKS[@]}"; do header="$header $check |"; divider="$divider---|"; done

if [ "$failed" -eq 0 ]; then title="## ✅ PR checks passed"; else title="## ❌ PR checks failed: $failed check(s)"; fi

{
  echo "$title"
  echo
  echo "Commit \`$sha\` · $# app(s) · $(($(date +%s) - started))s"
  echo
  echo "$header"
  echo "$divider"
  printf '%s' "$rows"
  echo
  echo "— skipped: the app has no such npm script."
  printf '%s' "$details"
} >"$SUMMARY"

# A PR comment holds at most 65536 characters.
if [ "$(wc -c <"$SUMMARY")" -gt 60000 ]; then
  head -c 60000 "$SUMMARY" >"$SUMMARY.tmp"
  printf '\n\n... truncated; see the job log.\n' >>"$SUMMARY.tmp"
  mv "$SUMMARY.tmp" "$SUMMARY"
fi

[ "$failed" -eq 0 ]
