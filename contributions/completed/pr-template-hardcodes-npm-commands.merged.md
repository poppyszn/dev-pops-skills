# PR template hardcodes `npm run` commands

> **Status: applied 2026-11-04** in project-infra 3.1.4, using the finding's second option: the checklist line now names "the project's lint, test and build commands", so the template stays verbatim with no substitution marker.

**Where it was found:** a pnpm + Nx monorepo (three apps: a NestJS API, a
Node SSR storefront, a static SPA) set up with project-infra, copying
`assets/monorepo-layout/.github/PULL_REQUEST_TEMPLATE.md`.

**Confirmed bug in this repo's template today:** yes, for any non-npm project.

**Reproduction**

```sh
grep -n 'npm' skills/project-infra/assets/monorepo-layout/.github/PULL_REQUEST_TEMPLATE.md
# 27:- [ ] `npm run lint`, `npm test` and `npm run build` pass locally, not only in CI
```

The project-infra skill says the template is "copied verbatim, no substitutions",
but a pnpm project has no reason to run `npm`, so the checklist line is wrong
the moment it is copied. The agent had to edit it by hand, which contradicts
"verbatim".

**Suggested fix:** make that line a marker the same way the workflows use
`<INTEGRATION_BRANCH>`, e.g. `<PKG_MANAGER> run lint` / `test` / `build`, and
list the substitution in project-infra's Greenfield step 4. Alternatively
reword to "the project's lint, test and build commands pass locally".
