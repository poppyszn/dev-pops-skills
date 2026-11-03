# Example: assembled monorepo layout

This is what it looks like when the templates in the docker, cicd and
security skills are actually applied to a project — a 3-app npm-workspaces monorepo (`api` = Node API,
`web` = Next.js, `admin` = static SPA behind nginx), modeled on
a real monorepo's root structure (`Makefile`, root
`compose.yml`, `docker/develop/`, `.github/workflows/`) but rebuilt using
only the templates that actually exist in those skills today (no Nuxt, no
custom static-server pattern — real repos have those, the skills don't
template them yet).

**App source code is intentionally NOT included** — only the
infrastructure files (Dockerfiles, entrypoints, compose files,
workflows, Makefile, dotfiles). Copy this tree's *shape* into a real
project, then drop your actual app source into `apps/*/`.

## Why this exists

The per-concern template library (the docker, cicd and security skills' `assets/`)
answers "what does the Node API Dockerfile look like." It doesn't answer
"where does that file go, and what changes when three of these templates
live in one repo together" — build contexts shift, `COPY` paths need
adjusting, compose files need to reference `apps/<name>/Dockerfile`
instead of a template's own directory, and two GitHub Actions files that
are unrelated in the library (`docker-build-push.yml` + `ssh-compose-deploy`)
need to be wired together into one deploy pipeline. That assembly step is
where mistakes happen. This directory is the answer key.

## Directory tree

```
.
├── Makefile                              ← adapted from docker: assets/Makefile
├── compose.yml                           ← adapted from docker: assets/node-api/compose.yml, extended to 3 apps
├── .env.example                          ← local dev values
├── .dockerignore                         ← copy of docker: assets/dockerignore, dot-prefixed
├── .editorconfig
├── .nvmrc
├── apps/
│   ├── api/
│   │   ├── Dockerfile                    ← adapted from docker: assets/node-api/Dockerfile
│   │   └── entrypoint.sh                 ← copy of docker: assets/node-api/entrypoint.sh
│   ├── web/
│   │   ├── Dockerfile                    ← adapted from docker: assets/frontend-nextjs/Dockerfile
│   │   └── entrypoint.sh                 ← adapted from docker: assets/frontend-nextjs/entrypoint.sh
│   └── admin/
│       ├── Dockerfile                    ← adapted from docker: assets/frontend-spa-nginx/Dockerfile
│       ├── nginx.conf                    ← copy of docker: assets/frontend-spa-nginx/nginx.conf
│       └── entrypoint.sh                 ← copy of docker: assets/frontend-spa-nginx/entrypoint.sh
├── docker/
│   └── develop/
│       ├── compose.yml                   ← new: pull-based deploy stack (the usual pull-based convention)
│       └── .env.example                  ← new: deploy-time env catalog
└── .github/
    ├── PULL_REQUEST_TEMPLATE.md          ← new: the PR shape, copied verbatim into every project
    ├── workflows/
    │   ├── ci.yml                        ← adapted from cicd: assets/workflows/ci-simple.yml (PRs to develop + manual)
    │   ├── docker-build-push.yml         ← VENDORED VERBATIM from cicd: assets/workflows/docker-build-push.yml
    │   ├── deploy-develop.yml            ← new: verify gate → docker-build-push.yml → both composite actions
    │   ├── run-seed-develop.yml          ← copied from cicd: assets/workflows/run-seed-develop.yml, no adaptation needed
    │   └── security.yml                  ← adapted from security: assets/workflows/security.yml (branch filled in)
    └── actions/
        ├── ssh-compose-deploy/action.yml ← VENDORED VERBATIM from cicd: assets/actions/ssh-compose-deploy/
        └── git-sync-deploy/action.yml    ← VENDORED VERBATIM from cicd: assets/actions/git-sync-deploy/
```

"VENDORED VERBATIM" files are **not** independent copies — GitHub Actions
requires reusable workflows and composite actions to physically live
under `.github/workflows/` / `.github/actions/` to be callable at all, so
this is the one place duplication is mandatory, not a style choice. Each
has a header comment pointing back to its source of truth in the
cicd or security skill's `assets/`; re-copy from there when that file changes,
don't hand-edit the vendored copy.

`PULL_REQUEST_TEMPLATE.md` needs no adaptation — copy it as it is. It is
deliberately *not* a vendored copy of the skills repo's own
`.github/PULL_REQUEST_TEMPLATE.md`: that one asks about skill versions,
`sources.md` rows and gap findings, which mean nothing in a client project.
This one asks about deploy impact and rollback. The two drift apart on
purpose, so don't sync them.

It matters more here than it looks. CI triggers on `pull_request` only, so the
pull request *is* the gate — and the template is the only place that asks
whether the stack was actually brought up (`docker compose up -d --wait`),
which CI never does.

## What required real adaptation (the parts that actually cause "cut and join" bugs)

- **Build contexts.** Every app's `Dockerfile` now assumes the build
  context is the **repo root** (`context: .` in `compose.yml`), not its
  own directory — `COPY package.json ./` works because `docker compose
  build` is invoked with the whole monorepo as context. Compare this to
  the docker skill's `assets/node-api/Dockerfile` in isolation, which needs `context: ../..`
  from its own `compose.yml` for the same reason (see the docker skill's
  `references/compose.md` for the exact bug this caused when it was wrong).
- **`COPY` paths for non-source files.** `entrypoint.sh` isn't at the
  build context root — it's at `apps/api/entrypoint.sh`,
  `apps/web/entrypoint.sh`, etc. Every `COPY` line for these files was
  updated to the full path from repo root.
- **npm workspaces build commands.** `npm run build` became `npm run
  build --workspace=apps/<name>` — building "the app" in a monorepo
  means building one workspace, not the whole repo.
- **Next.js standalone output path.** With workspaces, `.next/standalone`
  nests under the app's own workspace path
  (`apps/web/.next/standalone/...`), not flat at the repo root — flagged
  with a caveat comment in `apps/web/Dockerfile` since the exact shape is
  Next.js-version-dependent; verify with a real build before trusting it.
- **`docker/develop/` vs `docker/build-on-server/`.** This example uses
  `docker/develop/` for the **pull-based** stack, the
  usual pull-based convention — not the cicd skill's
  `docker/build-on-server/` convention, which is a different (and
  differently-named, on purpose) pattern. See
  the cicd skill's `references/build-on-server.md` for why these two are
  deliberately separate directory names.
- **CI on PRs, a light gate on deploy.** `ci.yml` runs only on pull
  requests to `develop` (plus manual dispatch). `deploy-develop.yml`
  never calls it. Its first job, `verify`, runs `npm ci`, then lint and
  typecheck across workspaces (`--if-present`), and `build-and-push`
  needs it, so `latest-develop` is never pushed for a broken commit.
  CI is enforced by required status checks on `develop`, which the user
  must enable in branch protection.
- **The develop deploy passes `commit_sha` to the build.** `docker-build-push.yml` takes an optional `ref` input, and `deploy-develop.yml` passes `ref: ${{ inputs.commit_sha }}`. Without it a manual deploy of a chosen commit built and tagged the commit that triggered the run instead.
- **Two composite actions chained, not one.** `ssh-compose-deploy` only
  pulls images and starts the stack — it doesn't sync
  `docker/develop/compose.yml` onto the host itself. `deploy-develop.yml`
  runs `git-sync-deploy` first for that reason, then computes
  `ssh-compose-deploy`'s `working-dir` input as
  `<WORKING_DIR>/<repo-name>/docker/develop` to point at exactly where
  `git-sync-deploy` put it — a wiring detail that isn't obvious from
  either action's own README in isolation.

## Local usage

```bash
cp .env.example .env
make docker-dev       # full local stack: postgres, redis, api, web, admin
make docker-dev-db    # infra only, if running an app natively instead
make dev-api          # native dev server for one app
```
