# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------
region = "eu-west-1" # <REGION>: set here on purpose, there is no default in variables.tf

tags = {
  Project     = "<PROJECT>"
  Environment = "production"
}

# ---------------------------------------------------------------------------
# Site (S3 + CloudFront)
# ---------------------------------------------------------------------------
site_bucket_name = "<PROJECT>-production-web"

# Custom domain(s). After the first apply, create a CNAME record from each alias
# to the site_distribution_domain_name output (an apex domain cannot be a CNAME).
# The certificate must be requested in us-east-1, whatever the region above is.
site_aliases             = ["<WEB_DOMAIN>"]
site_acm_certificate_arn = "arn:aws:acm:us-east-1:<ACCOUNT_ID>:certificate/<CERTIFICATE_ID>"

# Pick by where the users are: PriceClass_100 (US, Canada, Europe, Israel),
# PriceClass_200 (adds Asia, Africa, Middle East) or PriceClass_All.
site_price_class = "PriceClass_All"

site_noncurrent_version_expiration_days = 30
site_force_destroy                      = false

# ---------------------------------------------------------------------------
# GitHub Actions (OIDC)
# ---------------------------------------------------------------------------
site_github_role_name = "<PROJECT>-production-github-actions-web-deploy"

# Only one GitHub OIDC provider can exist per AWS account. Exactly one environment
# in the account sets this to true (production); the others set false and must be
# applied after it. See references/github-oidc-deploy.md.
site_create_github_oidc_provider = true

# Only a job that declares `environment: production` can assume the role, and the
# environment's protection rules apply first. Repositories created after
# 2026-07-15 (or opted in) use the immutable form instead:
#   repo:<GITHUB_ORG>@<ORG_ID>/<GITHUB_REPO>@<REPO_ID>:environment:production
# Check the real sub claim before applying; see references/github-oidc-deploy.md.
site_github_allowed_subjects = [
  "repo:<GITHUB_ORG>/<GITHUB_REPO>:environment:production",
]
