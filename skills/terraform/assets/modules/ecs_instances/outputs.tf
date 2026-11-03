output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling group"
  value       = aws_autoscaling_group.ecs.arn
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling group"
  value       = aws_autoscaling_group.ecs.name
}

output "instance_role_arn" {
  description = "ARN of the ECS instance role"
  value       = aws_iam_role.instance.arn
}
