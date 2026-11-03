# ssh-compose-deploy composite action

Extracted from a pattern copy-pasted near-identically across 5+
production workflows. Deploys a docker-compose stack to a remote host
over SSH, waits for containers to become healthy, dumps logs for any
container that isn't, and prunes old images.

## How to use it

Vendor this directory into your project (e.g.
`.github/actions/ssh-compose-deploy/`), then call it from a deploy
workflow:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    concurrency:
      group: deploy-production
      cancel-in-progress: false   # never cancel an in-flight deploy
    steps:
      - uses: ./.github/actions/ssh-compose-deploy
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
          ssh-known-hosts: ${{ secrets.SSH_KNOWN_HOSTS }}
          ssh-jump-host: ${{ secrets.SSH_JUMP_HOST }}
          ssh-jump-user: ${{ secrets.SSH_JUMP_USER }}
          ssh-host: ${{ secrets.SSH_HOST }}
          ssh-user: ${{ secrets.SSH_USER }}
          working-dir: /srv/myapp
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs worth knowing about

- `ssh-jump-host`/`ssh-jump-user`: leave both empty to SSH directly with
  no jump host — the action switches its generated `~/.ssh/config`
  accordingly.
- `compose-profiles`: space-separated, e.g. `"migrate seed"` — appended
  as repeated `--profile` flags to `pull`/`up`.
- `prune-retention`: passed straight to `docker image/builder prune
  --filter until=`, default `168h` (7 days).
- `ssh-port` defaults to `22`, but only if you *omit* the input — if
  your caller passes `ssh-port: ${{ secrets.SSH_PORT }}` and that
  secret doesn't exist, GitHub Actions passes an empty string, which
  overrides the default (`default:` only applies when an input is
  omitted entirely). Confirmed with a live failure: `ssh -p ''` errors
  with `"Bad port ''"`. This action falls back to `22` internally as a
  defense-in-depth measure, but write `ssh-port: ${{ secrets.SSH_PORT
  || '22' }}` at the call site anyway — don't rely on the internal
  fallback alone.

## Why `cancel-in-progress: false` on the calling workflow

Shown in the example above deliberately — CI workflows should cancel
stale runs, but a deploy workflow should NOT be cancelled mid-flight by
a newer push; that's how you get a host left mid-deploy. Set this at the
job/workflow level in whatever workflow calls this action.

## Host keys are pinned

The generated `~/.ssh/config` sets `StrictHostKeyChecking yes` and the action
writes the `ssh-known-hosts` input into `~/.ssh/known_hosts` first, so only the
real host (and the jump host, if there is one) can answer. An empty value fails
the step instead of falling back to trusting whatever responds.

Create the value once, from your own machine, and store it as the
`SSH_KNOWN_HOSTS` secret on the GitHub Environment:

```bash
ssh-keyscan -p 22 <host>            # add the jump host's line too, if one is used
ssh-keygen -lf <(ssh-keyscan -p 22 <host> 2>/dev/null)   # compare with the fingerprint your provider shows
```

Don't run `ssh-keyscan` inside the workflow: that trusts whatever answers on
the first connection, which is the thing pinning exists to prevent. If the host
is rebuilt, its keys change; update the secret from the new host.

Before cicd 3.0.0 this action disabled host-key checking as a documented
accepted risk. It no longer does; a deploy that used the old action needs the
new secret.

## Inputs are always passed through `env:`

Every `run:` step reads its inputs from an `env:` block (`$SSH_HOST`,
`$WORKING_DIR`, ...) rather than interpolating `${{ inputs.x }}` (or
`${{ github.* }}` / `${{ job.* }}`) directly into the script body. This
isn't a style choice — GitHub's own security-hardening guidance treats
direct `${{ }}` interpolation inside `run:` as a script-injection risk:
the expression is substituted into the script's *source text* before
bash ever runs it, so a value containing shell metacharacters (`` ` ``,
`$(...)`, a heredoc terminator) becomes executable code, not inert data.
Composite action inputs are usually filled from trusted secrets/vars
today, but a composite action is meant to be reused — some future caller
may wire an input to something less trusted (a branch name, a PR title)
without it being obvious from this file alone. Passing everything
through `env:` costs nothing and closes that door permanently, so do the
same in any step you add here.

## Values sent to the remote shell are `%q`-quoted, not manually wrapped

The "Deploy over SSH" step builds one remote command string locally
(`WORKING_DIR=$WORKING_DIR_Q ... bash -s`) and sends it over SSH. Each
value is passed through `printf '%q'` before being spliced in, rather
than manually wrapped as `VAR='$VAR'`. Manual single-quote wrapping
breaks the moment the value itself contains a single quote — the quote
closes early and whatever follows becomes literal shell syntax on the
remote end (e.g. a `working-dir` input of `/srv/app'; rm -rf / #` would
execute the `rm -rf /` if it were merely `'`-wrapped). `%q` shell-escapes
the value so it reconstitutes to the exact original string on the remote
side no matter what it contains — quotes, spaces, `$()`, backticks,
semicolons. Quote every value passed to a remote shell this way, not
just the ones you expect to contain spaces or special characters; a
value in an env var or secret can change without this file changing.

## Compose version compatibility

`docker compose ps --format json` changed output shape across Compose
versions — some emit one JSON object per line, others emit a single JSON
array. The health-check step handles both, so this action works
regardless of which Compose Engine version the target host runs.

## If you ever split the deploy into more than one SSH step: don't log out early

This action's own "Deploy over SSH" step does `docker login`, `pull`,
and `up` all inside the *same* SSH session, so this doesn't currently
bite here — but it's a real trap if you ever split a deploy into
separate `ssh` invocations (e.g. a real `deploy-develop.yml` that
does: one step logs in, pulls, and immediately logs out; a later,
separate SSH session then runs `docker compose pull` again to check
whether a mutable tag like `latest-develop` moved — but that pull now
fails `unauthorized`, since the earlier step already logged out and
`~/.docker/config.json` doesn't carry stale credentials past an explicit
logout). If you add a step that logs out of a registry, make sure
nothing later in the deploy still needs registry access — and mark any
final cleanup/logout step `if: always()` so it runs even when an earlier
step failed, rather than leaving credentials cached indefinitely on a
failed run.
