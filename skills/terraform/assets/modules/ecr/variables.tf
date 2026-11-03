variable "name" {
  description = "ECR repository name"
  type        = string
}

variable "image_tag_mutability" {
  description = "Tag mutability. IMMUTABLE stops a tag (such as a git SHA) from being overwritten."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Scan images for vulnerabilities when pushed"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Number of images to keep before older ones expire"
  type        = number
  default     = 30
}

variable "force_delete" {
  description = "Delete the repository even if it still contains images"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags for resource"
  type        = map(string)
  default     = {}
}
