# Templates Repo Design

Date: 2026-08-13

## Purpose

A personal repo of reusable, documented templates for CI/CD, Docker, and
frontend env-replacement setups, so that starting a new project (or fixing
one) doesn't mean re-deriving these patterns from scratch. It's meant to be
read by both the user and an AI coding assistant working in an unrelated
project directory.

## Source material

Patterns are extracted from real, production projects surveyed across
several client and work repositories. Each template below is traced to its best real-world
example rather than invented from scratch. Full survey findings are in the
session that produced this spec (not duplicated here) — see file-level
READMEs for the "why" behind each template.

## Scope

- **In scope now**: Node/TypeScript stack — GitHub Actions CI/CD, Docker
  (backend API images, frontend SPA/nginx images, Next.js images),
  docker-compose, and frontend runtime env-replacement.
- **Deliberately out of scope now, documented as future work**: PHP/Laravel,
  Python, Kubernetes/Helm/GitOps (a full GitOps stack exists in
  a work GitOps repository but is a different deployment model — SSH+compose is the
  target here).

## Repo structure

```
templates/
├── CLAUDE.md                          # AI-assistant index & usage instructions
├── README.md                          # human-facing overview
├── ci-cd/
│   └── github-actions/
│       ├── node/
│       │   ├── ci.yml                 # lint/test/build, Nx-affected variant
│       │   ├── ci.README.md
│       │   ├── ci-simple.yml          # non-monorepo lint/test/build
│       │   └── ci-simple.README.md
│       ├── docker-build-push.yml      # build/push to GHCR, matrix-capable
│       ├── docker-build-push.README.md
│       └── actions/
│           └── ssh-compose-deploy/    # composite action
│               ├── action.yml
│               └── README.md
├── docker/
│   ├── node-api/
│   │   ├── Dockerfile                 # deps → build → production, cache mounts
│   │   ├── entrypoint.sh              # migrate/seed/start command router
│   │   ├── compose.yml                # api+db+redis, migrate/seed/test profiles
│   │   └── README.md
│   ├── frontend-spa-nginx/
│   │   ├── Dockerfile
│   │   ├── nginx.conf.tpl
│   │   ├── entrypoint.sh              # __VAR__ + sed replacement, strip_quotes
│   │   └── README.md
│   ├── frontend-nextjs/
│   │   ├── Dockerfile
│   │   ├── entrypoint.sh
│   │   └── README.md
│   ├── Makefile                       # awk-parsed help, dev/deploy sections
│   ├── Makefile.README.md
│   └── dockerignore                   # renamed from .dockerignore to avoid being ignored itself
├── env-replacement/
│   └── README.md                      # explains the pattern, points at the docker/frontend-* templates
└── roadmap.md                         # future stacks — documented, not implemented
```

Organization principle: **by concern, then stack** (e.g. `docker/node-api`,
not `templates/node-api-bundle/docker`). This keeps templates
independently discoverable — someone (or an AI assistant) looking for "how
do I set up a Dockerfile for a Node API" finds it directly, without needing
to know which bundle it lives in.

## Templates and their source of truth

| Template | Extracted from | Notes |
|---|---|---|
| `docker/node-api/Dockerfile` | a client repo (`Dockerfile`) | 3-stage (deps/build/production), npm cache mount, non-root `node` user |
| `docker/node-api/entrypoint.sh` | a client repo + a client repo (identical) | `migrate`/`seed`/`start`/passthrough command router |
| `docker/node-api/compose.yml` | a client repo (`compose.yml`) | healthchecked deps, `migrate` as blocking one-shot, `seed`/`test` as profiles |
| `docker/frontend-spa-nginx/*` | a client repo | most mature env-replacement entrypoint (strip_quotes, fail-fast, scoped `find`), nginx conf with gzip + immutable caching + SPA fallback |
| `docker/frontend-nextjs/*` | a client repo | simplest ARG→ENV→sed entrypoint for `NEXT_PUBLIC_*` vars |
| `docker/Makefile` | a client repo (`Makefile`) | `awk`-parsed `## comment` help target, `.env: cp .env.example .env` bootstrap rule |
| `ci-cd/github-actions/node/ci.yml` | a client repo (`ci.yml`) | `nx affected` + conditional e2e based on affected apps |
| `ci-cd/github-actions/docker-build-push.yml` | a client repo (`deploy-develop.yml`) | matrix build-and-push with per-app GHA cache scoping |
| `ci-cd/github-actions/actions/ssh-compose-deploy` | copy-pasted across three client repos | extracted into one composite action: ssh-agent setup, ProxyJump config, remote compose up with `--wait`, JSON-based unhealthy-container detection + log dump, timed image/build prune, `$GITHUB_STEP_SUMMARY` report |

## Env-replacement pattern (the template's opinion)

Chosen pattern: **build-time placeholder tokens baked into the compiled
bundle, replaced via `sed` in `entrypoint.sh` at container start** — not a
separate `runtime-config.js` fetched at runtime. This matches what's
actually proven across three separate frontend projects, rather than
introducing an untested pattern.

Standard shape for every frontend entrypoint template:
1. Placeholder convention: `__ENV_VAR_NAME__` (double-underscore wrapped,
   matches the var name so it's greppable).
2. `strip_quotes` helper applied to every substituted value, guarding
   against `env_file:`-sourced values that arrive with quotes still
   attached.
3. Fail-fast validation of required vars before running `sed`, with a clear
   error message (as seen in the multi-app a client repo variant).
4. `find` scoped to the narrowest directory possible (e.g. per-app output
   dir, not the whole webroot) — avoids cross-app collisions and keeps
   container boot fast.
5. `exec "$@"` at the end always, so `CMD` / extra `docker run` args still
   work.
6. Optional `APP`-style multi-target selection (nginx conf template swap)
   only for images that intentionally serve more than one app — omitted
   from the single-app Next.js template.

## SSH-compose-deploy composite action

Because this exact block is duplicated near-verbatim across 5+ real
workflows, it becomes a proper composite action
(`ci-cd/github-actions/actions/ssh-compose-deploy/action.yml`) with inputs
for: SSH private key, jump host/user, target host/port, working directory,
git remote/ref, registry + image name, `.env` bootstrap behavior, compose
profile(s) to run, and prune retention window. Behavior preserved from the
source pattern:
- clone-with-token-then-strip-token pattern for private repo checkout,
- `docker compose up -d --wait --wait-timeout <n>`,
- unhealthy-container detection via `docker compose ps --format json | jq`,
  dumping `docker logs --tail 50` for any non-running container before
  failing,
- image/builder/container prune with a configurable `until=` retention,
- a `$GITHUB_STEP_SUMMARY` deployment report (status/image/commit/branch
  table), emitted with `if: always()`.

Consuming workflows call this action instead of copy-pasting the block.

## CI/CD scope boundary

CI templates cover **lint → test → build → docker build/push to a
registry (GHCR)** and stop there. Actual deployment (the SSH-compose-deploy
action) is a separate, explicitly-invoked workflow/job — matching the
a client repo / a client repo pattern of
decoupling "is this image good" from "is this image live." No specific
cloud provider or non-SSH deploy target is baked in.

## Documentation approach

Every template ships as **an actual, usable file plus a short
`README.md`** in the same directory (or `<name>.README.md` next to it when
the directory holds multiple sibling templates, e.g. `ci.yml` +
`ci.README.md`). Each README covers: what this template is for, which
variables/placeholders to change, and any gotchas (e.g. "don't forget to
add `!.env.example` to `.dockerignore`").

## AI-assistant entrypoint

Root `CLAUDE.md` acts as an index: for a given need ("set up CI for a Node
monorepo", "add runtime env injection to a Vite SPA", "deploy over SSH with
health checks"), it points to the specific template path and says to copy
it into the target project and adapt the marked variables. This lets an AI
assistant working in an unrelated project directory pull in a template on
request without re-deriving the pattern from memory.

## Roadmap (not implemented now)

`roadmap.md` documents planned future additions so intent isn't lost:
- PHP/Laravel: Dockerfile (php-fpm + nginx), Laravel-specific env handling,
  GitHub Actions (composer install, artisan test, opcache).
- Python: Dockerfile (Django/FastAPI), Alembic/Django migrations as a
  compose profile analogous to `migrate`, GitHub Actions (pytest, ruff).
- Kubernetes/Helm/GitOps: an alternative deploy target to
  SSH-compose-deploy, modeled on a work GitOps repository (Helm charts, ArgoCD,
  Vault secret injection) — only if a project outgrows single-host
  SSH+compose deploys.

## Out of scope entirely

- Architecture-doc templates (`docs/architecture.md` style) — noted as a
  good idea in the survey but not part of this spec; can be a separate
  follow-up template addition later.
- Any client-identifying content (real service names, credentials,
  internal hostnames) — all templates are scrubbed to generic placeholders.
  Note: a client repo (`.env.example`) was observed to
  contain what look like real (non-placeholder) credentials; this template
  repo will not reproduce those values, and the user should independently
  verify/rotate that source file's credentials since it's outside this
  repo's control.
