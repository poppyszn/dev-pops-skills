# Sources

External facts this skill relies on. Re-check them during an audit. Mark a row `unverified` in the Checked column if it couldn't be confirmed online.

| Fact | Source | Checked |
|---|---|---|
| `docker compose ps --format json` output differed across Compose versions (JSON Lines vs one array). The jq filter in `gotchas.md` handles both (tested on 2026-09-26). | Carried over from the templates repo | unverified |
| `mapfile`/`readarray` were added in bash 4.0; macOS ships bash 3.2.57 at `/bin/bash`. | https://gitea.psi.ch/pmodules/bash/src/tag/bash-4.0.38/CHANGES, https://github.com/antonbabenko/pre-commit-terraform/pull/627 | 2026-11-04 |
| zsh colon modifiers (`:a` absolute path, `:h` head, …) apply to unbraced parameter expansions such as `$var:a`. | https://zsh.sourceforge.io/Doc/Release/Expansion.html (Modifiers) | 2026-11-04 |
| GitHub Actions runs a step with no `shell:` as `bash -e {0}` (no pipefail); `shell: bash` adds `-o pipefail`. | https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax | 2026-11-04 |
| GNU `xargs` stops reading input when a command exits 255 (and itself exits 124). BSD `xargs -I` limits each replaced argument to 255 bytes unless `-S` is given. | https://man7.org/linux/man-pages/man1/xargs.1.html; `man xargs` on macOS 26.6.2 | 2026-11-04 |
