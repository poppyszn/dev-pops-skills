# Interview questions

Ask these before writing or substantially changing a skill. Ask them in one batch and skip any the user has already answered. Don't draft until you have the answers. If the user says "your call" on a question, propose an answer and get a yes.

## New skill

1. **Scope:** What tasks should this skill handle? Give 3–5 things you'd actually ask an agent to do.
2. **Out of scope:** What should it *not* handle, and which existing skill (if any) owns that?
3. **Triggers:** Which files, tools, commands or error messages signal this domain?
4. **Defaults:** Which choices should it make without asking (tools, versions policy, style, structure)? Anything you never want it to do?
5. **Risky actions:** Which commands or actions in this domain are destructive or affect shared/remote systems and must be confirmed first?
6. **Verification:** How do you check the work is right? (build, lint, test, dry-run, health check)
7. **Examples:** Can you show or describe one good result and one bad result (something an agent got wrong before)?
8. **Environment:** Which platforms or versions must it support (e.g. macOS + Linux, a specific CI provider, cloud)?

## Editing an existing skill

1. What went wrong, or what's missing? Include the request that exposed it, if you have it.
2. Should the change alter a default or the scope (major), add guidance (minor), or fix wording (patch)?
3. Does it affect a neighbouring skill?

## Audit

No interview. Run the audit, report findings, then ask which fixes to apply.
