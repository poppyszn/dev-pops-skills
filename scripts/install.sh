#!/usr/bin/env bash
# Symlink every skill in skills/ into the directories each agent scans.
# Symlinks keep one source of truth: edits in this repo show up everywhere.
#
# Usage:
#   scripts/install.sh [--uninstall] <target>...
#   scripts/install.sh [--uninstall] --project <dir>
#
# Targets (user-level):
#   claude       ~/.claude/skills
#   antigravity  ~/.gemini/config/skills   (read by Antigravity app, IDE and CLI)
#   agents       ~/.agents/skills          (optional vendor-neutral path for other agents)
#   all          claude + antigravity
#
# --project <dir> links into <dir>/.agents/skills and <dir>/.claude/skills.
#
# Paths are external facts: see skills/skill-authoring/references/sources.md.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
mode=install

usage() { awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"; exit "${1:-0}"; }

target_dir() {
  case "$1" in
    claude)      echo "$HOME/.claude/skills" ;;
    antigravity) echo "$HOME/.gemini/config/skills" ;;
    agents)      echo "$HOME/.agents/skills" ;;
    *) return 1 ;;
  esac
}

link_into() {
  local dest="$1" src name link
  [[ $mode == install ]] && mkdir -p "$dest"
  for src in "$repo"/skills/*/; do
    src="${src%/}"
    name="$(basename "$src")"
    link="$dest/$name"
    if [[ $mode == uninstall ]]; then
      # Only remove links that point back into this repo.
      if [[ -L "$link" && "$(readlink "$link")" == "$src" ]]; then
        rm "$link" && echo "removed $link"
      fi
    elif [[ -L "$link" && "$(readlink "$link")" == "$src" ]]; then
      echo "ok      $link"
    elif [[ -e "$link" || -L "$link" ]]; then
      echo "skip    $link (exists and is not ours)" >&2
    else
      ln -s "$src" "$link" && echo "linked  $link"
    fi
  done
}

[[ $# -gt 0 ]] || usage 1
if [[ $1 == --uninstall ]]; then mode=uninstall; shift; fi
[[ $# -gt 0 ]] || usage 1

case "$1" in
  -h|--help) usage 0 ;;
  --project)
    [[ -n "${2:-}" && -d "$2" ]] || { echo "--project needs an existing directory" >&2; exit 1; }
    proj="$(cd "$2" && pwd)"
    link_into "$proj/.agents/skills"
    link_into "$proj/.claude/skills"
    ;;
  *)
    # Resolve every target before touching the filesystem.
    dests=()
    for t in "$@"; do
      if [[ $t == all ]]; then
        for a in claude antigravity; do dests+=("$(target_dir "$a")"); done
      elif d="$(target_dir "$t")"; then
        dests+=("$d")
      else
        echo "unknown target: $t" >&2
        usage 1 >&2
      fi
    done
    for d in "${dests[@]}"; do link_into "$d"; done
    ;;
esac
