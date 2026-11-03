#!/usr/bin/env bash
# Weekly version-freshness checks, runnable locally or from the workflow:
#   - Docker Hub image tags pinned in skills/*/assets still resolve
#   - GitHub Actions pins in skills/*/assets and .github exist, are not archived,
#     and are not a major behind
#   - no skill is overdue for an online re-check (the validator's last-verified warning)
# Needs: gh (authenticated), curl, jq-free bash. Run from anywhere.
#
#   scripts/freshness-audit.sh [summary-file]
#
# Writes one markdown bullet per finding to summary-file (default: stdout) and
# exits 0 when nothing drifted, 3 when something did.
set -euo pipefail
cd "$(dirname "$0")/.."
summary_file=${1:-$(mktemp)}
: > "$summary_file"
drift_found=0
note() { echo "$1" >> "$summary_file"; drift_found=1; }

echo "Checking Docker Hub image tags still resolve..."
# image:tag pairs from FROM lines, compose image: lines, and
# `docker run ... <image>:<tag>` in workflows. Skips template
# placeholders (<...>, ${...}) and non-Docker-Hub registries.
while IFS=: read -r f ref; do
  image="${ref%%:*}"; tag="${ref#*:}"
  case "$image" in *"<"*|*'$'*|*.*/*) continue ;; esac
  [ "$image" = "$ref" ] && { note "- \`$f\`: \`$ref\` has no tag (unpinned)"; continue; }
  case "$image" in */*) repo_path="$image" ;; *) repo_path="library/$image" ;; esac
  if ! curl -fsS "https://hub.docker.com/v2/repositories/${repo_path}/tags/${tag}/" >/dev/null 2>&1; then
    note "- \`$f\`: \`${image}:${tag}\` not found on Docker Hub: removed, renamed, or never valid"
  fi
done < <(
  grep -rHoE '^FROM [^ ]+|^ *image: [^ ]+|docker run [^\\]* [a-z0-9./-]+:[A-Za-z0-9._-]+' skills --include=Dockerfile --include='*.yml' \
    | grep -F '/assets/' \
    | sed -E 's/^([^:]+):(FROM |[[:space:]]*image: |docker run .* )/\1:/' \
    | sort -u
)

echo "Checking GitHub Actions pins exist and aren't stale..."
for f in $(find skills -path '*/assets/*' -name '*.yml') $(find .github -name '*.yml'); do
  while read -r ref_full; do
    owner_repo="${ref_full%@*}"
    owner=$(echo "$owner_repo" | cut -d/ -f1)
    repo=$(echo "$owner_repo" | cut -d/ -f2)
    ref="${ref_full##*@}"

    if ! gh api "repos/${owner}/${repo}/git/refs/tags/${ref}" >/dev/null 2>&1; then
      note "- \`$f\`: \`${ref_full}\`: ref does not exist for ${owner}/${repo}"
      continue
    fi
    if [ "$(gh api "repos/${owner}/${repo}" --jq .archived)" = "true" ]; then
      note "- \`$f\`: \`${owner}/${repo}\` is archived"
    fi

    # Only compare majors for plain vN pins (e.g. v7); skip exact
    # patch pins (v0.36.0) and non-numeric refs (SHAs).
    if [[ "$ref" =~ ^v[0-9]+$ ]]; then
      latest_major=$(gh api "repos/${owner}/${repo}/tags" --paginate --jq '.[].name' 2>/dev/null | grep -E '^v[0-9]+$' | sort -t v -k2 -n | tail -1)
      pinned_num="${ref#v}"
      latest_num="${latest_major#v}"
      if [ -n "$latest_num" ] && [ "$pinned_num" -lt "$latest_num" ]; then
        note "- \`$f\`: \`${ref_full}\`: pinned major is behind current (\`${latest_major}\` available)"
      fi
    fi
  done < <(grep -oE 'uses: [a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+(/[a-zA-Z0-9_.-]+)*@[a-zA-Z0-9._-]+' "$f" | sed 's/uses: //' | sort -u)
done

echo "Checking skills are within their re-verification window..."
stale=$(./scripts/validate-skills.sh 2>&1 | grep -E 'last verified|FAIL' || true)
if [ -n "$stale" ]; then
  while IFS= read -r line; do note "- skills: ${line}"; done <<< "$stale"
fi

if [ -z "${1:-}" ]; then cat "$summary_file"; fi
[ "$drift_found" -eq 0 ] || exit 3
