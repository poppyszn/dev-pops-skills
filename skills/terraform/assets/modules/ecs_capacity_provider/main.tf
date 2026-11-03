resource "aws_ecs_capacity_provider" "capacity_provider" {
  name = var.name

  auto_scaling_group_provider {
    auto_scaling_group_arn         = var.autoscaling_group_arn
    managed_draining               = "ENABLED"
    managed_termination_protection = "ENABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = var.target_capacity
      minimum_scaling_step_size = var.minimum_scaling_step_size
      maximum_scaling_step_size = var.maximum_scaling_step_size
      instance_warmup_period    = var.instance_warmup_period
    }
  }

  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "association" {
  cluster_name       = var.cluster_name
  capacity_providers = [aws_ecs_capacity_provider.capacity_provider.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.capacity_provider.name
    base              = 1
    weight            = 100
  }

  # A capacity provider cannot be deleted while associated with a cluster.
  lifecycle {
    replace_triggered_by = [aws_ecs_capacity_provider.capacity_provider]
  }
}
