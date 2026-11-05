---
name: cicd
description: Use when creating, modifying, or debugging GitHub Actions CI/CD (.github/workflows/*.yml, .github/actions/*/action.yml), including lint/test/build CI for Node repos (single package, several apps, or Nx/npm-workspaces monorepos), single-job PR checks with a PR comment, building and pushing Docker images to GHCR (one image, or several in one Bake job), the standard deploy pipeline every project copies (build, migrate and deploy a compose stack over SSH, the same for develop and production), making every repository's deploy pipeline the same, seed and migration runs, production deploys (S3 + CloudFront web, Docker host servers, SHA-pinned rollback), and failing, slow, or flaky runs. Not for Dockerfiles or compose files (use docker), Terraform plan/apply pipelines (use terraform), security scanning, secrets, or token hardening (use security), or setting up a whole multi-app project at once (use project-infra).
metadata:
  version: "4.1.1"
  last-verified: "2026-11-05"
---

# CI/CD

Build CI and deploy pipelines on GitHub Actions from proven templates, and review or fix existing ones against the same rules.

## When to use

- Adding or editing a workflow or composite action
- "Set up CI", "build and push the image", "deploy develop to the server", "run the seed on develop"
- "Run the seed or migrations on demand", "add a manual migration workflow", "run migrations on the server"
- "Make our deploy pipelines consistent", "move this repo to the standard pipeline", "update the deploy pipeline in every repo", "why does every repo deploy differently?"
- A run is failing, slow, flaky, or reports success without doing its work

Not for: Dockerfile/compose content (`docker`), Terraform plan/apply pipelines (`terraform`), security scanning, secrets and permission hardening (`security`), whole-project setup (`project-infra`).

## Defaults

Apply these without asking. Deviate only if the project already does it differently (say so) or the user asks.

- **Start from a template, copied verbatim** with `cp`. Then edit only `<ANGLE_BRACKET>` markers and the deltas its reference names. Never retype a workflow from memory.
- **Existing files are merged, never overwritten.** If the project already has the workflow, diff it against the template and bring over only the missing fixes. A working adaptation (pnpm, per-app matrix, monorepo paths) is not drift, and a verbatim copy over it is a regression.
- **Workflow names follow `<Category>: <Action>` or `<Environment>: <Action>` (or the action alone for unified multi-environment workflows).** In GitHub's Actions sidebar, prefixing workflow names keeps them grouped cleanly:
  - CI workflows: `CI: <Name>` (e.g. `CI: PR checks`, `CI: Checks`, `CI: Warm dependency cache`, `CI: Nightly e2e`).
  - Environment-specific deploy and operational workflows: `<Environment>: <Action>` (e.g. `Production: Deploy`, `Production: Migrate`, `Production: Seed`, `Develop: Seed`, `Testing: Deploy`).
  - Unified multi-environment workflows (`deploy.yml`, `migrate.yml`, `seed.yml` with an environment input or branch trigger): named simply by the action (e.g. `Deploy`, `Migrate`, `Seed`), because one file serves multiple environments.
  - Reusable workflows: `name: "Reusable: <Name>"` (e.g. `Reusable: Deploy pipeline`, `Reusable: Deploy pipeline (Bake)`, `Reusable: Run service`), with filenames carrying a leading underscore (`_deploy-pipeline.yml`, `_deploy-pipeline-bake.yml`, `_run-service.yml`) so they group cleanly in file trees.
- **Deploys use the standard deploy pipeline.** A project's deploy is `.github/workflows/deploy.yml` (from `assets/deploy-workflows/deploy.yml`): its own `verify` job, then a call to the local `_deploy-pipeline.yml` (or `_deploy-pipeline-bake.yml` for multi-app Bake builds) with `secrets: inherit`. The same file deploys `develop` and `production`; seeds and migrations go through `seed.yml` and `migrate.yml` over `_run-service.yml`. `_deploy-pipeline.yml`, `_deploy-pipeline-bake.yml` and `_run-service.yml` are copied verbatim with the vendored header and never edited in the project; a change to them is made in this skill and re-copied into every project (`references/deploy-pipeline.md`). Both pipelines support an optional `runner` input (default: `ubuntu-24.04-arm`, or pass `ubuntu-latest` or a JSON list `["ubuntu-24.04-arm", "ubuntu-latest"]` to build on both). No per-environment deploy files and no vendored deploy actions. The self-contained deploy templates remain only when the user asks for them.
- **Manual runs for migrations and seeds:** When using the standard deploy pipeline, manual database operations use `migrate.yml` and `seed.yml` (calling `_run-service.yml` with an `environment` choice input `[develop, production]`). They run against the exact commit SHA currently live on the host. For older per-environment deploy setups, `Production: Migrate`, `Production: Seed`, and `Develop: Seed` run against that specific environment.
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
5. **For an existing workflow (review/fix):** for deploys, run `assets/scripts/check-deploy-conformance.sh` from the project root first; it compares the two copied pipeline files with this skill's and lists every other difference from the standard. Check the rest against the Defaults and `references/gotchas.md`. Classify each difference as deliberate, drift, or uncovered, and report the list before editing.
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
- Deploy pipeline: in a scratch repository with the five files copied, run `actionlint` (it checks every input `deploy.yml` passes against what `_deploy-pipeline.yml` declares); `check-deploy-conformance.sh` reports `conforms` for a migrated project
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
| Deploy any project the same way: the standard pipeline (verbatim files, matrix or Docker Bake) and the short files each project keeps; check a project against it | `assets/deploy-workflows/{_deploy-pipeline,_deploy-pipeline-bake,_run-service,deploy,seed,migrate}.yml`, `assets/scripts/check-deploy-conformance.sh` | `references/deploy-pipeline.md` |
| Run a migration or seed job on demand against a deployed environment | `assets/deploy-workflows/{migrate,seed}.yml` (standard pipeline, calling `_run-service.yml`) or `assets/workflows/{migrate-production,seed-production,run-seed-develop}.yml` | `references/deploy-pipeline.md`, `references/run-seed.md` |
| Production: web to S3 + CloudFront, servers to a Docker host over SSH (pnpm + Nx, or npm workspaces), plus manual migrate and seed | `assets/workflows/deploy-production-nx.yml` or `deploy-production.yml`, `migrate-production.yml`, `seed-production.yml` (with `docker-build-push.yml`) | `references/deploy-production.md` |

- `references/gotchas.md`: every CI/deploy rule with the real bug behind it. Read before reviewing or fixing an existing pipeline.
- `references/sources.md`: action versions and platform facts, with the date each was checked.
