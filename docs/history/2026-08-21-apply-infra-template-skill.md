# apply-infra-template Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `apply-infra-template` skill (greenfield + audit modes, apply-time version-freshness checks) and its companion `version-freshness-audit.yml` self-audit workflow, so agents applying templates from this repo reproduce them byte-for-byte instead of paraphrasing, and stale version pins get caught automatically instead of silently propagating.

**Architecture:** The skill is a single `SKILL.md` (standard Claude Code skill frontmatter: `name` + `description`) plus a sibling `README.md`, living at `skills/apply-infra-template/` in this repo — the canonical, single copy. Personal activation is a filesystem symlink into `~/.claude/skills/`, not a second copy. The companion workflow is operational tooling for this repo only (like `.github/dependabot.yml`), living at `.github/workflows/version-freshness-audit.yml`, not in the `ci-cd/github-actions/` template library.

**Tech Stack:** Markdown (skill content), YAML (GitHub Actions), `gh` CLI (GitHub API), `curl`+Docker Hub registry API, `jq`.

## Global Constraints

- Copy via `cp`, never regenerate via `Write` — the core rule the whole skill exists to enforce (see spec).
- The skill's canonical source stays in this repo; personal use is a symlink, never a duplicated copy.
- `version-freshness-audit.yml` is operational tooling for this repo, not a copy-paste template — belongs at `.github/workflows/`, not `ci-cd/github-actions/`.
- On finding version drift, the workflow opens/updates a GitHub Issue — it never auto-fixes or auto-PRs (out of scope per spec).
- Every version claim in this plan was verified against the real GitHub API before being written down (see spec's self-review note) — do not swap in unverified version numbers while implementing.

---

## Task 1: `skills/apply-infra-template/SKILL.md`

**Files:**
- Create: `skills/apply-infra-template/SKILL.md`

**Interfaces:**
- Produces: the skill's trigger `description` (used by Claude Code to decide when to invoke it) and its step-by-step procedure — later tasks (README, CLAUDE.md pointer) reference this file by path and by its two named modes ("Greenfield mode", "Audit mode").

- [ ] **Step 1: Write the skill file**

`skills/apply-infra-template/SKILL.md`:
```markdown
---
name: apply-infra-template
description: Use when setting up, adding, or modifying CI/CD pipelines, Dockerfiles, docker-compose stacks, GitHub Actions workflows, or deploy pipelines, in any project. Governs how to correctly apply templates from <old-templates-repo> with byte-for-byte fidelity instead of paraphrasing them, and how to assemble multiple templates together without botching the wiring between them.
---

# Apply Infra Template

Applies CI/CD, Docker, and deploy templates from `<old-templates-repo>`
to a project with byte-for-byte fidelity. This procedure exists because
paraphrasing a template from memory silently drops the fixes baked into
it (a `HEALTHCHECK`, a `restart:` policy, `printf '%q'` quoting), and
improvised multi-template assembly gets the wiring between files wrong
even when each file looks right in isolation.

**Announce at start:** "I'm using the apply-infra-template skill."

## The one rule everything else follows

**Copy with `cp` (the Bash tool), never recreate with `Write`.** Writing
a new file from your own impression of a template — even one you just
read — is a probabilistic reconstruction, not a copy. `cp` moves bytes;
there is nothing for it to drift. Every step below that says "copy"
means `cp`. Every step that says "adapt" means `cp` first, then `Edit`
for exactly the named deltas — never a freehand rewrite of the whole
file.

## Step 0: Detect mode

Check the target repo for existing infra files: any `Dockerfile`,
`compose*.yml`, `.github/workflows/*.yml`, `.github/actions/*`,
`Makefile`.

- **None found → Greenfield mode.**
- **Some found → Audit mode.**

## Greenfield mode

1. **Identify needs.** Read `<old-templates-repo>/CLAUDE.md`'s "I
   need to..." table. Map every piece the request needs onto a specific
   template path. If more than one template applies, this is a
   multi-template assembly — do step 3 in addition to step 2 for each
   piece.

2. **Single-file copy.**
   - `cp` the template file verbatim into the target project.
   - Read its sibling `README.md` for what to change and why.
   - `Edit` *only* the specific `<ANGLE_BRACKET_PLACEHOLDER>` markers the
     README names. Nothing else — not even things that look
     improvable; that's scope creep this skill exists to prevent, not
     invite.
   - **Version freshness.** If the copied file pins a version (a
     Dockerfile `FROM image:tag`, a workflow `uses: owner/repo@ref`),
     verify it's still current before finishing: check the image tag or
     action ref actually exists and isn't several majors behind
     (`WebFetch`/`WebSearch` the registry, or for GitHub Actions,
     `gh api repos/<owner>/<repo>/git/refs/tags/<ref>` to confirm it
     exists and `gh api repos/<owner>/<repo>/tags --paginate --jq
     '.[].name'` filtered to `^v[0-9]+$` to find the current major
     floating tag). If the template's pin is stale or invalid, use the
     verified-current version in the copied file instead — and file the
     stale template pin itself as a gap (step 6). Don't silently "fix
     forward" in only the target project without also flagging it back.

3. **Multi-template assembly.**
   - Read `examples/monorepo-layout/README.md` in full first,
     specifically its "What required real adaptation" section.
   - Per file, follow that section's guidance: verbatim `cp`, or `cp` +
     `Edit` for exactly the deltas it names (build context, `COPY`
     paths, workspace build commands, compose service references).
     Don't improvise wiring it doesn't cover — that's a gap, see step 6.
   - GitHub Actions composite actions and reusable workflows must be
     vendored into `.github/actions/` / `.github/workflows/` verbatim
     (`cp`) — `uses:` resolution requires the physical file to be
     there; this isn't optional duplication.

4. **Self-verify.**
   - `diff` every file that should be verbatim against its source
     template. Any difference is either a documented, intended
     substitution, or a mistake — there is no third category.
   - Run the templates repo's own validation commands against the
     copied files: `bash -n <file>` for shell scripts, `python3 -c
     "import yaml; yaml.safe_load(open('<file>'))"` for YAML, `make
     help` for Makefiles.

5. **Manifest.** End with a short summary: templates used (with paths),
   what was substituted and why, and anything still needing the user's
   input (real hostnames, secrets, API URLs). This is what the user
   actually audits, not a full diff of the target repo.

6. **File gaps, don't route around them.** If a template doesn't fit
   the target project, is wrong, or something needed doesn't exist,
   don't invent a silent one-off fix scoped to just this project. Write
   a finding to `<old-templates-repo>/contributions/`, following
   `contributions/README.md`'s format. This is not optional when a real
   gap is hit — a silent workaround in one project is exactly how
   templates drift from what people actually need.

## Audit mode

Target repo already has infra files — it may predate this skill, or was
set up by hand.

1. **Full inventory.** List every existing infra file in the target
   repo (Dockerfiles, compose files, workflows, actions, Makefile).
2. **Map each to its closest template**, using `CLAUDE.md`'s table and
   the file's own content/purpose. Note any file with no template
   counterpart.
3. **Diff and categorize each gap** into exactly one of:
   - **Deliberate customization** — a real, intentional project-specific
     difference (a different DB, a different port scheme). Leave it.
   - **Drift/staleness** — missing something the template has (a
     `HEALTHCHECK`, `env:` routing, `printf '%q'` quoting, a current
     version pin). Candidate fix.
   - **No template exists** — this file does something none of the
     current templates cover. Not a target-repo fix; file it (step 6)
     as a possible template gap.
4. **Report the full gap list before changing anything** — every
   drift/staleness item found, so the user sees the whole picture
   rather than a stream of individual edits with no overview.
5. **Fill gaps incrementally**, one at a time, each going through steps
   2-6 of greenfield mode (`cp`/targeted `Edit`, self-verify, manifest
   entry). No single sweeping rewrite of multiple files at once — each
   gap is its own reviewable change.

## Setup

This skill's canonical copy lives in this templates repo. To have it
fire in *any* project (not just when working directly inside this
repo), symlink it into your personal Claude Code skills directory:

```bash
ln -s <old-templates-repo>/skills/apply-infra-template ~/.claude/skills/apply-infra-template
```

A symlink, not a copy — this skill exists to prevent content drift, so
there must be exactly one copy of it too. See this directory's
`README.md` for the full setup writeup.
```

- [ ] **Step 2: Validate the frontmatter parses as YAML**

Run:
```bash
python3 -c "
import re
content = open('skills/apply-infra-template/SKILL.md').read()
match = re.match(r'^---\n(.*?)\n---\n', content, re.DOTALL)
assert match, 'no frontmatter block found'
import yaml
data = yaml.safe_load(match.group(1))
assert data['name'] == 'apply-infra-template'
assert 'description' in data
print('frontmatter OK:', data['name'])
"
```
Expected: `frontmatter OK: apply-infra-template`

- [ ] **Step 3: Commit**

```bash
git add skills/apply-infra-template/SKILL.md
git commit -m "Add apply-infra-template skill: greenfield + audit modes, version freshness checks"
```

---

## Task 2: `skills/apply-infra-template/README.md`

**Files:**
- Create: `skills/apply-infra-template/README.md`

**Interfaces:**
- Consumes: Task 1's `SKILL.md` (references it by relative path, describes what it does without duplicating its procedure content).

- [ ] **Step 1: Write the README**

`skills/apply-infra-template/README.md`:
```markdown
# apply-infra-template

Enforces byte-for-byte fidelity when applying templates from this repo
to another project — see `SKILL.md` for the actual procedure this skill
follows when it fires.

## Why this exists

Even when explicitly told to reference this templates repo, agents were
observed to (a) paraphrase template files instead of copying them,
silently dropping fixes that only exist because they fixed a real bug
once, and (b) botch the wiring when assembling multiple templates
together, despite `examples/monorepo-layout/` already documenting the
adaptations needed. See
`docs/superpowers/specs/2026-08-21-apply-infra-template-skill-design.md`
for the full design rationale.

## Personal setup (do this once)

```bash
ln -s <old-templates-repo>/skills/apply-infra-template ~/.claude/skills/apply-infra-template
```

This makes the skill fire in any project, not just when Claude Code is
working directly inside this templates repo. It's a symlink rather than
a copy deliberately — this skill's whole purpose is eliminating content
drift, so its own distribution can't introduce the same problem it's
meant to prevent. If you ever move this templates repo to a different
path, recreate the symlink pointing at the new location.

## Verifying it's active

Ask Claude Code (in any project) to set up a Dockerfile, GitHub Actions
workflow, or deploy pipeline. If the skill is active, it should announce
"I'm using the apply-infra-template skill" before doing anything else.

## If the symlink doesn't work on your system

Some tools resolve skill directories without following symlinks. If the
skill doesn't fire after the `ln -s` above, check your Claude Code
version's skill-discovery docs for whether it follows symlinks; the
fallback is copying the directory instead of symlinking, but that
reintroduces the drift risk described above — keep the copy in sync by
hand if you have to fall back to this.
```

- [ ] **Step 2: Verify both links in the README resolve**

Run:
```bash
[ -f skills/apply-infra-template/SKILL.md ] && echo "SKILL.md OK"
[ -f docs/superpowers/specs/2026-08-21-apply-infra-template-skill-design.md ] && echo "spec OK"
```
Expected: both lines print `OK`.

- [ ] **Step 3: Commit**

```bash
git add skills/apply-infra-template/README.md
git commit -m "Add apply-infra-template README: rationale and personal symlink setup"
```

---

## Task 3: Wire the skill into `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: Task 1/2's `skills/apply-infra-template/` path.

- [ ] **Step 1: Add a pointer right after the existing "don't regenerate from memory" paragraph**

In `CLAUDE.md`, find this existing paragraph (near the top, right after the repo's two-audience framing):
```
When working in an unrelated project and the user needs one of the
templates below, read the linked template + its sibling README, copy the
file(s) into the target project, and adapt anything marked with
`<ANGLE_BRACKET_PLACEHOLDER>`. Don't regenerate these patterns from
memory — copy from here, since they're extracted from real production
usage and each README explains the "why," not just the "what."
```

Insert immediately after it:
```markdown

**This is enforced, not just documented.** The
[`apply-infra-template`](skills/apply-infra-template/README.md) skill
encodes the exact procedure above (copy via `cp`, never regenerate via
`Write`; consult `examples/monorepo-layout/` before any multi-template
assembly; verify version pins are current; file gaps instead of routing
around them) as a followable checklist rather than prose to interpret.
If it's installed (see that skill's README for personal setup), it
fires automatically — but if you're reading this file directly without
the skill having fired, follow this same discipline by hand.
```

- [ ] **Step 2: Add `skills/` to the Repository structure list**

In `CLAUDE.md`'s "## Repository structure" section, find the bullet list (starts with `- \`docker/\` — Dockerfiles...`) and add a new bullet, keeping alphabetical-ish grouping with the other top-level directories — place it right before the `- \`examples/monorepo-layout/\`` bullet:
```markdown
- `skills/apply-infra-template/` — the Claude Code skill that enforces
  how templates from this repo get applied elsewhere (copy via `cp`,
  never regenerate; consult `examples/monorepo-layout/` for assembly;
  verify version pins; file gaps as contributions). See its own
  `README.md` for personal setup. This is the mechanism, not just the
  documentation — `CLAUDE.md`'s instructions above describe the same
  discipline for any agent reading this file without the skill active.
```

- [ ] **Step 3: Verify the file still parses as valid Markdown links (spot check) and the new section exists**

Run:
```bash
grep -q "apply-infra-template" CLAUDE.md && echo "pointer present"
grep -c "apply-infra-template" CLAUDE.md
```
Expected: `pointer present`, and a count of at least 2 (one in the new paragraph, one in the repository-structure bullet).

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "Wire apply-infra-template skill into CLAUDE.md as the enforced procedure"
```

---

## Task 4: `.github/workflows/version-freshness-audit.yml`

**Files:**
- Create: `.github/workflows/version-freshness-audit.yml`

**Interfaces:**
- Produces: a scheduled + manually-dispatchable workflow. No other task depends on its internals, but it references the same directories Task 1-3 describe (`docker/*/Dockerfile`, `ci-cd/github-actions/**/*.yml`).

- [ ] **Step 1: Write the workflow**

`.github/workflows/version-freshness-audit.yml`:
```yaml
# Operational tooling for THIS repo, not a copy-paste template for other
# projects — same category as .github/dependabot.yml. Checks that
# Dockerfile base images still resolve and that GitHub Actions version
# pins in the template library both exist and aren't several majors
# behind current, opening a GitHub Issue on drift rather than
# auto-fixing anything (same human-review-before-merge property as
# every other change in this repo).
#
# Prerequisite: this repo must be pushed to GitHub with Actions enabled
# for this workflow to actually run — it is a no-op sitting in a local
# checkout otherwise.

name: Version freshness audit

on:
  schedule:
    - cron: "0 6 * * 1" # weekly, Monday 06:00 UTC
  workflow_dispatch:

permissions:
  contents: read
  issues: write

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - name: Check Docker base images and Action version pins
        id: check
        run: |
          set -euo pipefail
          summary_file=$(mktemp)
          drift_found=0

          echo "Checking Docker base image tags still resolve..."
          for f in $(find docker -name Dockerfile); do
            while read -r image tag; do
              repo="${image##*/}"
              if ! curl -fsS "https://registry.hub.docker.com/v2/repositories/library/${repo}/tags/${tag}/" >/dev/null 2>&1; then
                echo "- \`$f\`: \`${image}:${tag}\` not found on Docker Hub (library/${repo}) — removed, renamed, or never valid" >> "$summary_file"
                drift_found=1
              fi
            done < <(grep -E '^FROM ' "$f" | awk '{print $2}' | awk -F: '{print $1, $2}')
          done

          echo "Checking GitHub Actions version pins exist and aren't stale..."
          for f in $(find ci-cd/github-actions .github/workflows .github/actions -name '*.yml' 2>/dev/null); do
            while read -r ref_full; do
              owner_repo="${ref_full%@*}"
              owner=$(echo "$owner_repo" | cut -d/ -f1)
              repo=$(echo "$owner_repo" | cut -d/ -f2)
              ref="${ref_full##*@}"

              if ! gh api "repos/${owner}/${repo}/git/refs/tags/${ref}" >/dev/null 2>&1; then
                echo "- \`$f\`: \`${ref_full}\` — ref does not exist for ${owner}/${repo}" >> "$summary_file"
                drift_found=1
                continue
              fi

              # Only compare majors for plain vN pins (e.g. v7); skip
              # exact patch pins (v0.9.0) and non-numeric refs (SHAs).
              if [[ "$ref" =~ ^v[0-9]+$ ]]; then
                latest_major=$(gh api "repos/${owner}/${repo}/tags" --paginate --jq '.[].name' 2>/dev/null | grep -E '^v[0-9]+$' | sort -t v -k2 -n | tail -1)
                pinned_num="${ref#v}"
                latest_num="${latest_major#v}"
                if [ -n "$latest_num" ] && [ "$pinned_num" -lt "$latest_num" ]; then
                  echo "- \`$f\`: \`${ref_full}\` — pinned major is behind current (\`${latest_major}\` available)" >> "$summary_file"
                  drift_found=1
                fi
              fi
            done < <(grep -oE 'uses: [a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+(/[a-zA-Z0-9_.-]+)*@[a-zA-Z0-9._-]+' "$f" | sed 's/uses: //')
          done

          echo "drift-found=$drift_found" >> "$GITHUB_OUTPUT"
          {
            echo "## Version Freshness Audit"
            if [ "$drift_found" = "1" ]; then
              cat "$summary_file"
            else
              echo "No drift found."
            fi
          } >> "$GITHUB_STEP_SUMMARY"
          cp "$summary_file" /tmp/drift-summary.md
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Open or update an issue on drift
        if: steps.check.outputs.drift-found == '1'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          set -euo pipefail
          existing=$(gh issue list --label version-freshness --state open --json number --jq '.[0].number' || echo "")
          {
            echo "Automated weekly scan found stale or invalid version pins."
            echo ""
            cat /tmp/drift-summary.md
            echo ""
            echo "Fix directly (if verified) or file a finding in \`contributions/\` per that folder's README, same as any other gap."
          } > /tmp/issue-body.md

          if [ -n "$existing" ]; then
            gh issue comment "$existing" --body-file /tmp/issue-body.md
          else
            gh issue create \
              --title "Version freshness audit: drift found ($(date -u +%Y-%m-%d))" \
              --label version-freshness \
              --body-file /tmp/issue-body.md
          fi
```

- [ ] **Step 2: Validate YAML syntax**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/version-freshness-audit.yml'))"
```
Expected: no output (parses successfully).

- [ ] **Step 3: Extract and syntax-check the embedded bash**

Run:
```bash
python3 -c "
import yaml
data = yaml.safe_load(open('.github/workflows/version-freshness-audit.yml'))
steps = data['jobs']['audit']['steps']
for step in steps:
    if 'run' in step:
        open('/tmp/step-check.sh', 'w').write(step['run'])
        import subprocess
        result = subprocess.run(['bash', '-n', '/tmp/step-check.sh'])
        print(step.get('name', 'unnamed'), '->', 'OK' if result.returncode == 0 else 'FAIL')
"
```
Expected: both steps print `-> OK`.

- [ ] **Step 4: Dry-run the detection logic against this repo's real files (without the GitHub Issue step)**

Run:
```bash
set -euo pipefail
summary_file=$(mktemp)
drift_found=0

for f in $(find docker -name Dockerfile); do
  while read -r image tag; do
    repo="${image##*/}"
    if ! curl -fsS "https://registry.hub.docker.com/v2/repositories/library/${repo}/tags/${tag}/" >/dev/null 2>&1; then
      echo "- \`$f\`: \`${image}:${tag}\` not found" >> "$summary_file"
      drift_found=1
    fi
  done < <(grep -E '^FROM ' "$f" | awk '{print $2}' | awk -F: '{print $1, $2}')
done

for f in $(find ci-cd/github-actions .github/workflows .github/actions -name '*.yml' 2>/dev/null); do
  while read -r ref_full; do
    owner_repo="${ref_full%@*}"
    owner=$(echo "$owner_repo" | cut -d/ -f1)
    repo=$(echo "$owner_repo" | cut -d/ -f2)
    ref="${ref_full##*@}"
    if ! gh api "repos/${owner}/${repo}/git/refs/tags/${ref}" >/dev/null 2>&1; then
      echo "- \`$f\`: \`${ref_full}\` ref does not exist" >> "$summary_file"
      drift_found=1
    fi
  done < <(grep -oE 'uses: [a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+(/[a-zA-Z0-9_.-]+)*@[a-zA-Z0-9._-]+' "$f" | sed 's/uses: //')
done

echo "drift_found=$drift_found"
cat "$summary_file"
```
Expected: `drift_found=0` and an empty summary file — this repo's pins were all just bumped to verified-current versions in the prior session, so a clean run confirms the detection logic doesn't false-positive against known-good state.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/version-freshness-audit.yml
git commit -m "Add version-freshness-audit.yml: weekly self-audit of Docker/Action pins"
```

---

## Task 5: Personal activation (user-performed, not agent-performed)

**Files:** none (filesystem operation outside this repo)

This task is a note for the human, not a code change — included so the plan doesn't silently skip the step the whole design exists to enable.

- [ ] **Step 1: Create the symlink**

Run (as the user, in their own shell — not something an agent should do unprompted to `~/.claude/`):
```bash
ln -s <old-templates-repo>/skills/apply-infra-template ~/.claude/skills/apply-infra-template
```

- [ ] **Step 2: Verify it resolves**

Run:
```bash
ls -la ~/.claude/skills/apply-infra-template
readlink ~/.claude/skills/apply-infra-template
```
Expected: shows a symlink pointing at `<old-templates-repo>/skills/apply-infra-template`.

---

## Self-review notes

- **Spec coverage:** Task 1 covers the spec's "Skill content: the
  procedure" section in full (step 0 mode detection, greenfield steps
  1-6 including the version-freshness sub-step, audit mode steps 1-5).
  Task 2 covers "Location and personal use." Task 3 covers the
  "belt-and-suspenders" `CLAUDE.md` pointer. Task 4 covers "Version
  freshness: a companion self-audit workflow" in full (weekly +
  dispatch trigger, both check types, issue-not-PR on drift, dedup via
  label). Task 5 covers the symlink step from "Location and personal
  use" as a human action, not skipped.
- **No placeholders:** `SKILL.md`, its `README.md`, and
  `version-freshness-audit.yml` are complete, real content — no
  TBD/TODO. The workflow's detection logic was tested locally against
  live data (Docker Hub API, GitHub API) before being written into this
  plan, not assumed correct.
- **Type/name consistency:** the skill's `name: apply-infra-template`
  frontmatter matches the directory name `skills/apply-infra-template/`
  and every cross-reference to it (README, CLAUDE.md, symlink target)
  uses that same path consistently.
