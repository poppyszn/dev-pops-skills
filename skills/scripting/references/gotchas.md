# Shell gotchas, with the bugs behind them

Entries marked **Shipped once** caused a real bug in a template before being fixed.

## A command that reads stdin eats the rest of a heredoc script

**Shipped once.** When a script is delivered on stdin (`ssh host 'bash -s' << 'EOF'`, `bash -s < script`), any command that reads stdin (`docker run -i`, `docker compose run`, `ssh` without `-n`, `read`) consumes the remaining script lines. Bash then sees end of input and exits 0, so everything after that command silently never runs.

```bash
bash -s << 'EOF'
echo before
docker run --rm -i alpine sh -c 'cat >/dev/null'
echo after      # never printed
EOF
```
Fix: redirect that command's stdin: `… < /dev/null` (or `ssh -n`). Verify by echoing a marker as the script's last line.

## Hand-wrapped quotes don't protect remote commands

**Shipped once.** Building `"cd '$DIR' && …"` for a remote shell breaks as soon as `$DIR` contains `'`, and the rest of the value runs as code. Quote each value with `printf '%q'` and splice the result in unquoted:

```bash
dir=$(printf '%q' "$DIR")
ssh "$host" "cd $dir && docker compose up -d --wait"
```
Quote every value, not only the ones you expect to contain special characters.

## Env-file values can arrive with quotes attached

Values loaded via compose `env_file:` can keep their surrounding quotes (`API_URL="https://x"` arrives as `"https://x"`). Substituting them unmodified produces broken URLs in the bundle. Strip one pair of leading and trailing quotes before use:

```sh
strip_quotes() {
  printf '%s' "$1" | sed 's/^["'"'"']//;s/["'"'"']$//'
}
```

## Validate before acting

Check required variables with `: "${VAR:?message}"` **before** any side effect (`sed -i`, migrations, network calls). A missing variable should be a clear startup error, not a half-configured container.

## `exec "$@"` at the end of entrypoints

Without `exec`, the shell stays PID 1: the app doesn't receive `SIGTERM` (slow, unclean shutdowns), and `CMD` or extra `docker run` arguments are ignored.

## CLI output shapes change between versions

**Shipped once.** `docker compose ps --format json` emitted JSON Lines in some Compose versions and a single JSON array in others. A `jq` filter written for one shape broke on the other. Accept both, e.g. `jq -s 'if (.[0]|type)=="array" then .[0] else . end'`, or document the assumed version.

## Overriding a base image's entrypoint skips its setup

**Shipped once.** A custom `ENTRYPOINT` on nginx silently skipped nginx's own template-rendering step. Before replacing an image's entrypoint, read what the original does.

## Without `pipefail`, a pipe hides the failure on its left

`set -e` stops on a failing command, but a pipeline's status is its *last* command's. In `services=$(detect.sh | paste -sd ' ' -)` a failing `detect.sh` leaves `services` empty and the script carries on as if nothing changed. Scripts get `set -euo pipefail` for this reason; it matters most where the shell isn't yours: a CI runner's default shell (GitHub Actions runs `bash -e`, no pipefail, unless the step says `shell: bash`) or a caller that sources your code. When you can't set it, don't pipe the command whose failure matters:
```bash
out=$(detect.sh)          # exits here under -e if detect.sh fails
services=$(echo $out)     # reshape on the next line
```
Test it: replace the left-hand command with `exit 1` and check the script fails.

## Bash 4 features fail on macOS's bash 3.2

macOS still ships bash 3.2, so `#!/usr/bin/env bash` there runs 3.2 unless the user installed a newer one. `mapfile`/`readarray`, `${var,,}`/`${var^^}`, associative arrays (`declare -A`) and `|&` are bash 4+. A script using them passes in CI (Linux, bash 5) and fails on a developer's laptop with `mapfile: command not found`, or the reverse, for a pre-push hook. Either avoid them in scripts people run locally:
```bash
# instead of: mapfile -t apps < <(ls -d apps/*/)
apps=$(find apps -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
for app in $apps; do …; done
```
or require bash 4 up front: `[ "${BASH_VERSINFO[0]}" -ge 4 ] || { echo "needs bash 4+ (brew install bash)" >&2; exit 1; }`. When testing a CI script on a Mac, run it with the newer bash (`/opt/homebrew/bin/bash script.sh`).

## zsh reads `$var:a` as a modifier, not text

In zsh (the macOS default interactive shell), `:a`, `:h`, `:t`, `:r` and others after an unbraced parameter are expansion modifiers. `git show $REF:apps/api/main.ts` turns into `git show <absolute path of $REF>pps/api/main.ts` and fails with "unknown revision". Brace the name when text follows a colon: `git show "${REF}:apps/api/main.ts"`. Scripts with a bash shebang are unaffected; this bites one-off commands typed or pasted into a zsh session. Two other zsh traps in pasted one-liners: a line made only of `=` characters (`echo =====` works, `=====` alone tries to expand a command name), and an unmatched glob, which is an error in zsh instead of being passed through.

## Run a function in parallel by re-invoking the script

`xargs -P` runs commands, not shell functions. Instead of `export -f` (bash-only, and fragile under `env -i` or `sh`), give the script a mode that does one item and have it call itself:
```bash
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
if [ "${1:-}" = --one ]; then do_one "$2"; exit 0; fi
printf '%s\n' "$@" | xargs -P "${PARALLEL:-4}" -I{} bash "$SELF" --one {}
```
Each item runs in its own process, so parallel items share no shell state; have each write its result to a file (`$OUT/<item>.result`) and read those back after `xargs` returns, instead of parsing interleaved output. Make `do_one` exit 0 and record failures in the result file: GNU `xargs` stops reading input once a command exits 255. On macOS (BSD `xargs`), `-I` also caps each replaced argument at 255 bytes unless `-S` raises it, so pass short names, not file contents. (The cicd skill's `run-pr-checks.sh` uses this pattern.)
