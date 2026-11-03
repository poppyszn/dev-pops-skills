---
name: security
description: Use when adding or reviewing security scanning in CI (secret scanning with gitleaks, npm dependency audit, container image CVE scanning with Trivy, CodeQL static analysis as an opt-in), triaging scan failures or CVE findings, hardening a Dockerfile or GitHub Actions workflow (least-privilege permissions, pinned versions, script injection, secrets in env files), or handling secrets and credentials in infrastructure config. Not for general Dockerfile or compose authoring (use docker), general pipeline authoring or deploys (use cicd), or shell script correctness (use scripting).
metadata:
  version: "2.2.0"
  last-verified: "2026-09-26"
---

# Security

Add scanning to a project from a proven template, triage what it finds, and harden containers and pipelines.

## When to use

- "Add security scanning", "scan for secrets / CVEs", "set up CodeQL"
- A gitleaks, `npm audit`, Trivy or CodeQL job is failing
- Reviewing a Dockerfile, compose file or workflow for security problems
- Deciding where a secret should live and how it reaches a container or job

Not for: writing Dockerfiles or compose stacks (`docker`), writing CI or deploy pipelines (`cicd`).

## Defaults

Apply these without asking. Deviate only if the project already does it differently (say so) or the user asks.

- **Start from `assets/workflows/security.yml`, copied verbatim** with `cp`. It has three independent jobs (secrets, dependencies, image); remove the ones that don't apply rather than rewriting.
- **Existing security workflows are merged, never overwritten.** The template assumes npm and a root `Dockerfile`. A project adapted for pnpm, Nx or per-app Dockerfiles keeps those adaptations: diff, then bring over only missing fixes.
- **Triggers follow CI:** `pull_request` to `<INTEGRATION_BRANCH>` (not pushes), plus a **weekly `schedule:`** (new CVEs against unchanged code) and **`workflow_dispatch:`** (re-run right after a disclosure). See `references/security-workflow.md`.
- **Prefer a tool's own image over a wrapper action that adds licensing.** gitleaks runs from its own image, because `gitleaks-action` needs a license key (free, registration required) for organization repos.
- **CodeQL is opt-in** (`assets/workflows/security-codeql.yml`). Add it only for public repos, or private ones with the paid GitHub Code Security add-on. Otherwise say it was left out and why.
- **Everything pinned:** actions to a version tag, scanner images to an exact release (`zricethezav/gitleaks:v8.30.1`), never `:latest`.
- **Workflow hardening** (shared with cicd):
  - least-privilege `permissions:` at the top of the file
  - job-level blocks list *every* permission the job needs (they replace the top-level block)
  - no `${{ }}` inside `run:` bodies (use `env:`)
  - values sent over SSH quoted with `printf '%q'`
- **Container hardening** (shared with docker):
  - non-root `USER`
  - no build tools or npm in runtime images
  - pinned base images
  - public-facing services get an `environment:` allowlist, never the full shared `.env`
- **Cloud credentials come from OIDC federation, never stored keys.** The role's trust policy checks the audience and pins the `sub` claim to one GitHub Environment (`repo:<org>/<repo>:environment:<env>`), never a bare `repo:<org>/<repo>:*`, so only that environment's job, behind its required reviewers, can assume it. The permissions are a short, resource-scoped list. The terraform skill's deploy-role modules enforce this.
- **SSH deploys pin the host key** (`SSH_KNOWN_HOSTS`, `StrictHostKeyChecking yes`). The deploy key's private half lives only in the GitHub environment secret, never on the host. The deploy user has no sudo, sshd allows keys only, and no deploy creates the host's `.env` from the example (placeholder secrets must not boot in production).
- **Secrets live in the platform's secret store** (GitHub Environment or repository secrets, the host's `.env` outside git). Never commit them, never put them in chat, and never bake them into images or `ARG`s.
- **Fix findings by upgrading or removing the vulnerable component.** Suppress only with a written reason and the user's agreement.

## Workflow

1. **Inspect.** Check repo visibility (public or private), the Dockerfiles present, the package manager, and any existing security workflows or Dependabot config.
2. **Adding scanning:** `cp` the asset to `.github/workflows/security.yml`, read `references/security-workflow.md`, then:
   - fill `<INTEGRATION_BRANCH>`
   - point `image-scan` at the right Dockerfile(s), using the matrix variant for several apps
   - for pnpm, swap in the pnpm `dependency-audit` variant from the reference
   - add `security-codeql.yml` only if step 1 allows it
   - if a security workflow already exists, merge instead of copying (see Defaults)
3. **Check pins are current.** Confirm each action ref exists and is the current major, and that the gitleaks image tag is the latest release (`gh api repos/gitleaks/gitleaks/releases/latest`). Update `references/sources.md` if they moved.
4. **Triaging a failure:** read the actual finding (CVE id, package, fixed version, path). Then:
   - prefer upgrading the base image or dependency
   - for npm-in-image CVE noise, strip npm from the runtime stage (docker skill)
   - for a leaked secret, treat it as compromised: it must be **rotated**, not just deleted from the file
5. **Reviewing config:** check against the Defaults. List each finding with its risk and a proposed fix before editing.
6. **Verify** (see Verification).
7. **File gaps** in the skills repo's `contributions/` folder (two levels above this skill's real path) when a template is wrong or missing. Leave out the client, project and repository names; describe the project's shape instead ("a single-app NestJS API").

## Requires confirmation

Stop and confirm with the user before any of these:

- Rotating, revoking or deleting any secret, key or token
- Rewriting git history to purge a secret (`git filter-repo`, BFG, force-push)
- Adding suppressions or allowlists (`.gitleaksignore`, `.trivyignore`, lowering `--audit-level` or severity)
- Enabling paid features (Code Security / Secret Protection) or changing org or repo security settings
- Running `npm audit fix --force` or major-version upgrades that change behaviour

## Verification

Run these and report the actual output before calling the work done:

- YAML parses, and `actionlint` passes if installed
- Every `uses:` ref and scanner image tag exists (see step 3)
- Every job with a `permissions:` block lists all it needs (CodeQL: `contents: read` + `security-events: write`)
- Local scan where tools allow it:
  - `docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:v8.30.1 detect --source /repo --redact`
  - `npm audit --audit-level=high`
  - `trivy image <tag>` if installed
- After a fix, re-run the failing scan and show it passing

## Examples

Good: scanner image pinned, least privilege, CodeQL job complete.
```yaml
permissions:
  contents: read
jobs:
  codeql:
    permissions:
      contents: read        # a job-level block replaces the top-level one
      security-events: write
```

Bad (both were in the template until 2026-09-26):
```yaml
docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest ...   # unpinned: can change or break without notice
codeql:
  permissions:
    security-events: write   # no contents: read → checkout fails on private repos
```

Bad: deleting a leaked key from the file and committing. It stays in git history and in every clone. Rotate it first.

## References

Load these only when the task needs them:

- `assets/workflows/security.yml`: the default scanning workflow (gitleaks, npm audit, Trivy)
- `assets/workflows/security-codeql.yml`: opt-in CodeQL (public repos or Code Security licence only)
- `references/security-workflow.md`: per-job notes, the pnpm and multi-Dockerfile variants, CodeQL licensing, trigger rationale
- `references/sources.md`: scanner and action versions and licensing facts, with the date each was checked
