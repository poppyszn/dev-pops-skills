---
name: cicd
description: Use when creating, modifying, or debugging CI/CD pipelines in GitHub Actions (.github/workflows/*.yml, .github/actions/*/action.yml), including lint/test/build CI for Node repos (single package, several independent apps, or Nx/npm-workspaces monorepos), single-job PR checks with a PR comment summary, building and pushing Docker images to GHCR (one image, or several in one Docker Bake job), deploying a compose stack to a server over SSH (registry pull or build-on-server), running seed/migration jobs against a deployed environment, production deploys (web to S3 + CloudFront, servers to a Docker host over SSH, with preflight, migrate-then-restart and SHA-pinned rollback), and failing, slow, or flaky pipeline runs. Not for writing Dockerfiles or compose files (use docker), Terraform plan/apply pipelines (use terraform), security scanning workflows, secrets, or token hardening (use security), or setting up a whole multi-app project at once (use project-infra).
metadata:
  version: "3.2.2"
  last-verified: "2026-11-01"
---

# CI/CD

Build CI and deploy pipelines on GitHub Actions from proven templates, and review or fix existing ones against the same rules.

## When to use

- Adding or editing a workflow or composite action
- "Set up CI", "build and push the image", "deploy develop to the server", "run the seed on develop"
- A run is failing, slow, flaky, or reports success without doing its work

Not for: Dockerfile/compose content (`docker`), Terraform plan/apply pipelines (`terraform`), security scanning, secrets and permission hardening (`security`), whole-project setup (`project-infra`).

## Defaults

Apply these without asking. Deviate only if the project already does it differently (say so) or the user asks.

- **Start from a template, copied verbatim** with `cp`. Then edit only `<ANGLE_BRACKET>` markers and the deltas its reference names. Never retype a workflow from memory.
- **Existing files are merged, never overwritten.** If the project already has the workflow, diff it against the template and bring over only the missing fixes. A working adaptation (pnpm, per-app matrix, monorepo paths) is not drift, and a verbatim copy over it is a regression.
- **Composite actions and reusable workflows are vendored** into the project's `.github/actions/` and `.github/workflows/`. `uses: ./…` needs the physical file. Keep a header comment naming the source asset, and never hand-edit the vendored copy.
- **Actions pinned to a version tag** (`@v7`), never `@main` or `@latest`. Container images run in steps are pinned too.
- **Least-privilege `permissions:`** at the top of every workflow (`contents: read` minimum). Grant more per job only where needed. A job-level block replaces the top-level one entirely, and a called workflow can't get more than its caller grants.
- **CI runs on pull requests only:** `pull_request` targeting `<INTEGRATION_BRANCH>` (the branch PRs merge into, e.g. `main` or `develop`) plus `workflow_dispatch`, with no push trigger. CI is enforced by making its jobs **required status checks** on that branch, a setting the user must turn on (list it in the summary). `nx-set-shas` gets `main-branch-name: <INTEGRATION_BRANCH>`.
- **Deploys never call the CI workflow.** Each deploy has a light `verify` job that `build-and-push` (or `deploy`) `needs`: install, lint, typecheck, and Nx module-boundary lint when the repo uses Nx. Nothing is pushed or deployed for a broken commit. Full test suites stay on PRs.
- **Concurrency:** `cancel-in-progress: true` for CI and build workflows, `false` for deploys (a cancelled deploy leaves a host half-updated).
- **No `${{ }}` inside `run:` scripts.** Pass inputs, `github.*` and secrets through `env:` and use the shell variable. Inline expressions are GitHub's documented script-injection pattern.
- **Values sent into a remote shell over SSH are quoted with `printf '%q'`**, every one of them, never hand-wrapped in quotes.
- **`docker compose run` inside an SSH heredoc gets `< /dev/null`.** Otherwise it swallows the rest of the script and the step still passes.
- **Log out of a registry in the final `if: always()` cleanup step, before anything there that can fail** (or from an `EXIT` trap in a one-off script). A logout that sits behind a failing command never runs.
- **Production deploys** (`references/deploy-production.md`):
  - the host runs images by commit SHA (`IMAGE_TAG`), and `latest-production` is only a pointer
  - the repository is synced with `git init` + `fetch` and the token is never written to `.git/config`
  - SSH host keys are pinned (`SSH_KNOWN_HOSTS`, strict checking)
  - a blocking `preflight.sh` runs before anything changes, and the host `.env` is never created by a deploy
  - migrations run as their own step before the api restarts, and a failure stops the job
  - a rollback is `commit_sha` with `skip_build`
- **`environment: production` has required reviewers and `production` is a protected branch.** Both are settings the user turns on: list them in the summary.
- **Optional SSH port:** `ssh-port: ${{ secrets.SSH_PORT || '22' }}`. An unset secret passes an empty string, which becomes `Bad port ''`.
- **Deploy secrets live in a GitHub Environment** (e.g. `develop`). Never ask for hosts or keys in chat, and never hardcode them.
- **When copying a workflow into a real project,** add a `github-actions` entry to that project's `dependabot.yml` so its action pins stay current.

## Workflow

1. **Inspect the project.** Find existing workflows, repo shape (one package, several independent apps, or a workspaces/Nx monorepo), registry (GHCR or none) and deploy target. If several apps and a deploy pipeline must be assembled together, switch to `project-infra`.
2. **Pick the template** from the References table and read its reference file first. For production also read the docker skill's production compose and the terraform skill's static-site and docker-host references for the AWS side.
3. **Copy assets verbatim.** Workflows go to `.github/workflows/`, composite actions to `.github/actions/<name>/action.yml`. Edit only markers and documented deltas. Fill `<INTEGRATION_BRANCH>` with the branch PRs target (ask if it isn't clear from the repo). If the file already exists, merge instead (see Defaults).
4. **Check pins are current.** For each `uses: owner/repo@ref`, confirm the ref exists (`gh api repos/<owner>/<repo>/git/refs/tags/<ref>`) and the major isn't behind (`gh api repos/<owner>/<repo>/releases/latest`). For images, check the registry. Use the current version and file the stale template pin as a gap (step 7).
5. **For an existing workflow (review/fix):** check it against the Defaults and `references/gotchas.md`. Classify each difference as deliberate, drift, or uncovered, and report the list before editing.
6. **Verify** (see Verification).
7. **File gaps, don't route around them:** write a finding to the skills repo's `contributions/` folder (two levels above this skill's real path; format in its `README.md`). Leave out the client, project and repository names; describe the project's shape instead ("a single-app NestJS API").

## Requires confirmation

Stop and confirm with the user before any of these:

- Triggering a workflow run (`gh workflow run`), re-running a deploy, or pushing to a branch that triggers a deploy
- Running `deploy-production`, `migrate-production` or `seed-production` (live traffic and the production database)
- Creating, changing or deleting repository/environment secrets or variables (`gh secret set`, `gh variable set`)
- Changing branch protection, environments or required reviewers
- Anything that SSHes into or changes a remote host
- Deleting workflow runs, caches, artifacts or packages

## Verification

Run these and report the actual output before calling the work done:

- YAML parses: `python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" <file>` for every workflow/action touched
- `actionlint` if installed (catches expression and shell errors YAML parsing can't)
- Every `uses:` ref exists (step 4)
- Read every `run:` body, in workflows and in `.github/actions/*/action.yml`, and confirm it contains no `${{ }}`, comments included. All such values must arrive through `env:`.
- `diff` each vendored or verbatim file against its asset. Every difference must be a documented substitution.
- Shell assets (`run-pr-checks.sh`, `detect-affected.sh`): `bash -n` and `shellcheck`, then run `detect-affected.sh` against a real base ref, and make one check fail on purpose to see the summary and a non-zero exit
- Bake: `docker buildx bake -f docker-bake.hcl --print` resolves every app, and one app builds locally
- Production: `preflight.sh` exits 0 against a realistic `.env` and exits 1 for each rule you added (test it with fixture files, never the real `.env`)
- Where possible, a real run on a branch or PR (after confirmation), with the result reported

## Examples

Good: inputs routed through `env:`, remote values quoted.
```yaml
- name: Deploy
  env:
    WORKING_DIR: ${{ inputs.working-dir }}
  run: |
    remote_dir=$(printf '%q' "$WORKING_DIR")
    ssh "$SSH_TARGET" "cd $remote_dir && docker compose up -d --wait"
```

Bad: shipped once in `ssh-compose-deploy`. The expression is pasted into the script before bash runs, so shell metacharacters in the value execute:
```yaml
  run: ssh host "cd '${{ inputs.working-dir }}' && docker compose up -d"
```

Bad: a deploy that calls CI as a reusable workflow (`uses: ./.github/workflows/ci.yml`). It re-runs the full suite already run on the PR for the same commit, slowing every deploy. Use the light `verify` job instead.

Bad: `docker compose run --rm migrate` followed by `up -d --wait` in the same `ssh … bash -s << 'EOF'` heredoc, without `< /dev/null`. `up` never runs and the job is green.

## References

Load these only when the task needs them:

| Need | Assets | Read first |
|---|---|---|
| CI for a single-package Node repo | `assets/workflows/ci-simple.yml` | `references/ci-simple.md` |
| CI for several independent apps (no workspaces) | `assets/workflows/ci-multi-app.yml` | `references/ci-multi-app.md` |
| CI for an Nx monorepo (affected-only) | `assets/workflows/ci.yml` | `references/ci-nx.md` |
| Build and push an image to GHCR (reusable workflow) | `assets/workflows/docker-build-push.yml` | `references/docker-build-push.md` |
| Deploy a compose stack over SSH, pulling from a registry | `assets/actions/ssh-compose-deploy/action.yml` | `references/ssh-compose-deploy.md` |
| Deploy by building on the target host (no registry) | `assets/workflows/deploy-develop-build-on-server.yml` + `assets/actions/git-sync-deploy/action.yml` | `references/build-on-server.md`, `references/git-sync-deploy.md` |
| PR checks for an npm-workspaces monorepo in one job, posted as a PR comment | `assets/workflows/pr-checks.yml`, `assets/scripts/run-pr-checks.sh`, `assets/scripts/detect-affected.sh` | `references/pr-checks.md` |
| Build several app images from one repo in one job (Docker Bake), and deploy only what a push changed | `assets/workflows/docker-bake-push.yml`, `assets/bake/docker-bake.hcl` (+ `detect-affected.sh`) | `references/docker-bake.md` |
| Run a seed job on demand against a deployed environment | `assets/workflows/run-seed-develop.yml` | `references/run-seed.md` |
| Production: web to S3 + CloudFront, servers to a Docker host over SSH (pnpm + Nx, or npm workspaces), plus manual migrate and seed | `assets/workflows/deploy-production-nx.yml` or `deploy-production.yml`, `migrate-production.yml`, `seed-production.yml` (with `docker-build-push.yml`) | `references/deploy-production.md` |

- `references/gotchas.md`: every CI/deploy rule with the real bug behind it. Read before reviewing or fixing an existing pipeline.
- `references/sources.md`: action versions and platform facts, with the date each was checked.
