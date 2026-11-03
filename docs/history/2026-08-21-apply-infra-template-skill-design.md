# `apply-infra-template` Skill Design

Date: 2026-08-21

## Problem

Agents (Claude Code sessions) working in *other* projects, even when
explicitly told to reference this templates repo, produce infra code
that deviates from the actual template files in two observed ways:

1. **Paraphrase instead of copy.** The agent reads a template file
   (Dockerfile, workflow YAML, entrypoint script) and, when writing the
   new file into the target project, regenerates it from its own
   impression of what it read rather than reproducing it exactly. The
   result looks similar but silently drops or alters details (a
   `HEALTHCHECK`, a `restart:` policy, a `printf '%q'` quoting fix, an
   `env:` routing pattern) that only exist because they fixed a real
   bug once. This is standard LLM generation behavior — even with the
   source in context, writing new text is a probabilistic reconstruction
   unless the agent is explicitly told to move bytes instead of write
   words.
2. **Botched assembly.** When a target project needs more than one
   template combined (a Node API + a frontend + CI/CD + a deploy
   pipeline), each individual file may look roughly right in isolation,
   but the wiring between them is wrong — build contexts, `COPY` paths,
   compose service names, workflow-to-action references — even though
   `examples/monorepo-layout/` already documents exactly what needs to
   change and why.

Discovery is *not* the problem here — the user already explicitly
references the templates repo when starting a session in a new project.
The failure is in execution fidelity once the agent has the reference.

## Goal

An agent that has been pointed at this templates repo produces infra
files that are **byte-identical to the source template** except for
deliberate, documented substitutions (`<ANGLE_BRACKET_PLACEHOLDER>`
markers, or the specific adaptations `examples/monorepo-layout/`
documents for multi-template assembly) — with no silent drift.

## Approach: a Skill, not more documentation

`CLAUDE.md` already documents what to do; the problem isn't missing
information, it's that prose gets *understood and reconstructed* rather
than *followed*. A Skill with an explicit, mechanical procedure is
followed step-by-step (this environment's existing Superpowers skills —
`brainstorming`, `writing-plans` — already demonstrate that skills get
followed with much higher fidelity than passive instructions). The core
mechanical fix is procedural, not informational: **copy via the `Bash`
tool's `cp`, never regenerate via `Write`** — this removes the
regeneration step entirely for anything that should be verbatim, so
there's no drift for the agent's generation to introduce.

## Location and personal use

- **Canonical source:** `skills/apply-infra-template/SKILL.md` inside
  this templates repo, versioned alongside the templates it governs.
  Written up as a finding and applied here the same way any other
  template fix is — this is infrastructure for using the repo
  correctly, so it belongs in the repo.
- **Personal activation:** a symlink at
  `~/.claude/skills/apply-infra-template` pointing at
  `<old-templates-repo>/skills/apply-infra-template`, so it fires
  in any project (not just when working directly in the templates
  repo) without duplicating content anywhere. A symlink was chosen over
  a copy specifically because a copy re-introduces the exact
  content-drift risk this skill exists to eliminate — there must be
  exactly one copy of the procedure.
- The templates repo's own `CLAUDE.md` gets a short pointer to the
  skill's existence, as a belt-and-suspenders fallback for any agent
  that ends up reading `CLAUDE.md` directly without the skill having
  fired.

## Skill content: the procedure

**Trigger description:** fires on any request to set up, add, or modify
CI/CD pipelines, Dockerfiles, docker-compose stacks, GitHub Actions
workflows, or deploy pipelines, in any project.

**Step 0: Detect mode.** Scan the target repo for existing infra files
(any `Dockerfile`, `compose*.yml`, `.github/workflows/*.yml`,
`.github/actions/*`, `Makefile`). None found → **greenfield mode**,
proceed to step 1. Some found → **audit mode**, go to "Audit mode"
below instead of step 1; audit mode still ends by going through steps
2-6 for each gap it decides to fill.

**Steps (greenfield mode):**

1. **Identify needs.** Read `<old-templates-repo>/CLAUDE.md`'s "I
   need to..." table and map the request's requirements onto specific
   template paths. If more than one template applies, this is a
   multi-template assembly (go to step 3 after step 2 for each piece).

2. **Single-file copy: `cp`, then targeted `Edit`.**
   - Copy the template file verbatim into the target project with the
     `Bash` tool's `cp` — never `Write` a freshly-generated version.
   - Read the source file's sibling `README.md` for what to change and
     why.
   - Use `Edit` to change *only* the specific `<ANGLE_BRACKET_PLACEHOLDER>`
     markers the README calls out. Do not touch anything else in the
     file, even things that look like they "could be improved" — that's
     scope creep this skill exists to prevent, not invite.
   - **Version freshness check.** If the copied file pins a version
     (a Dockerfile `FROM image:tag`, a workflow `uses: owner/repo@ref`),
     verify that pin is still current before finishing — check the
     image tag or action ref actually exists and isn't several versions
     behind (`WebFetch`/`WebSearch` the registry or the action repo's
     releases/tags). If it's stale or invalid, use the correct current
     version in the copied file instead of the stale template value,
     and treat the stale template pin itself as a gap — file it per
     step 6, the same as any other gap. Don't silently "fix forward" in
     just the target project without also flagging it back.

3. **Multi-template assembly: read the example first.**
   - Before copying anything, read
     `examples/monorepo-layout/README.md` in full, specifically its
     "What required real adaptation" section.
   - For each file, decide per that section whether it's a verbatim
     copy (`cp`) or needs a specific, documented adaptation (`cp` then
     `Edit` for exactly the deltas the example's README names — build
     context, `COPY` paths, workspace build commands, compose service
     references). Do not improvise wiring the example doesn't cover;
     if you hit a case it doesn't cover, that's a gap — see step 6.
   - GitHub Actions composite actions / reusable workflows are a
     special case: they must be vendored into `.github/actions/` /
     `.github/workflows/` verbatim (`cp`, not `Write`) because `uses:`
     resolution requires it — this isn't optional duplication, see
     `examples/monorepo-layout/README.md`'s explanation.

4. **Self-verify before finishing.**
   - For every file that should be verbatim: `diff` it against the
     source template. Any difference is either an intended, documented
     substitution or a bug in this step — there is no third category.
   - Run the same validation commands the templates repo documents for
     that file type (`bash -n` for shell scripts, `python3 -c "import
     yaml; yaml.safe_load(open(...))"` for YAML, `make help` for
     Makefiles) against the copied-in files in their new location.

5. **End with a manifest.** A short summary: which templates were used
   (with paths), what was substituted and why, and anything left as a
   placeholder that still needs the user's input (real hostnames,
   secrets, API URLs). This is what the user actually audits, not a
   full diff of the target repo.

6. **Gap found while applying a template?** If a template doesn't fit
   the target project, is wrong, or something needed doesn't exist yet,
   don't improvise a silent workaround scoped to just the target
   project. Write a finding to
   `<old-templates-repo>/contributions/` per that folder's existing
   convention (see `contributions/README.md`), the same way any other
   agent working in another project would. This is not optional when a
   real gap is hit — silently working around it in one project is
   exactly how the templates repo drifts from what people actually need.

**Audit mode** (target repo already has some infra files — e.g. a
project that adopted templates before this skill existed, or was set up
by hand):

1. **Full inventory.** List every existing infra file in the target
   repo (Dockerfiles, compose files, workflows, actions, Makefile).
2. **Map each to its closest template.** Using `CLAUDE.md`'s table and
   the file's own content/purpose, find the template it most resembles
   (or note it has no template counterpart at all).
3. **Diff and categorize each gap** into exactly one of:
   - **Deliberate customization** — a real, intentional project-specific
     difference (a different DB, a different port scheme). Leave it.
   - **Drift/staleness** — missing a `HEALTHCHECK`, missing `env:`
     routing, a stale version pin, missing `printf '%q'` quoting on
     values sent to a remote shell, etc. — something the template has
     that this file should have too. Candidate for a fix.
   - **No template exists** — this file does something none of the
     current templates cover. Not something to fix in the target repo;
     it's a candidate for step 6 (file it as a gap), since it may be a
     pattern worth the templates repo adopting.
4. **Report the full gap list before changing anything** — every
   "drift/staleness" item found, so the user can see the whole picture
   rather than a stream of individual edits with no overview.
5. **Fill gaps incrementally**, one at a time, each going through the
   same steps 2-6 as greenfield mode (`cp`/targeted `Edit`, self-verify,
   manifest entry). Do not do one sweeping rewrite of multiple files at
   once — each gap should be its own reviewable change.

## Version freshness: a companion self-audit workflow

The skill's apply-time freshness check (above) only catches drift when
a template actually gets applied somewhere. A template that just sits
unused in this repo for months can still go stale — a base image gets
a new stable tag, an action's version gets yanked or superseded — with
nothing to notice until the next time someone happens to copy it.

A new **operational** workflow (not a copy-paste template for other
projects — infrastructure for this repo itself, the same category as
the existing `.github/dependabot.yml`) lives at
`.github/workflows/version-freshness-audit.yml`:

- **Trigger:** weekly `schedule:` + `workflow_dispatch:`, matching the
  convention already established for `ci-cd/github-actions/security.yml`.
- **Checks:** every `FROM <image>:<tag>` across `docker/*/Dockerfile`
  (is this still a current stable tag for that image?) and every
  `uses: <owner>/<repo>@<ref>` across `ci-cd/github-actions/**/*.yml`
  and `.github/workflows/*.yml` (does that ref actually exist as a real
  tag/release for that action?) — this second check directly targets
  the exact bug class already caught once by hand
  (`aquasecurity/trivy-action@0.28.0` never having been a real tag).
- **On finding drift:** opens a GitHub Issue in this repo summarizing
  what's stale/invalid, rather than auto-fixing anything — a human (or
  an agent working in this repo) turns a real finding into either a
  direct template fix or a `contributions/*.md` file, the same review
  gate every other change in this repo already goes through. Auto-PRs
  were considered and rejected for now: opening an issue is simpler,
  needs fewer permissions, and keeps the human-review-before-merge
  property consistent with everything else in this repo.
- **Known prerequisite, not a blocker for building this:** this
  workflow can only actually run once this repo is pushed to GitHub
  with Actions enabled — it currently has no remote
  (`origin/main: gone`). Build and document it now; note the
  prerequisite in its own header comment so it's not a silent no-op
  mystery later.

## Testing / validation approach

This isn't code, so there's no test suite in the traditional sense.
Validate by dry run: exercise the skill against a fresh mock project
that needs 2-3 combined templates (e.g. a Node API + a frontend + CI +
a deploy pipeline), and confirm:

- Every file that should be verbatim is byte-identical to its source
  template (`diff` returns nothing) apart from documented substitutions.
- A deliberately-introduced paraphrase (hand-edit a copied file to
  differ from source without documenting why) is caught by the
  self-verification step, not shipped silently.
- Multi-template assembly wiring matches what
  `examples/monorepo-layout/` documents, not an improvised alternative.
- Audit mode: exercise it against a mock project seeded with 2-3 infra
  files that deliberately have known drift (missing `HEALTHCHECK`, an
  old action tag, unescaped `$` in a `.env.example`) — confirm the full
  gap list surfaces every seeded issue before any fix is applied, and
  that fixes land one at a time, not as a single bulk rewrite.
- Freshness check: confirm the skill actually flags a deliberately stale
  pin (e.g. an old `actions/checkout@v3`) rather than silently accepting
  whatever the template happens to have pinned.
- `version-freshness-audit.yml`: validated by running it manually
  (`workflow_dispatch`) once this repo has a GitHub remote — not
  something that can be verified purely by local syntax-checking, since
  its job is to call out to real registries/APIs.

## Out of scope

- Extending this to non-infra code style/methodology ("code like me"
  for general application code) — explicitly deferred; this skill is
  scoped to CI/CD, Docker, and deploy infra only, matching the
  templates repo's own scope.
- Automating the symlink setup with a script — a one-line `ln -s`
  documented in the skill's own README is sufficient; not worth
  building tooling for a single `ln -s` command.
- Enforcing step 6 (filing a contribution) via any technical mechanism —
  it's a procedural instruction to the agent, not something externally
  verifiable from outside the conversation.
- Auto-opening PRs (vs. issues) from `version-freshness-audit.yml` —
  deferred; issues are enough for now, PRs can be a later fast-follow
  once the issue-only version has proven itself.
- Pushing this repo to GitHub / enabling Actions — a real prerequisite
  for `version-freshness-audit.yml` to actually run, but it's the
  user's infrastructure decision to make separately, not part of this
  spec.
