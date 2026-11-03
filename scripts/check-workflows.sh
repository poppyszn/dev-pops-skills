#!/usr/bin/env bash
# actionlint over every workflow the skills ship, laid out the way a project
# would hold them (so `uses: ./.github/workflows/...` resolves), plus this
# repo's own workflows. Needs actionlint on PATH (or ACTIONLINT=/path).
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
lint=${ACTIONLINT:-actionlint}
command -v "$lint" >/dev/null || { echo "actionlint not found (set ACTIONLINT=/path)" >&2; exit 2; }
status=0

# 1. This repo's own workflows.
(cd "$root" && "$lint" -no-color .github/workflows/*.yml) || status=1

# 2. The cicd skill's templates, copied into one scratch project. Placeholders
#    like a `<APP_NAME>` job id are meant to be edited, so they are ignored.
tmp=$(mktemp -d); git init -q "$tmp"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.github/workflows" "$tmp/.github/actions"
cp "$root"/skills/cicd/assets/workflows/*.yml "$tmp/.github/workflows/"
cp -R "$root"/skills/cicd/assets/actions/. "$tmp/.github/actions/"
(cd "$tmp" && "$lint" -no-color -ignore 'invalid job ID "<[A-Z_]+>"' .github/workflows/*.yml) || status=1

# 3. The project-infra example is already a complete project layout.
ex=$(mktemp -d); git init -q "$ex"; trap 'rm -rf "$tmp" "$ex"' EXIT
cp -R "$root/skills/project-infra/assets/monorepo-layout/.github" "$ex/.github"
(cd "$ex" && "$lint" -no-color .github/workflows/*.yml) || status=1

[ "$status" -eq 0 ] && echo "actionlint: all workflows clean"
exit "$status"
