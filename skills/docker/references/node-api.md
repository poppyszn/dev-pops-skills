# Node API Docker template

Multi-stage Dockerfile + command-router entrypoint + docker-compose stack
for a Node/TypeScript API (TypeORM migrations assumed; adjust the
`migrate` case in `entrypoint.sh` if you use a different ORM/migration
tool).

## What to change when copying this template

- `Dockerfile`: adjust `EXPOSE` port and the `dist/src/main.js` path if
  your build output differs.
- `entrypoint.sh`: replace the `migrate`/`seed` commands if you're not on
  TypeORM (e.g. Prisma: `npx prisma migrate deploy`). If your replacement
  actually needs `npx`/`npm` at runtime, drop the `RUN rm -rf
  .../npm ...` line in the production stage — otherwise leave it in, see
  below.
- `compose.yml`: rename `api` if you have multiple services in one repo;
  adjust `DB_*`/`REDIS_*` env var names to match your app's config
  loader.

## How the pieces fit together

- `migrate` runs once and blocks `api`/`seed` via
  `depends_on: condition: service_completed_successfully` — migrations
  are NOT gated behind a compose profile, because they should always run
  before the app starts.
- `seed` IS gated behind the `seed` profile (`docker compose --profile
  seed up`) — you don't want seeding to run on every `up`. For seeding an
  already-deployed environment on demand (not as part of every deploy),
  see the cicd skill's `assets/workflows/run-seed-develop.yml`.
- The `seed` service assumes a runnable `seed` command already exists
  *in the built image* — that's not automatic. Confirm your build
  actually produces `entrypoint.sh`'s `seed` case target (`dist/src/seed.js`
  by default) before wiring this up: a `seed.ts` script that exists in
  source but was never wired into your build config's entry points
  (e.g. a webpack config's `additionalEntryPoints`) means the compose
  `seed` service references a command that isn't actually in the image.
  Nothing fails loudly until someone tries to run it.
- The `api` healthcheck assumes a `/health` endpoint exists; add one if
  it doesn't. The same check is duplicated as a Dockerfile `HEALTHCHECK`
  so the image reports its own health outside compose too (e.g. under a
  plain `docker run`, or an orchestrator reading the image's built-in
  check).
- Both copies of that check target `127.0.0.1`, never `localhost`.
  **Shipped once:** this template's `HEALTHCHECK` used `localhost` while
  the two frontend templates had already been fixed, so a healthy API
  container sat in `starting` until it failed — the base image resolves
  `localhost` to `::1` first and Node binds IPv4 only. `depends_on:
  condition: service_healthy` then blocks everything downstream. Same
  root cause as `frontend-nextjs.md` and `compose.md`.
- `postgres`/`redis`/`api` set `restart: unless-stopped` — `migrate` and
  `seed` intentionally don't, since they're one-shot jobs that should
  run once and exit, not restart-loop.
- `deploy.resources.limits` values are starting-point defaults, not
  measured for your workload — adjust `cpus`/`memory` per service once
  you have real usage data. Compose (v2, non-Swarm) applies these limits
  directly; they aren't a Swarm-only no-op.
- `entrypoint.sh`'s `migrate` case retries the migration command itself
  (up to 10 attempts, 3s apart) instead of exec'ing it once. **This
  isn't defensive-programming filler** — on a *fresh* volume, the
  official Postgres image's own entrypoint starts a temporary server for
  `initdb`, stops it, then starts the real one; `pg_isready` can catch
  the temp server's brief "ready" window and report the container
  `Healthy` right as it's about to restart for real. `depends_on:
  condition: service_healthy` then lets `migrate` start immediately into
  that restart gap. Confirmed with a live repro (fresh volume, `docker
  compose up`): `migrate` hit `ECONNREFUSED` even though `postgres` had
  already reported `Healthy`. Retrying the migration is more robust than
  trying to make the healthcheck itself airtight against this race.
- The production stage's `RUN rm -rf .../npm ...` line removes npm
  itself from the final image. **Not optional cleanup** — npm ships its
  own vendored copies of `tar`/`brace-expansion`/`ip-address`/`undici`/
  etc., and those show up as CVEs in an image scan (Trivy, etc.) for
  code this image never executes (the container only ever runs `node
  <file>.js`, never `npm`). Confirmed via a live Trivy scan on a real
  app built from this template: removing npm dropped `image-scan`
  findings from 7 (1 critical, 6 high) to 0, with zero change in actual
  runtime behavior.

## `compose.yml` vs `compose.deploy.yml`

- `compose.yml` **builds** the image from source (`build:` blocks) and
  includes `postgres`/`redis` — full local dev stack.
- `compose.deploy.yml` **pulls** an already-built image (`image:`, no
  `build:`) and assumes externally-managed postgres/redis — use it to
  test "what will actually run in production" without rebuilding, or as
  a local dry-run of what `ssh-compose-deploy` runs remotely. Fill in
  `<GH_ORG>`/`<REPO>` in its `image:` refs before using it.

See `assets/Makefile` (and `references/makefile.md`) for `make` targets covering both (`docker-dev-*`
vs `docker-deploy-*`).

No registry yet? `docker/build-on-server/compose.yml` is a third option,
for deploying by building directly on the target host instead of
pulling from a registry — see
the cicd skill's `references/build-on-server.md`.

## Object storage (S3)

The stack has no S3 service by default. If the API uses object storage, add the Adobe S3Mock block from `object-storage.md` to `compose.yml` (persistent) and `compose.testing.yml` (ephemeral), and wire the client for path-style access. Don't use MinIO: it's archived.

## Test-only infrastructure: `compose.testing.yml`

For integration tests (in CI or locally) that need real Postgres/Redis but none of the app services. Copy it to `docker/testing/compose.yml`. It differs from `compose.yml` on purpose:

- **Anonymous volumes**, not named ones, so `down -v` always gives the next run a clean database.
- **Tighter resource limits.**
- **No `restart:`.** A crashed dependency should fail the run, not be hidden.

Run it with `up -d --wait`, then run the tests, then `down -v`. Prefer it over mocking infrastructure: mocked tests can pass while the real thing fails.

## Variant: NestJS monorepo in webpack mode

`entrypoint.sh`'s `migrate` case runs the TypeORM CLI against `dist/typeorm-cli.config.js`, which assumes that config is compiled as its own file. In a NestJS monorepo with `"webpack": true` (the default for NestJS 11 monorepos), `nest build <service>` emits **one bundle** (`dist/apps/<service>/main.js`). The CLI config isn't emitted separately, and the CLI can't load a DataSource out of the bundle.

What works:

1. Add a `dev` stage that keeps devDependencies (`ts-node`, `tsconfig-paths`) and the full source:
   ```dockerfile
   FROM base AS dev
   COPY --from=deps /app/node_modules ./node_modules
   COPY . .
   ```
2. Run migrations as compose one-shot services that target that stage and call the project's own script (which already uses `ts-node -r tsconfig-paths/register`):
   ```yaml
   x-migrate: &migrate
     build:
       context: .
       target: dev
     restart: "no"
     env_file: .env

   migrate-<service>:
     <<: *migrate
     command: npm run <service>:migration:run
     depends_on:
       postgres:
         condition: service_healthy
   ```
3. Remove the `migrate` case from the production `entrypoint.sh`. In this layout migrations are a compose concern, not a runtime command.

The `dev` stage image is large (full source plus devDependencies). Use it only for migration and seed jobs, never as a runtime stage.

## Variant: SQLite, no migrations

For small apps using `type: 'sqlite'` with `synchronize: true` (demos, prototypes). There's no database server, no migrations and no seed step. Deltas from the template:

- **`compose.yml`:** drop `postgres`, `redis`, `migrate` and `seed`, keeping only the app services. Remove the `depends_on` entries that pointed at them.
- **`entrypoint.sh`:** keep only the `start|"")` and `*)` cases.
- **Persistence:** add a dedicated data directory owned by the runtime user, and mount a named volume there, not over `/app` (which would shadow `dist` and `node_modules`):
  ```dockerfile
  RUN mkdir -p /app/data && chown node:node /app/data
  ```
  ```yaml
  volumes:
    - app-data:/app/data
  ```
  Point the app's SQLite path at `/app/data/<name>.sqlite`.
- **`/health`:** still required by the `HEALTHCHECK`. Add a trivial endpoint if the app has none.

## Production stack on one Docker host

Assets: `compose.production.yml`, `preflight.sh`, `env.production.example`. Copy them to `docker/production/compose.yml`, `docker/production/preflight.sh` and `docker/production/.env.example` (the real `.env` is created on the host and kept out of git). The `cicd` skill's production deploy runs them; the `terraform` skill's `docker-host` reference builds the host.

It differs from `compose.deploy.yml` on purpose:

- **Ports on `127.0.0.1`.** nginx on the same host is the one public entry point. Docker publishes a port on every interface unless it is given an address, so the security group would otherwise be the only thing keeping the api private.
- **The commit, not a moving tag.** Images are `...-api:${IMAGE_TAG:-latest-production}` and the deploy sets `IMAGE_TAG` to the commit SHA, so what runs is an exact image and a rollback is a redeploy of an older SHA. Run any manual compose command on the host with the same `IMAGE_TAG`, or it uses `latest-production`.
- **No `build:`, no database.** `DATABASE_URL` points at a managed Postgres.
- **A blocking preflight.** `preflight.sh` runs in `docker/production/` before anything changes (`bash ./preflight.sh "api ssr"`): the `.env` exists, `NODE_ENV=production` is declared exactly, no `<placeholder>` value is left (a placeholder secret must not boot in production), and `docker compose config --quiet` renders the stack. Add one `require_line` or `forbid_pattern` per value that must never be wrong (a stage flag, a kill switch). It never prints the file. Test it with fixture files, never the real `.env`.
- **The `migrate` service runs on its own** (`docker compose run --rm migrate < /dev/null`) before the api restarts. `seed` sits behind the `seed` profile and is never part of a deploy.

A public server-rendered app (a Nitro storefront, say) goes in the same file. Paste this next to `api`; it takes an explicit `environment:` list, not `env_file`, and its own healthcheck is the image's `HEALTHCHECK` (see `node-ssr-nitro.md`):

```yaml
  ssr:
    image: ghcr.io/<GH_ORG>/<REPO>-ssr:${IMAGE_TAG:-latest-production}
    restart: unless-stopped
    # Deliberately not `env_file: .env`: that file carries DATABASE_URL and
    # JWT_SECRET, which a public-facing container must not hold. List only what
    # the app reads, interpolated from named lines in .env.
    environment:
      API_UPSTREAM: http://api:3000
      NODE_ENV: production
      PUBLIC_SITE_ORIGIN: ${SSR_PUBLIC_SITE_ORIGIN:-http://localhost:3001}
      TRUST_PROXY_HOPS: ${SSR_TRUST_PROXY_HOPS:-1}
    ports:
      - "127.0.0.1:${SSR_PORT:-3001}:3000"
    depends_on:
      api:
        condition: service_healthy
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 512M
```

Add `SSR_PUBLIC_SITE_ORIGIN` (and `SSR_TRUST_PROXY_HOPS` if it differs from 1) to `.env.example`, and a `deploys_app ssr && require_line ...` line to `preflight.sh` for anything the app must have.

## `$`-containing secrets in `.env`

If your `.env` holds a secret that can contain a literal `$` (a bcrypt
hash always does — `$2b$12$...`), escape every `$` as `$$`. Compose
interpolates `$VAR` references inside `env_file:`-loaded `.env` values
themselves, not just when injecting them into `compose.yml` — an
unescaped `$` gets treated as an undefined variable reference and
silently dropped. See `references/compose.md` for the full
writeup and a way to verify the value round-tripped intact.

## Local usage

```bash
cp .env.example .env   # create this in your project root
docker compose -f docker/node-api/compose.yml up -d --wait
docker compose -f docker/node-api/compose.yml --profile seed up seed
```
