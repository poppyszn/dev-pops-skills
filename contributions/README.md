# Contributions

> Carried over from the old `templates` repo on 2026-09-26. Findings merged
> before then reference that repo's layout (`docker/<name>/`, `ci-cd/github-actions/`,
> `CLAUDE.md`); those templates now live in `skills/docker`, `skills/cicd`,
> `skills/security` and `skills/project-infra`.

Findings from agents working in *other* projects (not this one) that
adapted a template from this repo and hit something worth feeding back —
a bug, a gotcha, a missing gotcha in the docs. Written up here instead of
changed directly in the templates, so the maintainer can review, verify,
and apply deliberately rather than have templates drift from
unreviewed edits.

## Filing a finding

One file per finding (or a small cluster of related findings from the
same debugging session, like `deploy-develop-ssh-heredoc-gotchas.md`
below). Include:

- **Where it was found** — which project, which template it was adapted
  from (even loosely — "adapted from a client monorepo's
  deploy-develop.yml, not directly from this repo" is useful context).
  Don't name private or client repositories in a finding; describe the
  shape instead ("an Nx monorepo with four apps")
- **Whether it's a confirmed bug in this repo's own template today**, or
  something found in an adaptation/derivative that may or may not still
  apply here — say which, explicitly, per finding if a file covers more
  than one.
- **A reproduction**, not just an assertion — a minimal repro (a few
  lines of shell, a `diff`) is far easier for the maintainer to verify
  quickly than a description of symptoms.
- **A suggested fix**, if you have one — but don't apply it directly to
  the template files themselves.

## What happens to a finding

The maintainer (or an agent working directly in this repo) reviews the
write-up, verifies it — re-running the repro locally is the bar, not
just reading it and agreeing — then applies whatever fix or documentation
update is warranted directly to the relevant skill (its assets,
references or SKILL.md), following the skill-authoring skill like any
other change: check facts online, bump the version, add a changelog
entry, and run the validator.

Once applied (in full or in part — not every finding in a multi-finding
file needs a code change; some are "document this as guidance" rather
than "fix this bug"), the file is renamed with a `.merged.md` suffix, moved into
`completed/` (e.g. `deploy-develop-ssh-heredoc-gotchas.md` →
`completed/deploy-develop-ssh-heredoc-gotchas.merged.md`), and gets a
short status note under its title noting what was applied where. Open
findings are the files directly in this folder; everything in
`completed/` is done. The original write-up
stays in the file below that note — it's the rationale/reproduction
record, not dead weight to delete.

A file in `completed/` is a record, not something to re-review or re-apply
from — check the git log around its rename for the commits that actually
applied it.
