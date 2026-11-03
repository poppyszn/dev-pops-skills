# Missing: a standalone, manual "run seed" workflow template

> **Status: merged.** Added
> `ci-cd/github-actions/run-seed-develop.yml` + sibling README, rebuilt
> (not copied verbatim) to apply this repo's established safety
> standards: job-level `env:` routing (no direct `${{ }}` in `run:`),
> `printf '%q'`-quoting every value spliced into the remote SSH command,
> `${SSH_PORT:=22}` empty-input guard, and `chmod 700/600` on
> `~/.ssh`/`~/.ssh/config`. Kept the `docker compose run --rm seed <
> /dev/null` fix from the original draft (correctly cites the
> already-merged heredoc-gotchas finding). Also added the "confirm the
> seed entrypoint is actually built" note to `docker/node-api/README.md`,
> and copied the new workflow into `examples/monorepo-layout/` (no
> adaptation needed — that example already uses the pull-based
> `docker/develop/` flow this workflow targets). Wired into `CLAUDE.md`'s
> index and repository-structure list.
>
> Kept below as the original write-up/rationale — see git history around
> this file's rename to `.merged.md` for the applying commits.

**Where found:** a client repo, while building its `develop` CI/CD from
these templates (`docker/node-api`, `deploy-develop-build-on-server.yml` /
the client-derived variant, `ssh-compose-deploy`). Not a bug in anything
that exists today — a gap in what's covered.

**The gap:** `docker/node-api/compose.yml` and `compose.deploy.yml`
already model a `seed` service correctly (gated behind the `seed` profile,
documented in `docker/node-api/README.md`), and
`ssh-compose-deploy/README.md` even mentions `compose-profiles: "migrate
seed"` as a valid input. But there's no template anywhere in
`ci-cd/github-actions/` for a **standalone, manual, `workflow_dispatch`-only
workflow that just runs the seed job** against an already-deployed
environment, independent of a deploy. Today, the only documented way to
run `seed` via these templates is folding `seed` into `compose-profiles`
on every `ssh-compose-deploy` call — which means it either runs on *every*
deploy (usually wrong — seed jobs are typically idempotent-but-not-free,
or outright not meant to be rerun on every push) or not at all.

In practice, "seed the develop/staging database" is a distinct,
occasional, manual operation — re-seeding after a schema change, restoring
demo data after a database reset, etc. — separate from the deploy
lifecycle. A copy-paste-ready template for that seems worth having
alongside `deploy-develop-build-on-server.yml`, not just documented as a
`compose-profiles` value on the deploy action.

**What a client repo built** (adapted to fit, not copied from any existing
template here — there was nothing to copy from): a small
`workflow_dispatch`-only workflow, no push trigger, that SSHes to the
target host and runs `docker compose --env-file .env --profile seed run
--rm seed` against whatever's already deployed there. Deliberately does
**not** git-sync the repo or rebuild/redeploy anything first — it assumes
a normal deploy already put a current `docker/develop/.env` (or
equivalent) and the target image on the host, and only concerns itself
with running the one-shot seed job:

```yaml
name: Seed develop database

on:
  workflow_dispatch:

concurrency:
  group: seed-develop
  cancel-in-progress: false

jobs:
  seed:
    name: Seed develop database
    runs-on: ubuntu-latest
    environment: develop
    timeout-minutes: 10
    env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      GITHUB_ACTOR: ${{ github.actor }}
      WORKING_DIR: ${{ secrets.WORKING_DIR }}
      REPO: ${{ github.repository }}
      SSH_HOST: ${{ secrets.SSH_HOST }}
      SSH_PORT: ${{ secrets.SSH_PORT }}
      SSH_TARGET: ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }}
      SSH_JUMP_HOST: ${{ secrets.SSH_JUMP_HOST }}
      SSH_USER_JUMP: ${{ secrets.SSH_USER_JUMP }}
    steps:
      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}

      - name: Configure SSH
        run: |
          mkdir -p ~/.ssh
          if [ -n "$SSH_JUMP_HOST" ]; then
            cat >> ~/.ssh/config << EOF
          Host ${SSH_JUMP_HOST}
            StrictHostKeyChecking no

          Host ${SSH_HOST}
            StrictHostKeyChecking no
            ProxyJump ${SSH_USER_JUMP}@${SSH_JUMP_HOST}
          EOF
          else
            cat >> ~/.ssh/config << EOF
          Host ${SSH_HOST}
            StrictHostKeyChecking no
          EOF
          fi

      - name: Run seed job
        run: |
          ssh -p "$SSH_PORT" "$SSH_TARGET" \
            GITHUB_TOKEN="$GITHUB_TOKEN" \
            GITHUB_ACTOR="$GITHUB_ACTOR" \
            WORKING_DIR="$WORKING_DIR" \
            REPO="$REPO" \
            'bash -s' << 'EOF'
            set -euo pipefail
            echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_ACTOR" --password-stdin
            cd "${WORKING_DIR}/${REPO##*/}/docker/develop"
            docker compose --env-file .env --profile seed pull seed
            # < /dev/null — see the deploy-develop-ssh-heredoc-gotchas.merged.md
            # finding in this same folder: docker compose run attaches stdin
            # interactively by default and will eat the rest of this heredoc
            # (the docker logout line below) if not redirected away from it.
            docker compose --env-file .env --profile seed run --rm seed < /dev/null
            docker logout ghcr.io
          EOF

      - name: Seed summary
        if: always()
        run: |
          echo "## Seed Report" >> $GITHUB_STEP_SUMMARY
          echo "- **Status**: ${{ job.status }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Triggered by**: ${{ github.actor }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Commit**: \`${{ github.sha }}\`" >> $GITHUB_STEP_SUMMARY
```

Verified locally end-to-end (not just this SSH-wrapped version — the
underlying `docker compose --profile seed run --rm seed` invocation, plus
the webpack/Dockerfile wiring needed to produce a runnable `seed.js` in the
image in the first place — see below) against a real Postgres + migrate +
seed run.

**One more layer this exposed, worth calling out separately:** the
compose-level `seed` service in `docker/node-api/compose.yml` assumes a
runnable `seed` command already exists *in the built image*. That's not
automatic — in a client repo's case (Nx + `NxAppWebpackPlugin`, same
`generatePackageJson`/`additionalEntryPoints` shape as the
`tslib`/`importHelpers` gotcha filed separately), the app had a
`seed.ts` script written but never wired into `webpack.config.js`'s
`additionalEntryPoints` or copied in the Dockerfile — so the compose
`seed` service would have referenced a command that didn't exist in the
image at all. Worth a line in `docker/node-api/README.md` (or wherever
seed's compose shape is documented) explicitly flagging: "confirm your
build actually produces the `seed` entrypoint your image's `CMD`/compose
`command:` references before wiring this up" — the template can't detect
this for you since it's app-specific, but it's an easy thing to wire the
compose/CI side of and forget the actual build side of, since nothing
fails loudly until someone tries to run it.

**Suggested fix:** a new template file, something like
`ci-cd/github-actions/run-seed.yml` (or fold as a second example into
`deploy-develop-build-on-server.yml`'s README rather than a fully separate
file — maintainer's call), alongside a one-line addition to
`docker/node-api/README.md` about confirming the seed entrypoint is
actually built before wiring up the compose service.
