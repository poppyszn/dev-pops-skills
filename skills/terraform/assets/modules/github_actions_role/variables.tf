variable "name" {
  description = "Name of the IAM role GitHub Actions assumes"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the account's GitHub OIDC provider (token.actions.githubusercontent.com)"
  type        = string
}

variable "allowed_subjects" {
  description = "GitHub OIDC `sub` claims allowed to assume the role, e.g. repo:<org>/<repo>:environment:production"
  type        = list(string)

  validation {
    condition = length(var.allowed_subjects) > 0 && alltrue([
      for s in var.allowed_subjects : startswith(s, "repo:") && !endswith(s, ":*")
    ])
    error_message = "allowed_subjects must be a non-empty list of repo:<org>/<repo>:... patterns that do not end in :*, which would let any branch or pull request assume the role."
  }
}

variable "managed_policy_arns" {
  description = "AWS-managed or customer-managed policies to attach"
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "JSON of an inline policy to attach, or null for none"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the role"
  type        = map(string)
  default     = {}
}
