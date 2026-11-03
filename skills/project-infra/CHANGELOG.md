# Changelog

## 3.1.1 - 2026-11-03

- The example's `apps/api` and `apps/admin` `HEALTHCHECK` lines carry the same `# hadolint ignore=DL3025` and reason as the docker templates they were adapted from.

## 3.1.0 - 2026-11-03

- The "file gaps" step now says to leave out the client, project and repository names and describe the project's shape instead (standard §12 in skill-authoring).

## 3.0.0 - 2026-11-03

- **Breaking: the example's develop deploy pins host keys**, following cicd 3.0.0. The vendored `git-sync-deploy` and `ssh-compose-deploy` actions are re-copied, and the example's `deploy-develop.yml` and `run-seed-develop.yml` pass or read the new `SSH_KNOWN_HOSTS` secret. A project scaffolded from 2.x needs that secret on its `develop` environment (the output of `ssh-keyscan -p <port> <host>`).
- Checked: the validator confirms every vendored copy matches its source, and `actionlint` is clean on the example's workflows.

## 2.2.0 - 2026-11-01

- New "Production on AWS" section: maps a production request onto the docker, cicd, terraform and security pieces and lists what only the user can do (GitHub Environment and branch protection, applying the AWS side, certificate and DNS, the deploy key pair, certbot, the host `.env`).
- The example's vendored `docker-build-push.yml` is re-copied from cicd 2.1.0 (new optional `ref` input) and its develop deploy now passes `commit_sha` to the build, which fixes a manual deploy of a chosen commit building the wrong one.

## 2.1.0 - 2026-09-27

- New guidance: the git conventions now travel with the scaffold — branches `<type>/<slug>`, Conventional Commits, one logical change per commit, and never pushing to or merging into the integration branch. Previously only `AGENTS.md` carried these, so a project set up from this skill inherited nothing.
- New asset `assets/monorepo-layout/.github/PULL_REQUEST_TEMPLATE.md`, copied verbatim into every project. Since CI triggers on `pull_request` only, the PR is the gate, and the template is the only place that asks whether the stack was actually brought up — which CI never does. Deliberately not a vendored copy of this repo's own PR template; the two ask different questions.
- The greenfield manifest's "needs the user" now also names *requiring* pull requests in branch protection, not just required status checks.

## 2.0.3 - 2026-09-27

- Fixed: the example's root `compose.yml` and `docker/develop/compose.yml` both healthchecked the api service against `localhost`, inherited from the docker skill's compose templates (docker 1.2.3). Re-copied the fix.

## 2.0.2 - 2026-09-27

- Fixed: the example's `apps/api/Dockerfile` inherited the `localhost` `HEALTHCHECK` bug from the docker skill's `node-api` template (docker 1.2.2). Re-copied the fix; `apps/web` and `apps/admin` already had it.

## 2.0.1 - 2026-09-26

- The example's `run-seed-develop.yml` comment now points to the cicd skill's `references/gotchas.md`.

## 2.0.0 - 2026-09-26

- **Changed defaults**, following cicd 2.0.0 and security 2.0.0 in the example project: `ci.yml` runs on PRs to `develop` plus manual; `deploy-develop.yml` gains a `verify` gate before `build-and-push`; `security.yml` has no CodeQL and is now adapted (branch filled in), not vendored.
- Manifest now lists branch protection (required checks) and the CodeQL opt-in decision under "needs the user".
- New rule: existing working files are merged, never overwritten.

## 1.0.0 - 2026-09-26

- Migrated from the templates repo's apply-infra-template skill and examples/monorepo-layout: greenfield and audit modes, copy-never-retype rule, wiring answer key.
- Example: added least-privilege `permissions:` to every workflow (the build job grants `packages: write` to the reusable workflow), re-vendored `docker-build-push.yml` (it had dropped its `name:`), pinned gitleaks, fixed CodeQL permissions.
