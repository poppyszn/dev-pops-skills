resource "aws_s3_bucket" "this" {
  bucket        = var.name
  force_destroy = var.force_destroy

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    # Losing this bucket loses the state of everything it tracks. Destroying it
    # must be a deliberate edit of this file, not a side effect of a plan.
    prevent_destroy = true
  }
}

# Versioning keeps every earlier state file, so a bad apply can be rolled back.
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    bucket_key_enabled       = false # bucket keys only apply to SSE-KMS
    blocked_encryption_types = ["SSE-C"]

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Matches the bucket as it was created. BucketOwnerEnforced is AWS's current
# recommendation; switching is a separate, deliberate change.
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

data "aws_partition" "current" {}

locals {
  # Built from the name, not aws_s3_bucket.this.arn, so the policy document is
  # known at plan time and an import shows a real diff instead of a replacement.
  bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::${var.name}"
}

data "aws_iam_policy_document" "this" {
  statement {
    sid     = "denyOutdatedTLS"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      "${local.bucket_arn}/*",
      local.bucket_arn,
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }

  statement {
    sid     = "denyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      "${local.bucket_arn}/*",
      local.bucket_arn,
    ]

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

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.this.json

  # The policy must not be evaluated before public access settings are in place.
  depends_on = [aws_s3_bucket_public_access_block.this]
}
