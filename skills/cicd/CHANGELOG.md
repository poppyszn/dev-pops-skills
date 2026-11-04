# Changelog

## 3.2.0 - 2026-11-04

- **New: single-job PR checks** (`assets/workflows/pr-checks.yml`, `assets/scripts/run-pr-checks.sh`, `assets/scripts/detect-affected.sh`, `references/pr-checks.md`), from a monorepo's pipeline that replaced a per-app matrix: one runner checks every affected app several at a time and posts one PR comment (updated in place) with a pass/fail table and the end of each failing log. The comment step has `continue-on-error` so only the checks decide the result, and the summary shows `pull_request.head.sha`, not the merge commit.
- **New: several app images in one Docker Bake job** (`assets/workflows/docker-bake-push.yml`, `assets/bake/docker-bake.hcl`, `references/docker-bake.md`). Same tags as `docker-build-push.yml`, one GHA cache scope per app, `max-parallelism` sized to the runner. The reference also covers deploying only what a push changed (`github.event.before`, a missing base deploys everything, an empty list skips the later jobs).
- `references/gotchas.md`: the default step shell has no pipefail; `GITHUB_SHA` on `pull_request` is a merge commit; cache scope, 7-day eviction and gzip vs zstd entries; private-repo hosted runners are 2 CPU / 8 GB; diff the whole push; `paths-ignore: .github/**` and two push-triggered deploys; seeds on request; quote a `name:` containing `: `.
- `docker-build-push.yml` and its reference no longer name a real repository and owner (standard §12); the project-infra vendored copy is re-copied.
- Checked: both scripts pass `bash -n` and shellcheck; in a throwaway npm-workspaces repo `detect-affected.sh` gave the same results on bash 3.2 and 5 (a two-commit push, the last commit only, no change, a shared-folder change, an unknown base exits 1), and `run-pr-checks.sh` produced the table, a failing lint's excerpt and exit 1, `—` for a missing script, and exit 0 for "nothing to check" and all-green. `docker buildx bake --print` resolved the bake file with and without CI variables, one app built by name, and two apps built together shared all but their own layer. `actionlint` (with shellcheck) reports nothing on the new and edited workflows.
- Not run: a real GitHub Actions run of either workflow (the patterns ran in production on the source pipeline, but these generic copies have not).

## 3.1.0 - 2026-11-03

- The "file gaps" step now says to leave out the client, project and repository names and describe the project's shape instead (standard §12 in skill-authoring).

## 3.0.0 - 2026-11-03

- **Breaking: the develop SSH path pins host keys.** `ssh-compose-deploy` and `git-sync-deploy` take a new required `ssh-known-hosts` input, `run-seed-develop.yml` reads a new `SSH_KNOWN_HOSTS` secret, and all three set `StrictHostKeyChecking yes` (they were `no`, documented as an accepted risk). An empty value fails the step. Existing callers must add the `SSH_KNOWN_HOSTS` secret (the output of `ssh-keyscan -p <port> <host>`, plus the jump host's line) and pass it; this is the same rule the production workflows already used, so the two paths no longer disagree.
- `references/ssh-compose-deploy.md`: the "Accepted risk" section is replaced by "Host keys are pinned" (how to create the value, why not to scan inside the workflow). `git-sync-deploy.md`, `run-seed.md` and `deploy-production.md` updated to match.
- Checked: all workflows and actions parse; `actionlint` is clean on every template (laid out as a project holds them); the new "Configure SSH" step was run in a throwaway `HOME` for each of the three files with an empty value (exits 1, writes nothing), a value, and a value plus a jump host (strict on every host block).
- Not run: a real deploy against a host.

## 2.1.0 - 2026-11-01

- **New: production deploy templates**, built from a hand-made pipeline after a review: `deploy-production-nx.yml` (pnpm + Nx, affected detection) and `deploy-production.yml` (npm workspaces), `migrate-production.yml` and `seed-production.yml`, with `references/deploy-production.md`. Web goes to S3 + CloudFront with an OIDC role; servers deploy to a Docker host over SSH.
- Differences from the source pipeline, on purpose: a light lint + typecheck gate inside the detect job instead of embedding the full CI; the host runs images by commit SHA with a `skip_build` rollback; a clone-safe sync (`init` + `fetch`) that never writes the token to `.git/config` and refuses to run `git clean` unless `.env` is ignored; registry logout that cannot be skipped; `preflight.sh` as a testable script; smoke tests that catch a distribution rewriting missing files to the app shell.
- **`docker-build-push.yml`: new optional `ref` input** (builds and tags that commit; empty keeps the old behaviour). Fixes the build ignoring a requested commit. The example project's vendored copy is re-copied and its develop deploy now passes `commit_sha`.
- New defaults for production deploys and for registry logout (see SKILL.md); gotchas for each bug behind them.
- Checked: all four workflows parse, every `run:` script passes `bash -n`, no `${{ }}` inside any script, every pinned action exists; the app-selection `jq` filters (9 cases) and the Compose-output handling (5 shapes) were run; the real sync step was run against a local repository (fresh host, `.env` created first, second deploy, `.env` not ignored).
- Not run: a real workflow run (no repository or host available) and `actionlint` (not installed). Fetching by SHA from github.com is `unverified` in `references/sources.md`.

## 2.0.1 - 2026-09-26

- Updated the path to the completed multi-app finding; the `run-seed-develop.yml` comment now points to `references/gotchas.md` instead of a contributions file.

## 2.0.0 - 2026-09-26

- **Changed default:** CI templates (`ci-simple`, `ci`, `ci-multi-app`) run on `pull_request` to `<INTEGRATION_BRANCH>` plus `workflow_dispatch`, with no push trigger. Required status checks enforce CI. `nx-set-shas` gets `main-branch-name`.
- **New default:** deploys never call CI and carry a light `verify` job (install, lint, typecheck) that gates the deploy. Added to `deploy-develop-build-on-server.yml`.
- New rule: existing workflows are merged, never overwritten with a template.
- Applied `contributions/ci-templates-no-pull-request-trigger-reuse` and `deploy-workflow-embeds-ci-gate`.

## 1.0.0 - 2026-09-26

- Migrated from the templates repo: ci-simple, Nx ci, docker-build-push, deploy-develop-build-on-server and run-seed-develop workflows, plus the ssh-compose-deploy and git-sync-deploy actions, and the CI standards (now `references/gotchas.md`).
- New `ci-multi-app.yml` for several independent apps without workspaces (applied finding).
- Added least-privilege top-level `permissions:` to every workflow that lacked it (`ci`, `ci-simple`, `deploy-develop-build-on-server`, `run-seed-develop`). `nx-set-shas` gets `actions: read`.
- Verified every action pin exists and is the current major.
