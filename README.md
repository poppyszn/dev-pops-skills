# dev-pops-skills

**My DevOps best practices, packaged as agent skills, so an AI agent builds infrastructure the way I would.**

Ask an agent to "dockerize this API", "add CI", or "host this SPA on S3 and CloudFront" and you usually get something that works once and that you wouldn't run in production: unpinned images, long-lived cloud keys, `latest` tags, a deploy that can't be rolled back. These skills hold the agent to a fixed set of defaults instead. The templates are copied rather than improvised, risky steps stop and ask first, and every task ends with checks whose output is shown, not claimed.

What makes it different from a pile of prompts is that the skills are **kept correct**. Every external fact (an image tag, an action version, whether a project is archived) is checked online and recorded with its source and date. A validator enforces one written standard on every pull request. A weekly job opens an issue when a pinned version goes stale. Bugs found in real deployments go back in as reproducible findings. Most skill collections rot silently; this one is built not to.

It works with Claude Code and Antigravity, and with any agent that supports the open [Agent Skills](https://agentskills.io/specification) format.

> **This is opinionated on purpose.** The defaults are mine: Node/TypeScript, Docker Compose, GitHub Actions, GHCR, AWS with Terraform. If your opinions differ, fork it and change the defaults. The skills are small enough to read in an afternoon, and the `skill-authoring` skill walks an agent through changing them to your rules.

## What's in it

| Skill | The agent uses it to… |
|---|---|
| [docker](skills/docker/SKILL.md) | write Dockerfiles and compose stacks (dev, deploy, production host) for Node APIs, SPAs, Next.js and Nitro; local S3 with Adobe S3Mock |
| [cicd](skills/cicd/SKILL.md) | build GitHub Actions CI, push images to GHCR, deploy over SSH, ship production (S3 + CloudFront web, Docker host servers), run migrate and seed jobs |
| [terraform](skills/terraform/SKILL.md) | write AWS infrastructure from hand-written modules (EC2, ECS behind an ALB, static site), with GitHub OIDC deploy roles and production, staging and development kept identical |
| [security](skills/security/SKILL.md) | add gitleaks, dependency audit, Trivy and opt-in CodeQL; harden workflows and containers; handle secrets |
| [scripting](skills/scripting/SKILL.md) | write shell scripts and Makefiles that are quoted, fail fast and behave the same over SSH and in CI |
| [project-infra](skills/project-infra/SKILL.md) | set up or audit a whole repo at once, with the pieces above wired together |
| [skill-authoring](skills/skill-authoring/SKILL.md) | create, change and audit the skills themselves, to the same rules |

## A few of the defaults

These are applied without asking, unless the project or you say otherwise:

- **No long-lived cloud keys.** Deploys use GitHub OIDC, with the role pinned to one GitHub Environment.
- **Everything is pinned.** Images to a tag, actions to a version, SSH host keys to a known fingerprint.
- **Deploys are by commit.** The host runs the image tagged with the commit SHA, so a rollback redeploys an existing image instead of rebuilding.
- **Single-page apps are not hidden behind a catch-all error page.** A missing JavaScript file stays a 404 instead of returning the app shell with a 200.
- **Local S3 is Adobe S3Mock.** MinIO's community edition is archived.
- **Nothing destructive happens unconfirmed.** Deleting volumes, pushing images, deploying and touching secrets all stop and ask first.

## Quick start

Install once. The skills are linked, not copied, so editing them here updates every agent.

```bash
git clone https://github.com/poppyszn/dev-pops-skills
cd dev-pops-skills
./scripts/install.sh all      # Claude Code + Antigravity
```

Then open any project and ask in plain words. The agent matches your request against each skill's description and loads the right one:

| You say | It loads |
|---|---|
| "Set up Docker, CI and a develop deploy for this repo" | project-infra |
| "Audit this repo's infra against the templates" | project-infra |
| "Dockerize this NestJS API with Postgres" | docker |
| "Why is this workflow failing?" | cicd |
| "Add secret and CVE scanning" | security |
| "Host this SPA on S3 and CloudFront" | terraform |

To force one, name it: `/project-infra set up this repo`. Check they're loaded with `/skills` in Claude Code, or **Customizations** in Antigravity.

Other install options:

```bash
./scripts/install.sh claude                # one agent only
./scripts/install.sh --project ~/code/app  # one project only (add the links to its .gitignore)
./scripts/install.sh --uninstall all       # removes only links that point at this repo
```

Claude Code can also install it as a plugin: `/plugin marketplace add /path/to/dev-pops-skills`, then `/plugin install dev-pops-skills@dev-pops`.

For an agent with no skill-loading mechanism, only a static instructions field, `./scripts/export-portable.sh skills/docker` flattens a skill into one pasteable document. `--check` tells you when the pasted copy has drifted.

## What happens when you ask

1. The agent loads the matching skill and **inspects your project first**.
2. It tells you which templates it plans to use, **copies them verbatim** and edits only the marked spots.
3. It **checks versions online** (image tags, action versions, whether a project is archived) instead of trusting memory.
4. It **stops and asks** before anything destructive or remote.
5. It runs the skill's **verification checks** and shows you the output.
6. It ends with what it used and what only you can provide: secrets, hostnames, DNS.

It never commits for you. If a template doesn't fit your project, the agent fixes your project minimally and files a write-up in [`contributions/`](contributions/), so the fix can be reviewed and applied to the skill later.

## Does it actually work?

Two pieces of evidence, both limited and both in the repo:

- **A before/after.** [`docs/demo/dockerize-api/`](docs/demo/dockerize-api/README.md) runs one prompt ("dockerize this NestJS API with Postgres") with and without the `docker` skill and scores both against a 14-point checklist: 11 without the skill, 13 with it. The gap is modest on this prompt, and the page says why.
- **A trigger test.** [`evals/triggers.json`](evals/triggers.json) holds 31 prompts and the skill each should load (including four that should load none). `./scripts/eval-triggers.sh --lint` checks the dataset in CI; `--run` asks a real agent each prompt and reports which skill loaded. The live run needs a logged-in CLI, and hasn't been run against these skills yet.

Two short write-ups of bugs these skills now avoid: [the single-page app that never returns a 404](docs/writing/the-spa-that-never-404s.md) and [the first deploy that couldn't follow its own runbook](docs/writing/deploy-clone-into-a-directory-that-exists.md).

## How the skills are built

Every skill follows [one standard](skills/skill-authoring/references/standard.md), enforced by a validator that runs on every pull request:

- A description that says **"Use when…"** and names its neighbours with **"Not for…"**, so the right skill triggers.
- **Fixed defaults**, **risky actions that need confirmation**, **verification checks**, and **good and bad examples**.
- A **semver version and a changelog**. A changed default is a major bump.
- **Templates in `assets/`**, with a vendored-copy check that fails when a copy drifts from its source.
- **External facts in `references/sources.md`**, each with a URL and the date it was checked. A skill not re-checked in 90 days is flagged, and a weekly workflow opens an issue when a pinned image or action goes stale.

```bash
./scripts/validate-skills.sh               # all skills
./scripts/validate-skills.sh skills/docker # one skill
```

CI (`.github/workflows/validate.yml`) also runs the trigger-dataset and link checks, `actionlint` over every workflow template, `docker compose config` over every compose template, a gitleaks scan of the full history, and `terraform validate` for every environment kind.

To add or change a skill, ask an agent: "make a skill for X" or "audit the skills". The `skill-authoring` skill interviews you, checks online, writes it, validates it and shows you the diff.

## Layout

```
skills/<name>/
  SKILL.md           frontmatter + core workflow, loaded when triggered
  CHANGELOG.md
  references/        detail loaded on demand; sources.md holds the dated external facts
  assets/            templates to copy verbatim
evals/               the trigger dataset and the before/after checklist
contributions/       open findings from real projects; completed/ holds the applied ones
roadmap.md           planned work and pending decisions
docs/demo/           the before/after run, with its outputs
docs/writing/        short write-ups of bugs found in real deployments
docs/history/        design rationale from before this repo existed
scripts/             install, validate, export, evals, and the lint and asset checks CI runs
.github/             this repo's own CI, release, Dependabot and the weekly freshness audit
AGENTS.md            instructions for any agent working in this repo (CLAUDE.md imports it)
```

## Status

The skills are in daily use on my own projects, and the templates come from setups that run in production. The stack is deliberately narrow: Node/TypeScript only, with PHP, Python and Kubernetes listed on the [roadmap](roadmap.md) but not built. Whether an agent *triggers* the right skill is tested by [`evals/`](evals/triggers.json), but that test hasn't been run live against these skills yet, so treat trigger reliability as unmeasured.

Contributions are welcome as issues describing a gap, or as pull requests that follow [`AGENTS.md`](AGENTS.md).

## License

[MIT](LICENSE).
