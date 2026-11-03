data "aws_region" "current" {}

# Task definition for a one-off job (migration, seed). Run it with `aws ecs run-task`;
# it is not attached to a service.
resource "aws_ecs_task_definition" "task" {
  family                   = var.name
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.image
      essential = true
      cpu       = var.cpu
      memory    = var.memory
      command   = var.command

      environment = [for name, value in var.environment : { name = name, value = value }]
      secrets     = [for name, value_from in var.secrets : { name = name, valueFrom = value_from }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = var.name
        }
      }
    }
  ])

  tags = var.tags
}
