# git-sync-deploy composite action

The no-registry counterpart to `ssh-compose-deploy`: instead of pulling
a prebuilt image from a registry, this syncs the repo's source onto the
remote host (clone on first run, fetch + hard-reset after) so
`docker compose build` can build the image **on the host it runs on**.
Use this when you don't have (or don't want) a container registry —
e.g. a private, non-org repo where standing up GHCR access feels like
overkill for a single develop-branch preview environment.

See the repo's `docs/history/2026-08-13-build-on-server-deploy-design.md`
for the full design rationale, and
`../../deploy-develop-build-on-server.yml` for the workflow that calls
this action.

## How to use it

Vendor this directory into your project (e.g.
`.github/actions/git-sync-deploy/`), then call it from a deploy
workflow before building/starting the stack:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: develop
    concurrency:
      group: deploy-${{ github.ref }}
      cancel-in-progress: false
    steps:
      # Required even if this job doesn't otherwise need the repo's
      # source — `uses: ./.github/actions/...` resolves a local action
      # from the runner's own checked-out workspace, and every job
      # starts on a fresh, empty runner. Without this, the local action
      # can't be found at all ("Can't find 'action.yml'... Did you
      # forget to run actions/checkout").
      - uses: actions/checkout@v4

      - uses: ./.github/actions/git-sync-deploy
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
          ssh-known-hosts: ${{ secrets.SSH_KNOWN_HOSTS }}
          ssh-host: ${{ secrets.SSH_HOST }}
          # || '22', not a bare secret reference: an unset SSH_PORT
          # secret evaluates to an empty string, which overrides this
          # action's own `default: '22'` (defaults only apply when an
          # input is omitted entirely, not when it's passed as "").
          ssh-port: ${{ secrets.SSH_PORT || '22' }}
          ssh-user: ${{ secrets.SSH_USER }}
          working-dir: ${{ secrets.WORKING_DIR }}
          repo: ${{ github.repository }}
          branch: ${{ github.ref_name }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
      # ... build/start steps follow, see deploy-develop-build-on-server.yml
```

## Required secrets, in one place

Configure these on a GitHub Environment named `develop` (Settings →
Environments) rather than repo-wide secrets — that gives you the option
to add required reviewers later without changing any workflow code:

| Secret | Purpose |
|---|---|
| `SSH_PRIVATE_KEY` | Key this action authenticates with |
| `SSH_KNOWN_HOSTS` | Pinned host keys: the output of `ssh-keyscan -p <port> <host>` (add the jump host's line if one is used). Required; checking is strict |
| `SSH_HOST` | Target host (or the final hop if using a jump host) |
| `SSH_PORT` | Defaults to `22` if unset — but only if the *input* is omitted. Write `ssh-port: ${{ secrets.SSH_PORT || '22' }}` at the call site, not a bare `${{ secrets.SSH_PORT }}`; an unset secret is an empty string, not "undefined", and an explicitly-empty input overrides the action's default. Confirmed with a live failure: `ssh -p ''` → `"Bad port ''"`. |
| `SSH_USER` | Remote user |
| `SSH_JUMP_HOST` / `SSH_USER_JUMP` | Optional — only needed behind a bastion/ProxyJump |
| `WORKING_DIR` | Absolute path on the host the repo gets cloned into (this action appends the repo name itself — pass the parent dir, e.g. `/srv/deploys`, not `/srv/deploys/my-repo`) |

`github-token` is **not** a secret to configure — pass through the
workflow's own automatic `secrets.GITHUB_TOKEN`. It's valid only for the
lifetime of the job, which is exactly long enough to clone/fetch a
private repo over HTTPS; this action resets the remote's URL to a
token-free form immediately after use so nothing sensitive is left in
`.git/config` on the host between deploys.

If an agent or teammate is setting this up and doesn't have these
values, the answer is "ask a human to add them under this repo's
`develop` GitHub Environment" — never ask for the raw host/key/path in
chat, and never hardcode them into the workflow file.

## Why this exists alongside `ssh-compose-deploy`

`ssh-compose-deploy` assumes `docker compose pull` against a registry
(it does a `docker login ghcr.io`). That's the right choice once you
have a registry in the loop — the image is built once in CI and the
exact same artifact is what gets deployed. This action is for the case
where that tradeoff isn't worth it yet: building on the host is slower
per-deploy and ties up the host's CPU during the build, but it's zero
registry setup and works identically for any private repo without
needing GHCR (or another registry) configured at all.

## Same security conventions as `ssh-compose-deploy`

- Inputs are read from `env:` blocks in every `run:` step, never
  interpolated directly as `${{ }}` into script bodies — see that
  action's README for the script-injection rationale.
- Every value crossing into the remote shell is `printf '%q'`-escaped
  before being spliced into the SSH command, not manually
  single-quote-wrapped.
- Host keys are pinned (`StrictHostKeyChecking yes` with `ssh-known-hosts`), as described in `ssh-compose-deploy.md`.
