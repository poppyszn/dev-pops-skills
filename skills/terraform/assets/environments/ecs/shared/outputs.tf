output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = module.alb.alb_dns_name
}

output "service_name" {
  description = "Name of the ECS service"
  value       = module.ecs_service.service_name
}

output "autoscaling_group_name" {
  description = "Name of the container instance Auto Scaling group"
  value       = module.ecs_instances.autoscaling_group_name
}

output "capacity_provider_name" {
  description = "Name of the capacity provider"
  value       = module.ecs_capacity_provider.capacity_provider_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "github_actions_role_arn" {
  description = "ARN of the role GitHub Actions assumes"
  value       = module.github_oidc.role_arn
}

output "one_off_task_families" {
  description = "Task definition families for one-off tasks"
  value       = { for name, task in module.ecs_one_off_task : name => task.task_definition_family }
}
