variable "cf_price_class" {
  type        = string
  default     = "PriceClass_100"
  description = "The price class for the MTA STS CloudFront distribution. Options: PriceClass_100 (North America and Europe), PriceClass_200 (North America, Europe, Asia, Middle East, and Africa) or PriceClass_All (all edge locations)."
}

variable "cf_waf_web_acl" {
  type        = string
  default     = null
  description = "AWS WAF web ACL to associate with the CloudFront distribution."
}

variable "domain" {
  type        = string
  description = "The domain MTA-STS/TLS-RPT is being deployed for."
}

variable "mode" {
  type        = string
  default     = "testing"
  description = "MTA-STS policy 'mode'. Either 'testing' or 'enforce'."
}

variable "max_age" {
  type        = string
  default     = "86400"
  description = "MTA-STS max_age. Time in seconds the policy should be cached. Default is 1 day"
}

variable "mx" {
  type        = list(string)
  description = "'mx' value for MTA-STS policy. List of MX hostnames to be included in MTA-STS policy"
}

variable "reporting_email" {
  type        = string
  default     = ""
  description = "(Optional) Email to use for TLS-RPT reporting."
}

variable "s3_policy_bucket" {
  type        = map(string)
  description = "Map of variables relating to the Shared S3 bucket. Comes from the S3 module."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "(Optional) tags to apply to underlying resources"
}
