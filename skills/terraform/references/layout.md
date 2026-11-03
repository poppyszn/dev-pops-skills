# Project layout and environments

Read this when scaffolding a project, adding an environment, or deciding where a value belongs.

## Layout

```
terraform/
├── Makefile                       ← assets/project/Makefile
├── .gitignore                     ← assets/project/gitignore
├── scripts/check-env-parity.sh    ← assets/project/check-env-parity.sh
├── modules/<name>/{main,variables,outputs}.tf
└── environments/
    ├── production/
    ├── staging/
    └── development/
        ├── providers.tf   ┐
        ├── main.tf        │ identical in every environment
        ├── variables.tf   │ (common/providers.tf + <kind>/shared/)
        ├── outputs.tf     │
        ├── backend.tf     ┘ (from backend.tf.example, once the state bucket exists)
        ├── terraform.tfvars   ← the only per-environment code: values (assets/environments/<kind>/tfvars/<env>.tfvars)
        ├── backend.hcl        ← per-environment state location, from backend.hcl.example
        └── .terraform.lock.hcl
```

Put `terraform/` at the application repository root (or `infra/` if the project already uses that name; keep the Makefile and scripts inside it). The environment folder is always plural `environments/`.

## What may differ between environments

| May differ | Must not differ |
|---|---|
| `terraform.tfvars` values (names, sizes, counts, flags, subjects) | any `.tf` file |
| `backend.hcl` (the state key) | the set of variables a `terraform.tfvars` sets |
| | the provider version in `.terraform.lock.hcl` |

`scripts/check-env-parity.sh` fails on a differing file, a differing set of tfvars variables, a tfvars entry that is not a declared variable, and a required variable that is not set. If an environment needs a resource the others do not, add it to all three behind a variable (`count = var.enable_x ? 1 : 0`, off by default) rather than forking `main.tf`.

## Where a value belongs

- Specific to an environment (region, names, sizes, counts, deletion protection, CIDRs, subjects): `terraform.tfvars`, visible, no default in the environment's `variables.tf`. The region is `eu-west-1` unless the user names another; it is written in every `terraform.tfvars` on purpose.
- A sensible default for any consumer of a module: the module's `variables.tf`.
- A secret: never in `terraform.tfvars`. Pass a Secrets Manager or SSM Parameter Store ARN (see `container_secrets`) and let the service read it at runtime.

Typical differences when filling the three files from the templates:

| Setting | production | staging | development |
|---|---|---|---|
| Instance size / count | larger, min 2 | smaller, min 1 | smallest that runs the workload, min 1 |
| `alb_enable_deletion_protection` | `true` | `false` | `false` |
| `desired_count` | 2 or more | 1 | 1 |
| ECR images kept | 30 | 15 | 10 |
| `create_github_oidc_provider` | `true` (the one creator) | `false` | `false` |
| GitHub subject branch | `main` | `staging` | `develop` |

These are starting points. Ask the user for real sizing; do not tune cost or capacity silently.

## Naming

`<PROJECT>-<environment>-<thing>` for everything that is named, because all three environments share one AWS account by default and many names (IAM roles and policies, security groups per VPC, ALBs per region, ECR repositories) must be unique there. Keep `<PROJECT>` short: load balancer and target group names are capped at 32 characters, and the target group adds `-tg` to the ALB name (`<PROJECT>-production-alb-tg` is 18 characters plus the project name).

If the user wants separate AWS accounts per environment, the code does not change: each environment gets its own credentials (profile or role chosen outside Terraform), its own backend bucket in `backend.hcl`, and `create_github_oidc_provider = true` in each account. State the assumption you made.

## Adding an environment or a resource

- **New environment:** copy every `.tf` file and the `.terraform.lock.hcl` from an existing environment folder, write its `terraform.tfvars` and `backend.hcl`, run `make init ENV=<name>` and `make check`. The parity script discovers it automatically.
- **New resource or module:** edit `main.tf`, `variables.tf` and `outputs.tf` the same way in every environment, add the values to every `terraform.tfvars`, then `make parity`. Procedure for the module itself: `references/module-standard.md`.
- **An EC2 instance and a static site (S3 + CloudFront) in one project:** start from the `ec2` kind and add the static-site blocks; the exact steps are in `references/static-site.md`. The two kinds use disjoint names so they compose.
- **Both an EC2 instance and an ECS service in one project:** extend the one root. Add the missing module blocks and variables to all three environments identically. Do not create a second root that forks the module copies.
- **Removing a resource:** removing a module block destroys real infrastructure. That is a confirmation, not a refactor.

## Makefile

`make help` lists the targets. `make check` is the gate (format, validate, parity) and needs no credentials. `make plan ENV=<name>` and `make apply ENV=<name>` need credentials; `apply` is a confirmation (see SKILL.md). `make lock` writes lock-file hashes for linux, macOS and windows so CI on any of them can `init`, and copies the file to every environment. The provider is downloaded once into a shared plugin cache, not once per environment (`references/state-and-backend.md`).
