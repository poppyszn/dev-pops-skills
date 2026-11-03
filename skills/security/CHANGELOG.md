# Changelog

## 2.2.0 - 2026-11-03

- The "file gaps" step now says to leave out the client, project and repository names and describe the project's shape instead (standard §12 in skill-authoring).

## 2.1.0 - 2026-11-01

- New defaults, from reviewing a hand-made production deployment: cloud credentials via OIDC federation with the trust policy pinned to one GitHub Environment (no stored keys, no `repo:<org>/<repo>:*`), and pinned SSH host keys with the deploy key's private half only in the environment secret. The cicd production templates and the terraform deploy-role modules implement both.

## 2.0.1 - 2026-09-27

- Fixed: the Defaults list stated its triggers twice and contradicted itself — one bullet said `pull_request` to the integration branch, the next said "PR and push to main". The second was prose left over from 1.0.0 that the 2.0.0 trigger change didn't delete. Both shipped workflows and `references/security-workflow.md` say pull requests only, so the stale bullet is gone and its rationale merged into the surviving one.

## 2.0.0 - 2026-09-26

- **Changed default:** CodeQL moved out of `security.yml` into an opt-in `security-codeql.yml` (paid on private repos without GitHub Code Security).
- **Changed default:** triggers are `pull_request` to `<INTEGRATION_BRANCH>` plus weekly schedule and manual dispatch, with no push to `main`.
- Added a pnpm `dependency-audit` variant. New rule: existing security workflows are merged, never overwritten (a verbatim copy regressed an adapted pnpm/Nx file).
- Applied `contributions/security-template-codeql-job-paid-feature`.

## 1.0.0 - 2026-09-26

- Migrated `security.yml` and its reference from the templates repo.
- Fixed:
  - gitleaks image pinned to `v8.30.1` (was `:latest`)
  - CodeQL job now has `contents: read` (required on private repos)
  - top-level `permissions: contents: read`
  - the multi-Dockerfile matrix example had stale pins and no `runs-on`
- Corrected facts:
  - `gitleaks-action`'s license key is free, not paid
  - CodeQL on private repos needs GitHub Code Security (GHAS was split)
