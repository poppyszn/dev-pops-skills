# The `docker/build-on-server/` convention

`docker/build-on-server/` is a per-project directory (not a copy-paste
template of its own — you write it per project, following this shape)
holding the compose stack that `deploy-develop-build-on-server.yml`
deploys. It's the **build-on-server sibling** of the existing
`compose.deploy.yml` convention (see the docker skill's `references/node-api.md` §
"`compose.yml` vs `compose.deploy.yml`") — same idea, different source
for the image:

| | `compose.deploy.yml` (project root) | `docker/build-on-server/compose.yml` |
|---|---|---|
| Image source | `image:` — pulled from a registry | `build:` — built on the host it runs on |
| Requires | A registry (GHCR etc.), `docker-build-push.yml` in CI | Nothing beyond Docker on the target host |
| Deployed by | `ssh-compose-deploy` | `deploy-develop-build-on-server.yml` + `git-sync-deploy` |
| Use when | You have (or are fine setting up) a registry | Private/non-org repo, don't want a registry yet |

Use one or the other for a given project's deploy path, not both.

**Naming note:** this directory is deliberately NOT called `docker/develop/`
even though the workflow that deploys it targets a `develop` branch/
environment. `docker/develop/` already means something else in the
wild — a `docker/develop/compose.yml` is often a
**pull-based** stack (`image:`, no `build:`), the opposite of what this
convention does. Naming this directory `docker/build-on-server/` instead
of reusing `docker/develop/` avoids that collision — see
the project-infra skill's `references/monorepo-layout.md` for
a worked layout that uses `docker/develop/` the *other* way (pull-based,
the more common convention) so you can compare both shapes
side by side.

## What goes in `docker/build-on-server/`

- **`compose.yml`** — same service shape as your project-root
  `compose.yml` (one-shot `migrate`/`seed` jobs without `restart:`,
  long-running app services with `restart: unless-stopped`,
  `depends_on: condition:` gating, `deploy.resources.limits`), but every
  service that runs your own code uses `build:` pointing at that
  service's Dockerfile — never `image:`. Infra services you don't
  control the image for (postgres, redis) can still use `image:` as
  normal; only your own app/API services need `build:`.
- **`.env.example`** — the deploy-time env catalog: production-mode
  values, container-network hostnames (`http://api:4000`, not
  `localhost`) for service-to-service calls, and any `_PORT` vars the
  compose file uses for host port mapping. `git-sync-deploy` copies this
  to `.env` on the host automatically the first time it syncs — it never
  overwrites an existing `.env`, so once you've filled in real secrets
  there by hand they persist across deploys.

## Multi-app monorepos

If your repo has more than one deployable app, list every app as its own
service in the same `docker/build-on-server/compose.yml`, each with its
own `build: {context: ., dockerfile: apps/<app>/Dockerfile}`.
`deploy-develop-build-on-server.yml` builds and starts the whole stack in
one pass — it doesn't currently support building only a changed subset;
if your project needs affected-only deploys, adapt the workflow to
compute an affected-apps list first (see the `detect` job in
`assets/workflows/deploy-production-nx.yml` for an Nx-based version of
that pattern, though note that workflow deploys pulled images, not
build-on-server) and pass it as
the service list to `docker compose build`/`up`.

## Why not just reuse the root `compose.yml`?

You could point `deploy-develop-build-on-server.yml` at the root
`compose.yml` directly instead of a separate `docker/build-on-server/`
copy, but keeping them separate lets the two diverge on purpose — e.g.
the root `compose.yml` runs local-only infra (`postgres`, `redis`,
`mailpit`) that the target host might not need if it has managed
Postgres/Redis instead, or the deploy stack needs different resource
limits / host ports than local dev. If your project's local and deploy
shapes are identical, it's fine for `docker/build-on-server/compose.yml`
to be a thin file that's mostly the same as the root one — just don't
assume that'll always be true and hardcode the root path into the
workflow.

## Pre-deploy gate

`deploy-develop-build-on-server.yml` runs a light `verify` job (install, lint, typecheck, `--if-present`) on the commit the server will build, and `deploy` needs it. Full test suites stay on PRs. See `gotchas.md`, "CI on pull requests, a light gate on deploys".
