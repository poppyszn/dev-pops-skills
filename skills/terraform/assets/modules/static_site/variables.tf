variable "name" {
  description = "Name of the S3 bucket and prefix for the CloudFront resources. Bucket names are unique across all of AWS, so include the project and environment, e.g. <PROJECT>-production-web"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,48}[a-z0-9]$", var.name))
    error_message = "name must be 3-50 characters: lowercase letters, digits and hyphens, not starting or ending with a hyphen (it prefixes CloudFront names that have a 64-character limit)."
  }
}

variable "aliases" {
  description = "Custom domain names for the distribution (CNAMEs). Leave empty to use only the *.cloudfront.net domain."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.aliases) == 0 || var.acm_certificate_arn != null
    error_message = "aliases need acm_certificate_arn: CloudFront only serves a custom domain over HTTPS with a certificate."
  }
}

variable "acm_certificate_arn" {
  description = "ARN of an ACM certificate covering every alias. CloudFront only accepts certificates in us-east-1, so request it there, whatever region the rest of the project uses. Null serves the default *.cloudfront.net certificate."
  type        = string
  default     = null

  validation {
    condition     = var.acm_certificate_arn == null || can(regex("^arn:aws[a-z-]*:acm:us-east-1:[0-9]{12}:certificate/", var.acm_certificate_arn))
    error_message = "acm_certificate_arn must be an ACM certificate ARN in us-east-1 (CloudFront cannot use certificates from other regions)."
  }
}

variable "minimum_protocol_version" {
  description = "CloudFront security policy for viewer connections when a custom certificate is used"
  type        = string
  default     = "TLSv1.2_2021"

  validation {
    condition     = contains(["TLSv1.2_2021", "TLSv1.2_2025", "TLSv1.3_2025"], var.minimum_protocol_version)
    error_message = "minimum_protocol_version must be TLSv1.2_2021, TLSv1.2_2025 or TLSv1.3_2025. Older policies allow TLS versions that are no longer acceptable."
  }
}

variable "price_class" {
  description = "CloudFront price class: PriceClass_100 (US, Canada, Europe, Israel), PriceClass_200 (adds Asia, Africa, Middle East) or PriceClass_All. Pick by where the users are."
  type        = string
  default     = "PriceClass_All"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200 or PriceClass_All."
  }
}

variable "web_acl_arn" {
  description = "ARN of a WAFv2 web ACL (created in us-east-1) to attach, or null for none"
  type        = string
  default     = null
}

variable "noncurrent_version_expiration_days" {
  description = "Days to keep a replaced object version in the bucket before it is deleted"
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_version_expiration_days >= 1
    error_message = "noncurrent_version_expiration_days must be at least 1."
  }
}

variable "force_destroy" {
  description = "Allow destroying the bucket while it still holds objects. Keep false in production."
  type        = bool
  default     = false
}

variable "hsts_max_age_seconds" {
  description = "Strict-Transport-Security max-age in seconds"
  type        = number
  default     = 31536000
}

variable "hsts_include_subdomains" {
  description = "Add includeSubDomains to Strict-Transport-Security. Only enable when every subdomain is served over HTTPS."
  type        = bool
  default     = false
}

variable "frame_option" {
  description = "X-Frame-Options value: DENY, or SAMEORIGIN if the app frames itself"
  type        = string
  default     = "DENY"

  validation {
    condition     = contains(["DENY", "SAMEORIGIN"], var.frame_option)
    error_message = "frame_option must be DENY or SAMEORIGIN."
  }
}

variable "referrer_policy" {
  description = "Referrer-Policy header value"
  type        = string
  default     = "no-referrer"
}

variable "content_security_policy" {
  description = "Content-Security-Policy header value, or null to send none. A policy is specific to the app, so there is no default."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags for resource"
  type        = map(string)
  default     = {}
}
