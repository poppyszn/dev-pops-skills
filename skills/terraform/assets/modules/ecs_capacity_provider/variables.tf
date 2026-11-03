variable "name" {
  description = "Capacity provider name"
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster to associate the capacity provider with"
  type        = string
}

variable "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling group backing the capacity provider"
  type        = string
}

variable "target_capacity" {
  description = "Target utilization percentage of the Auto Scaling group (1-100)"
  type        = number
  default     = 100
}

variable "minimum_scaling_step_size" {
  description = "Minimum number of instances ECS scales by at once"
  type        = number
  default     = 1
}

variable "maximum_scaling_step_size" {
  description = "Maximum number of instances ECS scales by at once"
  type        = number
  default     = 2
}

variable "instance_warmup_period" {
  description = "Seconds before a new instance counts towards scaling metrics"
  type        = number
  default     = 300
}

variable "tags" {
  description = "Tags for resource"
  type        = map(string)
  default     = {}
}
