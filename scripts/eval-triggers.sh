#!/usr/bin/env bash
# Does the right skill load for a given request? Checks evals/triggers.json.
#
#   scripts/eval-triggers.sh --lint        offline: dataset is well-formed and covers every skill
#   scripts/eval-triggers.sh --run         live: ask a headless agent each prompt, see which skill it loads
#   scripts/eval-triggers.sh --parse <f>   print the skills loaded in a saved stream-json transcript
#
# --run needs a logged-in Claude Code CLI (CLAUDE_BIN, default `claude`). Only this
# repo's skills are loaded (--setting-sources "" keeps your user-level skills out),
# and the run is read-only (plan mode, 3 turns). It costs real tokens: set
# EVAL_MODEL (default haiku) and EVAL_LIMIT to bound it. A prompt expecting "none"
# passes when no dev-pops skill loads.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
data="$root/evals/triggers.json"
mode=${1:---lint}

skills_loaded() { # stdin: stream-json; prints one skill name per line
  python3 -c '
import sys, json
for line in sys.stdin:
    try: e = json.loads(line)
    except ValueError: continue
    if e.get("type") != "assistant": continue
    for c in e.get("message", {}).get("content", []):
        if c.get("type") == "tool_use" and c.get("name") == "Skill":
            print(str(c.get("input", {}).get("skill", "")).split(":")[-1])
'
}

case "$mode" in
  --parse)
    skills_loaded < "${2:?usage: --parse <stream-json file>}"
    ;;
  --lint)
    python3 - "$root" <<'PY'
import json, sys, pathlib
root = pathlib.Path(sys.argv[1])
cases = json.loads((root / "evals/triggers.json").read_text())
skills = sorted(p.parent.name for p in (root / "skills").glob("*/SKILL.md"))
errors = []
seen = set()
for i, c in enumerate(cases, 1):
    if not isinstance(c.get("prompt"), str) or not c["prompt"].strip():
        errors.append(f"case {i}: missing prompt")
    if c["prompt"] in seen:
        errors.append(f"case {i}: duplicate prompt")
    seen.add(c["prompt"])
    if c.get("expect") != "none" and c.get("expect") not in skills:
        errors.append(f"case {i}: expect {c.get('expect')!r} is not a skill ({', '.join(skills)})")
for s in skills:
    n = sum(1 for c in cases if c.get("expect") == s)
    if n < 2:
        errors.append(f"skill {s}: {n} positive prompt(s), need at least 2")
if sum(1 for c in cases if c.get("expect") == "none") < 3:
    errors.append("need at least 3 prompts that should load no skill")
print(f"{len(cases)} cases, {len(skills)} skills")
for e in errors: print("FAIL", e)
sys.exit(1 if errors else 0)
PY
    ;;
  --run)
    bin=${CLAUDE_BIN:-claude}
    command -v "$bin" >/dev/null || { echo "CLAUDE_BIN not found: $bin" >&2; exit 2; }
    model=${EVAL_MODEL:-haiku}; limit=${EVAL_LIMIT:-1000}
    pass=0; total=0; failed=()
    work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
    while IFS=$'\t' read -r expect prompt; do
      [ "$total" -lt "$limit" ] || break
      total=$((total+1))
      ( cd "$work" && "$bin" -p "$prompt" --plugin-dir "$root" --setting-sources "" \
          --output-format stream-json --verbose --max-turns 3 --model "$model" \
          --no-session-persistence --permission-mode plan < /dev/null > out.jsonl 2> err.txt ) || true
      if grep -q 'Not logged in' "$work/out.jsonl" "$work/err.txt" 2>/dev/null; then
        echo "The CLI is not logged in; run it once interactively first." >&2; exit 2
      fi
      got=$(skills_loaded < "$work/out.jsonl" | paste -sd' ' -)
      if { [ "$expect" = none ] && [ -z "$got" ]; } || { [ "$expect" != none ] && [[ " $got " == *" $expect "* ]]; }; then
        pass=$((pass+1)); printf 'PASS  %-16s %s\n' "$expect" "$prompt"
      else
        failed+=("$expect | got: ${got:-nothing} | $prompt"); printf 'FAIL  %-16s %s\n      loaded: %s\n' "$expect" "$prompt" "${got:-nothing}"
      fi
    done < <(python3 -c '
import json, sys
for c in json.load(open(sys.argv[1])): print(c["expect"] + "\t" + c["prompt"])' "$data")
    echo; echo "$pass / $total prompts loaded the expected skill (model: $model)"
    [ "$pass" -eq "$total" ]
    ;;
  *) echo "usage: $0 --lint | --run | --parse <file>" >&2; exit 2 ;;
esac
