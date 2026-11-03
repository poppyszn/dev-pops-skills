# Gap: NestJS monorepo with webpack — ts-node migration stage pattern

> **Status: merged 2026-09-26** during the migration into dev-pops-skills.
> - `dev`-stage migration pattern, `x-migrate` anchor, and removing `migrate` from the production entrypoint documented in `skills/docker/references/node-api.md` ("Variant: NestJS monorepo in webpack mode").
> - Testing-only compose: new asset `skills/docker/assets/node-api/compose.testing.yml` (anonymous volumes, tighter limits, no restart), documented in the same reference.
>
> Paths in the original write-up below refer to the old templates repo.

**Found in:** a client repo (NestJS 11 monorepo, 11 services, webpack mode)
**Adapted from:** `docker/node-api/Dockerfile` + `docker/node-api/entrypoint.sh`
**Status:** Not a bug in the existing template — a missing pattern for webpack-mode NestJS monorepos.

## The problem

The `node-api` template's `entrypoint.sh` routes `migrate` to:

```sh
node node_modules/typeorm/cli.js migration:run -d dist/typeorm-cli.config.js
```

This assumes `typeorm-cli.config.js` is a separately compiled file alongside
the main bundle. In a **NestJS monorepo with `"webpack": true`** (the default
in `nest-cli.json` for NestJS 11 monorepos), `nest build <service>` outputs a
**single webpack bundle** at `dist/apps/<service>/main.js`. The TypeORM CLI
config is NOT a separate entry point in this build and is therefore NOT emitted
as a standalone `dist/apps/<service>/src/database/typeorm-cli.config.js`.

Running TypeORM CLI against the webpack bundle directly also does not work —
the CLI cannot import a DataSource from a webpack bundle in the expected way.

## What actually works

Use a separate **`dev` stage** in the Dockerfile that keeps all devDependencies
(including `ts-node` and `tsconfig-paths`) alongside the full source tree:

```dockerfile
FROM base AS dev
COPY --from=deps /app/node_modules ./node_modules
COPY . .
```

Compose migration services target this stage and override `command` directly:

```yaml
x-migrate: &migrate
  build:
    context: .
    target: dev
  restart: "no"
  env_file: .env

migrate-orders:
  <<: *migrate
  command: npm run orders-service:migration:run   # uses ts-node under the hood
  depends_on:
    postgres:
      condition: service_healthy
```

The `npm run <service>:migration:run` scripts in NestJS monorepos already use
`ts-node -r tsconfig-paths/register ./node_modules/typeorm/cli` — they run
fine from the dev stage without any additional setup.

The `entrypoint.sh` for the `production` stage drops the `migrate` case
entirely; migrations are a compose concern, not a runtime one.

## Suggested template addition

A new `docker/node-api-nx/` or `docker/node-api-monorepo/` template (or an
addendum to the existing `node-api` README) covering:

1. The `dev` stage pattern for ts-node migration jobs.
2. Why `migrate` must be removed from `entrypoint.sh` in webpack-mode projects.
3. The `x-migrate` anchor pattern in compose for one-shot migration services.
4. Caution: the `dev` stage image is large (full source + devDeps); only use
   it for migration/seed jobs, never as a runtime stage.

## Gap: testing compose template

Also encountered: no template exists for a **testing-only infrastructure
compose** (`docker/testing/compose.yml`) — infra services only, no `build:`
blocks, used in CI to spin up real dependencies before `npm test`. This is
distinct from the local dev compose (which also builds app images) and from
the deploy compose (which pulls pre-built images).

The pattern needed is straightforward — same services as the infra section of
`compose.yml`, minus `named volumes` (use anonymous volumes for clean state on
`down -v`), with tighter resource limits. Worth adding as a sibling template
to `docker/node-api/compose.yml` or documenting in `examples/monorepo-layout/`.
