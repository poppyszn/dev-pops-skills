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
  description = "GitHub OIDC subject claims allowed to assume the role. Use the environment form, e.g. repo:your-org/your-repo:environment:production, and check the real claim before applying."
  type        = list(string)

  validation {
    condition     = length(var.allowed_subjects) > 0 && alltrue([for s in var.allowed_subjects : s != "*" && startswith(s, "repo:")])
    error_message = "allowed_subjects must be a non-empty list of repo:<org>/<repo>:... patterns; a bare * would trust every GitHub repository."
  }

  validation {
    condition     = alltrue([for s in var.allowed_subjects : !endswith(s, ":*")])
    error_message = "allowed_subjects must not end in :* (that lets any branch, pull request or environment of the repository deploy). List each environment explicitly."
  }
}

variable "bucket_arn" {
  description = "ARN of the site bucket the role may write to"
  type        = string
}

variable "distribution_arn" {
  description = "ARN of the CloudFront distribution the role may invalidate"
  type        = string
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds. A deploy is short; one hour is the minimum AWS allows."
  type        = number
  default     = 3600
}

variable "tags" {
  description = "Tags for resource"
  type        = map(string)
  default     = {}
}
