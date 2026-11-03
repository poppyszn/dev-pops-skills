# Security policy

## What counts

This repo ships templates and instructions that agents copy into other people's projects, so a security bug here is usually a template or a default that produces an insecure result: a workflow that can be script-injected, an overly broad IAM policy, a host that trusts the wrong key, a secret written somewhere it shouldn't be.

## Reporting

Please report privately, not in a public issue: use **GitHub's private vulnerability reporting** (the "Report a vulnerability" button under this repo's **Security** tab). Include the file, what goes wrong, and a minimal way to reproduce it.

Expect an acknowledgement within a week. This is a personal project, so there is no SLA, but a confirmed problem in a template is treated as a bug fix with a changelog entry, and the finding is credited unless you'd rather it wasn't.

## Not in scope

- Findings about a project you set up *from* these skills. Those belong to that project.
- Known, documented tradeoffs in `references/` files, unless the documentation is wrong.
