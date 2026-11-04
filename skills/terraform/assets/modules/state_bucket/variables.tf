variable "name" {
  description = "Name of the Terraform state bucket"
  type        = string
}

variable "force_destroy" {
  description = "Allow Terraform to delete the bucket together with every object and version in it. Keep false: it holds the state."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the bucket"
  type        = map(string)
  default     = {}
}
