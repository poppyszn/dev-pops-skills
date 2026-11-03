# The first deploy that couldn't follow its own runbook

*A draft write-up of a bug found by running the documented steps in order. The repro below was run as written.*

The production runbook said, reasonably: before the first deploy, create the environment file on the server, `<app>/docker/production/.env`, with the real secrets. The deploy workflow then did what most deploy scripts do:

```bash
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone "$CLONE_URL" "$REPO_DIR"
fi
```

Each step is sensible. Together they fail. The runbook creates `$REPO_DIR` (it has to, to hold the `.env`), so there is no `.git` inside, so the script clones, and `git clone` refuses a directory that already has files.

## Repro (no network, no server)

```bash
git init -q --bare origin.git
git clone -q origin.git seed && (cd seed && git commit -q --allow-empty -m init && git push -q origin HEAD)
mkdir -p host/app/docker && touch host/app/docker/.env
git clone origin.git host/app
# fatal: destination path 'host/app' already exists and is not an empty directory.
```

The first deploy dies at its first step, on a host set up exactly as documented.

## The fix: don't clone, converge

```bash
cd host/app
git init -q
git remote add origin "$URL"
git fetch -q --depth 1 origin "$SHA"
git reset -q --hard FETCH_HEAD
```

Run the same four steps into the directory with the `.env` already in it, and the secret file survives. Run them on every deploy and the host always ends on the exact commit being deployed, whether it was empty, a stale checkout or a previous deploy.

## Two things to do while you're there

- **Don't write the token into `.git/config`.** Pass it for one command with `git -c http.extraheader=...` (what `actions/checkout` does). A `set -e` failure between "set the remote URL with the token" and "reset it" leaves the token on disk.
- **Check before `git clean`.** Cleaning the working tree deletes untracked files that aren't ignored, which includes the `.env` you just protected. Stop unless `.env` is gitignored.

## The general lesson

A runbook and the script it feeds are one system, and nobody tests that system until the first real deploy. Run the documented steps, in order, on a clean machine before you trust either.

*Template: `skills/cicd/assets/workflows/deploy-production-nx.yml` ("Sync repository to the deployed commit"). Tracked in `contributions/git-sync-deploy-clone-and-env-bootstrap.md` for the shared develop action.*
