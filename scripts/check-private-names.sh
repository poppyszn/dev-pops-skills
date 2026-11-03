#!/usr/bin/env bash
# Fails if a private client, project or repository name, or a personal path,
# appears in any file that is tracked or about to be (untracked, not ignored).
#
# Names come from a local, gitignored `.private-names` file (one per line, `#`
# comments allowed) and/or the PRIVATE_NAMES environment variable (newline- or
# comma-separated; set it from a repository secret in CI). Names match as whole
# words, case-insensitively, so list distinctive ones. With neither, only
# the built-in checks run:
#   - home-directory paths (/Users/<name>/, /home/<name>/, ~/Code/...)
#   - a `**Where found:**` line in contributions/ naming an `owner/repo`
#     that is not a path in this repository
#
# Matches are reported as file:line only, never the matched text, so a CI
# log on a public repo cannot repeat the name it caught.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
python3 - <<'PY'
import os, re, subprocess, pathlib, sys
root = pathlib.Path(".")
names = []
f = root / ".private-names"
if f.exists():
    names += [l.strip() for l in f.read_text().splitlines() if l.strip() and not l.strip().startswith("#")]
env = os.environ.get("PRIVATE_NAMES", "")
names += [n.strip() for n in re.split(r"[\n,]", env) if n.strip()]
names = sorted({n.lower() for n in names if len(n) >= 3})
# Whole-word, case-insensitive: "acme" matches "Acme-api" but not "acmes".
patterns = [re.compile(r"(?<![a-z0-9])" + re.escape(n) + r"(?![a-z0-9])") for n in names]

files = subprocess.check_output(["git", "ls-files", "-co", "--exclude-standard"], text=True).split("\n")
files = [p for p in files if p and p != ".private-names" and pathlib.Path(p).is_file()]
home = re.compile(r"(/Users/[a-z][a-z0-9._-]+/|/home/[a-z][a-z0-9._-]+/|~/Code/)")
slug = re.compile(r"`([A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+)`")
# First path segments that mean "a folder inside a project", not an owner.
project_dirs = {"apps", "packages", "libs", "services", "src", "docker", "docs", "scripts", "skills",
                "assets", "references", ".github", "infra", "terraform", "deploy", "config", "tools"}
hits = []
for p in files:
    try:
        lines = pathlib.Path(p).read_text().splitlines()
    except (UnicodeDecodeError, OSError):
        continue
    for i, line in enumerate(lines, 1):
        low = line.lower()
        if any(pt.search(low) for pt in patterns):
            hits.append(f"{p}:{i}: a name from the private list")
        if home.search(line) and p != "scripts/check-private-names.sh":
            hits.append(f"{p}:{i}: a home-directory path")
        if p.startswith("contributions/") and line.startswith("**Where found:**"):
            for s in slug.findall(line):
                parts = s.strip("/").split("/")
                looks_like_repo = len(parts) == 2 and "." not in parts[1] and parts[0].lower() not in project_dirs
                if looks_like_repo and not any((base / s).exists() for base in [root, *root.glob("skills/*"), root / "skills"]):
                    hits.append(f"{p}:{i}: 'Where found' names `owner/repo`-style path that is not in this repo")
for h in hits:
    print("FAIL ", h)
src = ".private-names" if f.exists() else ""
if env: src = (src + " + PRIVATE_NAMES").lstrip(" +")
print(f"{len(files)} files checked against {len(names)} private name(s){' from ' + src if src else ''} and the built-in checks: {len(hits)} hit(s)")
sys.exit(1 if hits else 0)
PY
