variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "tags" {
  description = "Tags for resource"
  type        = map(string)
  default     = {}
}
