#!/usr/bin/env bash
# Validate skills against references/standard.md (which builds on the Agent
# Skills spec: https://agentskills.io/specification).
#
# Usage: validate.sh [skill-dir...]
#   No arguments: validate every skill next to this one.
#   STALE_DAYS=<n> changes the staleness warning threshold (default 90).
#
# FAIL lines exit non-zero. WARN lines are reported but don't fail.
set -euo pipefail

# Resolve symlinks so an installed (linked) copy still finds the real repo.
skills_root="$(cd -P "$(dirname "$0")/../.." && pwd)"
stale_days="${STALE_DAYS:-90}"
required_headings=("When to use" "Defaults" "Workflow" "Requires confirmation" "Verification")
status=0

fail() { echo "FAIL $1: $2"; failed=1; status=1; }
warn() { echo "WARN $1: $2"; }

to_epoch() { date -j -f %Y-%m-%d "$1" +%s 2>/dev/null || date -d "$1" +%s 2>/dev/null; }

# Read a top-level or metadata frontmatter value, stripping optional quotes.
fm_value() {
  sed -nE "s/^$2:[[:space:]]*(.*[^[:space:]])[[:space:]]*$/\1/p" <<<"$1" | head -n 1 \
    | sed -E 's/^"(.*)"$/\1/; s/^'\''(.*)'\''$/\1/'
}

validate() {
  local dir="${1%/}" skill file frontmatter name desc version verified lines hits
  skill="$(basename "$dir")"
  file="$dir/SKILL.md"
  failed=0

  if [[ ! -f "$file" ]]; then fail "$skill" "missing SKILL.md"; return; fi
  if [[ "$(head -n 1 "$file")" != "---" ]]; then
    fail "$skill" "SKILL.md must start with '---' frontmatter"; return
  fi

  frontmatter="$(awk 'NR==1{next} /^---$/{exit} {print}' "$file")"
  name="$(fm_value "$frontmatter" name)"
  desc="$(fm_value "$frontmatter" description)"
  version="$(fm_value "$frontmatter" '[[:space:]]+version')"
  verified="$(fm_value "$frontmatter" '[[:space:]]+last-verified')"

  # Name and description (Agent Skills spec).
  [[ "$name" == "$skill" ]] || fail "$skill" "name '$name' does not match folder '$skill'"
  [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "$skill" "name must be lowercase a-z/0-9, single hyphens, no leading/trailing hyphen"
  (( ${#name} <= 64 )) || fail "$skill" "name is ${#name} chars (max 64)"
  [[ -n "$desc" ]] || fail "$skill" "missing description"
  (( ${#desc} <= 1024 )) || fail "$skill" "description is ${#desc} chars (max 1024)"
  [[ "$desc" == "Use when"* ]] || warn "$skill" "description should start with 'Use when'"
  [[ "$desc" == *"Not for"* ]] || warn "$skill" "description should name neighbours with 'Not for … (use X)'"

  # Version and changelog (standard §2, §10).
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail "$skill" "metadata.version missing or not semver (got '$version')"
  elif [[ ! -f "$dir/CHANGELOG.md" ]]; then
    fail "$skill" "missing CHANGELOG.md"
  elif ! grep -qE "^## \[?${version//./\\.}\]?([[:space:]]|$)" "$dir/CHANGELOG.md"; then
    fail "$skill" "CHANGELOG.md has no '## $version' entry"
  fi

  # Freshness (standard §7).
  [[ -f "$dir/references/sources.md" ]] || fail "$skill" "missing references/sources.md"
  if [[ ! "$verified" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || ! to_epoch "$verified" >/dev/null; then
    fail "$skill" "metadata.last-verified missing or not YYYY-MM-DD (got '$verified')"
  else
    local age=$(( ($(date +%s) - $(to_epoch "$verified")) / 86400 ))
    (( age <= stale_days )) || warn "$skill" "last verified $age days ago (> $stale_days); run an audit"
  fi

  # Required sections (standard §3).
  local h
  for h in "${required_headings[@]}"; do
    grep -qE "^## ${h}[[:space:]]*$" "$file" || fail "$skill" "missing '## $h' section"
  done
  if ! grep -qE '^## Examples[[:space:]]*$' "$file" && [[ ! -f "$dir/references/examples.md" ]]; then
    fail "$skill" "missing '## Examples' section or references/examples.md"
  fi

  # Size (standard §8).
  lines="$(wc -l <"$file" | tr -d ' ')"
  (( lines <= 500 )) || warn "$skill" "SKILL.md is $lines lines; move detail into references/"

  # Placeholders and agent-neutral wording (standard §9). sources.md and
  # CHANGELOG.md may name products.
  local docs=("$file")
  [[ -d "$dir/references" ]] && while IFS= read -r f; do docs+=("$f"); done \
    < <(find "$dir/references" -name '*.md' ! -name sources.md)

  if hits="$(grep -n 'TODO' "${docs[@]}")"; then
    warn "$skill" "$(wc -l <<<"$hits" | tr -d ' ') TODO placeholder(s) left"
  fi
  if hits="$(grep -nEi '\b(claude|gemini|antigravity|codex|copilot|cursor|windsurf)\b' "${docs[@]}")"; then
    warn "$skill" "agent-specific wording (skills should be agent-neutral):"
    sed "s#^$dir/#       #" <<<"$hits"
  fi

  # Every bundled file must be discoverable from SKILL.md (standard §3):
  # each references/*.md, and each top-level entry in assets/ and scripts/.
  local entry
  for entry in "$dir"/references/*.md "$dir"/assets/* "$dir"/scripts/*; do
    [[ -e "$entry" ]] || continue
    grep -qF "$(basename "$entry")" "$file" \
      || warn "$skill" "${entry#"$dir"/} is not mentioned in SKILL.md"
  done

  # Vendored copies must match their source asset byte for byte (standard §11).
  local vf src_skill src_path
  while IFS= read -r vf; do
    src_skill="$(sed -nE '1s/^# Vendored verbatim from the dev-pops ([a-z0-9-]+) skill: ([^ ]+)$/\1/p' "$vf")"
    src_path="$(sed -nE '1s/^# Vendored verbatim from the dev-pops ([a-z0-9-]+) skill: ([^ ]+)$/\2/p' "$vf")"
    if [[ ! -f "$skills_root/$src_skill/$src_path" ]]; then
      fail "$skill" "${vf#"$dir"/} is vendored from missing $src_skill/$src_path"
    elif ! tail -n +3 "$vf" | cmp -s - "$skills_root/$src_skill/$src_path"; then
      fail "$skill" "${vf#"$dir"/} has drifted from $src_skill/$src_path (re-copy it)"
    fi
  done < <([[ -d "$dir/assets" ]] && grep -rlE '^# Vendored verbatim from the dev-pops [a-z0-9-]+ skill: ' "$dir/assets" || true)

  (( failed )) || echo "ok   $skill ($version)"
}

if [[ $# -eq 0 ]]; then
  set -- "$skills_root"/*/
fi

for d in "$@"; do
  if [[ -d "$d" ]]; then validate "$d"; else echo "FAIL $d: not a directory"; status=1; fi
done

exit $status
