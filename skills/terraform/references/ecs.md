# ECS on EC2 template

Assets: `assets/modules/{ecs_cluster,ecs_instances,ecs_capacity_provider,ecs_service,ecs_task,alb,ecr,github_oidc,security_group}`, `assets/environments/ecs/`, `assets/github-actions/deploy-ecs.yml`.

Copy all nine modules and the environment files (see `references/layout.md`), then replace the markers in each `terraform.tfvars`: `<PROJECT>`, `<REGION>`, `<GITHUB_ORG>`, `<GITHUB_REPO>`.

## Shape

```
internet -> ALB (public) -> target group (instance targets) -> ECS service (bridge networking, dynamic host ports)
                                                                   ^ capacity provider -> Auto Scaling group of ECS-optimized instances
ECR repository  <- GitHub Actions (OIDC role) -> registers task definitions, runs one-off tasks, updates the service
```

`environments/*/main.tf` is wiring only. The two security groups make the ALB accept web traffic and the instances accept traffic only from the ALB, in the ephemeral port range `32768-65535` that dynamic host ports use.

## Why it is shaped this way

| Choice | Reason |
|---|---|
| ECS-optimized **Amazon Linux 2023** AMI from an SSM parameter | the Amazon Linux 2 variant reached end of life on 2026-06-30; the parameter always resolves to the current image |
| `protect_from_scale_in = true` on the ASG, `managed_termination_protection = "ENABLED"`, `managed_scaling` | managed termination protection only works together with managed scaling and instance scale-in protection |
| `managed_draining = "ENABLED"` | instances are drained before the ASG terminates them |
| `AmazonECSManaged` tag declared on the ASG | ECS adds it when the ASG joins a capacity provider; declaring it stops Terraform removing it |
| `ignore_changes = [desired_capacity]` on the ASG | ECS managed scaling owns the capacity once the provider is attached |
| `replace_triggered_by` on the cluster/provider association | a capacity provider cannot be deleted while associated with a cluster |
| `ignore_changes = [task_definition]` on the service | CI registers new revisions; Terraform must not roll the service back to the one it created |
| `depends_on = [module.alb, module.ecs_capacity_provider]` on the service | the target group must be on a listener, and the provider associated, before the service uses them |
| Deployment circuit breaker with rollback | a failing deploy rolls back by itself |
| IMDSv2 required on the launch template, Session Manager on the instances | no SSH port; instances carry only the SSM and ECS agent policies |
| Execution role vs task role | the execution role pulls images, writes logs and reads secrets; the task role is what the application runs as and gets `task_role_policy_arns` |
| `ecs_task` for migrations and seeds | one-off task definitions share the service's roles and log group, run with `aws ecs run-task`, and CI swaps in the new image first |
| Immutable ECR tags, scan on push, lifecycle policy | images are tagged with the commit SHA; old and untagged images expire |

## HTTPS

`certificate_arn = null` serves HTTP only. Set it to an ACM certificate ARN in the region and the ALB adds an HTTPS listener and redirects HTTP to it. Production should set it before real traffic.

## Limits of the template (use the module standard to go beyond)

- One service per ALB with one target group. A second service, path-based routing or a second listener rule needs new module work.
- The container instances run in the default VPC's public subnets; the security groups are the barrier. A private-subnet + NAT layout is a new VPC module and a cost decision to raise with the user.
- Secrets read through `container_secrets` use the execution role's `secretsmanager:GetSecretValue` and `ssm:GetParameters`. A KMS-encrypted secret also needs `kms:Decrypt` on the key; add it to the module when the first one appears.
- The service uses `public.ecr.aws/nginx/nginx:stable` only so the first apply has something to run; CI replaces it.

## Verification specific to this template

`make check`, then `make plan ENV=<name>`. After the first apply, `terraform output` gives the values the deploy workflow needs (see `references/github-oidc-deploy.md`).
