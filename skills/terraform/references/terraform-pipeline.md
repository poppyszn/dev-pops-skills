# Terraform pipeline: state bucket, GitHub roles and workflows

Assets: `assets/modules/{state_bucket,github_actions_role}`, `assets/github-actions/terraform-plan.yml`, `assets/github-actions/terraform-apply.yml`.

Use this to bring an existing state bucket under management and let a repository plan on pull requests and apply on merge without stored AWS keys. It is separate from the ECS deploy role in `references/github-oidc-deploy.md`: that role deploys an application, this one runs Terraform.

## 1. Check before writing

- **Credentials and account.** `aws sts get-caller-identity` must show the account that owns the state bucket; a 403 on the bucket usually means the wrong account. With `aws-vault`, IAM calls fail under the default session token (`InvalidClientTokenId`): run `aws-vault exec <profile> --no-session -- …` for anything that touches IAM, including `plan` on a root that has IAM resources.
- **Is there already a GitHub OIDC provider?** `aws iam list-open-id-connect-providers`. It is an account singleton; if it exists, look it up with `data "aws_iam_openid_connect_provider"` (by `url`) and never create or import it. Check its `ClientIDList` contains `sts.amazonaws.com`.
- **The repository's real `sub` format.** `gh api repos/<ORG>/<REPO>/actions/oidc/customization/sub` and the repository's `created_at`. `use_immutable_subject: false` means `repo:<ORG>/<REPO>:…`. Do not guess.
- **Does the GitHub environment gate anything?** `gh api repos/<ORG>/<REPO>/environments/<ENV>`. Empty `protection_rules` means merging to the branch applies with no approval. Tell the user; required reviewers are set in the repository settings (private repositories on a free plan may not have them).

## 2. Import the existing state bucket

`modules/state_bucket` mirrors a bucket as created by the usual setup: versioning, SSE-S3 (`blocked_encryption_types = ["SSE-C"]`), full public-access block, ownership controls and a deny-insecure-transport/old-TLS policy. Before writing it, read the live settings (`aws s3api get-bucket-versioning|encryption|policy|ownership-controls|public-access-block|tagging`) and make the module match them, so the plan imports without changing anything but tags.

- Add one `import` block per resource in the environment's `main.tf`: `to = module.<NAME>.aws_s3_bucket.this`, `id = var.state_bucket_name` (the same bucket-name id for versioning, encryption, public access block, ownership controls and policy). `plan` shows them as "will be imported"; the import happens on `apply`, which is a confirmation.
- Build the policy document's resource ARNs from the bucket **name**, not `aws_s3_bucket.this.arn`. The ARN is unknown until the import, which makes the policy document unknown and the plan show a bogus update.
- `prevent_destroy = true` is a literal on the bucket: it holds all the state. Removing it is a deliberate edit.
- After the first apply, delete the `import` blocks; they have done their job.
- The bucket's state lives in the bucket itself. That is fine once it exists; the first `init` needs the bucket to be reachable.

## 3. Roles

`modules/github_actions_role` creates one role trusted through the provider: audience `sts.amazonaws.com`, `sub` matched with `StringLike` against `allowed_subjects`, which the module rejects if empty or ending in `:*`. Instantiate it twice:

| Role | Subject | Permissions |
|---|---|---|
| plan | `repo:<ORG>/<REPO>:pull_request` | `ReadOnlyAccess` plus `s3:GetObject` on the state keys and `s3:PutObject`/`DeleteObject` on `*.tflock` (the lock file `use_lockfile` writes) |
| apply | `repo:<ORG>/<REPO>:environment:<ENV>` | `ReadOnlyAccess` plus what the resources need: state objects, bucket settings, and the service actions for the resources in the root |

The apply role has **no IAM write access**: a merged change cannot grant itself more permissions, so changes to roles and the provider are applied from a workstation. The roles do not exist until that first local apply.

Scope the apply role's service permissions from the AWS documentation for each resource, and say in the policy comments why a statement uses `"*"`. Known requirements:

- RDS with `manage_master_user_password`: `kms:DescribeKey`, `secretsmanager:CreateSecret`, `secretsmanager:TagResource`; add `secretsmanager:CancelRotateSecret` when rotation is switched off (see `references/rds-postgres.md`).
- Security groups: the `ec2:*SecurityGroup*` actions plus `ec2:CreateTags`/`DeleteTags`, with an `aws:RequestedRegion` condition.

These permissions were derived from documentation, not from a CI run. The first apply in CI may report an `AccessDenied`: widen by the missing action, not to a wildcard.

## 4. Workflows

Copy `assets/github-actions/terraform-plan.yml` and `terraform-apply.yml` to `.github/workflows/` and replace the markers (`<PLAN_ROLE_ARN>`, `<APPLY_ROLE_ARN>` from `terraform output`, `<ENVIRONMENT>`, `<GITHUB_ENVIRONMENT>`, `<REGION>`, `<TERRAFORM_VERSION>`). Re-check the pinned action majors (`actions/checkout`, `hashicorp/setup-terraform`, `aws-actions/configure-aws-credentials`) when you copy them.

- Plan runs on pull requests that touch `terraform/**`, apply on pushes to the main branch (and manually). Both need `permissions: id-token: write`.
- Apply plans to a file and applies exactly that plan. Both share one `concurrency` group and never cancel an in-flight run.
- To test the pipeline, open a pull request (the plan role is exercised) and merge it (the apply role is exercised). With no code change both report "No changes", which is enough to prove the roles.
