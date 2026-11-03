# Sources

External facts this skill and the repo depend on. Re-check them during an audit.

| Fact | Source | Checked |
|---|---|---|
| Skill format: `SKILL.md` with required `name` (≤64, lowercase/hyphens, matches folder) and `description` (≤1024). Optional `license`, `compatibility`, `metadata`, `allowed-tools`. `scripts/`, `references/` and `assets/` sit one level deep. | https://agentskills.io/specification | 2026-09-26 |
| Claude Code reads user skills from `~/.claude/skills/<name>/SKILL.md` and project skills from `.claude/skills/` (used by `scripts/install.sh`). | https://code.claude.com/docs/en/skills | 2026-09-26 |
| Antigravity reads global skills from `~/.gemini/config/skills/<name>/` (the only global path read by the app, IDE and CLI) and project skills from `.agents/skills/<name>/`. | https://antigravity.google/docs/skills/ , https://atamel.dev/posts/2026/07-01_where_agy_agent_skills/ | 2026-09-26 |
| Antigravity reads `AGENTS.md` natively (since v1.20.3), so no `GEMINI.md` is needed. | https://thepromptshelf.dev/blog/google-antigravity-agents-md-rules-guide-2026/ | 2026-09-26 |
| Gemini CLI is no longer used. Antigravity replaced it for this user, so there's no install target for it. | User, in conversation | 2026-09-26 |
| `~/.agents/skills` is a vendor-neutral skills path, kept as an optional install target. | https://geminicli.com/docs/cli/skills/ | 2026-09-26 |
| Claude Code: `/skills` lists loaded skills and `/<skill-name>` invokes one. It follows symlinked skill folders and picks up changes under `~/.claude/skills/` without a restart (a brand-new top-level skills dir needs `/reload-skills`). Used in README "Using the skills". | https://code.claude.com/docs/en/skills | 2026-09-26 |
| Antigravity: loaded skills are shown under Customizations in the agent side panel, `/<skill-name>` invokes one, and the agent picks skills automatically from their descriptions. Used in README "Using the skills". | https://antigravity.google/docs/skills/ | 2026-09-26 |
