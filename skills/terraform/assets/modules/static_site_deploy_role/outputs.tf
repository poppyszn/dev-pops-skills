output "role_arn" {
  description = "ARN of the role GitHub Actions assumes"
  value       = aws_iam_role.deploy.arn
}

output "role_name" {
  description = "Name of the role GitHub Actions assumes"
  value       = aws_iam_role.deploy.name
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = local.oidc_provider_arn
}
