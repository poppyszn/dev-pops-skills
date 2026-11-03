output "bucket_name" {
  description = "Name of the S3 bucket the deploy syncs into"
  value       = aws_s3_bucket.site.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.site.arn
}

output "distribution_id" {
  description = "ID of the CloudFront distribution to invalidate after a deploy"
  value       = aws_cloudfront_distribution.site.id
}

output "distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.site.arn
}

output "distribution_domain_name" {
  description = "The *.cloudfront.net domain. Point each alias at it with a CNAME record (an apex domain cannot be a CNAME)."
  value       = aws_cloudfront_distribution.site.domain_name
}
