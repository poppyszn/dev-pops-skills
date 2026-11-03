<!--
Branches are `<type>/<slug>`; commits follow Conventional Commits.
Keep a PR to one reviewable change.
Delete a section that genuinely does not apply, and say why in one line
rather than leaving it blank.
-->

## What changed

<!-- One or two sentences. -->

## Why

<!-- The reason, not the diff. Link the issue if there is one. -->

## How it was verified

<!--
The commands you ran and what they printed. Not "should work" — CI passing
is necessary, not sufficient, because CI does not start the stack.
-->

```
$
```

- [ ] `npm run lint`, `npm test` and `npm run build` pass locally, not only in CI
- [ ] For an infra change: `docker compose config -q` parses, and
      `docker compose up -d --wait` brings every service to `healthy`
- [ ] For a workflow change: YAML parses (`actionlint` if installed), and the
      job ran at least once — on this PR, or via `workflow_dispatch`
- [ ] Every new image tag and action ref is pinned to an exact version, never
      `latest`, and was confirmed current

## Deploy impact

<!--
Delete if none. Otherwise: does this need a migration, a new secret or
environment variable, a changed port, or a manual step on the server? Name
each one. A new secret is added in the GitHub Environment by a human — never
committed, and never pasted into a PR comment.
-->

## Rollback

<!--
How to undo this. "Revert the PR" only counts if it is actually true — a
migration, a pushed image tag, or a changed volume needs its own answer.
If you cannot say how to undo it, it is not ready.
-->
