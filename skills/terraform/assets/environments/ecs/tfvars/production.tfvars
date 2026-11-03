# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------
region = "eu-west-1" # <REGION>: set here on purpose, there is no default in variables.tf

tags = {
  Project     = "<PROJECT>"
  Environment = "production"
}

# ---------------------------------------------------------------------------
# ECS cluster
# ---------------------------------------------------------------------------
cluster_name = "<PROJECT>-production"

# ---------------------------------------------------------------------------
# Container instances (Auto Scaling group capacity provider)
# ---------------------------------------------------------------------------
instance_type                     = "t3.small"
asg_min_size                      = 2
asg_max_size                      = 4
capacity_provider_target_capacity = 100

# ---------------------------------------------------------------------------
# Security groups
# ---------------------------------------------------------------------------
alb_security_group_name        = "<PROJECT>-production-alb-SG"
alb_security_group_description = "Allow HTTP and HTTPS inbound traffic to the ALB and all IPv4 outbound traffic"

alb_ingress_rules = {
  http  = { cidr_ipv4 = "0.0.0.0/0", from_port = 80, to_port = 80, ip_protocol = "tcp" }
  https = { cidr_ipv4 = "0.0.0.0/0", from_port = 443, to_port = 443, ip_protocol = "tcp" }
}

alb_egress_rules = {
  allow_all_ipv4 = { cidr_ipv4 = "0.0.0.0/0", ip_protocol = "-1" }
}

instance_security_group_name        = "<PROJECT>-production-ecs-instance-SG"
instance_security_group_description = "Allow traffic from the ALB to ECS container instances and all IPv4 outbound traffic"

instance_egress_rules = {
  allow_all_ipv4 = { cidr_ipv4 = "0.0.0.0/0", ip_protocol = "-1" }
}

# ---------------------------------------------------------------------------
# ALB
# ---------------------------------------------------------------------------
alb_name                       = "<PROJECT>-production-alb" # AWS caps load balancer names at 32 characters; the target group adds "-tg"
alb_enable_deletion_protection = true

# Set to an ACM certificate ARN to enable HTTPS and redirect HTTP to HTTPS.
# certificate_arn = "arn:aws:acm:<REGION>:<AWS_ACCOUNT_ID>:certificate/<CERTIFICATE_ID>"

# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------
service_name    = "<PROJECT>-production"
container_image = "public.ecr.aws/nginx/nginx:stable" # placeholder for the first apply; CI deploys the real image
desired_count   = 2

# Plain and secret environment variables for the service and one-off tasks.
# Secrets map an env var name to a Secrets Manager or SSM Parameter Store ARN.
container_environment = {}
container_secrets     = {}

# Managed policy ARNs for permissions the application itself needs.
task_role_policy_arns = []

# ---------------------------------------------------------------------------
# One-off tasks (migrations, seeds)
# Run with: aws ecs run-task --cluster <cluster> --task-definition <service>-<key>
# The commands below are placeholders; CI swaps in your real image first.
# ---------------------------------------------------------------------------
one_off_tasks = {
  migrate = { command = ["sh", "-c", "echo replace with your migration command"] }
  seed    = { command = ["sh", "-c", "echo replace with your seed command"] }
}

# ---------------------------------------------------------------------------
# ECR
# ---------------------------------------------------------------------------
ecr_repository_name = "<PROJECT>-production"
ecr_max_image_count = 30

# ---------------------------------------------------------------------------
# GitHub Actions (OIDC)
# ---------------------------------------------------------------------------
github_role_name = "<PROJECT>-production-github-actions-deploy"

# Only one GitHub OIDC provider can exist per AWS account. Exactly one environment
# in the account sets this to true (production); the others set false and must be
# applied after it. See references/github-oidc-deploy.md.
create_github_oidc_provider = true

# Only these workflows can assume the role. Match the branch the deploy workflow runs on.
# Repositories created after 2026-07-15 (or opted in) use the immutable form instead:
#   repo:<GITHUB_ORG>@<ORG_ID>/<GITHUB_REPO>@<REPO_ID>:ref:refs/heads/<BRANCH>
# Check the real sub claim before applying; see references/github-oidc-deploy.md.
github_allowed_subjects = [
  "repo:<GITHUB_ORG>/<GITHUB_REPO>:ref:refs/heads/main",
]
