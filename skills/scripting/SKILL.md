---
name: scripting
description: Use when writing, reviewing, or debugging shell scripts (sh, bash) and Makefiles for DevOps work, such as container entrypoint scripts, remote commands sent over SSH or heredocs, ops and automation scripts, and parsing CLI output with jq. Also covers `make help` conventions, quoting and injection safety, fail-fast env validation, and scripts that pass locally but misbehave in CI, over SSH, or on another OS or tool version. Not for GitHub Actions workflow YAML (use cicd), Dockerfile instructions or compose files (use docker), or security scanning setup (use security).
metadata:
  version: "1.0.0"
  last-verified: "2026-09-26"
---

# Scripting

Write shell scripts and Makefiles that fail loudly, quote safely, and behave the same everywhere they run.

## When to use

- Writing or fixing an `entrypoint.sh`, an ops script, or a remote SSH command
- A `Makefile` needs targets, help output, or a safer structure
- A script works locally but silently skips steps, breaks on odd input, or differs across tool versions

Not for: workflow YAML (`cicd`), Dockerfiles and compose (`docker`).

## Defaults

Apply these without asking. Deviate only if the project already does it differently (say so) or the user asks.

- **Shell choice:**
  - container entrypoints are POSIX `#!/bin/sh` with `set -e` (alpine images have no bash)
  - ops and automation scripts are `#!/usr/bin/env bash` with `set -euo pipefail`
- **Fail fast on required input.** Put `: "${VAR:?ERROR: VAR is required}"` for every required variable before doing any work.
- **Quote every expansion** (`"$var"`, `"$@"`).
- **Commands sent to a remote shell:** quote each value with `printf '%q'`, never hand-wrapped quotes.
- **`docker run` / `docker compose run` inside a script delivered on stdin** (`ssh host 'bash -s' << 'EOF'`) gets `< /dev/null`. Otherwise it eats the rest of the script.
- **Entrypoints end with `exec "$@"`**, so the real process gets PID 1 and signals, and `CMD` arguments still work.
- **Strip stray quotes from env-file values** before use (the `strip_quotes` helper in the docker skill's entrypoints).
- **Scope `find`** to the smallest directory that can contain the target. Use `-print0 | xargs -0` for filenames.
- **Don't assume a CLI's output shape is stable.** When parsing (`jq` over `docker compose ps --format json`, etc.), handle every shape seen across versions, or state the assumed version.
- **Makefiles:**
  - a `## description` on every user-facing target, grouped under `##@ Section` headers, rendered by the standard `awk` help target
  - `.DEFAULT_GOAL := help`
  - destructive variants (`clean`, volume removal, force-overwriting `.env`) are separate, clearly named targets, never folded into the obvious one
  - `.PHONY` for every non-file target

## Workflow

1. **Identify where the script runs:** inside a container (sh, no bash), on the host, over SSH, or in CI. That decides the shell and what tools exist.
2. **Reuse proven pieces.** Entrypoints come from the docker skill's assets and Makefiles from its `assets/Makefile` (copy, then adapt). Ops scripts follow the Defaults above.
3. **Write or fix the script.** For fixes, reproduce the failure with a minimal case first (see `references/gotchas.md` for the known silent failures).
4. **Check any external tool versions** the script depends on (flags, output formats) against current docs before relying on them.
5. **Verify** (see Verification).

## Requires confirmation

Stop and confirm with the user before running any script or command that:

- Deletes files or data (`rm -rf`, `find … -delete`, volume or database removal)
- Overwrites existing config or env files (`.env`, `~/.ssh/config`, `~/.docker/config.json`)
- Runs on a remote host (`ssh`, `scp`, `rsync` to a server)
- Rewrites git history or force-pushes
- Installs or upgrades system packages

## Verification

Run these and report the actual output before calling the work done:

- `sh -n <file>` (POSIX) or `bash -n <file>` for every script touched
- `shellcheck <file>` if installed. Fix or justify each warning.
- Run the script with the failure cases that matter: a missing required variable exits non-zero with a clear message, and a value containing spaces or quotes survives intact
- `make help` lists every user-facing target, and a bare `make` prints help
- For heredoc or SSH scripts: confirm the *last* command in the script actually ran (echo a marker), not just that the step exited 0

## Examples

Good: an entrypoint that fails fast, sanitises and hands off.
```sh
#!/bin/sh
set -e
: "${VITE_API_URL:?ERROR: VITE_API_URL environment variable is required}"
_API_URL=$(strip_quotes "${VITE_API_URL}")
find /usr/share/nginx/html -type f -name "*.js" -print0 | xargs -0 sed -i -e "s|__VITE_API_URL__|${_API_URL}|g"
exec "$@"
```

Bad: a remote command built with hand-wrapped quotes. A value containing `'` injects syntax on the remote host (this shipped once):
```bash
ssh "$host" "cd '$WORKING_DIR' && docker compose up -d"
# fix: dir=$(printf '%q' "$WORKING_DIR"); ssh "$host" "cd $dir && docker compose up -d"
```

## References

Load these only when the task needs them:

- `references/gotchas.md`: the silent failures behind the Defaults (stdin-eating commands, quoting, env-file quotes, output shape drift), with repros
- `references/sources.md`: external tool behaviour facts, with the date each was checked
