variable "name" {
  description = "Task definition family, e.g. production-migrate"
  type        = string
}

variable "container_name" {
  description = "Container name"
  type        = string
  default     = "app"
}

variable "image" {
  description = "Container image"
  type        = string
}

variable "command" {
  description = "Command to run in the container"
  type        = list(string)
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

variable "execution_role_arn" {
  description = "ARN of the task execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the task role"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group the container logs to"
  type        = string
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

variable "tags" {
  description = "Tags for resource"
  type        = map(string)
  default     = {}
}
