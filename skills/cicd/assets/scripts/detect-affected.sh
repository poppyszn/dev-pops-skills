#!/usr/bin/env bash
# Print the apps a change touches, one per line, from a git base ref to HEAD.
#
#   scripts/detect-affected.sh origin/develop     # a pull request: base branch
#   scripts/detect-affected.sh "$BEFORE_SHA"      # a push: the commit before it
#
# One script for PR checks, deploys and a pre-push hook, so their rules cannot
# drift. A change under <APPS_DIR>/<app>/ affects that app; a change to a
# shared path (below) affects every app. No `mapfile`: it runs on macOS bash 3.2.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

APPS_DIR="<APPS_DIR>" # e.g. apps

# Paths every app depends on (extended regex, matched against each changed
# path). Add the shared library folder and anything the images or the deploy
# read for every app (a bake file, a shared entrypoint, the deploy compose file).
SHARED='^(<SHARED_DIR>/|package\.json$|package-lock\.json$|tsconfig[^/]*\.json$|docker-bake\.hcl$)'

base="${1:?usage: detect-affected.sh <base-ref>}"
git rev-parse --verify --quiet "${base}^{commit}" >/dev/null ||
  { echo "detect-affected: unknown base ref: $base" >&2; exit 1; }

# Three dots: what HEAD added since it left the base. For a push the base is an
# ancestor, so this is the same as two dots.
changed=$(git diff --name-only "${base}...HEAD")
[ -n "$changed" ] || exit 0

all=$(find "$APPS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)

if printf '%s\n' "$changed" | grep -qE "$SHARED"; then
  printf '%s\n' "$all"
  exit 0
fi

for app in $all; do
  if printf '%s\n' "$changed" | grep -q "^$APPS_DIR/$app/"; then
    echo "$app"
  fi
done
