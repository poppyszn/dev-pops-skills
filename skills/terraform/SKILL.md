---
name: terraform
description: Use when writing, reviewing, or debugging Terraform for AWS: *.tf files, terraform.tfvars, .terraform.lock.hcl, modules/ or environments/ folders, terraform init/plan/apply/validate/fmt, provider-version or state-lock errors, or setting up production, staging and development environments for an EC2 instance (optionally a Docker host behind nginx deployed over SSH), a single-page app on S3 + CloudFront, or an ECS-on-EC2 service (ALB, ECR, capacity provider), with GitHub Actions OIDC deploy roles. Also covers writing a new hand-written module for an AWS resource the templates lack, remote S3 state, and drift between environments. Not for Dockerfiles or compose (use docker), CI workflows other than the ECS deploy template (use cicd), secret scanning or CVE scanning (use security), shell scripts (use scripting), or setting up a whole multi-app project (use project-infra).
metadata:
  version: "0.2.0"
  last-verified: "2026-11-01"
---

# Terraform

Provision AWS infrastructure from hand-written modules, with three identical environments (production, staging, development), and handle resources the templates do not cover by following the same standard.

## When to use

- Adding or changing `.tf` files, `terraform.tfvars`, a module, or the `environments/` folders
- "Set up Terraform for an EC2 instance / an ECS service with a load balancer"
- Adding an environment, or a new AWS resource to an existing Terraform project
- `terraform init/plan/apply` failures, provider or lock-file problems, state lock errors, environments that no longer match

Not for: images and compose (`docker`), pipelines other than the ECS deploy template (`cicd`), scanning and secrets (`security`), shell scripts (`scripting`), whole-project setup across several apps (`project-infra`).

## Defaults

Apply these without asking. Deviate only if the project already does it differently (say so) or the user asks.

- **Hand-written modules only.** No registry modules. Provider `hashicorp/aws` pinned `~> 6.0`, `required_version = ">= 1.10"`.
- **Layout:** `terraform/modules/<name>/{main,variables,outputs}.tf` and `terraform/environments/{production,staging,development}/`. Every project has all three environments. Details in `references/layout.md`.
- **Environments are identical.** Everything in them is byte-identical except `terraform.tfvars` and `backend.hcl`. Differences are values, never code. `make parity` enforces it.
- **No environment-specific defaults in an environment's `variables.tf`.** The region (`eu-west-1`), names, sizes and counts are set visibly in `terraform.tfvars`. Defaults live in modules. Only optional toggles (null or empty) keep one.
- **Modules follow `references/module-standard.md`:** typed, described, validated variables; `tags` merged with `Name`; secure defaults; `for_each` over maps; no provider blocks or hard-coded regions, accounts or ARNs.
- **Secure by default:** encrypted volumes, IMDSv2 only, no SSH (Session Manager instead; a Docker host deployed over SSH opts in, see `references/docker-host.md`), deletion protection on in production, immutable ECR tags, GitHub OIDC instead of stored keys, least-privilege IAM with a `Sid` per statement.
- **Static sites are private S3 behind CloudFront**, routed by a CloudFront Function, never S3 website hosting and never distribution-wide 403/404-to-`index.html` error responses (they turn a missing asset into an HTML 200). The ACM certificate is requested in us-east-1 and passed in as an ARN. See `references/static-site.md`.
- **A host that runs containers sets `metadata_hop_limit = 2`**, or the containers cannot reach the instance role's credentials.
- **One AWS account for all environments** unless the project says otherwise. Names carry the environment (`<PROJECT>-<env>-…`). The GitHub OIDC provider is an account singleton: exactly one environment creates it.
- **Lock file committed** with hashes for every platform (`make lock`). State, plans and `.terraform/` are never committed (`gitignore` asset).
- **Remote state:** S3 with native locking (`use_lockfile`), configured through a per-environment `backend.hcl` so the `.tf` files stay identical. See `references/state-and-backend.md`.
- **Docs before code.** Read the docs for the provider version in the lock file before writing or changing a resource's arguments, and treat deprecation warnings as defects.

## Workflow

1. **Inspect.** Look for an existing `terraform/` folder, the `terraform version`, the lock file, the backend, and which environments exist. If the task spans several apps and pipelines, switch to `project-infra`.
2. **Pick the template:** `ec2` for a single instance (with the `docker_host` block when it runs compose behind nginx), `static-site` for a single-page app on S3 + CloudFront, `ecs` for a service behind an ALB on EC2 capacity (see References). An instance plus a site composes `ec2` and `static-site` in one root (`references/static-site.md`). If none fits, go to step 6.
3. **Scaffold by copying.** `cp -r <skill>/assets/modules/<needed> terraform/modules/`; for each environment copy the four `shared/*.tf` files and `tfvars/<env>.tfvars` as `terraform.tfvars`; copy `project/Makefile`, `project/check-env-parity.sh` (to `scripts/`) and `project/gitignore` (as `.gitignore`). Never retype a template.
4. **Fill the markers.** Replace every `<ANGLE_BRACKET>` marker. Only touch `terraform.tfvars` per environment, then run `make parity`.
5. **Check versions are current** (search the web or the registry): provider and Terraform releases, AMI parameter paths, action versions in the deploy workflow. Record new facts in `references/sources.md`.
6. **Beyond the examples.** For a resource, service or pattern with no template, follow the procedure in `references/module-standard.md`: look for an existing module, read the locked provider's docs, write a module to the standard, then wire it into **all three** environments identically.
7. **Existing project (review or fix).** Compare it with the templates and the standard. Classify each difference as deliberate (leave it), drift (propose a fix), or uncovered. Report the list before editing. Never reshape state-bearing resources without confirmation.
8. **Verify** (see Verification).
9. **File gaps.** If a template is wrong or missing something, fix the project minimally and write a finding to the skills repo's `contributions/` folder (format in its `README.md`).

## Requires confirmation

Stop, state exactly what will run and what it affects, and wait for a yes before any of these:

- `terraform apply` or `destroy`, any `-auto-approve`, `-target`, `-replace`, `-refresh-only` with changes
- Any `terraform state` subcommand, `import`, `-migrate-state`, `-reconfigure`, `force-unlock`, `-lock=false`
- Creating the state bucket, or changing the backend of an environment that has state
- A plan that destroys or replaces an instance, load balancer, cluster, repository, role or any stateful resource
- Changing `deletion_protection`, `force_delete`, `prevent_destroy`, or the GitHub OIDC provider (one per account)
- Changing a CloudFront distribution's aliases, certificate or origin, or the DNS record that points at it (live traffic)
- Opening or widening a security group rule for port 22, or detaching or replacing an Elastic IP (the address DNS points at)
- Deleting or editing state files, or running Terraform against credentials for an account the user did not name

`plan` and the checks below are read-only and run without asking. Say which account and region a `plan` will contact.

## Verification

Run these from `terraform/` and report the actual output before calling the work done:

- `make check` (runs `terraform fmt -check -recursive`, `terraform validate` in every environment, and `scripts/check-env-parity.sh`)
- `terraform plan` for each environment touched, with the resource counts shown. If credentials are missing, say the plan was not run; never claim success.
- `grep -n 'zh:\|h1:' environments/*/.terraform.lock.hcl` shows the same provider version in every environment
- No `default =` left on environment-specific variables, and no value in `.tf` files that belongs in `terraform.tfvars` (`grep -rn eu-west-1 environments/*/*.tf` is empty)
- `git status` shows no `*.tfstate`, `*.tfplan` or `.terraform/`
- Static site, after the first deploy: the smoke test in `references/static-site.md`. A missing `/assets/` file must return 404, not 200.
- Docker host: `bash -n` on `assets/modules/docker_host_user_data/docker-host.sh`, and a public key (never a private one) in `docker_host.deploy_public_key`

## Examples

Good: a new resource handled the standard way.
```text
Need an S3 bucket for uploads -> no template -> read the aws_s3_bucket docs for the locked
provider -> write modules/s3_bucket/{main,variables,outputs}.tf (encryption, public access
block, versioning, tags) -> add a module block to environments/*/main.tf (identical in all
three) -> add its variables to variables.tf and values to every terraform.tfvars -> make check
```

Bad: shortcuts that cause drift or hidden behaviour.
```hcl
module "vpc" { source = "terraform-aws-modules/vpc/aws" }      # registry module, not hand-written
variable "region" { default = "eu-west-1" }                     # value hidden in variables.tf, not in tfvars
ami = "ami-06468be052a4195a6"                                   # one region's image ID; goes stale
```
Also bad: adding a resource to `environments/production/main.tf` only. The next `make parity` fails, and staging no longer predicts production.

## References

Load these only when the task needs them:

| Need | Assets | Read first |
|---|---|---|
| Project layout, environment values, naming, adding an environment | `assets/project/` (`Makefile`, `check-env-parity.sh`, `gitignore`), `assets/environments/*/shared/` | `references/layout.md` |
| A resource or pattern with no template | `assets/modules/` as examples | `references/module-standard.md` |
| One EC2 instance with a security group | `assets/modules/{ec2,security_group}`, `assets/environments/ec2/` | `references/ec2.md` |
| ECS service on EC2 behind an ALB, with ECR and migrations | `assets/modules/{ecs_*,alb,ecr,security_group}`, `assets/environments/ecs/` | `references/ecs.md` |
| One EC2 instance that runs compose behind nginx, deployed over SSH | `assets/modules/docker_host_user_data` (with `docker-host.sh`), the `ec2` module's `metadata_hop_limit`, `elastic_ip` and `user_data` | `references/docker-host.md` |
| A single-page app on S3 + CloudFront, with its GitHub deploy role | `assets/modules/{static_site,static_site_deploy_role}`, `assets/environments/static-site/` | `references/static-site.md` |
| GitHub Actions deploying to ECS or publishing a static site without stored keys | `assets/modules/github_oidc`, `assets/github-actions/deploy-ecs.yml`, `assets/modules/static_site_deploy_role` | `references/github-oidc-deploy.md` |
| Remote state, backend migration, lock file | `assets/environments/*/shared/backend.*.example` | `references/state-and-backend.md` |

- `references/sources.md`: external facts (versions, doc claims) with the date each was checked.
