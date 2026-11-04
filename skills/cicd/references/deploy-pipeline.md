# Deploy pipeline

Assets: `assets/deploy-workflows/` (`deploy-pipeline.yml`, `deploy-pipeline-bake.yml` and `run-service.yml`, copied verbatim; `deploy.yml`, `seed.yml` and `migrate.yml`, the project's own entry points), `assets/scripts/check-deploy-conformance.sh`.

Every project deploys the same way: images built in CI and pushed to GHCR, then a compose stack updated over SSH. When each project writes its own pipeline, the copies drift: an audit of one organization's 12 repositories found deploy files from 124 to 492 lines, seven names for the job before the build, production as a near-copy of the develop file under three different names, and host-key checking switched off in most of them. So the pipeline is one set of files in this skill, copied unchanged into every project, and a check that fails when a copy has been edited or has fallen behind.

## The standard

| | Every project |
|---|---|
| Pipeline files | `.github/workflows/deploy-pipeline.yml` (or `deploy-pipeline-bake.yml` for Docker Bake microservices) and `run-service.yml` (verbatim copies), plus the project's own `deploy.yml`, and `seed.yml` / `migrate.yml` when the compose file has those services. Nothing else deploys. |
| Branches and environments | `develop` deploys to the `develop` GitHub Environment, `production` to `production`. One file serves both. |
| Jobs | `verify` (the project's own lint and typecheck) > `build` > `migrate` (only with `migrate: true`) > `deploy` |
| Images | `ghcr.io/<owner>/<repo>-<app>`, tagged with the commit SHA (what the host runs) and `latest-<environment>` |
| Host | the repository synced to `<WORKING_DIR>/<repo>` at the deployed commit; compose files in `docker/<environment>/`, the host's `.env` beside them and gitignored |
| SSH | host keys pinned from the `SSH_KNOWN_HOSTS` secret, strict checking, registry logout on every exit |
| Rollback | run Deploy manually with an older `commit_sha` |

## Set up a project

1. Copy `deploy-pipeline.yml` and `run-service.yml` into `.github/workflows/`, each preceded by two header lines, and do not edit them afterwards:

   ```
   # Vendored verbatim from the dev-pops cicd skill: assets/deploy-workflows/<file>
   # Source of truth is that file — re-copy from there, don't hand-edit here.
   ```

2. Copy `deploy.yml` and fill every marker: the project's install, lint and typecheck commands, the app list as JSON (`'["api","web"]'`), and whether it migrates. A single-app repository also sets `dockerfile: Dockerfile` under `with:`. The Dockerfile for each app is found as `apps/<app>/Dockerfile` unless `dockerfile:` says otherwise (`{app}` stands for the app's name).
3. Copy `seed.yml` and `migrate.yml` when the compose file has `seed` or `migrate` services. Each provides a manual `workflow_dispatch` trigger with a single `environment` choice input (`[develop, production]`). Unified workflows use action-only names (`name: Deploy`, `name: Seed`, `name: Migrate`) to cleanly serve both environments.
4. Compose: `docker/develop/compose.yml` and `docker/production/compose.yml`, one service per app named like the app, each with `image: ghcr.io/<owner>/<repo>-<app>:${IMAGE_TAG:-latest-<environment>}`. A `migrate` service when `migrate: true`.
5. `.gitignore` covers `docker/*/.env`. The deploy runs `git clean` on the host and stops if the `.env` is not ignored.
6. GitHub Environments `develop` and `production`, each with the secrets `SSH_HOST`, `SSH_USER`, `SSH_PRIVATE_KEY`, `SSH_KNOWN_HOSTS` (the output of `ssh-keyscan -p <port> <host>`, plus the bastion's), `WORKING_DIR`, and optionally `SSH_PORT`, `SSH_JUMP_HOST`, `SSH_USER_JUMP`. An optional variable `HEALTH_URL` is checked after each deploy. Give `production` required reviewers and limit its deployment branches to `production`.
7. On each host, the operator creates `<WORKING_DIR>/<repo>/docker/<environment>/.env` with real values. A deploy never creates it.
8. Run `bash <skill>/assets/scripts/check-deploy-conformance.sh` from the project root. It compares the copied files byte for byte with the skill's and lists every other difference from this standard.

### Microservices with Docker Bake: `deploy-pipeline-bake.yml`

When several apps or microservices in a repository share base Dockerfile stages (e.g. `node_modules` install, common OS packages), building them with standard matrix jobs runs those stages independently on every runner and creates different layer digests, forcing the server to download duplicate blobs for each service.

Instead of `deploy-pipeline.yml`, vendor `deploy-pipeline-bake.yml`:
1. Copy `assets/deploy-workflows/deploy-pipeline-bake.yml` with its vendored header into `.github/workflows/deploy-pipeline-bake.yml`.
2. Place `docker-bake.hcl` (from `assets/bake/docker-bake.hcl`) at the repo root, listing each microservice in its matrix.
3. In `deploy.yml`, call `uses: ./.github/workflows/deploy-pipeline-bake.yml` instead.
Bake builds all services on one BuildKit builder; shared stages build once, layers match byte-for-byte, and the host pulls shared layers only once.

## Changing the pipeline

Change `deploy-pipeline.yml` or `run-service.yml` here, in the skill, with a version bump and changelog entry. Then roll it out: for each project, re-copy the file with its two header lines, run the conformance check, and open one pull request per project. Deploy `develop` first and check the run before merging the production side. The conformance check run over all of an organization's projects shows which are behind.

The pipeline files carry no per-project values: everything that differs lives in the project's `deploy.yml` (apps, migrate, Dockerfile pattern) and its GitHub Environments. A rollout is therefore never a merge, only a copy.

## Moving an existing project

Run the conformance check first; its list is the work. In one pull request per project:

- Add the five files and remove every `deploy-*`, `run-seed-*`, `seed-*` and `migrate-*` workflow, `docker-build-push.yml` where only the old deploy used it, and the vendored `ssh-compose-deploy` / `git-sync-deploy` actions.
- Point every compose image at `${IMAGE_TAG:-latest-<environment>}`.
- Add `SSH_KNOWN_HOSTS` to both environments, and rename a production branch or environment called `main` or `prod` to `production`. A branch rename touches branch protection and anything that pushes to it: confirm it with the user.
- Deploy develop first and check the run, then production.

## Why it is built this way

- **Copies, not a shared repository.** A reusable workflow could live in one organization repository and be called by tag, so a fix reaches every project at once. It would also make every project depend on a private repository: a repository handed to a client, or moved to another account, would stop deploying. It needs an organization-level access setting too. Copies cost one pull request per project per change, which an agent opens in one pass, and the conformance check keeps them honest.
- **A calling job cannot set `environment`**, so the pipeline's own jobs set it from the input, and that is where environment secrets become available.
- **The caller must still pass the secrets.** `secrets: inherit` passes them all. An environment secret the caller does not pass resolves to an empty string without an error, so each SSH job checks every secret it needs first and names the missing ones.
- **Permissions only narrow.** A called workflow cannot grant itself more than the caller's job allows, so `deploy.yml` grants `packages: write` for the build.
- **GitHub creates an environment the first time a job names it.** `deploy.yml` only deploys `develop` and `production`, so a manual run from another branch cannot create a stray environment with no secrets.
- **A deploy is never cancelled halfway.** The caller's concurrency group queues a second deploy instead.
- **Seeds and migrations run against what is live.** The deploy records the SHA it put live on the host (outside the repository, which `git clean` would empty), and `run-service.yml` runs that exact build; before the first deploy it refuses to run. Manual runs for either service use a single entry point (`seed.yml` or `migrate.yml`) with an `environment` choice input (`[develop, production]`).
