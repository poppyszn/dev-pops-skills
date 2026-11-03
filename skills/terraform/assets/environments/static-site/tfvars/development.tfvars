# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------
region = "eu-west-1" # <REGION>: set here on purpose, there is no default in variables.tf

tags = {
  Project     = "<PROJECT>"
  Environment = "development"
}

# ---------------------------------------------------------------------------
# Site (S3 + CloudFront)
# ---------------------------------------------------------------------------
site_bucket_name = "<PROJECT>-development-web"

# Custom domain(s). After the first apply, create a CNAME record from each alias
# to the site_distribution_domain_name output (an apex domain cannot be a CNAME).
# The certificate must be requested in us-east-1, whatever the region above is.
# No alias and no certificate: the site is served on its *.cloudfront.net address.
site_aliases             = []
site_acm_certificate_arn = null

# Pick by where the users are: PriceClass_100 (US, Canada, Europe, Israel),
# PriceClass_200 (adds Asia, Africa, Middle East) or PriceClass_All.
site_price_class = "PriceClass_100"

site_noncurrent_version_expiration_days = 30
site_force_destroy                      = true

# ---------------------------------------------------------------------------
# GitHub Actions (OIDC)
# ---------------------------------------------------------------------------
site_github_role_name = "<PROJECT>-development-github-actions-web-deploy"

# The provider already exists (production creates it), so look it up. Apply
# production first.
site_create_github_oidc_provider = false

# Only a job that declares `environment: development` can assume the role, and the
# environment's protection rules apply first. Repositories created after
# 2026-07-15 (or opted in) use the immutable form instead:
#   repo:<GITHUB_ORG>@<ORG_ID>/<GITHUB_REPO>@<REPO_ID>:environment:development
# Check the real sub claim before applying; see references/github-oidc-deploy.md.
site_github_allowed_subjects = [
  "repo:<GITHUB_ORG>/<GITHUB_REPO>:environment:development",
]
