# Templates Repo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `templates/` repo — reusable, documented CI/CD, Docker, and env-replacement templates for Node/TypeScript projects, extracted from real production repos, indexed by a root `CLAUDE.md` for AI-assistant use.

**Architecture:** Static template repo, organized by concern-then-stack (`docker/`, `ci-cd/github-actions/`, `env-replacement/`). Each template is a real, copy-pasteable file (Dockerfile, entrypoint.sh, workflow yaml, etc.) plus a sibling `README.md` explaining what to change. No build system of its own — validation is syntax-checking each file type (`bash -n` for shell, PyYAML `safe_load` for YAML) plus a content-marker check for Dockerfiles.

**Tech Stack:** Docker, docker-compose, GitHub Actions, POSIX `sh`, Node.js 24 (as the example runtime in templates), PyYAML (for local YAML syntax validation only — not a repo dependency).

## Global Constraints

- Env-replacement uses build-time placeholder tokens (`__VAR_NAME__`, double-underscore wrapped) replaced via `sed` in `entrypoint.sh` at container start — not a runtime-config.js/envsubst file. (Design decision, confirmed with user.)
- Every frontend entrypoint template includes: a `strip_quotes` helper, fail-fast validation of required vars before the `sed` pass, `find` scoped to the narrowest directory, and `exec "$@"` at the end.
- CI templates stop at "build and push image to a registry" — no cloud-specific or non-SSH deploy step is baked into CI templates themselves.
- The SSH-deploy pattern (webfactory/ssh-agent + ProxyJump + `docker compose up --wait` + JSON-based health check + prune + step summary) is extracted as a single reusable composite action, not duplicated per workflow.
- Every template file ships with a sibling `README.md` (or `<name>.README.md` when multiple templates share a directory) explaining what to change and any gotchas.
- All content is scrubbed of client-identifying names/values; user-fillable spots use `<ANGLE_BRACKET_PLACEHOLDER>` convention, distinct from the `__RUNTIME_VAR__` convention used for container-startup substitution.
- No secrets, real hostnames, or real credentials appear anywhere in this repo.

---

## Task 1: `docker/node-api` template

**Files:**
- Create: `docker/node-api/Dockerfile`
- Create: `docker/node-api/entrypoint.sh`
- Create: `docker/node-api/compose.yml`
- Create: `docker/node-api/README.md`

**Interfaces:**
- Produces: an `entrypoint.sh` with commands `migrate`, `seed`, `start` (default), and passthrough (`exec "$@"` for anything else) — later tasks (README/CLAUDE.md index) reference these command names verbatim.

- [ ] **Step 1: Create the Dockerfile**

`docker/node-api/Dockerfile`:
```dockerfile
# syntax=docker/dockerfile:1

# ---- deps: install all dependencies (cached) ----
FROM node:24-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit --no-fund

# ---- build: compile TypeScript, then prune to production deps ----
FROM node:24-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build \
    && npm prune --omit=dev

# ---- production: minimal runtime image ----
FROM node:24-alpine AS production
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./package.json
COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh
USER node
EXPOSE 3000
ENTRYPOINT ["./entrypoint.sh"]
CMD ["start"]
```

- [ ] **Step 2: Create the entrypoint command router**

`docker/node-api/entrypoint.sh`:
```sh
#!/bin/sh
set -e

case "$1" in
  migrate)
    exec node node_modules/typeorm/cli.js migration:run -d dist/typeorm-cli.config.js
    ;;
  seed)
    exec node dist/src/seed.js
    ;;
  start|"")
    exec node dist/src/main.js
    ;;
  *)
    exec "$@"
    ;;
esac
```

- [ ] **Step 3: Create the compose file**

`docker/node-api/compose.yml`:
```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${DB_USER:-app}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-app}
      POSTGRES_DB: ${DB_NAME:-app}
    ports:
      - "${DB_PORT:-5432}:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-app}"]
      interval: 5s
      timeout: 5s
      retries: 10

  redis:
    image: redis:7-alpine
    ports:
      - "${REDIS_PORT:-6379}:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 10

  migrate:
    build:
      context: ..
      dockerfile: docker/node-api/Dockerfile
    command: migrate
    env_file: .env
    depends_on:
      postgres:
        condition: service_healthy

  seed:
    build:
      context: ..
      dockerfile: docker/node-api/Dockerfile
    command: seed
    env_file: .env
    profiles: ["seed"]
    depends_on:
      migrate:
        condition: service_completed_successfully

  api:
    build:
      context: ..
      dockerfile: docker/node-api/Dockerfile
    command: start
    env_file: .env
    ports:
      - "${API_PORT:-3000}:3000"
    depends_on:
      migrate:
        condition: service_completed_successfully
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:3000/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres-data:
```

- [ ] **Step 4: Validate shell and YAML syntax**

Run:
```bash
bash -n docker/node-api/entrypoint.sh
python3 -c "import yaml; yaml.safe_load(open('docker/node-api/compose.yml'))"
grep -q '^FROM node:24-alpine AS production$' docker/node-api/Dockerfile
```
Expected: no output from `bash -n` or the yaml load (both mean success), and the `grep` finds the production stage line.

- [ ] **Step 5: Write the README**

`docker/node-api/README.md`:
```markdown
# Node API Docker template

Multi-stage Dockerfile + command-router entrypoint + docker-compose stack
for a Node/TypeScript API (TypeORM migrations assumed; adjust the
`migrate` case in `entrypoint.sh` if you use a different ORM/migration
tool).

## What to change when copying this template

- `Dockerfile`: adjust `EXPOSE` port and the `dist/src/main.js` path if
  your build output differs.
- `entrypoint.sh`: replace the `migrate`/`seed` commands if you're not on
  TypeORM (e.g. Prisma: `npx prisma migrate deploy`).
- `compose.yml`: rename `api` if you have multiple services in one repo;
  adjust `DB_*`/`REDIS_*` env var names to match your app's config
  loader.

## How the pieces fit together

- `migrate` runs once and blocks `api`/`seed` via
  `depends_on: condition: service_completed_successfully` — migrations
  are NOT gated behind a compose profile, because they should always run
  before the app starts.
- `seed` IS gated behind the `seed` profile (`docker compose --profile
  seed up`) — you don't want seeding to run on every `up`.
- The `api` healthcheck assumes a `/health` endpoint exists; add one if
  it doesn't.

## Local usage

```bash
cp .env.example .env   # create this in your project root
docker compose -f docker/node-api/compose.yml up -d --wait
docker compose -f docker/node-api/compose.yml --profile seed up seed
```
```

- [ ] **Step 6: Commit**

```bash
git add docker/node-api
git commit -m "Add docker/node-api template (Dockerfile, entrypoint, compose, README)"
```

---

## Task 2: `docker/frontend-spa-nginx` template

**Files:**
- Create: `docker/frontend-spa-nginx/Dockerfile`
- Create: `docker/frontend-spa-nginx/nginx.conf.tpl`
- Create: `docker/frontend-spa-nginx/entrypoint.sh`
- Create: `docker/frontend-spa-nginx/README.md`

**Interfaces:**
- Produces: `entrypoint.sh` with a `strip_quotes()` shell function and a `find <dir> -name "*.js" -print0 | xargs -0 sed -i ...` substitution pass — the pattern documented in `env-replacement/README.md` (Task 5) as the canonical example.

- [ ] **Step 1: Create the build+runtime Dockerfile**

`docker/frontend-spa-nginx/Dockerfile`:
```dockerfile
# syntax=docker/dockerfile:1

FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit --no-fund
COPY . .
# Placeholder tokens (e.g. __VITE_API_URL__) are baked into the built
# bundle here; real values are substituted at container startup by
# entrypoint.sh, so this same image works across every environment.
RUN npm run build

FROM nginx:1.27-alpine AS production
COPY docker/frontend-spa-nginx/nginx.conf.tpl /etc/nginx/templates/app.conf.template
COPY docker/frontend-spa-nginx/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY --from=build /app/dist /usr/share/nginx/html
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
```

- [ ] **Step 2: Create the nginx config template**

`docker/frontend-spa-nginx/nginx.conf.tpl`:
```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    gzip on;
    gzip_types text/css application/javascript application/json image/svg+xml;
    gzip_min_length 1024;

    location ~* \.(?:js|css|svg|png|jpg|jpeg|gif|ico|woff2?)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

- [ ] **Step 3: Create the entrypoint with placeholder substitution**

`docker/frontend-spa-nginx/entrypoint.sh`:
```sh
#!/bin/sh
set -e

# Strips a single pair of leading/trailing quotes, guarding against
# env_file-sourced values that arrive with quotes still attached.
strip_quotes() {
  printf '%s' "$1" | sed 's/^["'"'"']//;s/["'"'"']$//'
}

: "${VITE_API_URL:?ERROR: VITE_API_URL environment variable is required}"

_API_URL=$(strip_quotes "${VITE_API_URL}")

find /usr/share/nginx/html -type f -name "*.js" -print0 | xargs -0 sed -i \
  -e "s|__VITE_API_URL__|${_API_URL}|g"

exec "$@"
```

- [ ] **Step 4: Validate shell syntax and nginx config placeholders**

Run:
```bash
bash -n docker/frontend-spa-nginx/entrypoint.sh
grep -q 'try_files \$uri \$uri/ /index.html' docker/frontend-spa-nginx/nginx.conf.tpl
```
Expected: no output from `bash -n` (success), `grep` finds the SPA fallback line.

- [ ] **Step 5: Write the README**

`docker/frontend-spa-nginx/README.md`:
```markdown
# Frontend SPA (nginx) Docker template

Static SPA build (Vite/CRA/etc.) served by nginx, with **runtime**
environment injection: real env var values are substituted into the
already-built JS bundle when the container starts, so one image works
across dev/staging/prod without a rebuild.

## What to change when copying this template

- In your app code, reference env values as literal placeholder strings
  matching the `__VITE_API_URL__` convention (e.g. wrap them in your
  build config so the string `__VITE_API_URL__` ends up verbatim in the
  compiled output).
- `entrypoint.sh`: add one `-e "s|__YOUR_VAR__|${_YOUR_VAR}|g"` line and
  a matching `strip_quotes` call per env var you need injected. Add a
  `: "${YOUR_VAR:?...}"` guard for any var that's required.
- If your image serves more than one app/config from a single build
  (see a client repo in the source survey for this
  pattern), scope the `find` to a per-app subdirectory
  (`/usr/share/nginx/html/${APP}`) instead of the whole webroot, and
  swap in the matching nginx conf template based on an `APP` env var.
- `nginx.conf.tpl` uses nginx's built-in `envsubst`-on-templates feature
  via the `/etc/nginx/templates/` convention — this is unrelated to the
  JS placeholder substitution above, and only affects the nginx config
  itself (not your app's env vars).

## Why sed on the compiled bundle, not a separate config file

This template intentionally does NOT use a separate
`runtime-config.js`/`envsubst` file fetched by the app at runtime. The
sed-into-bundle approach is what's proven across multiple production
frontends; see `env-replacement/README.md` for the full rationale.
```

- [ ] **Step 6: Commit**

```bash
git add docker/frontend-spa-nginx
git commit -m "Add docker/frontend-spa-nginx template (Dockerfile, nginx conf, entrypoint, README)"
```

---

## Task 3: `docker/frontend-nextjs` template

**Files:**
- Create: `docker/frontend-nextjs/Dockerfile`
- Create: `docker/frontend-nextjs/entrypoint.sh`
- Create: `docker/frontend-nextjs/README.md`

**Interfaces:**
- Consumes: the same `strip_quotes` + placeholder-token pattern established in Task 2's `entrypoint.sh`, applied here to `.next` build output instead of a static `dist`.

- [ ] **Step 1: Create the Dockerfile**

`docker/frontend-nextjs/Dockerfile`:
```dockerfile
# syntax=docker/dockerfile:1

FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit --no-fund
COPY . .

# Placeholder tokens for every NEXT_PUBLIC_* var used at runtime — real
# values are substituted into the build output by entrypoint.sh at
# container startup, so this image works across every environment.
ARG NEXT_PUBLIC_API_URL=__NEXT_PUBLIC_API_URL__
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}

RUN npm run build

FROM node:24-alpine AS production
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/.next ./.next
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./package.json
COPY --from=build /app/public ./public
COPY docker/frontend-nextjs/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh
USER node
EXPOSE 3000
ENTRYPOINT ["./entrypoint.sh"]
CMD ["npm", "start"]
```

- [ ] **Step 2: Create the entrypoint**

`docker/frontend-nextjs/entrypoint.sh`:
```sh
#!/bin/sh
set -e

: "${NEXT_PUBLIC_API_URL:?ERROR: NEXT_PUBLIC_API_URL environment variable is required}"

find /app/.next -type f -name "*.js" -print0 | xargs -0 sed -i \
  -e "s|__NEXT_PUBLIC_API_URL__|${NEXT_PUBLIC_API_URL}|g"

exec "$@"
```

- [ ] **Step 3: Validate shell syntax**

Run:
```bash
bash -n docker/frontend-nextjs/entrypoint.sh
grep -q 'ARG NEXT_PUBLIC_API_URL=__NEXT_PUBLIC_API_URL__' docker/frontend-nextjs/Dockerfile
```
Expected: no output from `bash -n` (success), `grep` finds the ARG line.

- [ ] **Step 4: Write the README**

`docker/frontend-nextjs/README.md`:
```markdown
# Next.js frontend Docker template

Same runtime-env-injection idea as `docker/frontend-spa-nginx`, adapted
for Next.js: `NEXT_PUBLIC_*` vars are baked in as placeholder tokens at
build time via Dockerfile `ARG`/`ENV`, then `sed`-replaced in the
compiled `.next` output by `entrypoint.sh` at container start.

## What to change when copying this template

- Add one `ARG`/`ENV` pair in the Dockerfile and one `sed -e` line +
  `:  "${VAR:?...}"` guard in `entrypoint.sh` per `NEXT_PUBLIC_*` var
  your app uses.
- If you're using the Next.js `output: "standalone"` build mode, adjust
  the production stage's `COPY --from=build` lines and `CMD` to match
  (`node server.js` instead of `npm start`).

## Note

Only `NEXT_PUBLIC_*` vars can be substituted this way — they're the only
ones present in client-side bundle output at build time. Server-only env
vars should be passed normally via the container's environment; they
don't need placeholder substitution since server code reads
`process.env` directly at runtime.
```

- [ ] **Step 5: Commit**

```bash
git add docker/frontend-nextjs
git commit -m "Add docker/frontend-nextjs template (Dockerfile, entrypoint, README)"
```

---

## Task 4: `docker/Makefile` and `docker/dockerignore`

**Files:**
- Create: `docker/Makefile`
- Create: `docker/Makefile.README.md`
- Create: `docker/dockerignore`

**Interfaces:**
- Produces: `make help`, `make docker-dev`, `make docker-down`, `make docker-migrate`, `make docker-seed` targets — referenced by name in the root `CLAUDE.md` index (Task 10).

- [ ] **Step 1: Create the Makefile**

`docker/Makefile`:
```makefile
COMPOSE_FILE ?= docker/node-api/compose.yml

.PHONY: help docker-dev docker-down docker-migrate docker-seed docker-logs

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.env:
	cp .env.example .env

docker-dev: .env ## Start the local docker-compose stack
	docker compose -f $(COMPOSE_FILE) up -d --wait

docker-down: ## Stop the local docker-compose stack
	docker compose -f $(COMPOSE_FILE) down

docker-migrate: .env ## Run database migrations
	docker compose -f $(COMPOSE_FILE) run --rm migrate

docker-seed: .env ## Seed the database (requires the `seed` profile)
	docker compose -f $(COMPOSE_FILE) --profile seed run --rm seed

docker-logs: ## Tail logs for the local stack
	docker compose -f $(COMPOSE_FILE) logs -f
```

- [ ] **Step 2: Create the dockerignore template**

`docker/dockerignore`:
```
.git
.github
node_modules
**/node_modules
dist
**/dist
coverage
**/coverage
.env
.env.*
!.env.example
```

- [ ] **Step 3: Validate the Makefile's help-target parsing**

Run:
```bash
awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { print $1 }' docker/Makefile
```
Expected output (target names, one per line):
```
help
docker-dev
docker-down
docker-migrate
docker-seed
docker-logs
```

- [ ] **Step 4: Write the Makefile README**

`docker/Makefile.README.md`:
```markdown
# Makefile template

Self-documenting `make help` via the classic `awk`-parsed `## comment`
convention — add `## description` after any target and it shows up in
`make help` automatically.

## What to change when copying this template

- Copy into your project root as `Makefile` (not `docker/Makefile`) so
  `make` picks it up without `-f`.
- Update `COMPOSE_FILE` to point at wherever you place your
  `compose.yml` (see `docker/node-api/README.md`).
- The `.env` target auto-bootstraps `.env` from `.env.example` only if
  `.env` doesn't already exist — it won't clobber an existing one.

## `dockerignore` note

Rename `docker/dockerignore` to `.dockerignore` in your project root
when copying it (it's named without the leading dot here so it doesn't
get excluded from this templates repo itself). The `!.env.example`
negation line matters: it re-includes the example file after the
broader `.env.*` exclusion, so the example still ships in the build
context for documentation purposes.
```

- [ ] **Step 5: Commit**

```bash
git add docker/Makefile docker/Makefile.README.md docker/dockerignore
git commit -m "Add docker/Makefile and dockerignore templates"
```

---

## Task 5: `env-replacement/README.md`

**Files:**
- Create: `env-replacement/README.md`

**Interfaces:**
- Consumes: the entrypoint patterns established in Task 2 (`docker/frontend-spa-nginx/entrypoint.sh`) and Task 3 (`docker/frontend-nextjs/entrypoint.sh`) — this README explains the shared pattern and links to both as concrete examples.

- [ ] **Step 1: Write the README**

`env-replacement/README.md`:
```markdown
# Env replacement: runtime config injection for frontends

**The problem:** a frontend bundle is built once, but needs different
API URLs / keys per environment (dev, staging, prod). Rebuilding the
image per environment is slow and means the image you tested isn't the
exact image you deploy.

**The pattern used in this repo:** bake unique placeholder tokens
(`__VAR_NAME__`) into the bundle at build time, then `sed`-replace them
with real values in `entrypoint.sh` at container startup, before the
real process (`nginx`, `npm start`, etc.) starts. One image, configured
per-container at `docker run` / `docker compose up` time via normal env
vars.

See working examples:
- [`docker/frontend-spa-nginx/entrypoint.sh`](../docker/frontend-spa-nginx/entrypoint.sh) — Vite/CRA-style static SPA
- [`docker/frontend-nextjs/entrypoint.sh`](../docker/frontend-nextjs/entrypoint.sh) — Next.js `NEXT_PUBLIC_*` vars

## The five rules every entrypoint here follows

1. **Placeholder convention:** `__ENV_VAR_NAME__` — double-underscore
   wrapped, same name as the env var, so it's greppable in built output.
2. **`strip_quotes` helper** applied to every substituted value — guards
   against `env_file:`-sourced values arriving with quotes still
   attached (a real Docker Compose footgun).
3. **Fail-fast validation** (`: "${VAR:?error message}"`) for every
   required var, before running `sed` — a missing var should be a clear
   startup error, not a silently broken app.
4. **Scope `find` narrowly** — the smallest directory that could contain
   the placeholder (a per-app subfolder if one image serves multiple
   apps) — avoids cross-app collisions and keeps container boot fast.
5. **Always end with `exec "$@"`** — so `CMD` and any extra `docker run`
   arguments still work as expected.

## Why not a separate `runtime-config.js` fetched at runtime?

That's a legitimate alternative (avoids touching bundle files at all,
which is faster on very large builds), but it's not what this repo
templates, because it isn't what's proven in the source projects this
repo was extracted from. If you outgrow the sed-based approach (very
large bundles where the sed pass measurably slows container boot),
that's the documented next step — see `roadmap.md`.
```

- [ ] **Step 2: Commit**

```bash
git add env-replacement/README.md
git commit -m "Add env-replacement README explaining the shared placeholder+sed pattern"
```

---

## Task 6: `ci-cd/github-actions/node` CI templates

**Files:**
- Create: `ci-cd/github-actions/node/ci-simple.yml`
- Create: `ci-cd/github-actions/node/ci-simple.README.md`
- Create: `ci-cd/github-actions/node/ci.yml`
- Create: `ci-cd/github-actions/node/ci.README.md`

**Interfaces:**
- Produces: two independent workflow files. `ci-simple.yml` for a single-package repo; `ci.yml` for an Nx monorepo. Neither depends on the other.

- [ ] **Step 1: Create the simple (single-package) CI workflow**

`ci-cd/github-actions/node/ci-simple.yml`:
```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint-test-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 24
          cache: npm

      - run: npm ci

      - run: npm run lint

      - run: npm test

      - run: npm run build
```

- [ ] **Step 2: Create the README for the simple workflow**

`ci-cd/github-actions/node/ci-simple.README.md`:
```markdown
# Simple Node CI template

For a single-package Node/TypeScript repo (not a monorepo). Lint, test,
build on every PR and push to `main`.

## What to change when copying this template

- Adjust `node-version` to match your project's `.nvmrc`/`engines`
  field.
- If your test suite needs a database/Redis, add `services:` containers
  with healthchecks (see `ci.yml`'s README for a worked example) rather
  than mocking — mocked infra tests can pass while the real thing fails.
- `cancel-in-progress: true` is intentional for CI (not deploy) workflows
  — a new push should cancel a stale in-flight CI run.
```

- [ ] **Step 3: Create the Nx-monorepo CI workflow**

`ci-cd/github-actions/node/ci.yml`:
```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  affected:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-node@v4
        with:
          node-version: 24
          cache: npm

      - run: npm ci

      - uses: nrwl/nx-set-shas@v4

      - run: npx nx affected -t lint,test,build --parallel=3

      - name: Detect affected apps
        id: detect
        run: |
          apps=$(npx nx show projects --affected --type=app --json)
          echo "apps=$apps" >> "$GITHUB_OUTPUT"
    outputs:
      apps: ${{ steps.detect.outputs.apps }}

  e2e:
    needs: affected
    if: needs.affected.outputs.apps != '[]'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-node@v4
        with:
          node-version: 24
          cache: npm

      - run: npm ci

      - run: npx nx affected -t e2e --parallel=1
```

- [ ] **Step 4: Validate YAML syntax for both workflows**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('ci-cd/github-actions/node/ci-simple.yml'))"
python3 -c "import yaml; yaml.safe_load(open('ci-cd/github-actions/node/ci.yml'))"
```
Expected: no output (both parse successfully).

- [ ] **Step 5: Write the README for the Nx workflow**

`ci-cd/github-actions/node/ci.README.md`:
```markdown
# Nx monorepo CI template

For an Nx monorepo with multiple apps. Uses `nx affected` so only
changed projects run lint/test/build, and only runs e2e when an
affected project is an `app` (not a shared lib).

## What to change when copying this template

- Requires `nrwl/nx-set-shas` to correctly compute the affected base —
  don't remove this step or `nx affected` will fall back to comparing
  against the wrong commit.
- The `e2e` job's `if: needs.affected.outputs.apps != '[]'` guard means
  a lib-only PR (e.g. a shared types package) skips e2e entirely —
  adjust if you want e2e to run whenever ANY affected project changes.
- Add `paths-ignore: ['**.md', 'docs/**']` at the workflow level if you
  want doc-only changes to skip CI entirely.

## Adding a database/Redis for e2e

```yaml
services:
  postgres:
    image: postgres:16-alpine
    env:
      POSTGRES_PASSWORD: postgres
    ports: ["5432:5432"]
    options: >-
      --health-cmd pg_isready
      --health-interval 5s
      --health-timeout 5s
      --health-retries 10
```
Add this under the `e2e` job, then write a throwaway `.env.e2e` inline
via a heredoc step before running your e2e command.
```

- [ ] **Step 6: Commit**

```bash
git add ci-cd/github-actions/node
git commit -m "Add Node CI templates (simple single-package + Nx monorepo affected)"
```

---

## Task 7: `ci-cd/github-actions/docker-build-push.yml`

**Files:**
- Create: `ci-cd/github-actions/docker-build-push.yml`
- Create: `ci-cd/github-actions/docker-build-push.README.md`

**Interfaces:**
- Produces: a workflow triggerable via `workflow_call` (so it can be chained after Task 6's CI workflow) and `workflow_dispatch`, pushing to GHCR.

- [ ] **Step 1: Create the workflow**

`ci-cd/github-actions/docker-build-push.yml`:
```yaml
name: Build and push image

on:
  workflow_call:
    inputs:
      app:
        required: true
        type: string
      dockerfile:
        required: false
        type: string
        default: Dockerfile
      image-tag:
        required: true
        type: string
  workflow_dispatch:
    inputs:
      app:
        required: true
        type: string
      image-tag:
        required: true
        type: string

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-qemu-action@v3

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v6
        with:
          context: .
          file: ${{ inputs.dockerfile }}
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            ghcr.io/${{ github.repository }}-${{ inputs.app }}:${{ inputs.image-tag }}
            ghcr.io/${{ github.repository }}-${{ inputs.app }}:${{ github.sha }}
          cache-from: type=gha,scope=${{ inputs.app }}
          cache-to: type=gha,mode=max,scope=${{ inputs.app }}
```

- [ ] **Step 2: Validate YAML syntax**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('ci-cd/github-actions/docker-build-push.yml'))"
```
Expected: no output (parses successfully).

- [ ] **Step 3: Write the README**

`ci-cd/github-actions/docker-build-push.README.md`:
```markdown
# Docker build-and-push template

Reusable workflow (`workflow_call`) that builds a multi-arch image and
pushes it to GHCR with per-app GitHub Actions cache scoping. Stops at
"image is pushed" — deploying it is a separate, explicit step (see
`ci-cd/github-actions/actions/ssh-compose-deploy`).

## What to change when copying this template

- If you have multiple apps in one repo (monorepo), call this workflow
  once per app via a matrix in the calling workflow:
  ```yaml
  jobs:
    build:
      strategy:
        matrix:
          app: [api, web, admin]
      uses: ./.github/workflows/docker-build-push.yml
      with:
        app: ${{ matrix.app }}
        dockerfile: apps/${{ matrix.app }}/Dockerfile
        image-tag: latest-${{ github.ref_name }}
  ```
- Drop `platforms: linux/amd64,linux/arm64` (and the qemu setup step) if
  you only deploy to one architecture — multi-arch builds are slower.
- `cache-from`/`cache-to` scope is `inputs.app` so parallel matrix builds
  don't share (and thrash) a single cache.
```

- [ ] **Step 4: Commit**

```bash
git add ci-cd/github-actions/docker-build-push.yml ci-cd/github-actions/docker-build-push.README.md
git commit -m "Add reusable docker-build-push GitHub Actions template"
```

---

## Task 8: `ssh-compose-deploy` composite action

**Files:**
- Create: `ci-cd/github-actions/actions/ssh-compose-deploy/action.yml`
- Create: `ci-cd/github-actions/actions/ssh-compose-deploy/README.md`

**Interfaces:**
- Produces: a composite action (`uses: ./ci-cd/github-actions/actions/ssh-compose-deploy` when vendored into a project's `.github/actions/`) with named inputs — the README documents each input's purpose so callers don't need to read `action.yml` to use it.

- [ ] **Step 1: Create the composite action**

`ci-cd/github-actions/actions/ssh-compose-deploy/action.yml`:
```yaml
name: SSH compose deploy
description: >
  Deploy a docker-compose stack to a remote host over SSH (with optional
  ProxyJump), with health-checked startup and image/build pruning.

inputs:
  ssh-private-key:
    required: true
  ssh-jump-host:
    required: false
    default: ""
  ssh-jump-user:
    required: false
    default: ""
  ssh-host:
    required: true
  ssh-user:
    required: true
  ssh-port:
    required: false
    default: "22"
  working-dir:
    required: true
    description: Remote path containing the project's compose.yml
  compose-profiles:
    required: false
    default: ""
    description: Space-separated compose profiles to include on `up` (e.g. "migrate")
  wait-timeout:
    required: false
    default: "120"
  prune-retention:
    required: false
    default: "168h"
  github-token:
    required: true

runs:
  using: composite
  steps:
    - uses: webfactory/ssh-agent@v0.9.0
      with:
        ssh-private-key: ${{ inputs.ssh-private-key }}

    - name: Configure SSH
      shell: bash
      run: |
        mkdir -p ~/.ssh
        if [ -n "${{ inputs.ssh-jump-host }}" ]; then
          cat >> ~/.ssh/config << EOF
        Host ${{ inputs.ssh-jump-host }}
          StrictHostKeyChecking no
        Host ${{ inputs.ssh-host }}
          StrictHostKeyChecking no
          ProxyJump ${{ inputs.ssh-jump-user }}@${{ inputs.ssh-jump-host }}
        EOF
        else
          cat >> ~/.ssh/config << EOF
        Host ${{ inputs.ssh-host }}
          StrictHostKeyChecking no
        EOF
        fi

    - name: Deploy over SSH
      shell: bash
      env:
        GH_TOKEN: ${{ inputs.github-token }}
        PROFILE_FLAGS: ${{ inputs.compose-profiles }}
      run: |
        ssh -p "${{ inputs.ssh-port }}" "${{ inputs.ssh-user }}@${{ inputs.ssh-host }}" \
          "WORKING_DIR='${{ inputs.working-dir }}' GH_TOKEN='$GH_TOKEN' PROFILE_FLAGS='$PROFILE_FLAGS' WAIT_TIMEOUT='${{ inputs.wait-timeout }}' PRUNE_RETENTION='${{ inputs.prune-retention }}' bash -s" << 'EOF'
        set -euo pipefail

        echo "$GH_TOKEN" | docker login ghcr.io -u x-access-token --password-stdin

        cd "$WORKING_DIR"

        profile_args=""
        for p in $PROFILE_FLAGS; do
          profile_args="$profile_args --profile $p"
        done

        if [ ! -f .env ] && [ -f .env.example ]; then
          cp .env.example .env
        fi

        docker compose $profile_args pull
        docker compose $profile_args up -d --wait --wait-timeout "$WAIT_TIMEOUT"

        unhealthy=$(docker compose ps --format json | jq -r 'select(.State != "running") | .Name')
        if [ -n "$unhealthy" ]; then
          for name in $unhealthy; do
            echo "=== logs: $name ==="
            docker logs --tail 50 "$name" || true
          done
          exit 1
        fi

        docker image prune -af --filter "until=$PRUNE_RETENTION"
        docker builder prune -af --filter "until=$PRUNE_RETENTION"
        EOF

    - name: Deployment summary
      shell: bash
      if: always()
      run: |
        {
          echo "## Deployment Report"
          echo "| Field | Value |"
          echo "|---|---|"
          echo "| Status | ${{ job.status }} |"
          echo "| Host | ${{ inputs.ssh-host }} |"
          echo "| Commit | ${{ github.sha }} |"
          echo "| Branch | ${{ github.ref_name }} |"
        } >> "$GITHUB_STEP_SUMMARY"
```

- [ ] **Step 2: Validate YAML syntax**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('ci-cd/github-actions/actions/ssh-compose-deploy/action.yml'))"
```
Expected: no output (parses successfully).

- [ ] **Step 3: Write the README**

`ci-cd/github-actions/actions/ssh-compose-deploy/README.md`:
```markdown
# ssh-compose-deploy composite action

Extracted from a pattern copy-pasted near-identically across 5+
production workflows. Deploys a docker-compose stack to a remote host
over SSH, waits for containers to become healthy, dumps logs for any
container that isn't, and prunes old images.

## How to use it

Vendor this directory into your project (e.g.
`.github/actions/ssh-compose-deploy/`), then call it from a deploy
workflow:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    concurrency:
      group: deploy-production
      cancel-in-progress: false   # never cancel an in-flight deploy
    steps:
      - uses: ./.github/actions/ssh-compose-deploy
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
          ssh-jump-host: ${{ secrets.SSH_JUMP_HOST }}
          ssh-jump-user: ${{ secrets.SSH_JUMP_USER }}
          ssh-host: ${{ secrets.SSH_HOST }}
          ssh-user: ${{ secrets.SSH_USER }}
          working-dir: /srv/myapp
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs worth knowing about

- `ssh-jump-host`/`ssh-jump-user`: leave both empty to SSH directly with
  no jump host — the action switches its generated `~/.ssh/config`
  accordingly.
- `compose-profiles`: space-separated, e.g. `"migrate seed"` — appended
  as repeated `--profile` flags to `pull`/`up`.
- `prune-retention`: passed straight to `docker image/builder prune
  --filter until=`, default `168h` (7 days).

## Why `cancel-in-progress: false` on the calling workflow

Shown in the example above deliberately — CI workflows should cancel
stale runs, but a deploy workflow should NOT be cancelled mid-flight by
a newer push; that's how you get a host left mid-deploy. Set this at the
job/workflow level in whatever workflow calls this action.
```

- [ ] **Step 4: Commit**

```bash
git add ci-cd/github-actions/actions/ssh-compose-deploy
git commit -m "Add ssh-compose-deploy composite action, extracted from duplicated deploy workflows"
```

---

## Task 9: `roadmap.md`

**Files:**
- Create: `roadmap.md`

- [ ] **Step 1: Write the roadmap**

`roadmap.md`:
```markdown
# Roadmap

Templates that are planned but not yet implemented. Node/TypeScript is
the only stack covered today (see `docker/`, `ci-cd/`,
`env-replacement/`). Everything below is intent, not code — don't
reference these paths from `CLAUDE.md` until they exist.

## PHP / Laravel

- `docker/php-laravel/`: `Dockerfile` (php-fpm + nginx, multi-stage with
  `composer install --no-dev` in the build stage).
- Env handling: Laravel's own `.env` + config cache
  (`php artisan config:cache`) means the runtime-placeholder-sed pattern
  used for JS frontends likely doesn't apply directly — needs its own
  design pass before copying the Node approach blindly.
- CI: `composer install`, `php artisan test` (or Pest), static analysis
  (Larastan/PHPStan).

## Python

- `docker/python-api/`: `Dockerfile` (Django or FastAPI, multi-stage
  with a venv or `uv`-based install).
- Migrations as a compose profile analogous to `docker/node-api`'s
  `migrate` service (`alembic upgrade head` or `manage.py migrate`).
- CI: `pytest`, `ruff`.

## Kubernetes / Helm / GitOps

An alternative deploy target to `ssh-compose-deploy`, for when a project
outgrows single-host SSH+compose deploys: Helm charts per service,
ArgoCD for sync, Vault-based secret injection
(`VaultConnection`/`VaultAuth`/`VaultStaticSecret` CRDs). Only worth
building when an actual project needs it — don't build speculatively.

## Architecture-doc template

A `docs/architecture.md` template (module topology, request lifecycle,
auth model, domain model) — noted as a good idea during the original
survey of source projects, but out of scope for the CI/Docker/env-replacement
focus of this repo's first version.
```

- [ ] **Step 2: Commit**

```bash
git add roadmap.md
git commit -m "Add roadmap.md documenting future template additions"
```

---

## Task 10: Root `README.md` and `CLAUDE.md` index

**Files:**
- Create: `README.md`
- Create: `CLAUDE.md`

**Interfaces:**
- Consumes: every template path created in Tasks 1–9 — this task is the index and must reference each by its real, now-existing path.

- [ ] **Step 1: Write the human-facing README**

`README.md`:
```markdown
# templates

Reusable, documented CI/CD, Docker, and env-replacement templates,
extracted from real production projects rather than written from
scratch. Copy a template into a project, adapt the marked variables, go.

## Layout

- `ci-cd/github-actions/` — GitHub Actions workflows and a composite
  deploy action.
- `docker/` — Dockerfiles, compose files, entrypoint scripts, a
  Makefile.
- `env-replacement/` — the runtime env-injection pattern used by the
  frontend Docker templates, explained once.
- `roadmap.md` — stacks/patterns planned but not yet built (PHP,
  Python, Kubernetes).

## Stack coverage

Node/TypeScript only, for now. See `roadmap.md` for what's planned
next.

## For AI coding assistants

See `CLAUDE.md` — it's an index mapping "I need to do X" to the exact
template path to copy.
```

- [ ] **Step 2: Write the AI-assistant index**

`CLAUDE.md`:
```markdown
# CLAUDE.md — templates repo index

This repo holds copy-paste-ready templates. When working in an
unrelated project and the user needs one of the following, read the
linked template + its README, copy the file(s) into the target project,
and adapt anything marked with `<ANGLE_BRACKET_PLACEHOLDER>`. Don't
regenerate these patterns from memory — copy from here, since they're
extracted from real production usage.

## "I need to..."

| Need | Template |
|---|---|
| Dockerize a Node/TypeScript API | [`docker/node-api/`](docker/node-api/README.md) |
| Dockerize a static frontend SPA (Vite/CRA) behind nginx | [`docker/frontend-spa-nginx/`](docker/frontend-spa-nginx/README.md) |
| Dockerize a Next.js app | [`docker/frontend-nextjs/`](docker/frontend-nextjs/README.md) |
| Inject env vars into a frontend at container startup (not build time) | [`env-replacement/README.md`](env-replacement/README.md) |
| Add a self-documenting `make help` + docker-compose Makefile | [`docker/Makefile`](docker/Makefile.README.md) |
| Set up CI (lint/test/build) for a single-package Node repo | [`ci-cd/github-actions/node/ci-simple.yml`](ci-cd/github-actions/node/ci-simple.README.md) |
| Set up CI for an Nx monorepo (affected-only) | [`ci-cd/github-actions/node/ci.yml`](ci-cd/github-actions/node/ci.README.md) |
| Build and push a Docker image to GHCR from CI | [`ci-cd/github-actions/docker-build-push.yml`](ci-cd/github-actions/docker-build-push.README.md) |
| Deploy a compose stack to a remote host over SSH | [`ci-cd/github-actions/actions/ssh-compose-deploy/`](ci-cd/github-actions/actions/ssh-compose-deploy/README.md) |

## Conventions used throughout this repo

- `__DOUBLE_UNDERSCORE__` tokens = runtime env-substitution placeholders
  (replaced by `sed` in an `entrypoint.sh` at container start). See
  `env-replacement/README.md`.
- `<ANGLE_BRACKETS>` = "fill this in when you copy the template" —
  never a runtime substitution, just a marker for the human/AI copying
  the file.
- Every template directory has its own `README.md` (or
  `<name>.README.md` when a directory holds multiple sibling templates)
  explaining what to change and why the template is shaped the way it
  is. Read it before copying — don't guess.

## Stack coverage

Node/TypeScript only today. Check `roadmap.md` before assuming a
PHP/Python/Kubernetes template exists — it likely doesn't yet.
```

- [ ] **Step 3: Verify every linked path exists**

Run:
```bash
for f in \
  docker/node-api/README.md \
  docker/frontend-spa-nginx/README.md \
  docker/frontend-nextjs/README.md \
  env-replacement/README.md \
  docker/Makefile.README.md \
  ci-cd/github-actions/node/ci-simple.README.md \
  ci-cd/github-actions/node/ci.README.md \
  ci-cd/github-actions/docker-build-push.README.md \
  ci-cd/github-actions/actions/ssh-compose-deploy/README.md \
  roadmap.md ; do
  [ -f "$f" ] && echo "OK: $f" || echo "MISSING: $f"
done
```
Expected: every line prints `OK:` — no `MISSING:` lines.

- [ ] **Step 4: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "Add root README and CLAUDE.md index tying all templates together"
```

---

## Self-review notes

- **Spec coverage:** every template listed in the design's file-structure
  section (Tasks 1–8) and repo-structure table has a task; `roadmap.md`
  (Task 9) and the root index (Task 10) match the spec's "AI-assistant
  entrypoint" and "Roadmap" sections.
- **No placeholders:** all file contents above are complete, real files —
  no TBD/TODO markers.
- **Type/name consistency:** `entrypoint.sh` command names (`migrate`,
  `seed`, `start`) are consistent between Task 1's Dockerfile/compose and
  its own entrypoint; `docker-build-push.yml`'s `inputs.app` name matches
  its README's matrix example; `ssh-compose-deploy`'s input names match
  between `action.yml` and its README usage example.
