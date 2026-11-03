variable "name" {
  description = "Name of the IAM role GitHub Actions assumes"
  type        = string
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Only one can exist per account; set to false to look up an existing one."
  type        = bool
  default     = true
}

variable "allowed_subjects" {
  description = "GitHub OIDC subject claims allowed to assume the role, e.g. repo:your-org/your-repo:ref:refs/heads/main"
  type        = list(string)

  validation {
    condition     = length(var.allowed_subjects) > 0 && alltrue([for s in var.allowed_subjects : s != "*" && startswith(s, "repo:")])
    error_message = "allowed_subjects must be a non-empty list of repo:<org>/<repo>:... patterns; a bare * would trust every GitHub repository."
  }
}

variable "ecr_repository_arns" {
  description = "ARNs of the ECR repositories the role can push to"
  type        = list(string)
}

variable "cluster_name" {
  description = "Name of the ECS cluster the role deploys to"
  type        = string
}

variable "service_name" {
  description = "Name of the ECS service the role can update"
  type        = string
}

variable "task_definition_families" {
  description = "Task definition families the role may run as one-off tasks"
  type        = list(string)
}

variable "pass_role_arns" {
  description = "ARNs of the task and execution roles the role may pass to ECS"
  type        = list(string)
}

variable "tags" {
  description = "Tags for resource"
  type        = map(string)
  default     = {}
}
