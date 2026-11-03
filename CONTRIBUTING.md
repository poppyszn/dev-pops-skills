# Contributing

This is a personal set of opinionated defaults, so the most useful contribution is usually **a gap report**, not a new skill: you used a template, it was wrong or missing something, and you can show it.

## Reporting a gap

Open an issue with:

- which skill and template, and what you were trying to do
- what went wrong, with the **smallest reproduction** you can (a few lines of shell, a `diff`)
- what you expected

A reproduction is the difference between a finding that gets applied and one that sits. See [`contributions/README.md`](contributions/README.md) for the format used for findings.

## Changing a skill

Read [`AGENTS.md`](AGENTS.md) first; it is short. The rules that matter:

- Changes to `skills/` follow [`skills/skill-authoring/SKILL.md`](skills/skill-authoring/SKILL.md): check external facts online and record them (with the date) in the skill's `references/sources.md`, bump the version, add a changelog entry.
- Branch `<type>/<slug>`, Conventional Commits, one logical change per commit.
- Verification in the PR is the real command and its real output.
- Run `./scripts/validate-skills.sh` and fix every FAIL before opening the PR. CI runs it, plus the other checks listed in `.github/workflows/validate.yml`.

A new default, or a changed one, is a major version bump and gets discussed first, in an issue.
