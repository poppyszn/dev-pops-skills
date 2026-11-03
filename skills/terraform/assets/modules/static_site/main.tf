# A private S3 bucket served through CloudFront for a single-page app. The
# bucket is reachable only by this distribution (origin access control), never
# directly. See references/static-site.md.

locals {
  origin_id = "${var.name}-s3"
}

# The managed policy caches by the URL only (no cookies, headers or query
# strings in the key) and honours the Cache-Control the deploy sets on each
# object. Its minimum TTL is 1 second, so even `no-cache` objects such as
# index.html can sit at the edge for a second: the deploy's invalidation covers it.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# ---------------------------------------------------------------------------
# Bucket
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "site" {
  bucket        = var.name
  force_destroy = var.force_destroy

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Origin access control only works with ACLs disabled.
resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Versioning keeps the previous build recoverable after `aws s3 sync --delete`.
resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 needs no extra key policy for CloudFront (SSE-KMS would).
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  # Versioning must be on before a noncurrent-version rule is accepted.
  depends_on = [aws_s3_bucket_versioning.site]

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid       = "AllowCloudFrontRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }

  # Without s3:ListBucket, S3 answers 403 for a missing key; with it, a real
  # 404. CloudFront never lists the bucket (no query string reaches the origin
  # and `/` is rewritten to /index.html), so this only fixes the status code.
  statement {
    sid       = "AllowCloudFrontListForNotFound"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.site.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.site.arn, "${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.bucket.json

  depends_on = [aws_s3_bucket_public_access_block.site]
}

# ---------------------------------------------------------------------------
# CloudFront
# ---------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = var.name
  description                       = "Origin access control for ${var.name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Client-side routing without custom error responses. A distribution-wide
# 403/404 -> /index.html rule would also answer a missing /assets/ chunk (or a
# broken bucket policy) with the app shell and a 200. This function rewrites
# only extensionless paths, so a missing file stays a real 404.
resource "aws_cloudfront_function" "spa_routing" {
  name    = "${var.name}-spa-routing"
  runtime = "cloudfront-js-2.0"
  comment = "Serve index.html for client-side routes; leave files and /assets/ alone"
  publish = true
  code    = file("${path.module}/spa-routing.js")
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "${var.name}-security-headers"
  comment = "Security headers for ${var.name}"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = var.hsts_max_age_seconds
      include_subdomains         = var.hsts_include_subdomains
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = var.frame_option
      override     = true
    }

    referrer_policy {
      referrer_policy = var.referrer_policy
      override        = true
    }

    dynamic "content_security_policy" {
      for_each = var.content_security_policy == null ? [] : [var.content_security_policy]

      content {
        content_security_policy = content_security_policy.value
        override                = true
      }
    }
  }
}

resource "aws_cloudfront_distribution" "site" {
  comment             = var.name
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  default_root_object = "index.html"
  price_class         = var.price_class
  aliases             = var.aliases
  web_acl_id          = var.web_acl_arn

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = local.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id           = local.origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_routing.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # The default *.cloudfront.net certificate fixes the minimum TLS version at
  # TLSv1 and cannot carry an alias; a custom domain needs an ACM certificate.
  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn == null ? null : "sni-only"
    minimum_protocol_version       = var.acm_certificate_arn == null ? null : var.minimum_protocol_version
  }

  tags = merge(var.tags, { Name = var.name })
}
