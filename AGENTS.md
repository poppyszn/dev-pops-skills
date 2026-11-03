# AGENTS.md

Guidance for any AI coding agent working in this repository. `CLAUDE.md` imports this file, and Antigravity reads it directly. Edit this file, not `CLAUDE.md`.

## What this repo is

A personal library of DevOps agent skills (docker, cicd, security, scripting, terraform, project-infra, plus skill-authoring for maintaining the rest). It includes the proven templates migrated from the old `templates` repo, as skill `assets/`. It replaces an earlier single, overcrowded skill file that agents rarely triggered or followed. The goals are to keep each skill small, triggered reliably, and needing no manual intervention, and usable by any agent that supports the open Agent Skills format.

`skills/` is the single source of truth, and `scripts/install.sh` symlinks it into each agent's skills directory.

## Skill layout

Each skill under `skills/<name>/` has the same shape:

- `SKILL.md`: frontmatter (`name`, a trigger-oriented `description` that also names sibling skills to use instead, `metadata.version`, `metadata.last-verified`) plus the short, always-applied defaults.
- `references/`: per-topic detail loaded on demand. Each skill's `references/sources.md` records the external facts it relies on.
- `assets/`: verbatim templates (Dockerfiles, compose, workflows, Makefile). Skills tell agents to `cp` these and edit only the marked `<ANGLE_BRACKET>` spots, so changing an asset changes what gets copied into other projects.
- `CHANGELOG.md`: one entry per version bump.

The skills cross-reference each other (docker, cicd, security, scripting; `project-infra` composes them). When a description or scope changes, check the siblings' "Not for" lines still agree.

`.claude-plugin/` (`plugin.json`, `marketplace.json`) packages the same `skills/` folder as a Claude Code plugin; keep its description in sync with the skill list in `README.md`. Pinned image tags and action versions in `assets/` are audited weekly by `.github/workflows/version-freshness-audit.yml`.

## Creating or changing skills

**Always follow `skills/skill-authoring/SKILL.md`.** Its rules are in `skills/skill-authoring/references/standard.md`. This applies to any change under `skills/`, even a small one. In short:

- Interview the user before drafting.
- Check external facts online instead of relying on memory.
- Bump the version and add a changelog entry.
- Run the validator.
- Show the diff. Never commit on your own.

Other repo-level folders:

- `contributions/`: gap findings filed by agents that hit a template problem in another project. **A finding never names the client, project or repository**; it describes the project's shape (`skills/skill-authoring/references/standard.md` §12). Apply them via skill-authoring's "Apply a finding" flow. Open findings sit directly in the folder; applied ones are moved to `contributions/completed/` and are closed records.
- `evals/`: the trigger dataset (`triggers.json`: which skill each prompt should load) the stand-in projects each prompt runs against (`workspaces/`: a base project plus optional overlays; not templates), and the mechanical checklist used by the before/after in `docs/demo/`. `--run` costs real usage, so it defaults to a 9-prompt sample. Add a prompt here whenever a skill's description changes or an agent picks the wrong skill.
- `roadmap.md`: planned templates and pending decisions. Nothing listed there exists yet.
- `docs/history/`: design rationale from the old templates repo. Read it for *why*, but its paths are outdated.
- `.github/`: this repo's own automation (Dependabot for image pins, and a weekly freshness audit that opens an issue on drift). These aren't templates.

Keep repo-level external facts (agent install paths, rules-file support) in `skills/skill-authoring/references/sources.md`. Update `scripts/install.sh` and `README.md` when those facts change.

## Git conventions

These apply to this repo and to every project set up from it. `skills/project-infra/SKILL.md` restates them so a scaffolded project carries them without reading this file.

**Branches: `<type>/<slug>`.** `type` is one of the commit types below; `slug` is kebab-case and names the change, not the ticket — `fix/node-api-healthcheck-ipv6`, not `fix/san-2`. Never work on `main` directly.

**Commits: Conventional Commits.** `<type>(<scope>): <subject>`

- `type`: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `build`, `perf`, `revert`. `!` after the scope, or a `BREAKING CHANGE:` footer, for a changed default or scope — the same thing that makes a skill's version bump major.
- `scope`: the skill directory name (`docker`, `cicd`, `security`, `scripting`, `terraform`, `project-infra`, `skill-authoring`), or `repo` for anything outside `skills/`. Omit only when a change genuinely spans everything.
- `subject`: imperative, lowercase, no trailing period, kept under ~72 characters.
- Body: why, not what — the diff already says what. If the change exists because of a real bug, the body is where its story goes before it is copied into a `references/` file.
- One logical change per commit. A version bump, its changelog entry and the change itself belong in the *same* commit; two unrelated skills do not.

**Pull requests** use `.github/PULL_REQUEST_TEMPLATE.md`. Keep a PR to one reviewable change — the same "one reviewable change per gap" rule the skills apply to a client repo. Verification is the actual command and its actual output, not a claim.

**Agents never merge**, and never push to `main`. A branch and a PR is the end of an agent's work here.

This does not relax `skill-authoring`'s rule that an agent shows the diff rather than committing unasked. These conventions are how a commit and a PR are shaped *once the user has asked for one*.

## Commands

```bash
./scripts/validate-skills.sh               # validate all skills (FAIL exits non-zero)
./scripts/validate-skills.sh skills/docker # validate one skill
./scripts/install.sh all                   # link skills for Claude Code + Antigravity
./scripts/install.sh --project <dir>       # link into one project's .agents/ and .claude/
./scripts/install.sh --uninstall all       # remove only links pointing at this repo
./scripts/export-portable.sh skills/docker # flatten one skill for an agent with no Skill tool
./scripts/export-portable.sh --check <file> # detect drift in a copy pasted elsewhere
./scripts/eval-triggers.sh --lint          # trigger dataset is well-formed (CI); --run needs a logged-in CLI
./scripts/check-links.sh                   # internal links and referenced paths exist
./scripts/check-private-names.sh           # no client/project names or home paths (uses a local, gitignored .private-names)
./scripts/check-compose.sh                 # docker compose config -q on every compose template
ACTIONLINT=$(which actionlint) ./scripts/check-workflows.sh   # actionlint over every workflow template
./scripts/freshness-audit.sh               # the weekly pin/tag check, runnable locally
```

## Agents with no Skill tool

`install.sh` and the Skill format assume the consuming agent can load a skill on demand (Claude Code, Antigravity). An agent whose only configuration surface is a static instructions bundle (no Skill tool, nothing fetched mid-task) can't use that — see `skills/skill-authoring/references/standard.md` §13. Use `scripts/export-portable.sh` to flatten a skill into one plain-text document sized for that, and re-run it (or `--check`) whenever the source skill changes, so the pasted copy doesn't rot.
