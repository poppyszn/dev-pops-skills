module "static_site" {
  source = "../../modules/static_site"

  name                               = var.site_bucket_name
  aliases                            = var.site_aliases
  acm_certificate_arn                = var.site_acm_certificate_arn
  price_class                        = var.site_price_class
  noncurrent_version_expiration_days = var.site_noncurrent_version_expiration_days
  force_destroy                      = var.site_force_destroy

  tags = var.tags
}

module "static_site_deploy_role" {
  source = "../../modules/static_site_deploy_role"

  name                 = var.site_github_role_name
  create_oidc_provider = var.site_create_github_oidc_provider
  allowed_subjects     = var.site_github_allowed_subjects
  bucket_arn           = module.static_site.bucket_arn
  distribution_arn     = module.static_site.distribution_arn

  tags = var.tags
}
