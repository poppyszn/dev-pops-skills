# git-sync-deploy fails if the target directory already has files, and always bootstraps `.env`

**Where found:** a review of a hand-built production pipeline, while building the production deploy templates in `skills/cicd` (`deploy-production-nx.yml` and its reference). The production workflow does its own sync because of the two problems below. The develop templates still use the action.

**Status:** confirmed in this repo's own asset, `skills/cicd/assets/actions/git-sync-deploy/action.yml`, and in its vendored copy in `skills/project-infra/assets/monorepo-layout/.github/actions/git-sync-deploy/`.

## 1. `git clone` into a directory that already has files fails

The action runs `if [ ! -d "$REPO_DIR/.git" ]; then git clone ... "$REPO_DIR"; fi`. If something created `<WORKING_DIR>/<repo>/` first (an operator placing `docker/develop/.env` ahead of the first deploy, which the docs for the production host tell people to do), the clone is refused and the deploy fails at its first step.

**Repro** (no SSH or GitHub needed):

```bash
git init -q --bare /tmp/origin.git
git clone -q /tmp/origin.git /tmp/seed && (cd /tmp/seed && git commit -q --allow-empty -m init && git push -q origin HEAD)
mkdir -p /tmp/host/app/docker/develop && touch /tmp/host/app/docker/develop/.env
git clone /tmp/origin.git /tmp/host/app
# fatal: destination path '/tmp/host/app' already exists and is not an empty directory.
```

`git init` + `git fetch` + `git reset --hard` into the same directory works and keeps the file.

## 2. The token is written into `.git/config`

The action does `git remote set-url origin "https://x-access-token:${GH_TOKEN}@github.com/..."` and resets the URL at the end. A command that fails in between (`set -e`) leaves the token in `.git/config`. The token only lives for the job, so the exposure is small, but nothing needs to be written: `git -c "http.extraheader=AUTHORIZATION: basic <base64 of x-access-token:token>" fetch ...` passes it for one command, which is how `actions/checkout` authenticates.

## 3. It copies `.env.example` to `.env` whenever `.env` is missing

Right for a develop box, wrong for production, where a host booting with placeholder secrets is worse than a deploy that stops. The production workflow therefore does not use this action.

## Suggested fix

- Replace the clone with `git init` (if no `.git`) + `git fetch --depth 1 origin <sha-or-branch>` + `git reset --hard FETCH_HEAD`, and pass the token with `http.extraheader`. The production workflow's "Sync repository to the deployed commit" step is a tested version of this (see `references/deploy-production.md`).
- Make the `.env.example` bootstrap an input (`bootstrap-env`, default `true` so develop keeps working) and say in the action's reference that production should not turn it on.
- Guard `git clean -fd` the way the production step does: stop unless the compose directory's `.env` is gitignored, because `git clean` deletes untracked files that are not ignored.
- Re-copy the vendored action into `skills/project-infra/assets/monorepo-layout/` (the validator fails on drift) and bump cicd and project-infra.

Not applied here: it changes a shared action used by every develop deploy, and the production templates do not depend on it.
