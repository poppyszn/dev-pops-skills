---
name: skill-authoring
description: Use when creating, editing, reviewing, splitting, renaming, or auditing an agent skill (a SKILL.md folder) or the structure of this skills repo, including when asked to "make a skill for X", "update the docker skill", "check the skills are up to date", "apply the contributions", or when the skill validator or the freshness-audit issue reports failures, drift, or stale skills. Not for carrying out the domain work a skill describes (use that skill, e.g. docker or cicd).
metadata:
  version: "0.4.0"
  last-verified: "2026-09-26"
---

# Skill authoring

Create and maintain skills to the repo's standard, so any agent can pick them up and follow them without manual help.

## When to use

- The user wants a new skill, or wants an existing one changed, split, renamed or reviewed
- The user asks to check that the skills or the repo are up to date (audit)
- `scripts/validate.sh` reports FAIL, or WARN for stale skills, or the weekly freshness-audit issue reports drift
- Findings in the repo's `contributions/` folder need applying

Not for: doing Docker, CI/CD, scripting or security work (use those skills).

## Defaults

- **Rules:** `references/standard.md` is the rulebook. Read it before writing anything.
- **Where skills go:** the `skills/` folder containing this skill's *real* path. Resolve symlinks, e.g. `cd -P <this-skill>/.. && pwd`. Use another location only if the user names one.
- **Interview first.** Never draft a skill before the user has answered `references/interview.md`.
- **Check online.** Confirm every external fact (images, versions, project status, paths) with a web search. Never write one from memory.
- **Never commit.** Show the result and let the user decide.

## Workflow

### Create or edit

1. **Interview.** Ask the questions in `references/interview.md` in one message and wait for answers.
2. **Check overlap.** Read the `description` of every skill in the skills folder. Decide whether to create a new skill, extend an existing one, or split one, and tell the user which and why.
3. **Scaffold** (new skill only). Copy `assets/SKILL.template.md` to `<skills>/<name>/SKILL.md`, `assets/CHANGELOG.template.md` to `<name>/CHANGELOG.md`, and `assets/sources.template.md` to `<name>/references/sources.md`.
4. **Write** it following `references/standard.md`, using the user's interview answers:
   - defaults
   - risky actions under Requires confirmation
   - verification checks
   - good and bad examples
5. **Verify external facts.** Search the web for each image, tool, version, action and path the skill mentions. Record each in `references/sources.md` with its URL and today's date. Set `metadata.last-verified` to today. Without web access, mark facts `unverified` and tell the user.
6. **Version it.** New skills start at `0.1.0`. For edits, bump the semver (see standard §10) and add a `CHANGELOG.md` entry.
7. **Validate.** Run `scripts/validate.sh <skills>/<name>` and fix every FAIL.
8. **Re-export if a portable copy exists.** If this skill has been pasted as static instructions for an agent with no Skill tool (standard §13), regenerate: `scripts/export-portable.sh <skills>/<name>`, and tell the user to re-paste it and where.
9. **Present.** Summarise the skill (triggers, defaults, confirmations, checks) and show the diff. Don't commit.

### Apply a finding

1. Read the finding in `contributions/` (the repo root is two levels above this skill's real path). Reproduce its claim, or confirm it against the current asset. Check any external fact online.
2. Apply it as a normal edit (Create or edit, steps 4–9):
   - assets: copy-then-edit
   - update the asset's reference
   - re-copy any vendored copies
   - version and changelog
3. Rename the finding to `<name>.merged.md`, move it into `contributions/completed/`, and put a status note under its title saying what was applied where (standard §12). Open findings are the files directly in `contributions/`.

### Audit

1. Run `scripts/validate.sh` with no arguments to check every skill and list stale ones.
2. For each skill, and for the repo itself (this skill's `references/sources.md` holds the repo facts: install paths, rules-file support, spec), re-check every `sources.md` row online:
   - Is it still true?
   - Is the project archived or moved?
   - Is there a newer version?

   For template assets, also check every image tag and action pin in `assets/`. The repo's weekly freshness-audit workflow does the mechanical part; you judge what to change.
3. Report the findings as a table (skill, fact, was, now, source) before changing anything.
4. For each fix the user approves: apply it, update `sources.md`, bump the version, add a changelog entry, and set `last-verified`. Also update `scripts/install.sh`, `README.md` or `AGENTS.md` if a repo fact changed.
5. Validate and present the diff, as in Create or edit.

## Requires confirmation

- Deleting, renaming or merging an existing skill folder.
- Changing a skill's scope or a default (a major version bump).
- Changing repo-level files (`scripts/install.sh`, `AGENTS.md`, `README.md`) during an audit.

## Verification

- `scripts/validate.sh <skill-dir>` passes with no FAIL. Report any remaining WARN lines to the user.
- `references/sources.md` has no row older than the skill's `last-verified` date, unless the row is marked `unverified` and the user was told.
- Every file in `references/`, `scripts/` and `assets/` is listed in the skill's References section (the validator warns otherwise).
- Assets pass their syntax checks (standard §11), and vendored copies match their source (the validator fails otherwise).
- If a portable copy exists for an agent with no Skill tool, `scripts/export-portable.sh --check <path-to-pasted-copy>` passes (standard §13).

## Examples

Good description:
> Use when writing, reviewing, or debugging Dockerfiles, .dockerignore, compose.yaml, image builds, or container runtime issues such as crash loops, port conflicts, and volume permissions. Not for CI pipelines that build images (use cicd) or image vulnerability scanning (use security).

Bad description (vague, no triggers, no boundaries):
> Helps with Docker and containers and related DevOps stuff.

Good external fact in a skill:
> Default object storage for local dev: check the current recommended image and whether the project is still maintained before pinning. See `references/sources.md` (checked 2026-09-26).

Bad external fact (from memory, may be archived or unpullable):
> Use `minio/minio:latest` for local S3.

## References

- `references/standard.md`: the full rules. Read before any create, edit or audit.
- `references/interview.md`: questions to ask before drafting.
- `references/sources.md`: repo-level external facts (install paths, spec) to re-check during audits.
- `assets/SKILL.template.md`, `assets/CHANGELOG.template.md`, `assets/sources.template.md`: copy these when scaffolding a skill.
- `scripts/validate.sh [skill-dir...]`: validates the given skills, or all skills if no argument is given. Run it; don't read it.
- `scripts/export-portable.sh [skill-dir...|--all]` / `--check <file>`: flattens a skill into a plain-text document for agents with no Skill tool (standard §13), or checks a previously pasted copy for drift. Run it; don't read it.
