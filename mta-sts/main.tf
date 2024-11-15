data "aws_caller_identity" "current" {
  provider = aws.account
}

locals {
  bucketname   = "mta-sts.${data.aws_caller_identity.current.account_id}.${var.domain}"
  policydomain = "mta-sts.${var.domain}"
  policyhash   = md5(format("%s%s%s", join("", var.mx), var.mode, var.max_age))
  s3_origin_id = "myS3Origin"
  tags         = merge(
    {
      "Service" = "MTA-STS"
      "Domain"  = var.domain
    },
    var.tags
  )
}

resource "aws_acm_certificate" "cert" {
  domain_name       = local.policydomain
  validation_method = "DNS"
  tags              = local.tags
  provider          = aws.useast1
}

data "aws_route53_zone" "zone" {
  name     = var.domain
  provider = aws.useast1
}

resource "aws_route53_record" "cert_validation" {
  name     = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_name
  type     = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_type
  zone_id  = data.aws_route53_zone.zone.id
  records  = [tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_value]
  ttl      = 60
  provider = aws.useast1
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
  provider                = aws.useast1
}

resource "aws_s3_object" "mtastspolicyfile" {
  key          = "${var.domain}/.well-known/mta-sts.txt"
  bucket       = var.s3_policy_bucket["s3_policybucket_id"]
  content      = templatefile("${path.module}/mta-sts.templatefile",
    {
      max_age  = var.max_age
      mode     = var.mode
      mx_lines = join("\n", formatlist("mx: %s", var.mx))
    }
  )
  content_type = "text/plain"
  tags         = local.tags
  provider     = aws.account
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  aliases     = [local.policydomain]
  enabled     = true
  price_class = var.cf_price_class
  web_acl_id  = var.cf_waf_web_acl
  tags        = local.tags
  provider    = aws.account

  origin {
    domain_name = var.s3_policy_bucket["s3_policybucket_regional_domain_name"]
    origin_id   = local.s3_origin_id
    origin_path = "/${var.domain}"

    s3_origin_config {
      origin_access_identity = var.s3_policy_bucket["cloudfront_oai_path"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 300
    max_ttl                = 300
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2018"
  }
}

resource "aws_route53_record" "cloudfrontalias" {
  name     = local.policydomain
  type     = "A"
  zone_id  = data.aws_route53_zone.zone.id
  provider = aws.account

  alias {
    evaluate_target_health = true
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
  }
}

resource "aws_route53_record" "smtptlsreporting" {
  zone_id  = data.aws_route53_zone.zone.id
  name     = "_smtp._tls.${var.domain}"
  type     = "TXT"
  ttl      = "300"
  count    = length(var.reporting_email) > 0 ? 1 : 0
  provider = aws.account

  records = [
    "v=TLSRPTv1;rua=mailto:${var.reporting_email}",
  ]
}

resource "aws_route53_record" "mtastspolicydns" {
  zone_id  = data.aws_route53_zone.zone.id
  name     = "_mta-sts.${var.domain}"
  type     = "TXT"
  ttl      = "300"
  provider = aws.account

  records = [
    "v=STSv1; id=${local.policyhash}",
  ]
}