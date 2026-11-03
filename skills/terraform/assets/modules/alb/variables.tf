variable "name" {
  description = "ALB name (also used as the target group name prefix)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC for the target group"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets the ALB is placed in (at least two AZs)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "IDs of the security groups to associate"
  type        = list(string)
}

variable "target_port" {
  description = "Default target group port. ECS overrides it with the dynamic host port per task."
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Target group health check path"
  type        = string
  default     = "/"
}

variable "deregistration_delay" {
  description = "Seconds the ALB waits before deregistering a draining target"
  type        = number
  default     = 30
}

variable "enable_deletion_protection" {
  description = "Protect the ALB from deletion"
  type        = bool
  default     = true
}

variable "certificate_arn" {
  description = "ACM certificate ARN. When set, adds an HTTPS listener and redirects HTTP to HTTPS."
  type        = string
  default     = null
}

variable "ssl_policy" {
  description = "SSL policy for the HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
}

variable "tags" {
  description = "Tags for resource"
  type        = map(string)
  default     = {}
}
