# Roadmap

Templates and decisions that are planned but not yet done. Node/TypeScript
is the only stack covered today (the `docker`, `cicd`, `security` and
`project-infra` skills). Everything below is intent, not code. Don't
reference these from any skill until they exist, and build them through
the skill-authoring skill (interview first, check online).

## Pending decisions (found while migrating, 2026-09-26)

- **Node 26 default.** Templates pin `node:24-alpine`. Node 24 moves to
  Maintenance LTS on 2026-10-20 and Node 26 becomes Active LTS on
  2026-10-28. Decide when to move the default (a major version bump for
  docker, cicd, security and project-infra).
- **Redis licensing.** `redis:7-alpine` resolves to 7.4, which is
  RSALv2/SSPLv1 only (not OSI open source). Options: `redis:8-alpine`
  (AGPLv3 available), `redis:7.2-alpine` (BSD, older), or a fork such as
  Valkey. Needs your call. See `skills/docker/references/sources.md`.
- **Postgres 18.** Templates use 16 (supported until 2028); 18 is the
  newest major.

## Affected-app detection for multi-app CI/CD (non-Nx)

Designed but not built: a `detect-changed-apps` composite action shared
by CI and deploy, so an API-only change doesn't rebuild or redeploy the
frontends. Full design in `docs/history/2026-08-21-affected-app-detection-design.md`
(paths there refer to the old templates repo). It would extend
`ci-multi-app.yml` and the example's `deploy-develop.yml`.

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
- Migrations as a compose profile analogous to the node-api template's
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

## Deploy to a Docker host over SSM instead of SSH

The `ec2` template is Session-Manager-only, but the production deploy template reaches a Docker host over SSH because a GitHub-hosted runner cannot be restricted to a source address. Running the deploy through SSM Run Command with the OIDC role would remove port 22, the bastion and the deploy key. Not templated: it would be a new deploy path with no production history. See `skills/terraform/references/docker-host.md`.
