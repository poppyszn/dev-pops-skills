# Dockerfile and compose rules, with the bugs behind them

The short rules are in SKILL.md under Defaults. This file holds the reasoning and the real incidents, so a rule isn't dropped as "style". Entries marked **Shipped once** caused a real bug in a template before being fixed.

## Build context resolves against the compose file's directory

A relative `build.context` (`..`, `../..`) resolves against the **compose file's own directory**, not the directory `docker compose` is run from. Count the levels back to the project root.

**Shipped once:** `node-api/compose.yml` used `context: ..`. From `docker/node-api/` that is `docker/`, not the project root, so `COPY package.json ./` would fail on any real project. Fixed to `context: ../..`, with `COPY` paths for files outside the app source (`entrypoint.sh`) made relative to the corrected root.

## `$` inside `.env` values must be doubled

Compose interpolates `$VAR` references **inside values of an `env_file:`-loaded `.env` itself**, not only in `compose.yml`. A bcrypt hash (`$2b$12$rK9nDVjYn...`) silently loses segments that look like variable names. Any `.env.example` documenting a secret that can contain `$` must say to escape every `$` as `$$`.

Verify: `docker compose --env-file .env config | grep <VAR>`. Seeing `$$` in the output means the value round-tripped intact. (Confirmed with a live repro.) This is separate from the `env-replacement.md` sed pattern and applies to backend services too.

## `service_healthy` on Postgres is not a readiness guarantee

On a fresh volume, the official Postgres entrypoint starts a temporary server for `initdb`, stops it, then starts the real one. `pg_isready` can report healthy during the temporary server's window, letting a dependent `migrate` start into the restart gap and hit `ECONNREFUSED`. (Confirmed with a live repro.) Don't try to perfect the healthcheck. **Retry the dependent command** instead (see `assets/node-api/entrypoint.sh`'s `migrate` case).

## `depends_on` needs a condition

Use `condition: service_healthy` or `condition: service_completed_successfully`. A bare service name only waits for the container to start, not to be ready.

## Restart policy: services yes, one-shot jobs no

Long-running services get `restart: unless-stopped`. One-shot jobs (`migrate`, `seed`) must not: a restarting one-shot job is a bug, not resilience.

## Resource limits are always present

Every service sets `deploy.resources.limits` (`cpus`, `memory`) as adjustable starting points. Compose v2 applies them outside Swarm too; they aren't a no-op.

## Public-facing services get an `environment:` allowlist, not the shared `env_file`

A shared `env_file: .env` on every service hands every secret to every container. Verified with `docker compose config`: an nginx or SSR container ends up holding `DATABASE_URL` and `JWT_SECRET` it never reads. Give public-facing services an explicit `environment:` list of only the variables they use, interpolated from the same env file (`VAR: ${VAR:-default}`). Backend services that need most of the file can keep `env_file`.

## `${VAR:?message}` breaks every command on the file

Compose interpolates the **whole file**, not only the services a command targets. One `${VAR:?…}` on one service with the variable unset makes `config`, `pull api`, `run migrate` and deploy preflights all fail, on any host whose `.env` predates the variable. (Reproduced.) Optional or newly added services use `${VAR:-default}`. Reserve `:?` for variables every service in the file needs.

## Build-local and pull-image compose files stay separate

When both exist for the same service, keep `compose.yml` (with `build:`) and `compose.deploy.yml` (with `image:`) as separate files, not one file toggled by a flag. A file with `build:` blocks rebuilds on `up`, which defeats testing a pulled image.

## Don't reuse a directory name with a different meaning

Before introducing a directory naming convention, check it doesn't already mean something incompatible in a real project these templates draw from.

**Shipped once:** `docker/develop/` was documented as build-on-server (`build:` blocks), while the real source project used it for the opposite, pull-based (`image:`) shape. Renamed to `docker/build-on-server/`. `docker/develop/` now means pull-based.

## Overriding a base image's ENTRYPOINT

If you override a base image's own `ENTRYPOINT` (nginx, postgres…), check what that entrypoint normally does before assuming it's safe to skip.

**Shipped once:** overriding nginx's entrypoint silently skipped its envsubst-on-templates step, so the config template was never rendered.

## Healthchecks: `127.0.0.1`, not `localhost`

On these alpine images, `localhost` can resolve to `::1` (IPv6) first while the server listens on IPv4, so `wget localhost` gets "connection refused" against a healthy server. Confirmed for both the nginx SPA and Next.js images.

This applies to a compose `healthcheck:` exactly as it does to a `HEALTHCHECK` in the Dockerfile — the check runs inside the same container, against the same resolver. Every compose healthcheck that talks HTTP to its own service targets `127.0.0.1`.

**Shipped once:** all four compose templates (`assets/node-api/compose.yml`, `assets/node-api/compose.deploy.yml`, and the project-infra example's root and `docker/develop/` stacks) healthchecked the api service against `localhost` while the Dockerfiles beside them had already been fixed. The api service therefore never left `starting`, and because `migrate`, `seed` and the frontends gate on `depends_on: condition: service_healthy`, the whole stack hung behind a container that was serving fine. Fixed in one pass; the rule is in the file as a comment so a copy carries it.

Not covered by this rule: a *host-side* URL such as `NEXT_PUBLIC_API_URL` or `VITE_API_URL`. Those are resolved by the developer's browser, not inside a container, and `localhost` is correct there.

## Publish on `127.0.0.1` when a reverse proxy on the host is the front door

A published port with no address (`"3000:3000"`) listens on every host interface (Docker's port-publishing docs). With nginx on the same host proxying to `127.0.0.1`, publish `"127.0.0.1:3000:3000"` instead: the container is then unreachable from outside even if a security group rule is added by mistake, and the host has no firewall of its own to catch it. `docker compose config` shows the result as `host_ip: 127.0.0.1`. The develop templates (`compose.deploy.yml`) keep the all-interfaces form because there the api may be reached directly.

## Run the commit, not a moving tag

Images were already pushed as both `latest-<env>` and the commit SHA, but a compose file pinned to the moving tag runs whatever was pushed last, so a rollback needed a rebuild. `${IMAGE_TAG:-latest-production}` lets the deploy run the exact SHA while a manual command with no variable still works. The host forgets old images after a week (the deploy prunes them); the registry keeps every SHA.
