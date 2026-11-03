# Production deploy: web on S3 + CloudFront, servers on a Docker host over SSH

Assets: `assets/workflows/deploy-production-nx.yml` (pnpm + Nx, affected detection) or `assets/workflows/deploy-production.yml` (npm workspaces), plus `migrate-production.yml`, `seed-production.yml` and the vendored `docker-build-push.yml`. From the `docker` skill: `assets/node-api/compose.production.yml`, `preflight.sh`, `env.production.example`. The AWS side (bucket, distribution, deploy role, the host itself) is the `terraform` skill's `static-site` template and `docker-host` reference.

```text
push to production, or run by hand
  detect / verify            light gate: lint + typecheck (Nx: only affected apps)
    ├─ build-and-push        one image per server app, tagged <sha> and latest-production (skipped on a rollback)
    │    └─ deploy-server    pull by SHA -> sync repo -> preflight -> migrate -> start -> smoke test -> clean up
    └─ deploy-web            build -> s3 sync -> CloudFront invalidation -> smoke test      (in parallel)
```

## Set up once

1. **AWS side**: the `terraform` skill (`references/static-site.md`, `references/docker-host.md`). Its outputs map onto the GitHub variables below.
2. **Copy the files** into the project, never retype them: the workflow you need, `migrate-production.yml`, `seed-production.yml` and `docker-build-push.yml` into `.github/workflows/`; `compose.production.yml` to `docker/production/compose.yml`, `preflight.sh` to `docker/production/preflight.sh`, `env.production.example` to `docker/production/.env.example`. Fill the `<ANGLE_BRACKET>` markers in the compose file and the `env:` block at the top of the workflow.
3. **`docker/production/.env` is in `.gitignore`.** The deploy runs `git clean`, which deletes untracked files that are not ignored; the sync step refuses to continue if the file is not ignored.
4. **A GitHub Environment named `production`** with required reviewers and deployment branches restricted to `production`. The OIDC role trusts only jobs that declare `environment: production`, so this is what gates AWS access.
5. **Branch protection on `production`**: changes arrive by pull request from the integration branch, and the CI jobs are required status checks. CI itself runs on pull requests (see SKILL.md), not here.
6. **Environment secrets and variables**:

   | Kind | Name | Value |
   |---|---|---|
   | secret | `SSH_PRIVATE_KEY` | Private half of the deploy key (generate the pair on your machine) |
   | secret | `SSH_USER`, `SSH_HOST` | Login for the host |
   | secret | `SSH_KNOWN_HOSTS` | `ssh-keyscan -p <port> <host>` output, plus the bastion's if one is used. Required: host checking is strict. |
   | secret | `WORKING_DIR` | Directory on the host where the repository is checked out |
   | secret (optional) | `SSH_PORT` | Defaults to 22 |
   | secret (optional) | `SSH_JUMP_HOST`, `SSH_USER_JUMP` | Bastion, if the host is private |
   | variable | `AWS_ROLE_ARN`, `AWS_REGION`, `WEB_BUCKET`, `CLOUDFRONT_DISTRIBUTION_ID` | From the Terraform outputs |
   | variable | `VITE_API_ORIGIN` | Public API origin, `https://...`, no trailing slash. Rename it to your framework's variable (`NEXT_PUBLIC_*`, ...) in the workflow too. |
   | variable (optional) | `WEB_URL`, `API_HEALTH_URL` | Turn on the post-deploy smoke tests, e.g. `https://erp.example.com` and `https://api.example.com/health` |

## First deploy

The sync step uses `git init` + `fetch`, so `docker/production/.env` can be created on the host **before** the first deploy. Create it at `<WORKING_DIR>/<repo>/docker/production/.env` from `.env.example`, fill in real values, then run the workflow. The preflight stops the deploy, with a message, if the file is missing, still has `<placeholder>` values or breaks a rule you added. Escape every `$` in a secret as `$$` (compose reads this file itself).

## Rollback

Run the workflow by hand with `commit_sha` set to the last good commit and `skip_build` on (in the Nx variant also `deploy_all`: "affected" is computed from the last successful deploy, so without it a rollback skips apps). It redeploys the images already built for that commit (the host runs `ghcr.io/<owner>/<repo>-<app>:<sha>`), re-syncs the repository to that commit, and rebuilds and re-syncs the web app from it. Without `skip_build` the same inputs rebuild that commit. Migrations are not reversed by a redeploy, so check them before releasing: they run while the old api still serves traffic and must stay compatible with it (add first, remove in a later release).

## Why it is shaped this way

- **A light gate, not the CI workflow.** Calling CI from a deploy re-runs the full suite for a commit whose pull request already ran it. Deploying with no check at all lets a broken push reach the host. The `detect` (or `verify`) job lints and typechecks, inside the job that already installs dependencies, and the build waits for it.
- **Deploy by commit SHA.** Every image is tagged `latest-production` and `<sha>`; the host runs the SHA (`IMAGE_TAG` in `compose.production.yml`). `latest-production` is a pointer for people. A compose file pinned to the moving tag turns a rollback into a rebuild.
- **`init` + `fetch`, token per command.** `git clone` refuses a directory that already holds files (tested: it fails with "destination path already exists and is not an empty directory"). The token is passed with `http.extraheader` for the one fetch and never written to `.git/config`, so a failed run cannot leave it behind.
- **The host `.env` is never created by the deploy.** `git-sync-deploy` copies `.env.example` to `.env` when none exists, which is right for a develop box and wrong here: a production host booting with placeholder secrets is worse than a deploy that stops. The preflight is a script in the repository (`preflight.sh`), run from the deployed commit on the host, so it can be tested and reviewed. It asserts exact non-secret lines, rejects `<placeholder>` values, and renders the stack with `docker compose config --quiet`; it never prints the file.
- **Migrations before the restart, as their own step.** A failed migration stops the job while the old api keeps running. The manual migrate and seed workflows share the `deploy-production` concurrency group, so none of them can overlap a deploy; seeding also needs the word `production` typed in.
- **Web in parallel with the servers.** A release does not wait on image builds, at the cost that a failed server deploy can leave the new SPA live against the old api. Keep api changes backward compatible with the previous SPA, or add `deploy-server` to the web job's `needs` to order them.
- **Pinned host keys.** `SSH_KNOWN_HOSTS` plus `StrictHostKeyChecking yes`, so nothing but the real host can answer. The develop actions (`ssh-compose-deploy`, `git-sync-deploy`) and `run-seed-develop.yml` pin host keys the same way since cicd 3.0.0, through the same `SSH_KNOWN_HOSTS` secret.
- **Logout cannot be skipped.** The cleanup step logs out of GHCR first and only then prunes, so a failing prune cannot leave the credentials on the host. The migrate and seed workflows log out from an `EXIT` trap.
- **Smoke tests that catch the real failures.** The web check requests a client-side route (it must return HTML with 200) and a file that cannot exist under `/assets/` (it must return 404). A distribution that rewrites missing files to the app shell passes a plain "does `/` load?" check and fails this one.
- **Cleanup prunes images older than a week and builder cache older than two** on the host. GHCR keeps every SHA-tagged image, so a rollback pulls again; the host only forgets.

## Choices to make when copying

- **Native arm64 builds.** `docker-build-push.yml` builds amd64 and arm64 under QEMU, which works for any host but is slow. For an arm64 host, replace the `build-and-push` job with an inline job on `runs-on: ubuntu-24.04-arm` that runs `docker/build-push-action` with the same two tags. The runner architecture must match the host.
- **Nx targets.** The gate runs `lint,typecheck`; use the targets the repository has. Module boundaries are enforced by the lint target (`@nx/enforce-module-boundaries`), so they need no step of their own.
- **`force_api_deploy`** (Nx variant): editing the host's `.env` touches no tracked file, so nothing is "affected". Run the workflow by hand with it on to run the preflight and reload the api.
- **Extra services** (a server-rendered storefront): add the app to `DEPLOYABLE_APPS`, give it an `apps/<name>/Dockerfile`, and add the `ssr` service block from the docker skill's `references/node-api.md` to the compose file.
- **Without the Nx variant:** `deploy-production.yml` deploys the apps in its `SERVER_APPS_ALL` list and the web app on every run; the manual `deploy_server` and `deploy_web` inputs narrow a hand-run.
