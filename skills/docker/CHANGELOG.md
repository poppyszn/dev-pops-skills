# Changelog

## 1.4.0 - 2026-11-03

- The "file gaps" step now says to leave out the client, project and repository names and describe the project's shape instead (standard §12 in skill-authoring).

## 1.3.0 - 2026-11-01

- **New: production stack** for a single Docker host behind nginx: `assets/node-api/compose.production.yml` (api, one-shot migrate, opt-in seed; ports on `127.0.0.1`; images run by `${IMAGE_TAG:-latest-production}`), `preflight.sh` (a blocking, testable check of the host `.env`) and `env.production.example`, documented in `references/node-api.md` with a paste-in `ssr` service for a server-rendered app. Built from a hand-made production setup after a review.
- New default: containers behind a reverse proxy on the host publish on `127.0.0.1`; production runs the commit SHA, not a moving tag. `references/compose.md` has the reasons.
- Tested: `preflight.sh` against fixture `.env` files (valid, each failure mode, exact-line matching, regex characters as literals, no secret value in a failure's output), and the compose file's rendered ports, image tags and seed profile.

## 1.2.3 - 2026-09-27

- Fixed: the same `localhost` healthcheck bug as 1.2.2, in the compose templates the Dockerfile fix left behind — `assets/node-api/compose.yml` and `assets/node-api/compose.deploy.yml` both healthchecked the api service against `localhost`. Now `127.0.0.1`, with the reason inline so a copy carries it.
- `references/compose.md` now states that the rule applies to a compose `healthcheck:` as well as a Dockerfile `HEALTHCHECK` (same container, same resolver), keeps the bug's story, and calls out the one case where `localhost` is correct: a host-side browser URL such as `NEXT_PUBLIC_API_URL`.

## 1.2.2 - 2026-09-27

- Fixed: `assets/node-api/Dockerfile`'s `HEALTHCHECK` targeted `localhost`, which this skill's own default forbids and its own bad example names. The two frontend templates were already fixed; node-api was missed. Now `127.0.0.1`, with the reason inline.
- `references/node-api.md` records the failure next to the rule, so it isn't dropped as style.

## 1.2.1 - 2026-09-26

- Updated the path to the completed Nitro finding (`contributions/completed/`).

## 1.2.0 - 2026-09-26

- New rule: existing working Docker files are merged, never overwritten with a template (from `contributions/security-template-codeql-job-paid-feature`, where a verbatim copy regressed an adapted file).

## 1.1.0 - 2026-09-26

- Local S3 is now Adobe S3Mock (dev and tests only, opt-in), with a new `references/object-storage.md`: service blocks, AWS SDK v3 wiring, limitations, and a MinIO swap guide. The service block was tested live (healthy, path-style PUT/GET, survives restart).
- MinIO (archived) is never introduced. Existing usage is reported as drift, and the swap requires confirmation.

## 1.0.0 - 2026-09-26

- Migrated from the templates repo: node-api, frontend-spa-nginx and frontend-nextjs templates, Makefile, dockerignore, env-replacement pattern, and the Dockerfile/compose standards (now `references/compose.md`).
- Applied open findings:
  - `compose.testing.yml` (test-only infra)
  - NestJS webpack-mode migration variant
  - SQLite variant
  - Nitro SSR reference (bind variables verified against Nitro docs)
  - `environment:` allowlist and `${VAR:?}` rules for compose
  - env-replacement applicability note
- Verified all image pins. Recorded that `redis:7-alpine` resolves to 7.4 (RSALv2/SSPL, not OSI open source) and that Node 26 becomes LTS on 2026-10-28.
