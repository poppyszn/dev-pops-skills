# Skill standard

The rules every skill in this repo follows. This file is the single source of truth. Other docs point here instead of repeating it.

Items marked **[checked]** are enforced by `scripts/validate.sh`. The rest rely on the author and review.

## 1. Scope

- One domain per skill. If a skill starts covering two domains, split it instead of extending it.
- Skills must not overlap. Every skill names its neighbours in its description ("Not for … (use X)").
- Folder name = `name` = lowercase a–z/0–9 with single hyphens, at most 64 chars, no leading or trailing hyphen. **[checked]**

## 2. Frontmatter

```yaml
---
name: docker
description: Use when … Not for … (use cicd).
metadata:
  version: "1.2.0"            # semver. Bump on every change.
  last-verified: "2026-09-26" # date external facts were last checked online
---
```

- `name`, `description`, `metadata.version` (semver) and `metadata.last-verified` (YYYY-MM-DD) are required. **[checked]**
- The description is at most 1024 chars **[checked]** and decides whether the skill triggers, so it must:
  - start with "Use when …" and list concrete triggers: file names, tools, commands, error symptoms, phrases the user would say
  - end with "Not for … (use <skill>)" for each neighbouring area
  - avoid vague words ("helps with", "various", "etc.")

## 3. Required sections in SKILL.md **[checked]**

| Heading | Contents |
|---|---|
| `## When to use` | Trigger situations, plus a "Not for" line naming the other skills. |
| `## Defaults` | The firm choices this skill makes (see §4). |
| `## Workflow` | Numbered steps the agent follows. |
| `## Requires confirmation` | Commands and actions the agent must stop and confirm first (see §5). Write "None." if none. |
| `## Verification` | Concrete checks to run before the work counts as done (see §6). |
| `## Examples` | At least one good and one bad example. Alternatively put them in `references/examples.md` and link it. |

`## References` is optional, but it must list every file in `references/`, `scripts/` and `assets/`, each with a note on when to use it. **[checked: warning]**

## 4. Defaults: fixed, override on ask

- Each skill states firm defaults (e.g. "bash with `set -euo pipefail`", "pin image tags by digest or exact version") and applies them **without asking**.
- The agent deviates only when:
  - the project already does it differently (follow the project and say so), or
  - the user asks for something else.
- Defaults must be written down. Never rely on the agent's taste.

## 5. Risky operations: always ask first

- Every destructive, irreversible or remote-affecting action goes under `## Requires confirmation`. Examples: deleting volumes or data, `prune`, force-push, deploys, applying infrastructure changes, rotating or revoking secrets, changing permissions on shared resources.
- The agent must stop, state exactly what it will run and what it affects, and wait for a yes.
- Read-only commands and local builds/tests run without asking.

## 6. Verification

- Every skill ends its workflow with checks that prove the result works. Examples: the build succeeds, the linter passes (shellcheck, hadolint, actionlint), the container starts and responds, a dry-run shows the expected changes.
- The agent reports the actual output. It doesn't claim success without running the checks.

## 7. Stay current: check online, never trust memory

Tools, images and platforms change. Model memory is out of date by default.

- Any **external fact** in a skill must be confirmed with a web search when it is written or edited. External facts include:
  - image names and tags
  - tool, action, package and API versions
  - whether a project is maintained, archived, relicensed or moved (e.g. an image that can no longer be pulled)
  - install paths and config locations
- Record each fact in `references/sources.md` **[checked: file exists]** as `fact | source URL | date checked`, using `assets/sources.template.md`.
- Update `metadata.last-verified` after a full check. The validator warns when it is older than 90 days **[checked]**. Then run an audit (see SKILL.md, Audit mode).
- Domain skills must include a workflow step telling the agent to confirm an image, action or version is current **at use time** before pinning or pulling it.
- If web search is unavailable, say so, mark the fact `unverified` in `sources.md`, and never guess.

## 8. Size and layout

- Keep SKILL.md short: well under 500 lines (a warning above that **[checked]**). It holds only what's needed on every run.
- Detail goes one level deep:
  - `references/*.md` for docs loaded on demand
  - `scripts/` for executables to run rather than read
  - `assets/` for templates and config to copy
- `CHANGELOG.md` sits in the skill root with an entry for the current version **[checked]**. SKILL.md does not link to it, so it doesn't use context on every run.

## 9. Agent-neutral wording

- Skills must work in any agent that supports the Agent Skills format.
- Don't name specific agent products or their internal tool names in SKILL.md or references. Describe the action instead ("run", "read the file", "search the web"). **[checked: warning]**
- `references/sources.md` and `CHANGELOG.md` are exempt, since they may need to name products.
- Agent-specific packaging lives outside `skills/`.

## 10. Changes

- Every change bumps `metadata.version`: patch for wording and fixes, minor for new guidance or sections, major for changed defaults or scope.
- Add a `CHANGELOG.md` entry with the date.
- Changes are shown to the user for review. Agents never commit on their own.

## 11. Template assets

Skills that ship templates (Dockerfiles, workflows, actions, config) put them in `assets/`. Retyping a template from memory drops the fixes baked into it, so:

- **Skills tell agents to copy assets with a file-copy command (`cp`), never to retype them.** "Adapt" means copy first, then edit only the named deltas.
- **Every asset has a reference** (`references/<name>.md`) saying what to change when copying and *why* it's shaped that way. Rules that came from a real bug keep the bug's story next to the rule ("Shipped once: …"), so nobody drops them as style.
- **Markers:**
  - `<ANGLE_BRACKETS>` = fill in when copying
  - `__DOUBLE_UNDERSCORE__` = runtime substitution (never mix the two)
- **Paths inside assets are target-project paths** (e.g. `COPY docker/node-api/entrypoint.sh`), not paths in this repo.
- **Vendored copies** (the same file shipped in two places, e.g. an action inside an example project) start with exactly:
  ```
  # Vendored verbatim from the dev-pops <skill> skill: <path-in-that-skill>
  # Source of truth is that file — re-copy from there, don't hand-edit here.
  ```
  and must match the source byte for byte after those two lines. **[checked]** When a source asset changes, re-copy every vendored copy.
- **Assets contain no secrets, real hostnames or client-identifying values.**
- **Assets pass syntax checks** before a change is presented:
  - `sh -n` for shell
  - YAML parse (plus `actionlint` if installed) for workflows
  - `docker compose config -q` for compose
  - `make help` for Makefiles

## 12. Gaps found while using a skill

When a skill's template or guidance turns out wrong or missing in a real project, the agent fixes the project minimally **and** files a finding in the repo's `contributions/` folder (format in its `README.md`). It never quietly works around the gap.

**Findings are anonymous.** A finding never names the client, the project, its repository or organisation, a person, a hostname or domain, or a local path. Describe the project's shape instead ("a single-app NestJS 11 + TypeORM API", "an Nx monorepo with four apps") and keep every technical detail. The same goes for anything copied out of a finding into a skill's `references/`, a changelog, a commit message or a pull request. `scripts/check-private-names.sh` enforces it in CI against the maintainer's private name list.

Applying a finding happens in this repo, through the normal flow:

1. Check it names no client, project, repository or person (genericize it first if it does), then reproduce it.
2. Check facts online.
3. Fix the skill.
4. Bump the version and add a changelog entry.
5. Validate.
6. Rename the finding to `<name>.merged.md`, move it into `contributions/completed/`, and add a status note under its title saying what was applied where.

## 13. Portable export for agents with no Skill tool

Some agents can't load a skill on demand: they have no Skill tool, no `/<skill-name>` invocation, and no way to fetch `references/` mid-task. They only get whatever static instructions were configured for them up front. `scripts/export-portable.sh` flattens one skill's `SKILL.md` plus its `references/*.md` (excluding `sources.md`) into a single plain-text document sized for that: paste it into wherever that agent's static instructions live.

This works today with no extra authoring effort because every skill already has to be agent-neutral (§9) and self-contained. Two things keep it that way:

- **Write for a document read top to bottom, not a tool invoked on demand.** "See `references/x.md` for the full list" is fine — the export inlines it as an appendix right after. Don't write guidance that only makes sense *because* something fetched it lazily (e.g. "come back to this section only once you've confirmed Y" reads fine either way; "this loads automatically once you need it" does not — say what to do, not how it arrived).
- **Don't assume runtime skill mechanics reach a plain-text reader.** No slash commands, no `/loop`, no "Artifacts panel". The validator's agent-neutral check (§9) already forbids naming these by product; `export-portable.sh` also flags the mechanic phrases themselves (`grep`-based, best-effort) as a second net, not a replacement for writing it right.
- **`assets/` isn't inlined.** Template files are copied with `cp` (§11) from this repo's checkout, which a portable-instructions agent needs the same as any other — the export just tells it the path and to use a file-copy command, not the file contents.

Regenerate after every version bump that changes wording a portable copy already carries: `scripts/export-portable.sh <skills>/<name>`. To check whether a previously pasted copy has drifted from the source skill, run `scripts/export-portable.sh --check <path-to-pasted-copy>` — it reads the skill name back out of the copy's own header and diffs a fresh render against it, non-zero exit on drift. There is no separate stored copy to rot inside this repo: the export is generated fresh from the current `SKILL.md` every time, so the only place staleness can creep in is a copy pasted into another system, which `--check` is for.
