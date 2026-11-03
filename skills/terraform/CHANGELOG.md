# Changelog

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
