# security.yml template ships a CodeQL job that is paid on private repos

> **Status: merged 2026-09-26** (security 2.0.0; docker 1.2.0, cicd 2.0.0 and project-infra 2.0.0 for the related rule).
> - Applied: CodeQL moved to the opt-in `skills/security/assets/workflows/security-codeql.yml`. Added a pnpm `dependency-audit` variant (`pnpm/action-setup@v6` verified) to `references/security-workflow.md`. The per-app image-scan matrix variant already existed there.
> - New rule in docker, cicd, security and project-infra: existing working files are merged, never overwritten with a template.

**Where found:** a client repo (private org repo), `.github/workflows/security.yml`
copied from `skills/security/assets/workflows/security.yml`.

**Status:** confirmed gap in this repo's own template. The `codeql` job is
included by default; its own comment admits private repos need the paid GitHub
Code Security add-on. A default that fails or bills on private repos is the
wrong default.

**Repro:** `grep -n codeql skills/security/assets/workflows/security.yml`, then
copy verbatim into a private repo without Code Security: the job cannot succeed.

**Suggested fix:** drop `codeql` from the default template (or ship it as a
separate opt-in asset, e.g. `security-codeql.yml`) and state in SKILL.md that it
is opt-in, public-repo or Code-Security-licensed only.

**Related, same session:** the template's `dependency-audit` uses `npm ci` /
`npm audit` and `image-scan` builds a root `Dockerfile`. Neither works for a
pnpm/Nx monorepo with `apps/<name>/Dockerfile`; a verbatim copy silently
regressed a working adapted file. Add a pnpm and a per-app-matrix variant, and
warn that "vendored verbatim" does not hold for non-npm repos.
