# Multi-app Node CI template

For a repo with **several independent apps side by side** (e.g. `backend/` and `frontend/`), each with its own `package.json` and `package-lock.json`, and **no** npm workspaces tying them together. This sits between `ci-simple.yml` (one root package) and `ci.yml` (Nx/workspaces monorepo, affected-only).

## What to change when copying this template

- Set `<INTEGRATION_BRANCH>` to the branch PRs merge into (`main`, `develop`…). CI runs on PRs to it plus manual dispatch, with no push trigger. Then make the job(s) required status checks on that branch.
- Copy the job once per app. Rename `<APP_NAME>` (the job id, e.g. `backend`) and set all three `<APP_DIR>` markers to that app's directory.
- `defaults.run.working-directory` makes every `run:` step execute inside the app. `uses:` steps ignore it, which is why `cache-dependency-path` must name the app's lockfile explicitly.
- Adjust `node-version` per app if they differ.
- **No tests?** Delete the `npm test` step for that app rather than leaving it to fail. A `create-next-app` scaffold, for example, has no `test` script. Add the step back once tests exist.

## Why one job per app, not a matrix

Apps in this layout usually differ (a job may drop `npm test`, need a service container, or use a different Node version). Separate jobs keep those differences explicit and readable. If every app is truly identical, a `strategy.matrix` over app directories works too.

## Origin

Filed as a gap from `test-app` (NestJS `backend/` + Next.js `frontend/`). See the repo's `contributions/completed/ci-simple-multi-app-non-workspace-gap.merged.md`.
