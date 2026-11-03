# Build-on-server develop deploy — design

Status: Approved
Source project this was extracted from: a client repo (Nx monorepo,
GHCR-based `docker/develop` deploy) — adapted here to drop the registry hop.

## Problem

The existing deploy story (`docker-build-push.yml` + `ssh-compose-deploy`)
assumes a container registry: CI builds an image, pushes to GHCR, the
remote host pulls it. That's the right shape for an org-owned GHCR
namespace, but doesn't fit a personal-account private repo where the
user doesn't want a registry in the loop at all. For that case the
simplest correct thing is: SSH to the target host, sync the repo's
source there, and let `docker compose build` build the image **on the
host it, using the same `docker/develop/compose.yml` shape as
`compose.deploy.yml`'s pull-based sibling, just with `build:` instead of
`image:`.

This was previously undocumented — an agent picking up this templates
repo had no path for "private repo, no registry, deploy by building on
the target host" and would either invent something ad hoc or ask the
human to explain SSH/secrets conventions that should already be written
down. This spec fills that gap.

## Non-goals

- Not replacing `ssh-compose-deploy`/`docker-build-push.yml` — both
  patterns stay, documented as alternatives for different situations
  (registry vs. no registry).
- Not building a generic "any CI provider" abstraction — GitHub Actions
  only, matching the rest of this repo's scope.

## Design

### 1. `ci-cd/github-actions/actions/git-sync-deploy/` (new composite action)

Mirrors `ssh-compose-deploy`'s security conventions (inputs via `env:`,
`printf '%q'` quoting into the remote shell, documented
`StrictHostKeyChecking no` tradeoff) but does source sync instead of
image pull:

- Configures SSH (optional `ssh-jump-host`/`ssh-jump-user`, same as
  `ssh-compose-deploy`).
- On the remote host: clones the repo into `working-dir` if not already
  present, else fetches and hard-resets to the target branch/SHA. Uses
  `https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO}.git` as the
  clone URL — the run's own `GITHUB_TOKEN` (passed as an input, sourced
  from `secrets.GITHUB_TOKEN` by the caller), valid for the lifetime of
  the job, no separate PAT needed even for a private repo. Immediately
  resets the origin URL to a token-free form after fetching so the
  token isn't left sitting in `.git/config` on disk.
- Bootstraps `docker/develop/.env` from `docker/develop/.env.example` on
  first sync only (never overwrites).

Inputs: `ssh-private-key`, `ssh-jump-host` (optional), `ssh-jump-user`
(optional), `ssh-host`, `ssh-user`, `ssh-port` (default `22`),
`working-dir`, `repo` (`owner/name`), `branch`, `github-token`,
`compose-dir` (default `docker/develop`).

### 2. `ci-cd/github-actions/deploy-develop-build-on-server.yml` (new workflow template)

Reusable/callable workflow modeled on a client repo's
`deploy-develop.yml` minus the `build-and-push`/GHCR-pull jobs:

1. Trigger: `push: branches: [develop]` (+ `workflow_dispatch` with an
   optional `commit_sha` input, matching the reference repo).
2. `concurrency: group: deploy-${{ github.ref }}, cancel-in-progress: false`
   — never cancel a mid-flight deploy (documented rationale carried over
   from `ssh-compose-deploy`).
3. Calls `git-sync-deploy` to land the code on the host.
4. Remote step: `cd docker/develop && docker compose --env-file .env build`,
   then (if a `migrate` service exists in the compose file)
   `docker compose --env-file .env run --rm migrate`, then
   `docker compose --env-file .env up -d --wait --wait-timeout 120`.
5. Health-check step reusing the JSONL-vs-array-tolerant `docker compose
   ps --format json | jq` pattern already established in
   `ssh-compose-deploy`/a client repo — dump logs for any
   non-running container and fail the job.
6. Prune step (`docker image/builder/container prune`, same retention
   defaults as `ssh-compose-deploy`).
7. `$GITHUB_STEP_SUMMARY` deployment report (status/host/commit/branch).

### 3. `docker/develop/` directory convention (documented, not a new template dir)

Add a short section to `docker/node-api/README.md`,
`docker/frontend-nextjs/README.md`, and `docker/frontend-spa-nginx/README.md`
each pointing at a new shared doc, `docker/develop-environment.README.md`:

- `docker/develop/compose.yml` is the **build-on-server sibling** of
  `compose.deploy.yml`: same service shape (one-shot `migrate`/`seed`,
  long-running app services, `restart: unless-stopped` on the latter
  only), but every service uses `build:` (pointing at the repo's
  Dockerfile) instead of `image:` — because there's no registry, the
  image must be built where it runs.
- `docker/develop/.env.example` documents the deploy-time env vars
  (production-mode values, container-network hostnames where relevant)
  — same idea as the project-root `.env.example` but for the deployed
  stack, not local dev.
- This directory is **only for the no-registry deploy path**. If a
  registry is in play, use `compose.deploy.yml` at the project root
  instead (existing convention) — don't use both for the same project.

### 4. Required GitHub Environment secrets (documented)

New table in `docker/develop-environment.README.md`, scoped to a GitHub
Environment named `develop` (matching a client repo's
`environment: develop` on the deploy job — enables required-reviewer
gating later if wanted):

| Secret | Purpose |
|---|---|
| `SSH_PRIVATE_KEY` | Key `git-sync-deploy`/deploy workflow authenticates with |
| `SSH_HOST` | Target host (or the final hop if using a jump host) |
| `SSH_PORT` | Defaults to `22` if unset |
| `SSH_USER` | Remote user |
| `SSH_JUMP_HOST` / `SSH_USER_JUMP` | Optional ProxyJump hop |
| `WORKING_DIR` | Absolute path on the host the repo is cloned into |

`GITHUB_TOKEN` is **not** a secret to configure — it's the workflow's
own automatic token, passed through as an input.

This table is the answer for "what do I ask the human for" — an agent
should ask the human to add these secrets/environment in GitHub repo
settings, never ask for the raw values in chat.

### 5. Multi-app matrix variant for `security.yml`'s `image-scan` job

`security.yml` currently assumes one Dockerfile at the project root.
Add a documented alternative in `security.README.md` (not a second
workflow file) showing the a client repo matrix shape:

```yaml
image-scan:
  strategy:
    matrix:
      app: [api, storefront, seller, admin] # one entry per Dockerfile
  steps:
    - uses: docker/build-push-action@v6
      with:
        file: apps/${{ matrix.app }}/Dockerfile
        tags: security-scan-${{ matrix.app }}:latest
        ...
    - uses: aquasecurity/trivy-action@...
      with:
        image-ref: security-scan-${{ matrix.app }}:latest
```

Note in the README: swap in this variant instead of the single-image
job whenever the repo has more than one Dockerfile (monorepo with
multiple deployable apps).

### 6. `CLAUDE.md` index

Add one row:

| Need | Template |
|---|---|
| Deploy to a branch environment by building directly on the target host (no registry, e.g. private non-org repo) | [`ci-cd/github-actions/deploy-develop-build-on-server.yml`](ci-cd/github-actions/deploy-develop-build-on-server.yml) + [`ci-cd/github-actions/actions/git-sync-deploy/`](ci-cd/github-actions/actions/git-sync-deploy/README.md) |

## Validation

Same as the rest of this repo — no build/test suite; syntax-check new
YAML with `python3 -c "import yaml; yaml.safe_load(...)"` and new shell
with `bash -n`.
