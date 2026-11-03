# Nitro SSR server has no template, plus two compose gotchas it exposed

> **Status: merged 2026-09-26** during the migration into dev-pops-skills.
> - #1: `skills/docker/references/node-ssr-nitro.md`. The unverified bind variable was checked against Nitro's docs (`NITRO_HOST`/`HOST`, default localhost, so `HOST=0.0.0.0` is required). The env-replacement reference now says it applies only to client-bundle values.
> - #2 and #3: added to `skills/docker/references/compose.md` and the docker skill's Defaults (`environment:` allowlist for public-facing services; `${VAR:-default}` for optional services).
>
> Paths in the original write-up below refer to the old templates repo.

**Where found:** a client repo, dockerizing a new `apps/store` (TanStack
Start on Nitro, `preset: 'node-server'`) into its develop pull-based stack.
The store's Dockerfile pre-existed; the closest template is
`docker/frontend-nextjs`. None of these findings changes a template file —
they are gaps and guidance to review.

## 1. Gap: no template for a non-Next Node SSR server

`docker/frontend-nextjs` is the only SSR template, and most of it is
Next-specific. What did *not* transfer to a Nitro server:

- **Output shape.** Nitro emits a self-contained `.output/` (run with
  `node .output/server/index.mjs`), not `.next/standalone` + `.next/static`
  + `public`. The runner needs neither pnpm nor `node_modules`, so the
  existing store image strips npm/corepack from the runner stage entirely.
- **No `HOSTNAME` override.** The template's long `ENV HOSTNAME=0.0.0.0`
  comment is about Next's `process.env.HOSTNAME` bind. The store's Dockerfile
  sets `HOST=0.0.0.0` and `PORT` instead. (I did not verify Nitro's bind
  variable myself; the app's own compose evidence says it serves correctly.)
- **No env-replacement entrypoint.** The store reads its config from
  `process.env` at runtime (a zod schema in `env.server.ts`) and has no
  build-time `PUBLIC_*` values inlined into the client, so the
  `entrypoint.sh` sed-substitution pattern in `env-replacement/` does not
  apply. Worth stating in that README: the pattern is only for values baked
  into a client bundle, not for a server that validates `process.env`.

**Suggested fix:** a short `docker/node-ssr-nitro/` template (or a section in
`frontend-nextjs/README.md`) covering the three differences above.

## 2. Guidance gap: a shared `env_file: .env` hands every secret to every container

`docker/develop/compose.yml` (the client-derived shape this repo follows)
gives **every** service `env_file: - .env`. Verified with
`docker compose config` in this repo: the nginx `web` container's rendered
environment contains the whole `.env`, including `DATABASE_URL` and
`JWT_SECRET`. That is harmless for the API, but a public-facing SSR container
should not hold database credentials it never reads.

**Fix applied in a client repo:** the store service uses an explicit
`environment:` allowlist (`${VAR:-default}` interpolated from the same
`--env-file`), listing only the variables its schema parses.

**Suggested doc change:** in the compose standards, say public-facing
services take an explicit `environment:` allowlist, not the shared
`env_file`.

## 3. Gotcha: `${VAR:?message}` in a shared compose file breaks every command

Compose interpolates the **whole file**, not just the services a command
targets. Reproduced: with `PUBLIC_SITE_ORIGIN: ${STORE_PUBLIC_SITE_ORIGIN:?…}`
on one service and the variable unset, `docker compose config --quiet` fails
with `required variable STORE_PUBLIC_SITE_ORIGIN is missing a value` — and
so would `pull api`, `run migrate`, and a deploy preflight, on any host whose
`.env` predates the variable. An *optional* new service must use
`${VAR:-default}`; reserve `:?` for variables every service in the file needs.

**Suggested doc change:** one line in the compose standards next to the
existing `$`-interpolation note.
