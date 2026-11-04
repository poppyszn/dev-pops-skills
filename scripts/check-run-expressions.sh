#!/usr/bin/env bash
# No ${{ }} expression anywhere in a `run:` body, comments included, in any
# workflow or composite action the skills ship or this repo runs. GitHub
# evaluates expressions in the whole body: an input pasted into script source
# is the script-injection pattern the cicd and security skills forbid, and a
# `secrets` expression inside a composite action stops the action loading at
# all (the context does not exist there). actionlint does not read action.yml
# files, so this check covers them. Needs python3 with PyYAML.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
git ls-files -z '*.yml' '*.yaml' | python3 -c '
import sys, yaml
files = [f for f in sys.stdin.read().split("\0") if f and ("/workflows/" in f or "/actions/" in f or "github-actions/" in f) and not f.startswith("evals/workspaces/")]
def runs(node):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "run" and isinstance(v, str):
                yield v
            else:
                yield from runs(v)
    elif isinstance(node, list):
        for x in node:
            yield from runs(x)
hits = 0
for f in files:
    for body in runs(yaml.safe_load(open(f))):
        for line in body.splitlines():
            if "${{" in line:
                hits += 1
                print(f"FAIL  {f}: {line.strip()[:110]}")
print(f"{len(files)} workflow/action file(s) checked: {hits} expression(s) inside run bodies")
sys.exit(1 if hits else 0)
'
