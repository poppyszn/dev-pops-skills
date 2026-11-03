# Deploy workflow gotchas found in production (a client repo)

> **Status: merged.** All three findings verified (two with a live
> repro) and applied:
> - #1 fixed in `ci-cd/github-actions/deploy-develop-build-on-server.yml`
>   (`< /dev/null` on the `docker compose run --rm migrate` line).
> - #2 documented as standing guidance in
>   `ci-cd/github-actions/actions/ssh-compose-deploy/README.md` (not a
>   current bug — that action keeps login/pull/up in one SSH session).
> - #3 documented in `CLAUDE.md`'s Compose files standards and linked
>   from `docker/node-api/README.md` (no `.env.example` in this repo
>   currently ships a `$`-containing secret, so no file needed a direct
>   fix, but the guidance is now in place before one does).
>
> Kept below as the original write-up/rationale — see git history around
> this file's rename to `.merged.md` for the applying commits.

Found while debugging a client repo's develop deploy pipeline (adapted
from a client repo's `deploy-develop.yml`, not directly from this
repo's templates — but one of the two bugs below is a **confirmed,
present-today bug in this repo's own
`ci-cd/github-actions/deploy-develop-build-on-server.yml`**). Written up
here rather than applied directly so the maintainer can review before
folding these into the templates and their READMEs.

## 1. `docker compose run` inside an SSH heredoc silently eats the rest of the script

**Confirmed present in this repo:**
`ci-cd/github-actions/deploy-develop-build-on-server.yml:82` (old templates-repo path) —
`docker compose --env-file .env run --rm migrate`, followed by more script
(the `up -d --wait` and unhealthy-container check a few lines later), all
inside the same `ssh ... 'bash -s' << 'EOF' ... EOF` heredoc.

**The bug:** `docker compose run` attaches to the container's stdin
interactively by default (like `docker run -i`). When the *entire remote
script* is itself being delivered to `bash -s` as one stdin stream (piped
over SSH as a heredoc), the container process consumes whatever of that
stream hasn't been read yet — i.e. every heredoc line still to come after
the `run` command — as its own input, before `bash` ever gets to read and
execute it. There's no error: from `bash`'s point of view its stdin just
ran out, which looks like a normal, successful end of script. Everything
after the `docker compose run` line (in `deploy-develop-build-on-server.yml`,
that's the actual `up -d --wait` + health check) silently never executes,
and the step still reports success.

**Reproduced with a minimal case**, no SSH or Compose required:
```bash
bash -s << 'EOF'
echo "before"
docker run --rm -i alpine sh -c 'cat >/dev/null'
echo "after"
EOF
# prints "before" only — "after" never runs
```
Adding `< /dev/null` to the `docker run`/`docker compose run` line fixes it:
```bash
bash -s << 'EOF'
echo "before"
docker run --rm -i alpine sh -c 'cat >/dev/null' < /dev/null
echo "after"
EOF
# prints "before" then "after"
```

**Fix:** append `< /dev/null` to every `docker compose run` (and any other
stdin-attaching command) that appears inside one of these SSH heredocs,
anywhere it's not the last command in the script:
```diff
- docker compose --env-file .env run --rm migrate
+ docker compose --env-file .env run --rm migrate < /dev/null
```

This class of bug is easy to miss in testing because the step reports
**success**, not failure — the only symptom is that later effects (the
app never actually gets deployed/started) don't happen. Worth adding to
CLAUDE.md's "this exact mistake shipped once already" list once fixed
here, alongside the other SSH-heredoc lessons already documented there.

**Where else to check:** any future template that puts more than one
docker command in an SSH heredoc, with an interactive-by-default command
(`docker run`/`docker compose run`/`docker exec` without `-T` or a stdin
redirect) anywhere but the last line.

## 2. Logging out of a registry before every step that needs it has run

Not present in this repo's current `ssh-compose-deploy` (it does `docker
login` and the actual `pull`/`up` all inside the *same* SSH session/heredoc,
so this doesn't bite there) — but worth documenting since it's an easy trap
for any future template that splits a deploy into more than one SSH
session/step, as a client repo's (and by extension a client repo's
adapted) `deploy-develop.yml` does:

1. Step A: `ssh ... 'docker login ghcr.io ...; docker pull ...; docker logout ghcr.io'`
2. Step B (separate `ssh` invocation, i.e. a new session): `docker compose pull` / `up`

Step B's `docker compose pull` needs to hit the registry again (image tags
like `latest-develop` are mutable, so a real deploy has to check whether
the tag moved) — but Step A already logged out, so Step B fails with
`unauthorized`. `~/.docker/config.json` persists across SSH sessions on
the same host/user, so this only breaks because of the *explicit* logout,
not because credentials don't otherwise carry over.

**Fix:** don't log out until nothing later in the deploy still needs
registry access — e.g. move `docker logout` into a final cleanup step, and
mark that cleanup step `if: always()` so it (and the logout) still runs
even if an earlier deploy step fails, instead of leaving credentials
cached indefinitely on a failed run.

## 3. `docker compose` interpolates `$VAR` inside `.env` files' own values, not just when injecting them into containers

Relevant to `env-replacement/README.md` and any template using
`env_file: - .env` with a secret that can contain a literal `$` — a bcrypt
hash always does (`$2b$12$...`).

**The bug:** Compose auto-loads a file named `.env` next to `compose.yml`
(and/or whatever `--env-file` points at) to interpolate `${VAR}`
references *inside `compose.yml` itself* — but it also applies that same
interpolation to the `.env` file's **own** values before handing them to
`env_file:`-declared services. A value like
`BOOTSTRAP_ADMIN_PASSWORD_HASH=$2b$12$rK9nDVjYn/7Kx5ZOgN7Y0...` gets
partially mangled: `$2b` and `$12` survive because they aren't valid
variable-name syntax (can't start with a digit), but `$rK9nDVjYn` *does*
match, gets treated as an undefined variable reference, and is silently
replaced with an empty string — dropping that whole segment from the
value the container actually receives.

**Reproduced:**
```bash
echo 'HASH=$2b$12$rK9nDVjYn/7Kx5ZOgN7Y0.KvJMqfI1kf33p056x3a7i3Nd9ufj5Za' > .env
docker compose run --rm --entrypoint sh <some-service> -c 'echo $HASH'
# → $2b$12/7Kx5ZOgN7Y0.KvJMqfI1kf33p056x3a7i3Nd9ufj5Za  (rK9nDVjYn silently dropped)
```
Escaping every literal `$` as `$$` fixes it:
```bash
echo 'HASH=$$2b$$12$$rK9nDVjYn/7Kx5ZOgN7Y0.KvJMqfI1kf33p056x3a7i3Nd9ufj5Za' > .env
# container now receives the exact original value
```

**Fix / doc addition:** any `.env.example` template that documents a
bcrypt-hash-shaped (or otherwise `$`-containing) value should say so
explicitly — e.g.:
```
# Escape every $ as $$ — docker compose interpolates $VAR references
# inside .env's own values, not just when injecting them into containers.
BOOTSTRAP_ADMIN_PASSWORD_HASH=<bcrypt-hash-with-every-$-doubled-to-$$>
```
and suggest verifying with `docker compose --env-file .env config | grep
<VAR>` before trusting a real secret went in correctly — the `config`
output re-escapes literal `$` as `$$` for display, so seeing `$$` there
confirms the value round-tripped intact.

This is a distinct mechanism from the `env-replacement/` pattern already
documented in this repo (that's `sed`/`envsubst` substituting placeholders
into a built frontend bundle at container startup) — this is Compose's own,
separate `.env`-file interpolation, and applies even to backend services
that never touch `env-replacement/entrypoint.sh` at all.
