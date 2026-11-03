# `ci-cd/github-actions/node/ci-simple.yml` has no guidance for multiple independent (non-workspace) apps in one repo

> **Status: merged 2026-09-26** during the migration into dev-pops-skills.
> - Applied as a new template: `skills/cicd/assets/workflows/ci-multi-app.yml` + `references/ci-multi-app.md` (per-app jobs, `working-directory`, per-app `cache-dependency-path`, drop `npm test` when no script exists).
>
> Paths in the original write-up below refer to the old templates repo.

**Where found:** `test-app` (personal/test-app) — a `backend/` (NestJS)
and `frontend/` (Next.js) as two sibling directories, each with its own
`package.json`/`package-lock.json`, deliberately **not** npm workspaces
(they're independent projects, not a monorepo needing shared
dependency resolution). Confirmed against this repo's current
`ci-simple.yml` and its README today.

**The gap:** `ci-simple.README.md` says "for a single-package Node/TypeScript
repo (not a monorepo)" and the workflow assumes one root `package.json`
(`npm ci` / `npm run lint` / `npm test` / `npm run build` with no
`working-directory`). This repo's templates cover the single-package
case (`ci-simple.yml`) and the npm-workspaces monorepo case (`ci.yml`,
Nx affected-only) but nothing in between: **multiple independent
sibling apps, each its own package, no workspaces file tying them
together.** That shape is common for a small project that intentionally
keeps two apps decoupled (no shared `node_modules`/lockfile) without
needing full Nx/workspaces tooling.

**What I did instead (in test-app only, not the template):** duplicated
the `ci-simple.yml` job once per app, each with
`defaults.run.working-directory: <app>` and its own
`cache-dependency-path` for `actions/setup-node`'s npm cache key. Also
dropped `npm test` from the frontend job — this project has no
automated tests by design (a `create-next-app` scaffold doesn't add a
`test` script by default, and running `npm test` errors when the script
doesn't exist).

**Suggested fix for this repo:** consider a
`ci-cd/github-actions/node/ci-multi-app.yml` (or a documented pattern in
`ci-simple.README.md`) for N independent sibling apps: one job per app
via `defaults.run.working-directory` + per-app
`cache-dependency-path`, and a note that a job should drop the `npm
test` step (rather than fail) when an app genuinely has no test script.
Not urgent — duplicating the job per app is a small, mechanical
adaptation — but worth documenting so it's copy-pasted consistently
instead of reinvented slightly differently each time.
