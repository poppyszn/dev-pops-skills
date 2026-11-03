# The role a GitHub Actions workflow assumes (no stored AWS keys) to publish a
# built single-page app: sync files into the site bucket and invalidate the
# CloudFront distribution. See references/static-site.md.

locals {
  oidc_url          = "token.actions.githubusercontent.com"
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

# There can only be one GitHub OIDC provider per account. Set
# create_oidc_provider to false when one already exists (the ECS template's
# github_oidc module creates it, for example).
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://${local.oidc_url}"
  client_id_list = ["sts.amazonaws.com"]

  tags = var.tags
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1

  url = "https://${local.oidc_url}"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # A job that references a GitHub Environment gets a sub of
    # repo:<ORG>/<REPO>:environment:<ENV>, whatever branch it runs on. Pinning
    # to the environment means only that environment's workflow (and its
    # protection rules, such as required reviewers) can assume the role.
    condition {
      test     = "StringLike"
      variable = "${local.oidc_url}:sub"
      values   = var.allowed_subjects
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = var.name
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  max_session_duration = var.max_session_duration

  tags = var.tags
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "ListSiteBucket"
    actions   = ["s3:ListBucket"]
    resources = [var.bucket_arn]
  }

  # aws s3 sync compares by listing, uploads with PutObject (which also covers
  # multipart uploads) and removes stale files with DeleteObject.
  statement {
    sid = "WriteSiteObjects"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:PutObject",
    ]
    resources = ["${var.bucket_arn}/*"]
  }

  statement {
    sid = "InvalidateDistribution"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
    ]
    resources = [var.distribution_arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "${var.name}-deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
