# Sources

External facts this skill relies on. Re-check them during an audit. Mark a row `unverified` in the Checked column if it couldn't be confirmed online.

| Fact | Source | Checked |
|---|---|---|
| `docker compose ps --format json` output differed across Compose versions (JSON Lines vs one array). The jq filter in `gotchas.md` handles both (tested on 2026-09-26). | Carried over from the templates repo | unverified |
