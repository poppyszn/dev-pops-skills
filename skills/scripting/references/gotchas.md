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
