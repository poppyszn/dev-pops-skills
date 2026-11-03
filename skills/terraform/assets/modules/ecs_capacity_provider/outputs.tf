output "capacity_provider_name" {
  description = "Name of the capacity provider"
  value       = aws_ecs_capacity_provider.capacity_provider.name
}

output "capacity_provider_arn" {
  description = "ARN of the capacity provider"
  value       = aws_ecs_capacity_provider.capacity_provider.arn
}
