---
name: project-infra
description: Use when setting up the infrastructure for a whole project at once, meaning several pieces wired together (Dockerfiles for multiple apps, compose stacks, CI, image builds, and deploy pipelines in one repo, often an npm-workspaces monorepo), or when auditing a repo's existing infra files as a set against the templates. Phrases like "set up this project's Docker and CI/CD", "dockerize and deploy this monorepo", or "check our infra against the templates". Not for a single Dockerfile or compose change (use docker), a single workflow (use cicd), or security scanning alone (use security).
metadata:
  version: "3.1.3"
  last-verified: "2026-09-26"
---

# Project infra

Assemble or audit a project's full infrastructure from the docker, cicd and security skills' templates, getting the wiring *between* files right, which is where hand assembly fails.

## When to use

- A new project needs Docker + CI + deploy together, or several apps dockerized in one repo
- An existing repo's infra files should be checked, as a set, against the templates
- A request spans more than one of docker, cicd and security

Not for: one isolated file (use `docker`, `cicd` or `security` directly).

## Defaults

Apply these without asking. Deviate only if the project already does it differently (say so) or the user asks.

- **Copy, never retype.** Every template file is copied with `cp`. "Adapt" means `cp` first, then edit exactly the named deltas, never a freehand rewrite. A file retyped from memory is a reconstruction, and it drops fixes.
- **The monorepo example is the answer key for wiring.** Before assembling several templates, read `references/monorepo-layout.md`, especially "What required real adaptation", and copy the *shape* of `assets/monorepo-layout/`.
- **Layout conventions:**
  - apps in `apps/<name>/` with their Dockerfile and entrypoint
  - root `compose.yml` with `context: .` for local dev
  - `docker/develop/` for the pull-based deploy stack
  - `docker/build-on-server/` only for the build-on-host shape (never the other way round)
- **Vendored actions and reusable workflows** go physically into `.github/actions/` and `.github/workflows/`, verbatim, with a header naming their source asset.
- **All the docker, cicd and security skill defaults apply** to each piece.
- **One reviewable change per gap** when fixing an existing repo, never one sweeping rewrite.
- **Existing working files are merged, never overwritten.** A project adapted for pnpm, Nx or per-app Dockerfiles isn't drift. Copying a template over it regresses it. Diff, then bring over only missing fixes.
- **CI and deploys follow the cicd defaults:** CI on PRs to the integration branch, and deploys gated by a light `verify` job, never by calling CI.
- **Git conventions travel with the scaffold.** Every project set up from here uses branches named `<type>/<slug>` (`fix/api-healthcheck-ipv6`, never `fix/ticket-12`) and Conventional Commits (`<type>(<scope>): <subject>`, imperative, why in the body, one logical change per commit). Copy `assets/monorepo-layout/.github/PULL_REQUEST_TEMPLATE.md` into the project's `.github/`. Since CI triggers on `pull_request` only, the PR *is* the gate — a project without a PR shape has no gate.
- **Never push to the integration branch or merge your own work.** A branch and a pull request is the end of the job.

## Workflow

Locate the sibling skills first: they sit next to this skill's real path (resolve symlinks). The skills repo root is two levels up.

1. **Detect the mode.** Look for any `Dockerfile`, `compose*.yml`, `.github/workflows/*.yml`, `.github/actions/*` or `Makefile`. None means **greenfield**, some means **audit**.

### Greenfield

2. **Map needs to templates.** List every piece the request needs and name the exact asset for each, from the docker, cicd and security skills' References tables. Tell the user the list.
3. **Copy the example's shape** when there are several apps: take `assets/monorepo-layout/` as the skeleton, and swap each app's files for the matching template. Apply only the adaptations `references/monorepo-layout.md` names:
   - build contexts
   - `COPY` paths
   - workspace build commands
   - compose service references
   - the two-action deploy chaining
4. **Vendor actions and reusable workflows** into `.github/` verbatim, and copy `assets/monorepo-layout/.github/PULL_REQUEST_TEMPLATE.md` alongside them.
5. **Check every pin is current** (image tags and action refs) as the docker and cicd skills describe. Fix stale pins in the project and file them as gaps.
6. **Verify** (see Verification).
7. **Manifest.** End with a short list:
   - templates used, with their asset paths
   - every substitution and why
   - what still needs the user:
     - secrets in the GitHub Environment, real hostnames, API URLs
     - **branch protection** with the CI jobs as required status checks on the integration branch, and pull requests required (this is what enforces both CI and the PR template)
     - whether to add opt-in CodeQL (public repo, or Code Security licence)

### Audit

2. **Inventory** every infra file in the repo.
3. **Map each to its closest template** and note files with no counterpart.
4. **Classify every difference** as exactly one of:
   - **deliberate customization** (leave it)
   - **drift or staleness** (missing healthcheck, `env:` routing, `printf '%q'`, permissions, a current pin: fix candidate)
   - **no template exists** (file it as a gap)
5. **Report the full list before changing anything.**
6. **Fix approved items one at a time,** each through Greenfield steps 3–7.

### Production on AWS

When the request is "set up production" (a web app on S3 + CloudFront, servers on a Docker host), map it onto these pieces and tell the user the list before copying anything:

| Piece | Where |
|---|---|
| Production compose, `preflight.sh`, `.env.example` | docker: `assets/node-api/compose.production.yml`, `preflight.sh`, `env.production.example` |
| Production deploy, manual migrate and seed workflows | cicd: `assets/workflows/deploy-production-nx.yml` (pnpm + Nx) or `deploy-production.yml` (npm), `migrate-production.yml`, `seed-production.yml` |
| Bucket, distribution, deploy role, the host | terraform (when that skill is installed): the `static-site` kind, the `docker_host` option of the `ec2` kind |
| OIDC role trust and SSH rules | security defaults |

Add these to the manifest's "needs the user", each of them a step only the user can take:

- the GitHub Environment `production` with required reviewers and deployment branches limited to `production`, and `production` as a protected branch
- applying the AWS side (`terraform apply` is a confirmation: show the plan first), the ACM certificate in us-east-1, and the DNS records (a CNAME for the site, an A record for the host)
- the deploy key pair, generated on the user's machine: public key into the Terraform values, private key into `SSH_PRIVATE_KEY`, plus `SSH_KNOWN_HOSTS`
- certbot on the host and the host's `.env` with real values (a deploy never creates it)
- the first-boot runbook in the terraform skill's `references/docker-host.md`

### Always

8. **File gaps, don't route around them.** When a template doesn't fit or is wrong, write a finding to the skills repo's `contributions/` folder (format in its `README.md`) as well as fixing the project. Leave out the client, project and repository names; describe the project's shape instead ("a single-app NestJS API").

## Requires confirmation

Stop and confirm with the user before any of these:

- Overwriting or deleting existing infra files in the project (audit fixes go one at a time, each approved)
- Anything the docker, cicd or security skills list under Requires confirmation (pushing images, triggering deploys, touching secrets or remote hosts, deleting volumes)

## Verification

Run these and report the actual output before calling the work done:

- `diff` every verbatim file against its source asset. Every difference must be a documented substitution. There's no third category.
- YAML parses for every workflow and action. `actionlint` if installed.
- `docker compose -f <file> config -q` for every compose file, with a `.env` present
- `sh -n` for every entrypoint, and `make help` for the Makefile
- If app source exists: `docker compose up -d --wait` on the local stack, with health reported
- The manifest (Greenfield step 7) is complete

## Examples

Good: assembly that follows the answer key.
```bash
cp <docker>/assets/node-api/Dockerfile apps/api/Dockerfile
# delta 1 (monorepo-layout.md "Build contexts"): context is the repo root
# delta 2 ("COPY paths"): COPY apps/api/entrypoint.sh ./entrypoint.sh
# delta 3 ("npm workspaces"): RUN npm run build --workspace=apps/api
```

Bad: each file looks right in isolation, but the wiring is wrong.
- `ssh-compose-deploy` pointed at a `working-dir` that `git-sync-deploy` never populated, because the two actions weren't chained (`git-sync-deploy` first, then `ssh-compose-deploy` at `<WORKING_DIR>/<repo>/docker/develop`)
- the per-app Dockerfile still uses `context: ../..` from the single-app template, inside a repo-root build

## References

Load these only when the task needs them:

- `assets/monorepo-layout/`: a complete assembled 3-app npm-workspaces repo (API, Next.js, SPA) with Makefile, compose stacks, CI, build/push, deploy, seed and security workflows, and `.github/PULL_REQUEST_TEMPLATE.md`. It has no app source. Copy its shape.
- `assets/monorepo-layout/.github/PULL_REQUEST_TEMPLATE.md`: the PR shape every project set up from here gets. Copied verbatim, no substitutions. Not a vendored copy of this repo's own template — that one asks about skill versions and `sources.md`, this one asks about deploy impact and rollback.
- `references/monorepo-layout.md`: what each file in the example came from and exactly what had to be adapted. Read before any multi-template assembly.
- `references/sources.md`: external facts, with the date each was checked.
