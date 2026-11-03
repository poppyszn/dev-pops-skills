variable "name" {
  description = "Service name (also used for the task family, log group and execution role)"
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the ECS cluster"
  type        = string
}

variable "capacity_provider_name" {
  description = "Name of the capacity provider the service runs on"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}

variable "container_name" {
  description = "Container name"
  type        = string
  default     = "nginx"
}

variable "image" {
  description = "Container image"
  type        = string
  default     = "public.ecr.aws/nginx/nginx:stable"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 80
}

variable "cpu" {
  description = "CPU units reserved for the container"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Hard memory limit for the container in MiB"
  type        = number
  default     = 256
}

variable "desired_count" {
  description = "Number of tasks to run"
  type        = number
  default     = 2
}

variable "health_check_grace_period_seconds" {
  description = "Seconds to ignore failing load balancer health checks on new tasks"
  type        = number
  default     = 60
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "enable_execute_command" {
  description = "Enable ECS Exec (shell access to running containers via Session Manager)"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Plain environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets injected into the container, as env var name => Secrets Manager or SSM Parameter Store ARN"
  type        = map(string)
  default     = {}
}

variable "task_role_policy_arns" {
  description = "Managed policy ARNs to attach to the task role (permissions the application needs)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags for resource"
  type        = map(string)
  default     = {}
}
