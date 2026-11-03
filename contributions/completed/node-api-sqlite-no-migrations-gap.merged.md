# `docker/node-api` assumes Postgres + TypeORM migrations; no lightweight SQLite variant exists

> **Status: merged 2026-09-26** during the migration into dev-pops-skills.
> - Documented as "Variant: SQLite, no migrations" in `skills/docker/references/node-api.md` (no DB/migrate/seed services, trimmed entrypoint, `/app/data` volume, `/health` still required).
>
> Paths in the original write-up below refer to the old templates repo.

**Where found:** `test-app` (a small NestJS + Next.js todo demo,
personal/test-app), adapting `docker/node-api/` and `docker/frontend-nextjs/`.
Confirmed against this repo's current templates today, not a derivative.

**The gap:** `docker/node-api/compose.yml`, `Dockerfile`, and
`entrypoint.sh` all assume a Postgres-backed app using TypeORM
migrations (`migrate`/`seed` compose services, `entrypoint.sh`'s
`migrate` case running `typeorm/cli.js migration:run`, `/health`
endpoint assumed already present). None of this fits a small app using
`type: 'sqlite'` + `synchronize: true` (no migrations, no separate DB
server, no seed step) — a legitimate, common shape for demos/prototypes,
not just this one project.

**What I did instead (in test-app only, not the template):**
- Dropped `postgres`/`redis`/`migrate`/`seed` from the compose file
  entirely — just `backend` + `frontend` services, no external DB.
- Reduced `entrypoint.sh` to only the `start|"")`/`*)` cases (no
  `migrate`/`seed` cases).
- Mounted a named volume at a dedicated `/app/data` directory (added
  `RUN mkdir -p /app/data && chown node:node /app/data` to the
  Dockerfile) rather than the whole `/app`, so the SQLite file persists
  across restarts without shadowing `dist`/`node_modules`.
- The app didn't have a `/health` endpoint (template's own README says
  "assumes a `/health` endpoint exists; add one if it doesn't") — added
  a trivial one (`@Get('health') → { status: 'ok' }`) to `AppController`.

**Suggested fix for this repo:** consider a `docker/node-api-sqlite/`
(or a documented "SQLite variant" section in `docker/node-api/README.md`)
covering: no postgres/redis services, no migrate/seed cases, a
dedicated data-dir + named-volume pattern for the SQLite file, and a
note that `synchronize: true` (no migrations) is a valid, common
config this template doesn't currently serve. Not urgent — the
Postgres+migrations shape is probably still the more common real
target — but worth a doc note at minimum so the next agent doesn't
have to rediscover the same set of deltas from scratch.
