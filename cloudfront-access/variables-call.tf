variable "s3_cross_account_bucket_access" {
  description = "List of cross-account bucket access rules"
  type = list(object({
    bucket_name = string

    # Existing (roles)
    principals = optional(list(object({
      account_id = string
      role_name  = string
    })), [])

    access     = optional(string, "read")
    prefixes   = optional(list(string), [])
    allow_list = optional(bool, true)

    existing_policy_json_path = optional(string, null)

    # NEW (CloudFront)
    cloudfront_access = optional(object({
      source_account_id = string
      source_arn_like   = optional(string)
      actions           = optional(list(string))
    }), null)
  }))
  default = []
}
