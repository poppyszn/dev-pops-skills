# Security scanning template

`security.yml` has three independent jobs, each useful on its own.
Remove any you don't need rather than treating this as all-or-nothing.
CodeQL is a separate, opt-in `security-codeql.yml` (see below).

**Existing security workflow in the project? Merge, don't overwrite.**
The template assumes npm and one root `Dockerfile`. A project already
adapted for pnpm, Nx or per-app Dockerfiles is not "drift": copying the
template over it regresses a working file (this happened in
a real Nx monorepo). Diff it and bring over only the missing fixes (pins,
permissions, triggers).

## Jobs

- **`secret-scan`** — runs gitleaks' own OSS Docker image directly
  against the full git history (`fetch-depth: 0`), not the maintained
  `gitleaks-action` wrapper. That wrapper needs a license key for repos
  owned by an organization (the key is free but needs registration);
  running the underlying tool directly needs no key for any account
  type. (An earlier version of this template said the key was paid.
  Checked against the action's README on 2026-09-26: it's free.)
- **`dependency-audit`** — `npm audit --audit-level=high`. Fails CI on
  high/critical advisories in your dependency tree. Complements
  Dependabot (which opens PRs) by blocking merges that introduce a new
  vulnerable dependency in the meantime.
- **`image-scan`** — builds the image locally (`push: false, load: true`,
  no registry round-trip needed) and scans it with Trivy for OS-package
  and language-dependency CVEs baked into the image layers, not just
  your `package.json`.

## Opt-in: `security-codeql.yml` (CodeQL)

GitHub's semantic static analysis for JS/TS (real vulnerability
classes: injection, XSS, unsafe deserialization, etc., not just
known-CVE matching). It's a separate asset because it isn't free
everywhere. Add it only after checking the repo's plan:

CodeQL is **free for public repositories**. For a **private** repo it
requires the paid **GitHub Code Security** add-on, billed per active
committer. (GitHub split the old Advanced Security bundle into Code
Security and Secret Protection; see `sources.md` for the current terms.)
If your repo is private and Code Security isn't enabled, don't add
`security-codeql.yml` (or confirm licensing first). Enabling it without the
add-on fails to run (or shows the org admin a billing prompt); it
doesn't silently skip.

## What to change when copying this template

- Set `<INTEGRATION_BRANCH>` to the branch PRs merge into (same as CI).
- **pnpm repos:** replace `dependency-audit`'s npm steps. `pnpm/action-setup`
  reads the pnpm version from `package.json`'s `packageManager` field
  when `version` is omitted:

  ```yaml
  dependency-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - uses: pnpm/action-setup@v6

      - uses: actions/setup-node@v7
        with:
          node-version: 24
          cache: pnpm

      - run: pnpm install --frozen-lockfile

      - run: pnpm audit --audit-level high
  ```

- `image-scan`'s `file: Dockerfile` assumes a Dockerfile at the repo
  root — point it at e.g. `docker/node-api/Dockerfile` if you're using
  one of the docker skill's templates.
- **Monorepo with more than one Dockerfile?** Replace the single
  `image-scan` job with a matrix, one entry per app, each scanning its
  own Dockerfile/image separately — extracted from
  a real 4-app repo:

  ```yaml
  image-scan:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        app: [api, storefront, seller, admin] # one entry per Dockerfile
    steps:
      - uses: actions/checkout@v7

      - uses: docker/setup-buildx-action@v4

      - uses: docker/build-push-action@v7
        with:
          context: .
          file: apps/${{ matrix.app }}/Dockerfile
          push: false
          load: true
          tags: security-scan-${{ matrix.app }}:latest
          cache-from: type=gha,scope=${{ matrix.app }}
          cache-to: type=gha,mode=max,scope=${{ matrix.app }}

      - uses: aquasecurity/trivy-action@v0.36.0
        with:
          image-ref: security-scan-${{ matrix.app }}:latest
          severity: HIGH,CRITICAL
          exit-code: "1"
  ```

  Swap in whichever app names/paths match your repo. Use this instead
  of (not in addition to) the single-image job above.
- `severity: HIGH,CRITICAL` + `exit-code: "1"` fails the build on
  high/critical CVEs. Drop `exit-code` (or set it to `"0"`) if you want
  Trivy to report without blocking CI while you triage a backlog of
  existing findings.
- The weekly `schedule:` trigger catches newly disclosed CVEs in
  already-built images/dependencies that haven't changed recently — keep
  it even if PR/push coverage feels sufficient.

## Triggers: pull requests + weekly cron + manual dispatch

Like CI, the scans run on pull requests to the integration branch, not
on push. Every security workflow also keeps both `schedule:` (a weekly
cron) and `workflow_dispatch:` (manual re-run):

- **Weekly cron** — PR scans only catch what's *newly introduced*.
  A base image or dependency that was clean last week can have a CVE
  disclosed against it today with zero code changes on your side; the
  weekly run is what catches that.
- **`workflow_dispatch`** — lets you re-run scans on demand right after
  a CVE disclosure or a gitleaks/Trivy ruleset update, without waiting
  for the next scheduled run or manufacturing a throwaway commit.
