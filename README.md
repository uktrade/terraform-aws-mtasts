# MTA-STS/TLS-RPT AWS Module

NOTE: This repo is forked from [ukncsc/terraform-aws-mtasts](https://github.com/ukncsc/terraform-aws-mtasts).

This repo contains a module for deploying an [MTA-STS](https://tools.ietf.org/html/rfc8461) and [TLS-RPT](https://tools.ietf.org/html/rfc8460) policy for a domain in AWS using [Terraform](https://www.terraform.io/).

This consists of using CloudFront/S3 with a Custom Domain to host the MTA-STS policy, with a TLS certificate provided by AWS ACM. It uses Route53 to configure the DNS portions of both MTA-STS and TLS-RPT.

## How to use this Module

This module assumes AWS Account with access to Route53, CloudFront, S3, and ACM, which also hosts the DNS (in Route53) for the domain you wish to deploy MTA-STS/TLS-RPT.
The providers are defined here to allow resources to be provisioned in both `us-east-1` and a local region (`eu-west-2` in this example). This method also allows additional providers to be defined for additional AWS accounts / profiles, if required.
Note some variables (such as `cf_waf_web_acl`, `cf_price_class`, `mode`, `tags`, etc.) are optional. `See variables.tf` for defaults.

```terraform
provider "aws" {
  alias                    = "useast1"
  region                   = "us-east-1"
  shared_config_files      = ["___/.aws/conf"]
  shared_credentials_files = ["___/.aws/creds"]
  profile                  = "myprofile"
}

provider "aws" {
  alias                    = "myregion"
  region                   = "eu-west-2"
  shared_config_files      = ["___/.aws/conf"]
  shared_credentials_files = ["___/.aws/creds"]
  profile                  = "myprofile"
}

module "shared_s3_bucket" {
  source = "github.com/uktrade/terraform-aws-mtasts/s3"
  tags   = local.default_tags

  providers = {
    aws.account = aws.myregion
  }
  
}

module "mtastspolicy_examplecom" {
  source           = "github.com/uktrade/terraform-aws-mtasts/mta-sts"
  domain           = "example.com"
  mx               = ["mail.example.com"]
  mode             = "testing"
  reporting_email  = "tlsreporting@example.com"
  s3_policy_bucket = module.shared_s3_bucket.s3_policy_bucket
  cf_price_class   = "PriceClass_200"
  cf_waf_web_acl   = "arn:aws:waf___"
  tags             = { "Terraform_source_repo" = "my-terraform-mta-sts-repo" }

  providers = {
    aws.useast1 = aws.useast1
    aws.account = aws.myregion
  }

}
```

Additional MTA STS resources can then be deployed, sharing the same S3 bucket via the `s3_policy_bucket` variable. This is making use of the `origin_path` configuration in CloudFront.

```terraform
module "mtastspolicy_examplecom_2" {
  source           = "github.com/uktrade/terraform-aws-mtasts/mta-sts"
  domain           = "example2.com"
  mx               = ["mail.example2.com"]
  reporting_email  = "tlsreporting@example2.com"
  s3_policy_bucket = module.shared_s3_bucket.s3_policy_bucket

  providers = {
    aws.useast1 = aws.useast1
    aws.account = aws.myregion
  }

}
```