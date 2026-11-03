# node-api template: NestJS `rootDir: ./` output paths, and `localhost` in HEALTHCHECK

**Where found:** a single-app NestJS 11 + TypeORM API, audited and
brought up with `project-infra`, using
`docker/assets/node-api/` and `cicd/assets/workflows/docker-build-push.yml`.

## 1. Entrypoint/CLI-config paths assume a flat `dist/` (confirmed template gap)

`entrypoint.sh` runs `migration:run -d dist/typeorm-cli.config.js` and
`seed` runs `dist/src/seed.js`. In a NestJS repo with `rootDir: "./"` the
build output is `dist/src/...`, so the real paths are
`dist/src/database/config/typeorm-cli.config.js` and
`dist/src/seed/seed.js`. Also, this repo's `typeorm-cli.config.ts` listed
migrations as `src/database/migrations/*{.ts,.js}` (cwd-relative, TS
only), which finds nothing in a production image.

Fix applied in the project: the migrations glob is now
`join(__dirname, '../migrations/*{.ts,.js}')`, which resolves to `.ts`
under ts-node and `.js` in `dist`. Suggested doc addition to
`references/node-api.md`: "find your real output paths
(`find dist -name typeorm-cli.config.js`) and make the CLI config's
migrations glob `__dirname`-relative."

## 2. Template HEALTHCHECK uses `localhost` (contradicts the docker skill default)

`assets/node-api/Dockerfile` and `compose.yml` healthchecks use
`http://localhost:3000/health`, but the docker skill's defaults say to use
`127.0.0.1` (IPv6-first resolution in Alpine/busybox `wget`). Changed to
`127.0.0.1` in the project. Suggest fixing the template and the
compose/deploy healthchecks to match.

## 3. Template assumes a `/health` endpoint exists

Documented in `node-api.md`, but the global-auth-guard case is worth a
line: with a global JWT guard the endpoint must be explicitly public
(here `@Public()`), or the healthcheck gets 401 and the container is
unhealthy forever.

## 4. Composite actions fail to load: `${{ secrets.SSH_PORT }}` inside a `run:` comment (confirmed bug in two templates)

`cicd/assets/actions/git-sync-deploy/action.yml` (line 99) and
`cicd/assets/actions/ssh-compose-deploy/action.yml` (line 98) contain, in a
shell comment inside `run: |`, the text `(e.g. ${{ secrets.SSH_PORT }} when
that secret was never set)`. GitHub evaluates `${{ }}` in the whole `run`
body, comments included, and the `secrets` context does not exist inside a
composite action, so the run fails at action load:

    Unrecognized named-value: 'secrets'. Located at position 1 within
    expression: secrets.SSH_PORT   (action.yml Line 94, Col 12)

Repro: any workflow that does `uses: ./.github/actions/git-sync-deploy`.
Copies in `project-infra/assets/monorepo-layout/.github/actions/` have the
same lines. Fix: reword the comment without `${{ }}` (applied in the project as
"e.g. a caller's SSH_PORT secret that was never set"). Also add
to `references/gotchas.md`: no `${{ }}` in comments either, and a check for
it in the cicd verification step (`grep -n '#.*\${{'`).
