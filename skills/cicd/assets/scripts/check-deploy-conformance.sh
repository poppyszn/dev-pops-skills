#!/usr/bin/env bash
# Lists every way a project's deploy pipeline differs from the standard
# (references/deploy-pipeline.md). Read-only. Run from anywhere:
#
#   bash check-deploy-conformance.sh [project-dir]
#
# The standard is read from this script's own skill (../deploy-workflows/), so
# a project's copies are compared byte for byte with the version the skill
# ships. Exits 0 when the project conforms, 1 when it lists differences.
# Portable to bash 3.2 (macOS).
set -uo pipefail

skill_assets="$(cd "$(dirname "$0")/.." && pwd)/deploy-workflows"
[ -d "$skill_assets" ] || { echo "standard not found: $skill_assets" >&2; exit 2; }
dir=${1:-.}
cd "$dir" || { echo "no such directory: $dir" >&2; exit 2; }
wf=.github/workflows
problems=0
say() { echo "  - $1"; problems=$((problems + 1)); }

echo "Deploy pipeline conformance: $(basename "$(pwd)")"

# 1. The two pipeline files are verbatim copies: two header lines, then the
#    skill's file unchanged. A hand edit shows up here, as does an old version.
pipeline_file="_deploy-pipeline.yml"
if [ -f "$wf/_deploy-pipeline-bake.yml" ] && [ ! -f "$wf/_deploy-pipeline.yml" ]; then
  pipeline_file="_deploy-pipeline-bake.yml"
fi

for f in "$pipeline_file" _run-service.yml; do
  if [ ! -f "$wf/$f" ]; then
    say "$wf/$f is missing (copy it from the skill's assets/deploy-workflows/ with the two vendored-copy header lines)"
  else
    head -1 "$wf/$f" | grep -q '^# Vendored verbatim from the dev-pops cicd skill: assets/deploy-workflows/' \
      || say "$wf/$f is missing its vendored-copy header"
    cmp -s <(tail -n +3 "$wf/$f") "$skill_assets/$f" \
      || say "$wf/$f differs from the skill's $f (re-copy it; do not edit the copy)"
  fi
done

# 2. The project's own entry points call the local pipeline.
if [ ! -f "$wf/deploy.yml" ]; then
  say "$wf/deploy.yml is missing (copy the skill's deploy.yml and fill its markers)"
else
  grep -qE 'uses: \./\.github/workflows/_deploy-pipeline(-bake)?\.yml' "$wf/deploy.yml" \
    || say "$wf/deploy.yml does not call ./.github/workflows/_deploy-pipeline.yml (or _deploy-pipeline-bake.yml)"
  grep -qE '^ *secrets: inherit' "$wf/deploy.yml" \
    || say "$wf/deploy.yml does not pass 'secrets: inherit' (environment secrets would arrive empty)"
  grep -qE '^ *verify:' "$wf/deploy.yml" \
    || say "$wf/deploy.yml has no 'verify' job before the deploy"
fi
for f in seed migrate; do
  if [ -f "$wf/$f.yml" ] && ! grep -qE 'uses: \./\.github/workflows/_run-service\.yml' "$wf/$f.yml"; then
    say "$wf/$f.yml does not call ./.github/workflows/_run-service.yml"
  fi
done

# 3. No legacy or per-environment pipeline files left beside them.
for f in "$wf"/*.yml "$wf"/*.yaml; do
  [ -e "$f" ] || continue
  case "$(basename "$f")" in
    deploy.yml|_deploy-pipeline.yml|_deploy-pipeline-bake.yml|_run-service.yml|seed.yml|migrate.yml) ;;
    deploy-*|*-deploy*|run-seed*|seed-*|run-migrat*|migrate-*|docker-build-push*|run-service*)
      say "$f is a legacy pipeline file; deploy.yml, seed.yml and migrate.yml replace it" ;;
  esac
done
for d in .github/actions/ssh-compose-deploy .github/actions/git-sync-deploy; do
  [ -d "$d" ] && say "$d is no longer needed: the pipeline deploys without it"
done

# 4. No host-key checking switched off anywhere in the workflows.
if grep -rlqE 'StrictHostKeyChecking[ =]+no' "$wf" .github/actions 2>/dev/null; then
  say "a workflow or action disables SSH host-key checking (pin keys with SSH_KNOWN_HOSTS)"
fi

# 5. Compose files the pipeline deploys: SHA-tagged images and an ignored .env.
for env in develop production; do
  cdir="docker/$env"
  [ -d "$cdir" ] || continue
  compose=""
  for c in compose.yml compose.yaml docker-compose.yml; do
    [ -f "$cdir/$c" ] && compose="$cdir/$c" && break
  done
  if [ -z "$compose" ]; then
    say "$cdir has no compose.yml"
    continue
  fi
  if grep -qE '^ *image: ' "$compose" && ! grep -qE '^ *image: .*\$\{IMAGE_TAG' "$compose"; then
    say "$compose does not tag images with \${IMAGE_TAG} (deploys run the commit SHA)"
  fi
  if ! git check-ignore -q "$cdir/.env" 2>/dev/null; then
    say "$cdir/.env is not gitignored (the deploy's git clean would delete the host's .env)"
  fi
done

if [ "$problems" -eq 0 ]; then
  echo "  conforms"
  exit 0
fi
echo "  $problems difference(s)"
exit 1
