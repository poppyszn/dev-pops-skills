# Nx monorepo CI template

For an Nx monorepo with multiple apps. Uses `nx affected` so only
changed projects run lint/test/build, and only runs e2e when an
affected project is an `app` (not a shared lib).

## What to change when copying this template

- Set `<INTEGRATION_BRANCH>` to the branch PRs merge into (`main`, `develop`…). CI runs on PRs to it plus manual dispatch, with no push trigger. Then make the job(s) required status checks on that branch.
- `<INTEGRATION_BRANCH>` appears twice: in `on.pull_request.branches` and in `nx-set-shas`' `main-branch-name`. Both must match.
- Requires `nrwl/nx-set-shas` to correctly compute the affected base —
  don't remove this step or `nx affected` will fall back to comparing
  against the wrong commit.
- The `e2e` job's `if: needs.affected.outputs.apps != '[]'` guard means
  a lib-only PR (e.g. a shared types package) skips e2e entirely —
  adjust if you want e2e to run whenever ANY affected project changes.
- Add `paths-ignore: ['**.md', 'docs/**']` at the workflow level if you
  want doc-only changes to skip CI entirely.

## Adding a database/Redis for e2e

```yaml
services:
  postgres:
    image: postgres:16-alpine
    env:
      POSTGRES_PASSWORD: postgres
    ports: ["5432:5432"]
    options: >-
      --health-cmd pg_isready
      --health-interval 5s
      --health-timeout 5s
      --health-retries 10
```
Add this under the `e2e` job, then write a throwaway `.env.e2e` inline
via a heredoc step before running your e2e command.
