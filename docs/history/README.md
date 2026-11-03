# History

Design specs and implementation plans from the old `templates` repo, carried over on 2026-09-26 as the rationale behind the templates now in `skills/`. They describe that repo's layout (`docker/<name>/`, `ci-cd/github-actions/`, `examples/`, `CLAUDE.md`), not this one's. Read them for *why* a template is shaped the way it is before changing it. Don't follow their paths or procedures.

| File | What it covers |
|---|---|
| `2026-08-13-templates-repo-design.md`, `2026-08-13-templates-repo.md` | Original design and build plan for the template library, including which real project each template was extracted from |
| `2026-08-13-build-on-server-deploy-design.md` | The build-on-server deploy shape (git-sync-deploy, `docker/build-on-server/`) |
| `2026-08-21-apply-infra-template-skill-design.md`, `2026-08-21-apply-infra-template-skill.md` | The old single skill that became `project-infra` (copy-never-retype, greenfield/audit modes) |
| `2026-08-21-affected-app-detection-design.md` | Unbuilt: change detection for multi-app CI/CD. See `roadmap.md` |
