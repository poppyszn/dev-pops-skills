# No template wires PR checks to the project's CI workflow

> **Status: merged 2026-09-26** (cicd 2.0.0, security 2.0.0, project-infra 2.0.0).
> - Checked: templates did run on `pull_request`, but hardcoded `push: [main]`, had no `workflow_dispatch`, and left `nx-set-shas` `main-branch-name` at its `main` default.
> - Applied: every CI and security template now triggers on `pull_request` to `<INTEGRATION_BRANCH>` plus `workflow_dispatch` (security also keeps its weekly schedule), with no push trigger. `ci.yml` sets `main-branch-name`. Required status checks are listed in project-infra's "needs the user".

**Where found:** a client repo, adapted from `skills/cicd/assets/workflows/ci.yml`
and `deploy-develop.yml`.

**Status:** confirmed gap. The Nx/pnpm CI had only `workflow_call` +
`workflow_dispatch` (reused by the deploy), so nothing ran on pull requests.
The security and CI templates trigger on `pull_request`/`push: [main]`, which
does not match a repo whose integration branch is `develop`.

**Repro:** open a PR against `develop`; no CI check appears.

**Suggested fix:** in the CI templates and `project-infra` guidance, make
`on: pull_request` (plus `workflow_dispatch`) the default trigger, and say
which branch pushes/PR targets to use for the repo's integration branch
(`develop` vs `main`). `nrwl/nx-set-shas` `main-branch-name` must match it.
