# Deploy workflow gates on CI by calling it as a reusable workflow

> **Status: merged 2026-09-26** (cicd 2.0.0, project-infra 2.0.0).
> - Checked: no template's deploy called CI (that was a client repo's adaptation), but no deploy had any check before shipping either.
> - Applied: "deploys never call CI" plus the light `verify` gate (install, lint, typecheck with `--if-present`; Nx variant with affected + module-boundary lint) in cicd Defaults and `references/gotchas.md`. The gate is added to `deploy-develop-build-on-server.yml` and the example's `deploy-develop.yml` (`build-and-push` needs it). `--workspaces --if-present` behaviour tested with npm 11.

**Where found:** a client repo `deploy-develop.yml`, same shape as the
`monorepo-layout` / cicd deploy templates' chaining.

**Status:** guidance gap. Calling CI from the deploy (`uses: ./.github/workflows/ci.yml`)
re-runs the full quality suite on every deploy, duplicating the PR run for the
same commit and slowing every deploy. The maintainer's decision is that CI runs
on pull requests only and the deploy workflow contains no CI job.

**Suggested fix:** state in `cicd` SKILL.md defaults that deploy workflows do
not embed CI (protect the branch with required PR checks instead), and make sure
no template's deploy calls the CI workflow. Note that this makes required
status checks / branch protection the enforcement point, so `project-infra`
should list it under "needs the user".

## Update: replace the gate with a light pre-deploy check

Removing CI from deploy entirely leaves nothing between a push and the server.
Maintainer decision: the deploy workflow carries a *light* gate, not the full
suite. It runs before any image is pushed and covers only what would break the
app once deployed: lint, module-boundary check, and
typecheck (affected projects, or everything on `deploy_all`). Full lint, unit,
e2e and browser tests stay on pull requests. Suggested fix: add this light-gate
shape to the cicd deploy template guidance, run inside the existing
change-detection job so it costs no extra install, and gate `build-and-push` on
it so `latest-<env>` is never pushed for a broken commit.
