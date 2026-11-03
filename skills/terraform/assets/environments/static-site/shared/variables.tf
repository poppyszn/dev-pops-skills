# Nothing environment-specific has a default here: every such value is set
# visibly in terraform.tfvars. Defaults live in the modules.

# General
variable "region" {
  description = "AWS region for the bucket and the IAM role. CloudFront itself is global; its certificate must be in us-east-1."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
}

# Site
variable "site_bucket_name" {
  description = "Name of the S3 bucket (unique across all of AWS) and prefix for the CloudFront resources"
  type        = string
}

variable "site_aliases" {
  description = "Custom domain names for the distribution, or an empty list to use only the *.cloudfront.net domain"
  type        = list(string)
}

variable "site_acm_certificate_arn" {
  description = "ARN of an ACM certificate in us-east-1 covering every alias, or null"
  type        = string
}

variable "site_price_class" {
  description = "CloudFront price class (PriceClass_100, PriceClass_200 or PriceClass_All)"
  type        = string
}

variable "site_noncurrent_version_expiration_days" {
  description = "Days to keep replaced object versions"
  type        = number
}

variable "site_force_destroy" {
  description = "Allow destroying the bucket while it holds objects (false in production)"
  type        = bool
}

# GitHub Actions
variable "site_github_role_name" {
  description = "Name of the IAM role GitHub Actions assumes to publish the site"
  type        = string
}

variable "site_create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider. Only one can exist per account; set to false if it already exists."
  type        = bool
}

variable "site_github_allowed_subjects" {
  description = "GitHub OIDC subject claims allowed to assume the role, e.g. repo:your-org/your-repo:environment:production"
  type        = list(string)
}
