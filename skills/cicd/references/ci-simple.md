# Simple Node CI template

For a single-package Node/TypeScript repo (not a monorepo). Lint, test,
build on every PR and push to `main`.

## What to change when copying this template

- Set `<INTEGRATION_BRANCH>` to the branch PRs merge into (`main`, `develop`…). CI runs on PRs to it plus manual dispatch, with no push trigger. Then make the job(s) required status checks on that branch.
- Adjust `node-version` to match your project's `.nvmrc`/`engines`
  field.
- If your test suite needs a database/Redis, add `services:` containers
  with healthchecks (see `ci.yml`'s README for a worked example) rather
  than mocking — mocked infra tests can pass while the real thing fails.
- `cancel-in-progress: true` is intentional for CI (not deploy) workflows
  — a new push should cancel a stale in-flight CI run.
