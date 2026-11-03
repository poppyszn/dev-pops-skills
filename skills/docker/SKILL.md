---
name: docker
description: Use when writing, reviewing, or debugging a Dockerfile, .dockerignore, compose.yaml / docker-compose.yml, or container entrypoint script, or when dockerizing a Node/TypeScript API, static SPA (Vite/CRA behind nginx), Next.js app, or Nitro SSR server. Also covers a production compose stack for a single Docker host behind nginx (loopback ports, images run by commit SHA, a preflight on the host `.env`), local S3 object storage for dev and tests (Adobe S3Mock, replacing MinIO), runtime env injection into frontend images, image size and layer caching, healthchecks, and container runtime issues such as crash loops, unreachable ports, or permission errors. Not for CI workflows or deploy pipelines (use cicd), image vulnerability scanning or secrets handling (use security), setting up a whole multi-app project (use project-infra), or general shell scripting (use scripting).
metadata:
  version: "1.4.1"
  last-verified: "2026-09-26"
---

# Docker

Dockerize Node/TypeScript apps from proven templates, and review or fix existing Dockerfiles and compose stacks against the same rules.

## When to use

- Adding or changing a `Dockerfile`, `.dockerignore`, compose file or `entrypoint.sh`
- "Dockerize this API / frontend / Next.js app"
- Build failures, slow or uncached builds, oversized images
- Containers that crash-loop, report unhealthy, can't be reached, or fail on file permissions

Not for: pipelines and deploys (`cicd`), CVE scanning and secrets (`security`), whole-project setup with several apps and pipelines (`project-infra`).

## Defaults

Apply these without asking. Deviate only if the project already does it differently (say so) or the user asks.

- **Start from a template, copied verbatim.** Copy the asset file with a file-copy command (`cp`), then edit only the `<ANGLE_BRACKET>` markers and the deltas its reference names. Never retype a template from memory: that silently drops fixes that exist because of real bugs.
- **Existing files are merged, never overwritten.** If the project already has a working Dockerfile or compose file (pnpm, Nx, per-app layouts), diff it against the template and bring over only missing fixes. A verbatim copy over a working adaptation is a regression.
- **Multi-stage build.** The final stage is the smallest runtime, not the build environment. Use a framework's traced output when one exists (Next.js `output: "standalone"`, Nitro `.output/`).
- **Pinned base images** (`node:24-alpine`), never `latest`.
- **Non-root `USER`** in the final stage.
- **`HEALTHCHECK` in the Dockerfile itself**, not only in compose, and against `127.0.0.1`, not `localhost`.
- **Package installs use `RUN --mount=type=cache`.**
- **Strip npm/npx from Node runtime images** that never run npm (removes unfixable CVE noise).
- **Runtime env for frontends:** `__VAR__` placeholders plus a `sed` entrypoint, following the five rules in `references/env-replacement.md`. Only for values baked into a client bundle.
- **Compose rules:**
  - `restart: unless-stopped` on services, none on one-shot jobs
  - `deploy.resources.limits` on every service
  - `depends_on` always with a `condition:`
  - public-facing services get an `environment:` allowlist, not the shared `env_file`
  - `${VAR:-default}` for optional values, `:?` only when every service needs it
  - `$` in `.env` secrets escaped as `$$`

  The reasons are in `references/compose.md`.
- **Build-local and pull-image stacks are separate files:** `compose.yml` and `compose.deploy.yml`.
- **A production stack publishes ports on `127.0.0.1` only**, pulls prebuilt images (never `build:`), and runs `ghcr.io/<owner>/<repo>-<app>:${IMAGE_TAG:-latest-production}` with the deploy setting `IMAGE_TAG` to the commit SHA. `preflight.sh` checks the host `.env` before every deploy. See `references/node-api.md`, "Production stack".
- **Local S3 is Adobe S3Mock** (`adobe/s3mock`, pinned), in dev and test stacks only, and only for apps that use object storage. Deployed environments use a real provider. **Never introduce MinIO** (archived). See `references/object-storage.md`.

## Workflow

1. **Inspect the project.** Find existing Docker files, the framework, the package manager and lockfile, the build output path, and whether it's a monorepo. If several apps or pipelines are involved, switch to `project-infra`.
2. **Pick the template** from the References table and read its reference file first.
3. **Copy the asset files verbatim** into the project, e.g. `cp <skill>/assets/node-api/Dockerfile docker/node-api/Dockerfile`. Then edit only the markers and the documented deltas.
4. **Check pins are current.** For each `FROM` / `image:` tag, confirm the tag exists and is a supported release (search the web or query the registry). Use a newer supported tag if the template's is stale, and file the stale pin as a gap (step 7).
5. **For an existing file (review/fix):** compare it against the template and `references/compose.md`. Classify each difference as a deliberate customization (leave it), drift from the rules (propose a fix), or something no template covers. MinIO counts as drift: propose the S3Mock swap. Report the list before editing.
6. **Verify** (see Verification).
7. **File gaps, don't route around them.** If a template doesn't fit or is wrong, apply the minimal fix in the project, then write a finding to the skills repo's `contributions/` folder (two levels above this skill's real path; format in its `README.md`). Leave out the client, project and repository names; describe the project's shape instead ("a single-app NestJS API").

## Requires confirmation

Stop and confirm with the user before any of these:

- `docker compose down -v`, `docker volume rm`, or anything else that deletes volumes or data
- `docker system prune`, `docker image prune -a`, `docker builder prune`
- Pushing an image to any registry
- Running containers or compose stacks against remote, shared or production Docker hosts (`DOCKER_HOST`, `--context`)
- Overwriting an existing `.env`
- Replacing MinIO (or any existing storage service) in a project, since it changes ports, env vars and where data lives

## Verification

Run these and report the actual output before calling the work done:

- `docker compose -f <file> config -q` for every compose file touched (with a `.env` present)
- `sh -n <entrypoint.sh>` for every entrypoint, plus `shellcheck` if installed
- `hadolint <Dockerfile>` if installed
- `docker build` of each changed image when the app source is present, and `docker compose up -d --wait` to confirm the healthchecks pass
- `diff` each file copied verbatim against its asset. Every difference must be a documented substitution.
- For `$`-containing secrets: `docker compose --env-file .env config | grep <VAR>` shows `$$`

## Examples

Good: copying the template, then adjusting only the documented delta.
```bash
cp <skill>/assets/node-api/Dockerfile docker/node-api/Dockerfile
# then edit only: EXPOSE port and the dist/src/main.js path, per references/node-api.md
```

Bad: a compose file written from memory. It shipped once with a context one level short:
```yaml
migrate:
  build:
    context: ..        # resolves to docker/, not the project root → COPY package.json fails
  depends_on: [postgres]   # bare name: waits for start, not readiness
  restart: unless-stopped  # one-shot job restart-loops
```

Bad: `HEALTHCHECK CMD wget http://localhost:3000/` on the Next.js image. `localhost` resolves to IPv6 first, so a healthy server reports unhealthy forever.

## References

Load these only when the task needs them:

| Need | Assets | Read first |
|---|---|---|
| Node/TypeScript API (+ Postgres/Redis, migrate/seed jobs, SQLite and NestJS-webpack variants, test-only infra) | `assets/node-api/` (`Dockerfile`, `entrypoint.sh`, `compose.yml`, `compose.deploy.yml`, `compose.testing.yml`) | `references/node-api.md` |
| Static SPA (Vite/CRA) behind nginx | `assets/frontend-spa-nginx/` | `references/frontend-spa-nginx.md` |
| Next.js app | `assets/frontend-nextjs/` | `references/frontend-nextjs.md` |
| Nitro SSR server (TanStack Start, Nuxt…) | start from `assets/frontend-nextjs/Dockerfile` | `references/node-ssr-nitro.md` |
| Production stack on one Docker host behind nginx (api, migrate, opt-in seed; optional server-rendered app) | `assets/node-api/compose.production.yml`, `preflight.sh`, `env.production.example` | `references/node-api.md` ("Production stack") |
| Local S3 for dev/tests (S3Mock), or replacing MinIO | paste the service block from the reference | `references/object-storage.md` |
| Runtime env injection into a frontend bundle | the frontend entrypoints | `references/env-replacement.md` |
| Sectioned `make help` Makefile for dev and deploy stacks | `assets/Makefile` | `references/makefile.md` |
| `.dockerignore` | `assets/dockerignore` (rename to `.dockerignore`) | `references/makefile.md` |

- `references/compose.md`: every Dockerfile/compose rule with the real bug behind it. Read before reviewing or fixing an existing stack.
- `references/sources.md`: external facts (image tags, runtime behaviour) with the date each was checked.
