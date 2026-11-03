---
name: <skill-name>
description: Use when <concrete triggers: tasks, file names, tools, commands, error symptoms>. Not for <adjacent area> (use <other-skill>).
metadata:
  version: "0.1.0"
  last-verified: "<YYYY-MM-DD>"
---

# <Skill Title>

<One or two sentences: what this skill does.>

## When to use

- <Specific trigger>
- <Specific trigger>

Not for: <area> (use `<other-skill>`).

## Defaults

Apply these without asking. Deviate only if the project already does it differently (say so) or the user asks.

- <Firm default and the reason for it>

## Workflow

1. <Step>
2. Before pinning or pulling any image, action or version, confirm it's current and maintained (search the web). Record it in `references/sources.md`.
3. <Step>

## Requires confirmation

Stop and confirm with the user before any of these:

- <Destructive or remote-affecting command/action>

## Verification

Run these and report the actual output before calling the work done:

- <Command or check>

## Examples

Good:
<example>

Bad:
<example, and why it's wrong>

## References

Load these only when the task needs them:

- `references/sources.md`: external facts this skill relies on, with the date each was checked
- `references/<topic>.md`: <when to read it>
