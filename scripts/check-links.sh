#!/usr/bin/env bash
# Broken internal references in the Markdown: relative links, and the
# `references/…`, `assets/…`, `scripts/…` paths a skill names in backticks
# (resolved against that skill's folder). Offline; external URLs are not checked.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
python3 - "$root" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
skip_dirs = {".git", "node_modules"}
# Paths the standard names as illustrations, not as real files.
illustrative = {"references/examples.md", "references/x.md"}
bad = []
def skill_dir(p):
    parts = p.relative_to(root).parts
    return root / parts[0] / parts[1] if len(parts) > 2 and parts[0] == "skills" else None
for md in sorted(root.rglob("*.md")):
    if skip_dirs & set(md.parts) or "docs/history" in md.as_posix():
        continue
    text = md.read_text(errors="replace")
    text_nocode = re.sub(r"```.*?```", "", text, flags=re.S)
    for m in re.finditer(r"\]\(([^)\s#]+)(?:#[^)]*)?\)", text_nocode):
        t = m.group(1)
        if re.match(r"[a-z]+:", t) or t.startswith(("#", "<")):
            continue
        if not (md.parent / t).resolve().exists():
            bad.append(f"{md.relative_to(root)}: link target missing: {t}")
    sd = skill_dir(md)
    if sd:
        for m in re.finditer(r"`((?:references|assets|scripts)/[A-Za-z0-9_./-]+\.[A-Za-z0-9]+)`", text_nocode):
            t = m.group(1)
            if any(c in t for c in "<*{$") or t in illustrative:
                continue
            found = (sd / t).exists() or (root / t).exists() or any((s / t).exists() for s in (root / "skills").iterdir())
            if not found and not list(sd.glob("assets/**/" + pathlib.Path(t).name)):
                bad.append(f"{md.relative_to(root)}: names {t}, not found in {sd.relative_to(root)}")
for b in bad:
    print("FAIL ", b)
print(f"{len(bad)} broken reference(s)")
sys.exit(1 if bad else 0)
PY
