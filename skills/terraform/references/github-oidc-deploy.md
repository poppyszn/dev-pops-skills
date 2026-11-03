# GitHub Actions deploy role and workflow

Assets: `assets/modules/github_oidc`, `assets/github-actions/deploy-ecs.yml`. Part of the ECS template; the role lets a workflow push images and deploy without stored AWS keys.

## The OIDC provider is an account singleton

AWS allows one GitHub OIDC provider per account. The module takes `create_oidc_provider`:

- exactly one environment in the account sets `create_github_oidc_provider = true` (production in the templates) and creates it;
- the others set `false` and look it up with a data source, so they must be applied **after** the creating environment, or the lookup fails;
- with separate AWS accounts per environment, every environment sets `true`.

Deleting or recreating the provider breaks every role that uses it: it is a confirmation.

## Subjects: check the real `sub` claim

`github_allowed_subjects` decides who can assume the role. It is matched with `StringLike` against the token's `sub` claim, and the audience must be `sts.amazonaws.com`.

- Repositories created before 2026-07-15: `repo:<ORG>/<REPO>:ref:refs/heads/<BRANCH>` (or `...:environment:<ENV>`).
- Repositories created on or after 2026-07-15, or opted in: the immutable form `repo:<ORG>@<ORG_ID>/<REPO>@<REPO_ID>:ref:refs/heads/<BRANCH>`.

Do not guess. Run the `github/actions-oidc-debugger` action once in the repository, or read the repository's OIDC settings, and copy the printed `sub` into `terraform.tfvars`. A wrong subject shows up as "Not authorized to perform sts:AssumeRoleWithWebIdentity". Never use a bare `repo:<ORG>/<REPO>:*` wildcard for production: it lets any branch or pull request deploy.

Use one subject per environment, matching the branch that environment's workflow runs on (production `main`, staging `staging`, development `develop`).

## What the role may do

Scoped to this environment's resources: log in to ECR and push to the environment's repository; register and describe task definitions (these actions cannot be resource-scoped); update and describe the one service; `RunTask` on the service's task definition families, restricted to the cluster by condition; describe and stop tasks in the cluster; `iam:PassRole` on the two task roles only, with `iam:PassedToService = ecs-tasks.amazonaws.com`.

## The workflow

Copy `assets/github-actions/deploy-ecs.yml` once per environment to `.github/workflows/deploy-<environment>.yml` in the **application** repository and replace every `<ANGLE_BRACKET>` marker from `terraform output` and the environment's `terraform.tfvars` (the comments name the source of each). It builds and pushes an image tagged with the commit SHA, runs the migration task and waits for it to finish, optionally runs the seed task on a manual run, then deploys the service and waits for stability. `permissions: id-token: write` is required for the OIDC token.

Migrations run while the old tasks still serve traffic, so they must be backwards compatible. Re-check the action versions in the workflow when you copy it (the weekly audit covers the pins inside this skill's assets).

## The static-site role

`assets/modules/static_site_deploy_role` (used by the `static-site` environment kind, see `references/static-site.md`) creates a second kind of deploy role with the same provider create-or-lookup rule and the same subject validation, scoped to publishing a built site: list the bucket, write and delete objects in it, create and read invalidations on one distribution. Its subject uses the **environment** form (`repo:<ORG>/<REPO>:environment:<ENV>`): a job that declares `environment:` gets that `sub` whatever branch it runs on, so the role is tied to the environment and its protection rules. The module rejects a subject that ends in `:*`.

If a root has both this role and the ECS `github_oidc` module, only one of them may create the provider: set `site_create_github_oidc_provider = false` and apply the ECS environment first.
