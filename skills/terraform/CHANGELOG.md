# Changelog

## 0.6.0 - 2026-11-04

- **Terraform pipeline template.** New `state_bucket` module (adopt an existing state bucket with `import` blocks, policy ARN built from the name so the plan is clean), `github_actions_role` module (OIDC role with validated subjects, reused for a read-only PR plan role and a no-IAM-write apply role) and `terraform-plan.yml` / `terraform-apply.yml` workflows, documented in `references/terraform-pipeline.md`. Includes the pre-checks that mattered in use: which account owns the bucket, an existing account-wide GitHub OIDC provider (look it up, never create), the repository's real `sub` format, whether the GitHub environment has any protection rules, and `aws-vault --no-session` for IAM.
- **`rds_postgres` module updated** from a real deployment: `publicly_accessible` (default false), `rotate_master_user_password` (off via `aws_secretsmanager_secret_rotation`, the provider's documented method), and the `ignore_changes` removal kept. `references/rds-postgres.md` now covers the rotation switch, the TLS default (`rds.force_ssl` is on from PostgreSQL 15), opening 5432 only on request, and how to price it from the AWS Price List API instead of from memory.
- Facts, doc URLs and dates added to `references/sources.md`.

## 0.5.0 - 2026-11-04

- **New `rds_postgres` module and `references/rds-postgres.md`.** One PostgreSQL instance (default `db.t4g.micro`, gp3, encrypted, not public, master password in Secrets Manager) with its subnet group, wired next to the `security_group` module in the default VPC. Written from the provider's docs and schema for 6.71.0; facts recorded in `references/sources.md`.
- **Docs before code is now explicit and sequenced.** A run building this module wrote the resource from memory and only afterwards checked the docs, which turned up an `ignore_changes = [engine_version]` that would have blocked a deliberate major upgrade. The default and the module-standard procedure now say: read the docs and dump the schema before writing, and a passing `plan` does not count as verification.
- Module-standard step 2 notes that the registry's resource pages return nothing to a plain fetch (read the provider's GitHub docs at the version tag instead) and that the schema dump needs a scratch folder, because an environment bound to the remote backend makes `init -backend=false` fail.
- New defaults: module labels in an environment's `main.tf` name the purpose (`billing_postgres_db`), with matching helper and output prefixes; fewer than three environments only when the user asks, in which case `make parity` is dropped.
- Inspect step: check the repository-root `.gitignore` for rules that exclude `*.tfvars` or the lock file, and confirm which AWS account the credentials (profile or `aws-vault`) point at before `init` or `plan`.

## 0.4.1 - 2026-11-03

- `docker-host.sh` starts with a `# shellcheck shell=bash` directive. It has no shebang on purpose (the module puts `#!/bin/bash` and the settings block in front of it), so shellcheck needs the shell named. shellcheck now blocks in this repo's CI.

## 0.4.0 - 2026-11-03

- **Providers download once per machine, not once per environment.** The project `Makefile` sets `TF_PLUGIN_CACHE_DIR` (default `~/.terraform.d/plugin-cache`, created if missing; an existing value wins). Terraform only uses a cached package that matches a lock-file checksum, so this stays safe with the committed lock files.
- **`make lock` writes the lock file once and copies it to every environment.** The parity check already required identical lock files, so locking each environment separately meant three runs of five platform downloads, with a parity failure in between.
- **Shared environment files are no longer duplicated per kind.** `providers.tf`, `backend.tf.example` and `backend.hcl.example` were byte-identical in `ec2`, `ecs` and `static-site`; they now live once in `assets/environments/common/`. The scaffold step copies `common/providers.tf` plus the kind's `shared/*.tf`; the scaffolded project is unchanged.
- **Leaner to load:** a shorter description (880 to 665 characters) and `SKILL.md` tightened without dropping a rule. Removed a Verification line that was wrong: `grep 'zh:\|h1:'` on the lock files prints hashes, not versions, and the parity check already compares the lock files.
- Checked: the `Makefile` run with GNU Make 3.81 and a stub `terraform` (`make help` renders; `make lock ENV=production` produces one identical lock file in all three environments and parity passes; the cache directory is created; a caller's `TF_PLUGIN_CACHE_DIR` is kept); `scripts/check-terraform-assets.sh` scaffolds all three kinds from the new layout and parity passes for each. `terraform validate` against the real provider runs in CI.

## 0.3.0 - 2026-11-03

- The "file gaps" step now says to leave out the client, project and repository names and describe the project's shape instead (standard §12 in skill-authoring).

## 0.2.0 - 2026-11-01

- **New: `static-site` template.** `static_site` module (private S3 bucket, origin access control, CloudFront distribution, a CloudFront Function for client-side routing, a security headers policy, versioning with a 30-day noncurrent tail) and `static_site_deploy_role` module (GitHub OIDC role scoped to the environment, with list/write/delete on the bucket and invalidation on the distribution), a `static-site` environment kind, and `references/static-site.md`. Built from a hand-made production setup after a review; the review's findings are recorded in the reference as the reasons behind each choice. Routing uses a function instead of 403/404 error responses so a missing `/assets/` file stays a 404.
- **New: Docker host.** `docker_host_user_data` module (settings block + `docker-host.sh`: updates, fail2ban, swap, deploy user, key-only sshd, Docker Engine, nginx + certbot) and `references/docker-host.md`, including the first-boot runbook. Only the deploy key's public half is on the host. All input is validated (hostnames, ports, key format) because it is written into a script that runs as root.
- **`ec2` module (additive, defaults unchanged):** `metadata_hop_limit` (1 or 2), `user_data` (ignored after create, because it only runs on first boot) and `elastic_ip`. **Fixes a gap in 0.1.0:** the hop limit was hard-coded to 1 and `ec2.md` said to keep it, which stops containers on a Docker host from reaching the instance role's credentials (AWS recommends 2 in container environments).
- **`ec2` environment kind:** new `metadata_hop_limit`, `elastic_ip` and optional `docker_host` variables, set in all three `tfvars` to the previous behaviour. SSH remains off by default; `docker_host` is the documented exception.
- The `ec2` and `static-site` kinds compose into one root (disjoint `site_*` names); `references/static-site.md` has the steps. Roadmap: deploy a Docker host over SSM instead of SSH.
- Checked with Terraform 1.15.8 and `hashicorp/aws` 6.71.0: `fmt`, parity and `validate` for `ec2`, `ecs`, `static-site` and a composed root; `terraform test` against a mocked provider for both new modules and the `ec2` changes; the deploy role's rendered policies; the routing function run in Node (14 cases); and the user-data settings block executed in a sandbox with 10 hostile inputs rejected.
- Not run: `terraform plan` or `apply` against a live account. The `minimum_protocol_version` values and the three-statement S3 permissions are marked `unverified` in `references/sources.md`.

## 0.1.0 - 2026-11-01

- Initial version. Built from two hand-written AWS projects (an EC2 instance, and ECS-on-EC2 behind an ALB with ECR and a GitHub OIDC deploy role) after a best-practice pass on both.
- Standard layout with three identical environments (production, staging, development): only `terraform.tfvars` and `backend.hcl` differ, enforced by `check-env-parity.sh` (also checks tfvars against declared variables). Region is set visibly in every `terraform.tfvars`, with no default in `variables.tf`.
- Modules shipped once under `assets/modules/`: `ec2`, `security_group`, `alb`, `ecr`, `ecs_cluster`, `ecs_instances`, `ecs_capacity_provider`, `ecs_service`, `ecs_task`, `github_oidc`. The `security_group` module is a single copy (the two source projects had drifted).
- `references/module-standard.md` gives the module rules and the procedure for resources the templates do not cover (read the locked provider's docs and schema, write the module, wire it into all three environments).
- Changes made to the source projects' code before it became assets: `required_version`, IMDSv2 and Session Manager on the EC2 module (SSH rule dropped), AMI from an SSM parameter, variable validations, S3 backend as partial configuration with native locking, lock-file hashes for five platforms, `actions/checkout` v7 in the deploy workflow.
- Unverified: the Canonical Ubuntu 26.04 SSM parameter path (documented, not resolved against a live account), and `make help` (no `make` available when written).
