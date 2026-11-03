# Makefile template

Self-documenting `make help` via the `awk`-parsed `## comment` +
`##@ Section` convention — add `## description` after any target and it
shows up in `make help` automatically, grouped under whichever `##@`
header precedes it. `.DEFAULT_GOAL := help` means a bare `make` (no
target) shows the same help instead of running the first target in the
file — the common Make footgun this avoids.

Extracted from the most mature version of this pattern found across
several real monorepos.

## Two compose files, two purposes

- `docker-dev-*` targets use `$(COMPOSE_FILE)` (`docker/node-api/compose.yml`)
  — builds images locally from source. Use while actively developing.
- `docker-deploy-*` targets use `$(DEPLOY_COMPOSE_FILE)`
  (`docker/node-api/compose.deploy.yml`) — pulls already-built images
  from a registry, no local build. Use to test "what will actually run
  in production" without rebuilding, or as a local dry-run of what
  `ssh-compose-deploy` will do on the remote host.

These are genuinely different compose files (`compose.deploy.yml` has no
`build:` blocks and assumes externally-managed postgres/redis, matching
the usual `docker/develop/compose.yml` shape), not
the same file with a flag — a `build:`-having compose file always
rebuilds on `up`, which defeats the point of testing a pulled image.

## Granular targets, not just up/down

`docker-dev-db` / `docker-dev-db-down` start/stop infra only (useful
when you're running the app itself outside Docker, e.g. `make dev`, but
still want a real Postgres/Redis). `docker-dev-apps` starts the app
assuming infra is already up. `docker-dev-clean` is a distinct target
from `docker-dev-down` — it adds `-v` to remove volumes, which is
destructive (wipes local DB data) and shouldn't be the default `down`
behavior.

## What to change when copying this template

- Copy `assets/Makefile` into your project root as `Makefile` so
  `make` picks it up without `-f`.
- Update `COMPOSE_FILE`/`DEPLOY_COMPOSE_FILE` to point at wherever you
  place those files (see `references/node-api.md`).
- Fill in `<GH_ORG>`/`<REPO>` in `compose.deploy.yml`'s `image:` refs.
- `docker-dev-db`/`docker-dev-apps` name `postgres`/`redis`/`api`
  explicitly, matching `docker/node-api/compose.yml`'s service names —
  rename if your service names differ, or add more `dev-<app>`-style
  native targets per the `##@ Local development` section if you have
  multiple apps in a monorepo (the project-infra example's
  `Makefile` is a multi-app version of that pattern).
- The `.env` target auto-bootstraps `.env` from `.env.example` only if
  `.env` doesn't already exist — it won't clobber an existing one.
  `docker-dev-env` is the explicit force-sync you reach for when
  `.env.example` gained new keys and you want them merged in — running
  `cp` again is the whole "merge," so it overwrites the entire file
  rather than merging key-by-key; save local overrides elsewhere first.

## `dockerignore` note

Rename `assets/dockerignore` to `.dockerignore` in your project root
when copying it (it's named without the leading dot here so it doesn't
get excluded from this templates repo itself). The `!.env.example`
negation line matters: it re-includes the example file after the
broader `.env.*` exclusion, so the example still ships in the build
context for documentation purposes.
