data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ALB accepts public web traffic; container instances only accept traffic from the ALB.
module "alb_security_group" {
  source = "../../modules/security_group"

  name          = var.alb_security_group_name
  description   = var.alb_security_group_description
  vpc_id        = data.aws_vpc.default.id
  ingress_rules = var.alb_ingress_rules
  egress_rules  = var.alb_egress_rules

  tags = var.tags
}

module "instance_security_group" {
  source = "../../modules/security_group"

  name        = var.instance_security_group_name
  description = var.instance_security_group_description
  vpc_id      = data.aws_vpc.default.id

  # Dynamic host ports (bridge networking) come from the ephemeral range.
  ingress_rules = {
    from_alb = {
      referenced_security_group_id = module.alb_security_group.security_group_id
      from_port                    = 32768
      to_port                      = 65535
      ip_protocol                  = "tcp"
    }
  }
  egress_rules = var.instance_egress_rules

  tags = var.tags
}

module "ecs_cluster" {
  source = "../../modules/ecs_cluster"

  cluster_name = var.cluster_name

  tags = var.tags
}

module "ecs_instances" {
  source = "../../modules/ecs_instances"

  name                   = var.cluster_name
  cluster_name           = module.ecs_cluster.cluster_name
  instance_type          = var.instance_type
  subnet_ids             = data.aws_subnets.default.ids
  vpc_security_group_ids = [module.instance_security_group.security_group_id]
  min_size               = var.asg_min_size
  max_size               = var.asg_max_size

  tags = var.tags
}

module "ecs_capacity_provider" {
  source = "../../modules/ecs_capacity_provider"

  name                  = "${var.cluster_name}-ec2"
  cluster_name          = module.ecs_cluster.cluster_name
  autoscaling_group_arn = module.ecs_instances.autoscaling_group_arn
  target_capacity       = var.capacity_provider_target_capacity

  tags = var.tags
}

module "alb" {
  source = "../../modules/alb"

  name                       = var.alb_name
  vpc_id                     = data.aws_vpc.default.id
  subnet_ids                 = data.aws_subnets.default.ids
  security_group_ids         = [module.alb_security_group.security_group_id]
  enable_deletion_protection = var.alb_enable_deletion_protection
  certificate_arn            = var.certificate_arn

  tags = var.tags
}

module "ecs_service" {
  source = "../../modules/ecs_service"

  name                   = var.service_name
  cluster_arn            = module.ecs_cluster.cluster_arn
  capacity_provider_name = module.ecs_capacity_provider.capacity_provider_name
  target_group_arn       = module.alb.target_group_arn
  image                  = var.container_image
  desired_count          = var.desired_count
  environment            = var.container_environment
  secrets                = var.container_secrets
  task_role_policy_arns  = var.task_role_policy_arns

  tags = var.tags

  # The target group must be attached to a listener before the service can use it,
  # and the capacity provider must be associated with the cluster first.
  depends_on = [module.alb, module.ecs_capacity_provider]
}

# One-off jobs (migrations, seeds), run with `aws ecs run-task`. They share the
# service's roles and log group, and CI swaps in the new image before each run.
module "ecs_one_off_task" {
  source   = "../../modules/ecs_task"
  for_each = var.one_off_tasks

  name               = "${var.service_name}-${each.key}"
  image              = var.container_image
  command            = each.value.command
  cpu                = each.value.cpu
  memory             = each.value.memory
  execution_role_arn = module.ecs_service.task_execution_role_arn
  task_role_arn      = module.ecs_service.task_role_arn
  log_group_name     = module.ecs_service.log_group_name
  environment        = var.container_environment
  secrets            = var.container_secrets

  tags = var.tags
}

module "ecr" {
  source = "../../modules/ecr"

  name            = var.ecr_repository_name
  max_image_count = var.ecr_max_image_count

  tags = var.tags
}

# Lets GitHub Actions push images and deploy without long-lived AWS keys.
module "github_oidc" {
  source = "../../modules/github_oidc"

  name                 = var.github_role_name
  create_oidc_provider = var.create_github_oidc_provider
  allowed_subjects     = var.github_allowed_subjects
  ecr_repository_arns  = [module.ecr.repository_arn]
  cluster_name         = module.ecs_cluster.cluster_name
  service_name         = module.ecs_service.service_name

  task_definition_families = concat(
    [module.ecs_service.task_definition_family],
    [for task in module.ecs_one_off_task : task.task_definition_family],
  )

  pass_role_arns = [
    module.ecs_service.task_execution_role_arn,
    module.ecs_service.task_role_arn,
  ]

  tags = var.tags
}
