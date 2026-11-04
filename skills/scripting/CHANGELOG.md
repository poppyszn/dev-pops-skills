# Changelog

## 1.1.0 - 2026-11-04

- `references/gotchas.md`: a pipe without `pipefail` hides the failure on its left (and CI's default shell has none); bash 4 features (`mapfile`, `${var,,}`, `declare -A`) fail on macOS's bash 3.2; zsh reads `$var:a` as a modifier; run a function in parallel by re-invoking the script under `xargs -P`.
- Verification: test a command's failure path, and run scripts people use on macOS under `/bin/bash` too.
- Checked: the bash 4.0 changes, zsh modifiers and `xargs` exit-255 behaviour online; macOS 26.6.2's `/bin/bash` is 3.2.57.

## 1.0.0 - 2026-09-26

- First complete version, built from the templates repo's shell and Makefile lessons: entrypoint rules, `printf '%q'` quoting, stdin-eating heredoc commands, output-shape drift, Makefile conventions.
- Added a tested jq filter for both `docker compose ps --format json` shapes.
