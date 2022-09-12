data "aws_caller_identity" "current" {
  provider = aws.account
}

locals {
  bucketname = "mta-sts-${data.aws_caller_identity.current.account_id}"
  tags = merge(
    { "Service" = "MTA-STS" },
    var.tags
  )
}

resource "aws_s3_bucket" "policybucket" {
  bucket   = local.bucketname
  tags     = local.tags
  provider = aws.account
}

resource "aws_s3_bucket_acl" "policybucket_acl" {
  bucket   = aws_s3_bucket.policybucket.id
  acl      = "private"
  provider = aws.account
}

resource "aws_cloudfront_origin_access_identity" "policybucketoai" {
  comment  = "OAI for shared MTA-STS policy bucket (${local.bucketname})"
  provider = aws.account
}

data "aws_iam_policy_document" "s3_policy" {
  provider = aws.account
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.policybucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.policybucketoai.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "policybucketpolicy" {
  bucket   = aws_s3_bucket.policybucket.id
  policy   = data.aws_iam_policy_document.s3_policy.json
  provider = aws.account
}

output "s3_policy_bucket" {
  value = tomap({
      "cloudfront_oai_path" = aws_cloudfront_origin_access_identity.policybucketoai.cloudfront_access_identity_path
      "s3_policybucket_regional_domain_name" = aws_s3_bucket.policybucket.bucket_regional_domain_name
      "s3_policybucket_id" = aws_s3_bucket.policybucket.id
    })
}
