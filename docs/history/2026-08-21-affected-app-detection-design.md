# Affected-App Detection for Multi-App CI/CD (non-Nx) Design

Date: 2026-08-21

## Problem

In a monorepo/multi-app repo, CI and deploy should scope to whichever
app(s) actually changed — an API-only change shouldn't lint/test/build
the frontend, and shouldn't redeploy it either. This repo already has
that behavior for Nx projects (`ci-cd/github-actions/node/ci.yml` uses
`nx affected`), but nothing standard for the common non-Nx case:
multiple independent sibling apps (each its own `package.json`, not npm
workspaces or a monorepo tool) — exactly the shape
`contributions/ci-simple-multi-app-non-workspace-gap.md` already
surfaced from real use, and exactly what `examples/monorepo-layout/`
already is (3 independent-in-spirit apps: `api`, `web`, `admin`).

## Goal

A reusable, standard mechanism for detecting which app(s) changed —
usable by both CI and deploy templates — without requiring Nx or any
other monorepo tool, and without introducing a third-party dependency
for something this simple to own directly.

## Approach: one composite action, two consumers

A `detect-changed-apps` composite action computes the affected-apps
list once, in one place; a CI template and a deploy template both
consume its output. This matches the existing pattern in this repo
(`ssh-compose-deploy`, `git-sync-deploy` — logic duplicated across
projects became one composite action) rather than reinventing
diff-detection per template.

**Rejected: `dorny/paths-filter` or similar third-party action.** The
underlying operation (diff file paths, match against prefixes) is
~20 lines of bash — not enough complexity to justify an external
dependency, consistent with this repo's existing taste (`security.yml`
already runs gitleaks' own image instead of a wrapper action for the
same reason). Worth noting explicitly: `tj-actions/changed-files`, a
competitor in this space, had a real supply-chain compromise in 2025 —
exactly the class of risk `CLAUDE.md`'s "Security-related additions"
standard exists to catch before adopting a new Action dependency.

## Component 1: `detect-changed-apps` composite action

**Location:** `ci-cd/github-actions/actions/detect-changed-apps/`

**Inputs:**
- `apps` (required) — comma-separated `name:path` pairs, e.g.
  `api:apps/api,web:apps/web,admin:apps/admin`.
- `shared-paths` (optional, default `""`) — comma-separated path
  prefixes; if any changed file matches one, every app in `apps` is
  marked affected. Matches a client repo's real, proven pattern (a shared
  `libs/` or root-config change affects everything downstream, found
  during the earlier repo audit) rather than inventing a new
  convention.

**Output:**
- `apps` — a JSON array of `{"name": "...", "path": "..."}` objects for
  every affected app, directly consumable by
  `fromJson(steps.<id>.outputs.apps)` in a `strategy.matrix`. An object
  per app (not a bare name string) because a matrix job needs both the
  name (for tags, display, image names) and the path (for
  `working-directory`, `dockerfile:`) — and app name doesn't always
  equal its directory (e.g. `test-app`'s `backend`/`frontend` do
  happen to match, but a future project's `apps/api` app named `api`
  has `name != path` in general... actually here name IS the last path
  segment in most cases; object form is still safer/more explicit than
  assuming that always holds).

**Diff-range logic, by trigger:**
- `pull_request` — compare `${{ github.event.pull_request.base.sha }}`
  to `${{ github.sha }}`.
- `push` — compare `${{ github.event.before }}` to `${{ github.sha }}`,
  **except** when `github.event.before` is the null SHA
  (`0000000000000000000000000000000000000000`, meaning this is the
  first push to a new branch and there's no meaningful prior commit to
  diff against) — treat as "everything affected."
- `workflow_dispatch` (or any other trigger without a natural diff
  range) — "everything affected." Safe default: never silently
  under-build. A caller wanting finer manual control adds its own input
  on top of this action, that's not this action's job.

**Requires the caller's checkout step to use `fetch-depth: 0`** — a
shallow checkout doesn't have the commits needed to diff against. This
is a documented requirement in the action's README, not something the
action can fix itself (it runs after checkout).

**Algorithm (the action's own step):**
1. Determine `base` and `head` refs per the trigger logic above (or set
   a `use-everything=true` flag when there's no valid range).
2. If using everything: output every app in `apps` as affected, skip to
   step 5.
3. `git diff --name-only "$base" "$head"` → list of changed file paths.
4. For each app in `apps`, check if any changed path starts with that
   app's `path` prefix → affected. If `shared-paths` is set and any
   changed path starts with one of those prefixes, mark every app
   affected regardless of individual matches.
5. Emit the `apps` output as a JSON array of the affected `{name,
   path}` objects (empty array `[]` if none — callers gate on this to
   skip downstream jobs entirely).

## Component 2: `ci-cd/github-actions/node/ci-multi-app.yml`

New CI template for the non-Nx multi-app case — resolves
`contributions/ci-simple-multi-app-non-workspace-gap.md` directly
rather than the ad hoc per-project workaround that finding describes.

- `detect` job: checkout with `fetch-depth: 0`, run
  `detect-changed-apps`, output the affected-apps JSON.
- `lint-test-build` job: `strategy.matrix.app:
  ${{ fromJson(needs.detect.outputs.apps) }}`, gated on
  `needs.detect.outputs.apps != '[]'`. Each matrix entry: `setup-node`
  with `cache-dependency-path: ${{ matrix.app.path }}/package-lock.json`,
  then `npm ci`, `npm run lint --if-present`,
  `npm test --if-present`, `npm run build --if-present`, all with
  `working-directory: ${{ matrix.app.path }}`. `--if-present` handles
  an app with no test script (or no lint script) by skipping it
  cleanly instead of failing — a general fix, not the contribution's
  per-project "just drop the npm test line" workaround.

## Component 3: `ssh-compose-deploy` extension

**Modify:** `ci-cd/github-actions/actions/ssh-compose-deploy/action.yml`

New optional input `services` (default `""`, space-separated service
names). When set, the remote `up` command becomes:
```bash
docker compose $profile_args up -d --wait --wait-timeout "$WAIT_TIMEOUT" --no-deps $SERVICES
```
instead of the current `up -d --wait --wait-timeout "$WAIT_TIMEOUT"`
(which brings up every default-profile service). Matches a client repo's real
`up -d --wait --wait-timeout 120 --no-deps $DEPLOY_APPS` pattern found
during the earlier audit, exactly. Empty/omitted `services` preserves
today's behavior (start everything) — existing callers are unaffected.

The unhealthy-container health check after `up` still checks *every*
currently-running container, not just the ones in `services` — starting
only the affected services with `--no-deps` doesn't stop already-running
unaffected ones, and catching any collateral breakage among them is a
conservative, correct default, not scope creep.

## Component 4: `ci-cd/github-actions/deploy-develop-multi-app.yml`

New deploy template, promoting what's currently hand-rolled inline in
`examples/monorepo-layout/.github/workflows/deploy-develop.yml` into a
real, documented, reusable library template — the example currently has
no single template it was copied from for this file, which is itself a
gap relative to how every other file in that example traces back to
`ci-cd/github-actions/`.

- `detect` job: `detect-changed-apps`, same as the CI template.
- `build-and-push` job: matrix over `fromJson(needs.detect.outputs.apps)`,
  calls `docker-build-push.yml` once per affected app (same shape
  `examples/monorepo-layout/deploy-develop.yml` already uses).
- `deploy` job: `git-sync-deploy` (to keep `docker/develop/compose.yml`
  current on the host, per the existing merged finding on why this step
  is needed even in the pull-based flow), then `ssh-compose-deploy` with
  `services` set to the space-joined affected-apps list
  (`${{ join(fromJson(needs.detect.outputs.apps).*.name, ' ') }}` —
  extracting just the `name` field from each affected-app object,
  space-joined for the `services` input).

`examples/monorepo-layout/.github/workflows/deploy-develop.yml` is
updated to be a straightforward copy of this new template (matching how
every other workflow in that example already traces to a library file),
not a hand-rolled equivalent.

## Testing / validation approach

Same syntax-validation baseline as every other template in this repo
(`bash -n`, YAML parse via PyYAML) plus a live dry run of the diff-range
logic, mirroring how `version-freshness-audit.yml`'s detection logic
was tested against real data before being written into its plan:

- Simulate each trigger case (`push` with a real prior SHA, `push` with
  the null-SHA first-push case, `pull_request`, `workflow_dispatch`)
  against a scratch git repo with a few commits touching different app
  directories, and confirm the output JSON matches what actually
  changed in each case.
- Confirm a `shared-paths` match correctly marks every app affected.
- Confirm the empty-diff case (no app directories touched, e.g. a
  docs-only commit) outputs `[]`.
- Extract and `bash -n` every embedded script, same as
  `version-freshness-audit.yml`'s plan did.
- Dry-run `ssh-compose-deploy`'s modified `up` command construction
  locally (build the string, confirm `--no-deps $SERVICES` appears only
  when `services` is set) — can't test an actual remote deploy without
  a real host, same limitation as the existing action.

## Resolves / relates to existing contributions

- `contributions/ci-simple-multi-app-non-workspace-gap.md` — resolved
  directly by Component 2. Mark `.merged.md` once implemented.
- `contributions/node-api-sqlite-no-migrations-gap.md` — unrelated to
  this spec, stays queued separately.

## Out of scope

- Extending `docker-build-push.yml` itself — it already accepts `app`/
  `dockerfile` as per-call inputs; the matrix-over-affected-apps logic
  lives in the *caller* (Component 4), not in that reusable workflow.
- A generic N-input "shared paths" resolver beyond simple prefix
  matching (e.g. glob patterns, `.gitignore`-style syntax) — prefix
  matching covers every real case seen so far (`libs/`, root config
  files); revisit only if a real project needs more.
- Applying this to `deploy-develop-build-on-server.yml` (the no-registry
  build-on-server flow) — that flow already builds/starts the whole
  stack in one pass per its own README's documented limitation
  ("doesn't currently support building only a changed subset"); extending
  it is a separate, later piece of work if actually needed, not bundled
  into this spec.
