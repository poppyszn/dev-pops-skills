# These map one to one onto the GitHub environment variables the deploy
# workflow reads: WEB_BUCKET, CLOUDFRONT_DISTRIBUTION_ID and AWS_ROLE_ARN.

output "site_bucket_name" {
  description = "S3 bucket the deploy syncs into (GitHub variable WEB_BUCKET)"
  value       = module.static_site.bucket_name
}

output "site_distribution_id" {
  description = "CloudFront distribution to invalidate (GitHub variable CLOUDFRONT_DISTRIBUTION_ID)"
  value       = module.static_site.distribution_id
}

output "site_distribution_domain_name" {
  description = "The *.cloudfront.net domain: the target of the CNAME record for each alias"
  value       = module.static_site.distribution_domain_name
}

output "site_deploy_role_arn" {
  description = "Role the deploy workflow assumes (GitHub variable AWS_ROLE_ARN)"
  value       = module.static_site_deploy_role.role_arn
}
