# CI/CD rules, with the bugs behind them

The short rules are in SKILL.md under Defaults. This file holds the reasoning and the real incidents, so a rule isn't dropped as "style". Entries marked **Shipped once** caused a real bug in a template before being fixed.

## Never interpolate `${{ }}` inside a `run:` script

**Shipped once:** `ssh-compose-deploy`'s three `run:` steps spliced `${{ inputs.ssh-host }}` and friends straight into the script. The expression is substituted *before* bash runs, so shell metacharacters in the value become executable code. This is GitHub's documented script-injection pattern. Fixed by routing every input through `env:` and using `"$VAR"` in the script.

## Quote values sent to a remote shell with `printf '%q'`

**Shipped once:** `ssh-compose-deploy` hand-wrapped values as `VAR='$VAR'`. A value containing `'` breaks out of that quoting and injects syntax into the remote command. Quote **every** value sent this way with `printf '%q'`, including ones you don't expect to contain special characters. An env var's contents can change without the workflow changing.

## `docker compose run` in an SSH heredoc eats the rest of the script

**Shipped once** (in `deploy-develop-build-on-server.yml`): `docker compose run` attaches stdin by default. When the whole remote script arrives on stdin (`ssh … 'bash -s' << 'EOF'`), the container reads the rest of the heredoc, and bash sees a normal end of input. Every line after `run` silently never executes, and the step passes.

Repro without SSH:
```bash
bash -s << 'EOF'
echo before
docker run --rm -i alpine sh -c 'cat >/dev/null'
echo after      # never printed
EOF
```
Fix: add `< /dev/null` to every `docker run` / `docker compose run` in such a heredoc.

## Don't log out of the registry until nothing else needs it

In a deploy split across several SSH sessions, a `docker logout` at the end of step A breaks step B's `docker compose pull` with `unauthorized`. Credentials otherwise persist in `~/.docker/config.json`. Log out in a final cleanup step marked `if: always()`, so it still runs after a failure.

## Unset secrets become empty strings, not missing values

`ssh-port: ${{ secrets.SSH_PORT }}` with the secret unset passes `''`, which overrides the action's default and fails with `Bad port ''`. Write `${{ secrets.SSH_PORT || '22' }}`. The action also falls back to 22 internally as defense in depth.

## Concurrency: cancel CI, never cancel deploys

`cancel-in-progress: true` is right for CI (a new push supersedes the old run). For deploys it's `false`: cancelling mid-deploy leaves the host half-updated.

## Permissions: least privilege, and how scoping really works

- Set `permissions:` at the top of every workflow (`contents: read` minimum). Otherwise the job gets the repository's default token, which may be broad.
- A **job-level** `permissions:` block *replaces* the top-level one; it doesn't add to it. Any permission not listed becomes `none`. The CodeQL job in `security.yml` had only `security-events: write`, so `actions/checkout` had no `contents: read` and would fail on private repos. Fixed 2026-09-26.
- A **reusable workflow** (`workflow_call`) can't receive more than its caller's job grants. A caller job using `docker-build-push.yml` must grant `packages: write` itself.
- `nrwl/nx-set-shas` needs `actions: read` (it looks up past successful runs via the API).

## Don't trust a CLI's output shape across versions

**Shipped once:** a `jq` filter over `docker compose ps --format json` handled only one shape. Compose emitted JSON Lines in some versions and a single JSON array in others. Handle both, or state the assumed version in the reference.

## Wrapped tools can carry their own licensing

`gitleaks-action` needs a license key (free, registration required) for organization repos, although `gitleaks` itself needs none. The security workflow runs gitleaks' own image instead. Check the *action's* terms, not only the tool's. See the security skill.

## Composite actions must be vendored

`uses: ./.github/actions/<name>` only resolves if the file is physically in the repo that runs the workflow. Copying the asset into `.github/actions/` is mandatory, not optional duplication. Re-copy from the asset when it changes, and never hand-edit the vendored copy.

## CI on pull requests, a light gate on deploys

Decided 2026-09-26, from a client monorepo (see `contributions/completed/`):

- **CI triggers on `pull_request` to the integration branch plus `workflow_dispatch`, not on push.** A hardcoded `push: branches: [main]` silently does nothing in a repo that integrates on `develop`. PR-only runs avoid running CI twice per merged PR. Enforcement comes from **required status checks** in branch protection, not from re-running CI later.
- **`nrwl/nx-set-shas` defaults `main-branch-name` to `main`.** In a `develop`-based repo, affected is computed against the wrong base unless it's set.
- **Deploys never call CI** (`uses: ./.github/workflows/ci.yml`). That re-runs the full suite on every deploy for a commit its PR already tested. **But a deploy with no check at all** lets a broken push reach the server. The answer is a light `verify` job that the build or deploy `needs`:
  - npm workspaces: `npm ci`, `npm run lint --workspaces --if-present`, `npm run typecheck --workspaces --if-present` (a workspace without the script is skipped; a failing script fails the job; checked with npm 11)
  - single package: the same without `--workspaces`
  - Nx: `nrwl/nx-set-shas` (with `main-branch-name`), then `npx nx affected -t lint,typecheck` (module boundaries are enforced by the lint target's `@nx/enforce-module-boundaries` rule). Use `npx nx run-many -t lint,typecheck` for a deploy-everything run.
  - Check out the same commit that gets built (`commit_sha` input when the workflow offers one).

## Production deploys

Decided 2026-11-01 while reviewing a hand-built production pipeline (see `deploy-production.md`):

- **`git clone` refuses a directory that already has files.** A host `.env` created before the first deploy makes the clone fail with "destination path already exists and is not an empty directory" (tested). The production sync uses `git init` + `git fetch --depth 1 origin <sha>` + `git reset --hard FETCH_HEAD`, which works either way. `git-sync-deploy` still clones, and also copies `.env.example` to `.env` when none exists: fine for a develop box, wrong for production, where placeholder secrets must never boot. Filed as a finding.
- **`git clean -fd` deletes the host's untracked `.env` unless it is gitignored.** The sync step checks `git check-ignore docker/production/.env` and stops before cleaning if the file is not ignored.
- **Don't put the token in `.git/config`.** `git remote set-url` with the token embedded, reset at the end, leaves it behind whenever a command in between fails. Pass it per command with `-c http.extraheader="AUTHORIZATION: basic ..."`.
- **A step that logs out of the registry must not depend on later commands succeeding.** With `set -e`, a failing `docker image prune` ahead of `docker logout` skipped the logout and left the credentials on the host. Log out first in the cleanup step (it is the last step that needs them) or from an `EXIT` trap.
- **A mutable `latest-<env>` tag makes rollback a rebuild.** Images were already tagged with the commit SHA but compose ran the moving tag. Run the SHA (`IMAGE_TAG`), keep `latest-<env>` as a pointer for people, and a rollback is a redeploy of an older SHA.
- **A skipped upstream job skips everything that `needs` it.** A rollback skips the build, so the deploy job needs `if: ${{ !cancelled() && ... contains(fromJson('["success","skipped"]'), needs.build-and-push.result) }}`, not the default behaviour.
- **A reusable workflow builds the commit that triggered the run, whatever the caller asked for.** `docker-build-push.yml` takes an optional `ref` input now; a caller that deploys a chosen commit must pass it, or the image is built from, and tagged with, the wrong commit.
- **A job that assumes an AWS role needs `id-token: write`, and a job-level `permissions:` block replaces the top-level one.** List `contents: read` beside it.
- **A distribution-wide 403/404-to-`index.html` rule hides real errors.** The web smoke test requests a file that cannot exist under `/assets/` and expects 404 for that reason. The Terraform static-site template uses a routing function instead.
