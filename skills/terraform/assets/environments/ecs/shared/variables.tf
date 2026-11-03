# Nothing environment-specific has a default here: every such value is set
# visibly in terraform.tfvars. Defaults live in the modules. Only optional
# toggles (null or empty) keep one.

# General
variable "region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
}

# ECS cluster
variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

# Container instances
variable "instance_type" {
  description = "EC2 instance type for the container instances"
  type        = string
}

variable "asg_min_size" {
  description = "Minimum number of container instances"
  type        = number
}

variable "asg_max_size" {
  description = "Maximum number of container instances"
  type        = number

  validation {
    condition     = var.asg_max_size >= var.asg_min_size
    error_message = "asg_max_size must be greater than or equal to asg_min_size."
  }
}

variable "capacity_provider_target_capacity" {
  description = "Target utilization percentage of the Auto Scaling group managed by ECS"
  type        = number

  validation {
    condition     = var.capacity_provider_target_capacity >= 1 && var.capacity_provider_target_capacity <= 100
    error_message = "capacity_provider_target_capacity must be between 1 and 100."
  }
}

# Security groups
variable "alb_security_group_name" {
  description = "ALB security group name"
  type        = string
}

variable "alb_security_group_description" {
  description = "ALB security group description"
  type        = string
}

variable "alb_ingress_rules" {
  description = "ALB security group ingress rules"
  type = map(object({
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    referenced_security_group_id = optional(string)
    from_port                    = optional(number)
    to_port                      = optional(number)
    ip_protocol                  = string
  }))
}

variable "alb_egress_rules" {
  description = "ALB security group egress rules"
  type = map(object({
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    referenced_security_group_id = optional(string)
    from_port                    = optional(number)
    to_port                      = optional(number)
    ip_protocol                  = string
  }))
}

variable "instance_security_group_name" {
  description = "Container instance security group name"
  type        = string
}

variable "instance_security_group_description" {
  description = "Container instance security group description"
  type        = string
}

variable "instance_egress_rules" {
  description = "Container instance security group egress rules"
  type = map(object({
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    referenced_security_group_id = optional(string)
    from_port                    = optional(number)
    to_port                      = optional(number)
    ip_protocol                  = string
  }))
}

# ALB
variable "alb_name" {
  description = "ALB name"
  type        = string
}

variable "alb_enable_deletion_protection" {
  description = "Protect the ALB from deletion"
  type        = bool
}

variable "certificate_arn" {
  description = "ACM certificate ARN. When set, adds an HTTPS listener and redirects HTTP to HTTPS."
  type        = string
  default     = null
}

# Service
variable "service_name" {
  description = "ECS service name"
  type        = string
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
}

variable "desired_count" {
  description = "Number of tasks to run"
  type        = number

  validation {
    condition     = var.desired_count >= 0
    error_message = "desired_count must be zero or greater."
  }
}

variable "container_environment" {
  description = "Plain environment variables for the service and one-off tasks"
  type        = map(string)
  default     = {}
}

variable "container_secrets" {
  description = "Secrets for the service and one-off tasks, as env var name => Secrets Manager or SSM Parameter Store ARN"
  type        = map(string)
  default     = {}
}

variable "task_role_policy_arns" {
  description = "Managed policy ARNs to attach to the task role (permissions the application needs)"
  type        = list(string)
  default     = []
}

variable "one_off_tasks" {
  description = "One-off task definitions (migrations, seeds), keyed by short name"
  type = map(object({
    command = list(string)
    cpu     = optional(number, 256)
    memory  = optional(number, 256)
  }))
  default = {}
}

# ECR
variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
}

variable "ecr_max_image_count" {
  description = "Number of images to keep in the ECR repository"
  type        = number
}

# GitHub Actions
variable "github_role_name" {
  description = "Name of the IAM role GitHub Actions assumes"
  type        = string
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider. Only one can exist per account; set to false if it already exists."
  type        = bool
}

variable "github_allowed_subjects" {
  description = "GitHub OIDC subject claims allowed to assume the deploy role, e.g. repo:your-org/your-repo:ref:refs/heads/main"
  type        = list(string)
}
