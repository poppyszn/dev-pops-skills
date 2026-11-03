<!--
Conventions: AGENTS.md -> "Git conventions".
Delete any section that genuinely does not apply, and say why in one line
rather than leaving it blank.
-->

## What changed

<!-- One or two sentences. One reviewable change per PR. -->

## Why

<!--
The reason, not the diff. If this exists because of a real bug, put the bug
here: what shipped, what broke, how it surfaced. Standard §11 wants that
story to end up next to the rule in a `references/` file — link the line
where it landed.
-->

## Skills touched

<!--
One row per skill. Every change under `skills/` bumps the version and adds a
dated CHANGELOG entry (standard §10): patch for wording and fixes, minor for
new guidance, major for a changed default or scope.
-->

| Skill | Version | Bump reason |
| --- | --- | --- |
|  | x.y.z -> x.y.z |  |

## Verification

<!--
The commands you ran and what they printed. "Should work" is not
verification; a check you could not run is listed under "Not verified"
below with the command the reviewer should run.
-->

```
$ ./scripts/validate-skills.sh
```

- [ ] `./scripts/validate-skills.sh` passes, with no new WARN
- [ ] Asset syntax checks for every asset touched (standard §11): `sh -n`, YAML parse / `actionlint`, `docker compose config -q`, `make help`
- [ ] Every vendored copy re-copied from its source asset, still byte-identical after the two header lines
- [ ] `last-verified` bumped **only** if an external fact was actually re-checked online, with the `sources.md` row to match

### Not verified

<!-- Anything you could not run, why, and the exact command to run instead. -->

## External facts checked

<!--
Standard §7: any image tag, action ref, package or API version in the diff
was confirmed online, and recorded in the skill's `references/sources.md` as
`fact | source URL | date checked`. List them, or write "none in this diff".
-->

## Gap findings

<!--
If this applies a `contributions/` finding, link it and confirm it was
renamed to `<name>.merged.md`, moved to `contributions/completed/`, and given
a status note saying what was applied where (standard §12).
-->

## Deviations

<!--
Anything here that goes against a rule in `AGENTS.md`, a skill's Defaults, or
`skills/skill-authoring/references/standard.md` — named, with the reason.
Silent deviation is the thing this section exists to prevent.
-->

## Rollback

<!--
How to undo this if it turns out wrong. For a skills change this is usually
"revert the commit and the version bump" — say so explicitly rather than
leaving it implied.
-->
