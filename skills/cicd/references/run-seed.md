# Run seed job (develop) template

A standalone, `workflow_dispatch`-only workflow that runs the `seed`
compose service against an already-deployed environment — independent
of any deploy. No push trigger, no git-sync, no rebuild.

## Why this is a separate workflow, not a `compose-profiles` flag

`docker/node-api/compose.yml` and `ssh-compose-deploy` already support a
`seed` profile (`ssh-compose-deploy`'s `compose-profiles: "migrate
seed"` input). That's enough if you want seeding to run on *every*
deploy — but that's usually wrong: seed jobs are typically
idempotent-but-not-free, or outright not meant to rerun on every push.
In practice "seed the database" is a distinct, occasional, manual
operation (post-schema-change reseed, restoring demo data after a reset)
that needs its own trigger, separate from the deploy lifecycle.

It's also not just `ssh-compose-deploy` with `compose-profiles: seed` on
its own, deploy-less run: that action's remote script does `docker
compose up -d --wait`, which expects services to reach a *running*
state — a one-shot `seed` container (`restart: "no"`) exits after it
finishes, which `--wait`'s health check would flag as "not running" and
fail the step even on a successful seed. This template uses `docker
compose run --rm seed` instead, which is the correct subcommand for a
one-shot job.

## What to change when copying this template

- Copy to `.github/workflows/run-seed-develop.yml`. Requires the same
  `develop` GitHub Environment secrets as `deploy-develop-build-on-server.yml`
  / `deploy-develop.yml` (`SSH_HOST`, `SSH_PORT`, `SSH_USER`,
  `SSH_JUMP_HOST`, `SSH_USER_JUMP`, `WORKING_DIR`, `SSH_PRIVATE_KEY`, `SSH_KNOWN_HOSTS`).
- **Pull-based deploys only** (the templates' `docker/develop/` convention,
  deployed by `ssh-compose-deploy`): works as-is. **Build-on-server
  deploys** (`docker/build-on-server/`): drop the `docker login` and
  `docker compose ... pull seed` lines — the image is already local, so
  there's nothing to log in for or pull.
- Copy the whole `docker/develop/` (or `docker/build-on-server/`) path
  if you keep your compose files somewhere other than that default.

## Before wiring this up: confirm the image actually has a `seed` entrypoint

`docker/node-api/compose.yml`'s `seed` service assumes a runnable `seed`
command already exists *in the built image* — that's not automatic. A
`seed.ts` script that exists in your source but was never wired into
your build config's entry points (e.g. an Nx webpack config's
`additionalEntryPoints`) means the compose `seed` service references a
command that was never actually built into the image. Nothing fails
loudly until someone runs it — confirm `entrypoint.sh`'s `seed` case
(`dist/src/seed.js` by default) is a real build output before relying on
this template.
