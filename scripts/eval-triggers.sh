#!/usr/bin/env bash
# Does the right skill load for a given request? Checks evals/triggers.json.
#
#   scripts/eval-triggers.sh --lint        offline: dataset is well-formed and covers every skill
#   scripts/eval-triggers.sh --run         live: ask a headless agent each prompt, see which skill it loads
#   scripts/eval-triggers.sh --parse <f>   print the skills loaded in a saved stream-json transcript
#
# --run needs a logged-in Claude Code CLI (CLAUDE_BIN, default `claude`). Only this
# repo's skills are loaded (--setting-sources "" keeps your user-level skills out).
# Each prompt runs against a fresh copy of evals/workspaces/base plus the case's
# optional overlay. Runs are kept as cheap as possible, because each one is a
# real agent session on your account:
#   - it stops the moment a skill loads (that is the only thing measured)
#   - read-only tools only (Skill, Read, Glob, Grep): nothing is written or run
#   - at most EVAL_MAX_TURNS turns (default 3) and EVAL_BUDGET dollars (default 0.03)
#   - by default a sample: the first prompt for each skill and two that should
#     load none (9 runs). EVAL_ALL=1 runs every prompt; EVAL_ONLY=<skill> runs
#     that skill's prompts. EVAL_LIMIT=<n> caps the count. EVAL_MODEL (default haiku).
# A prompt expecting "none" passes when no dev-pops skill loads.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
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
    w = c.get("workspace")
    if w is not None and not (root / "evals/workspaces" / w).is_dir():
        errors.append(f"case {i}: workspace {w!r} is not a folder in evals/workspaces/")
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
    command -v "$bin" >/dev/null || { echo "CLAUDE_BIN not found: $bin (install the Claude Code CLI and log in once, or set CLAUDE_BIN)" >&2; exit 2; }
    python3 - "$root" "$bin" <<'PY'
import json, os, shutil, subprocess, sys, tempfile, time, pathlib
root, binary = pathlib.Path(sys.argv[1]), sys.argv[2]
model = os.environ.get("EVAL_MODEL", "haiku")
turns = os.environ.get("EVAL_MAX_TURNS", "3")
budget = os.environ.get("EVAL_BUDGET", "0.03")
cases = json.loads((root / "evals/triggers.json").read_text())
only = os.environ.get("EVAL_ONLY")
if only:
    cases = [c for c in cases if c["expect"] == only]
elif os.environ.get("EVAL_ALL") != "1":
    seen, sample, nones = set(), [], 0
    for c in cases:
        if c["expect"] == "none":
            if nones < 2: sample.append(c); nones += 1
        elif c["expect"] not in seen:
            seen.add(c["expect"]); sample.append(c)
    cases = sample
cases = cases[:int(os.environ.get("EVAL_LIMIT", len(cases)))]
print(f"{len(cases)} prompt(s), model {model}, at most {turns} turns and ${budget} each\n")
passed, spent = 0, 0.0
for c in cases:
    work = pathlib.Path(tempfile.mkdtemp()) / "p"
    shutil.copytree(root / "evals/workspaces/base", work)
    if c.get("workspace"):
        shutil.copytree(root / "evals/workspaces" / c["workspace"], work, dirs_exist_ok=True)
    cmd = [binary, "-p", c["prompt"], "--plugin-dir", str(root), "--setting-sources", "",
           "--tools", "Skill,Read,Glob,Grep", "--max-turns", turns, "--max-budget-usd", budget,
           "--output-format", "stream-json", "--verbose", "--model", model,
           "--no-session-persistence", "--permission-mode", "plan"]
    proc = subprocess.Popen(cmd, cwd=work, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL, text=True)
    loaded, cost, deadline = None, None, time.time() + 180
    for line in proc.stdout:
        if "Not logged in" in line:
            proc.kill(); sys.exit("The CLI is not logged in; run it once interactively first.")
        try: e = json.loads(line)
        except ValueError: continue
        if e.get("type") == "assistant":
            for part in e.get("message", {}).get("content", []):
                if part.get("type") == "tool_use" and part.get("name") == "Skill":
                    loaded = str(part.get("input", {}).get("skill", "")).split(":")[-1]
        if e.get("type") == "result":
            cost = e.get("total_cost_usd")
        if loaded or time.time() > deadline:
            proc.kill(); break          # the answer is known: stop spending
    proc.wait()
    shutil.rmtree(work.parent, ignore_errors=True)
    ok = (loaded is None) if c["expect"] == "none" else (loaded == c["expect"])
    passed += ok
    if cost: spent += cost
    note = "" if cost is None else f"  (${cost:.3f})"
    print(f"{'PASS' if ok else 'FAIL'}  {c['expect']:16} {c['prompt']}" + ("" if ok else f"\n      loaded: {loaded or 'nothing'}") + note)
print(f"\n{passed} / {len(cases)} prompts loaded the expected skill (model: {model})")
if spent: print(f"reported cost of runs that finished on their own: ${spent:.3f} (runs stopped early report none)")
sys.exit(0 if passed == len(cases) else 1)
PY
    ;;
  *) echo "usage: $0 --lint | --run | --parse <file>" >&2; exit 2 ;;
esac
