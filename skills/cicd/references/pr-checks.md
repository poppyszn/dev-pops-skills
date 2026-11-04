# Single-job PR checks template

`assets/workflows/pr-checks.yml` with `assets/scripts/run-pr-checks.sh` and `assets/scripts/detect-affected.sh`: one job that builds, lints and tests every app a pull request touches, several apps at a time, and posts one PR comment saying what passed and what failed. For an npm-workspaces monorepo with apps under one folder (`apps/`). Nx monorepos use `ci.yml` (affected targets) instead.

## What to change when copying

- Copy the workflow to `.github/workflows/` and both scripts to `scripts/`, then `chmod +x scripts/*.sh`.
- `<INTEGRATION_BRANCH>`: the branch PRs merge into. Add more branches if PRs target several (e.g. `main` and `develop`).
- `<APPS_DIR>` in both scripts: the folder holding one directory per app.
- `<SHARED_DIR>` in `detect-affected.sh`: the shared library folder (`libs`, `packages`). A change there checks every app. Extend `SHARED` with anything else every app depends on.
- `CHECKS` in `run-pr-checks.sh`: the npm script names to run per app, in order. An app without a script shows `—` for it.
- `CHECKS_PARALLEL` in the workflow: apps checked at once. Keep 2 on a hosted runner for a private repo (2 CPUs, 8 GB). On a bigger or self-hosted runner, raise it until memory, not CPU, is the limit.
- Use the same `detect-affected.sh` in a pre-push hook and in deploys (`references/docker-bake.md`), so "what changed" means one thing everywhere.

## Why one job, not a matrix

A matrix needs one runner per app. On a small self-hosted pool (say 3 runners) a PR touching 11 apps queued for over 10 minutes before the last app started. On hosted runners each app paid its own checkout, install and cache restore. One job runs `npm ci` once and checks apps side by side: measured on 11 apps, about 31 billed minutes became about 5.5 minutes on one runner.

`run-pr-checks.sh` re-invokes itself per app (`--target <app>`) through `xargs -P`, because `xargs` can only run commands, not shell functions. Each check writes `<app>/<check>.log` and `<check>.result` under `.checks/`, and the parent reads them back to build the table. Add `.checks/` to `.gitignore`.

## The PR comment

- **One comment, updated in place.** The body starts with `<!-- pr-checks-summary -->`; the step looks for a bot comment starting with that marker and edits it instead of adding a new one per push.
- **The comment step has `continue-on-error: true` and `if: !cancelled()`.** The checks step decides pass or fail. Without `continue-on-error`, a comment that cannot be posted (a fork's read-only token, an API error) fails a green run; without `!cancelled()` a failed check skips the comment, the one time it matters.
- **The commit shown is `pull_request.head.sha`.** On `pull_request`, `GITHUB_SHA` is a temporary merge commit that exists nowhere in the PR. Shipped once: every summary named a commit nobody could find.
- **Failures show the end of the log**, with the checkout path stripped and lines cut at 300 characters, inside a `<details>` block. The whole summary is cut at 60,000 characters (a comment holds 65,536).
- The job summary (`$GITHUB_STEP_SUMMARY`) gets the same Markdown, so a run started by hand also shows it.

## Parallel apps share one Docker daemon

When e2e tests start containers (Testcontainers, a compose file), apps checked at the same time run on the same daemon. A fixed container name makes them clash: shipped once, three e2e checks failed with `409 Conflict: container name already in use`, and one run's `docker rm -f` deleted another run's database mid-test. The script exports `CHECK_TARGET=<app>` to every check: use it in test setup for anything named (`withName(\`e2e-postgres-${process.env.CHECK_TARGET ?? 'local'}\`)`), or leave names to Testcontainers, which picks random ones.

## Caching dependencies

`setup-node` with `cache: npm` caches the npm download cache, not `node_modules`. For a large monorepo, caching `node_modules` itself (keyed on `package-lock.json`, `npm ci` only on a miss) saves more. Three platform rules decide whether that cache ever hits:

- **A PR run restores only caches saved on its own branch, its base branch or the default branch.** A cache saved by an earlier PR run is invisible to every other PR. Save it from a push to the integration branch (a small workflow that runs on lockfile changes).
- **Entries not restored for 7 days are evicted** (10 GB per repository). In a quiet week the cache vanishes; add a daily `schedule` to that workflow. Scheduled runs use the default branch's workflow file and commit.
- **Runner types don't share entries when one lacks `zstd`.** The cache uses zstd when the runner has it and gzip otherwise, and the compression method is part of the cache version. A self-hosted runner without zstd (most minimal images) cannot restore what a hosted runner saved, and the reverse. Warm the cache on the same runner type that reads it, or install zstd on both.
