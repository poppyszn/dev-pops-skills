# Changelog

## 0.5.0 - 2026-11-03

- New rule, standard §12: **findings are anonymous**. A finding never names the client, project, repository, organisation, a person, a hostname, domain or local path; it describes the project's shape and keeps every technical detail. The same applies to anything copied from a finding into a skill, changelog, commit or PR. "Apply a finding" now starts by genericizing, and Verification runs `scripts/check-private-names.sh`.

## 0.4.0 - 2026-09-27

- Standard §13: portable export for agents with no Skill tool (no on-demand loading), and the authoring convention (write for top-to-bottom reading, no runtime-mechanic-only phrasing, assets stay pointers) that keeps every skill flattenable without extra effort.
- New `scripts/export-portable.sh`: flattens a skill's `SKILL.md` + `references/*.md` into one plain-text document, plus `--check <file>` to detect drift against a copy pasted elsewhere.
- Create/edit workflow: re-export step after validate, when a portable copy exists. Verification: `--check` must pass for any such copy.

## 0.3.0 - 2026-09-26

- Applied findings now move to `contributions/completed/` (keeping the `.merged.md` suffix); open findings are the files directly in `contributions/`.

## 0.2.1 - 2026-09-26

- sources.md: recorded how Claude Code and Antigravity list and invoke skills (the README usage guide depends on it).

## 0.2.0 - 2026-09-26

- Standard §11 (template assets: copy-not-retype, a reference per asset, markers, vendored-copy header) and §12 (gap findings in `contributions/`).
- New "Apply a finding" workflow. Audit mode now covers asset pins and the weekly freshness-audit issue.
- Validator: FAIL when a vendored copy drifts from its source; WARN when a bundled file isn't mentioned in SKILL.md.

## 0.1.0 - 2026-09-26

- Initial version: interview-first authoring, overlap check, online verification of external facts, audit mode, and a validator enforcing the standard.
