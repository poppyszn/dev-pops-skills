data "aws_region" "current" {}

locals {
  secret_arns = values(var.secrets)
}

resource "aws_cloudwatch_log_group" "service" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role: lets ECS pull the image, write container logs and read secrets.
resource "aws_iam_role" "task_execution" {
  name               = "${var.name}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "secrets" {
  count = length(local.secret_arns) > 0 ? 1 : 0

  statement {
    actions   = ["secretsmanager:GetSecretValue", "ssm:GetParameters"]
    resources = local.secret_arns
  }
}

resource "aws_iam_role_policy" "secrets" {
  count = length(local.secret_arns) > 0 ? 1 : 0

  name   = "${var.name}-read-secrets"
  role   = aws_iam_role.task_execution.id
  policy = data.aws_iam_policy_document.secrets[0].json
}

# Task role: the identity the application code runs as. ECS Exec needs the
# ssmmessages permissions below.
resource "aws_iam_role" "task" {
  name               = "${var.name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "execute_command" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "execute_command" {
  count = var.enable_execute_command ? 1 : 0

  name   = "${var.name}-execute-command"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.execute_command.json
}

resource "aws_iam_role_policy_attachment" "task" {
  for_each = toset(var.task_role_policy_arns)

  role       = aws_iam_role.task.name
  policy_arn = each.value
}

resource "aws_ecs_task_definition" "task" {
  family                   = var.name
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.image
      essential = true
      cpu       = var.cpu
      memory    = var.memory

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = 0 # dynamic host port, registered with the target group by ECS
          protocol      = "tcp"
        }
      ]

      environment = [for name, value in var.environment : { name = name, value = value }]
      secrets     = [for name, value_from in var.secrets : { name = name, valueFrom = value_from }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.service.name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = var.container_name
        }
      }
    }
  ])

  tags = var.tags
}

resource "aws_ecs_service" "service" {
  name            = var.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = var.desired_count

  health_check_grace_period_seconds = var.health_check_grace_period_seconds
  enable_execute_command            = var.enable_execute_command

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    base              = 1
    weight            = 100
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  # Spread across AZs first, then pack onto as few instances as possible.
  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  ordered_placement_strategy {
    type  = "binpack"
    field = "memory"
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = var.tags

  # CI registers new task definition revisions and updates the service; Terraform
  # must not roll the service back to the revision it created.
  lifecycle {
    ignore_changes = [task_definition]
  }
}
