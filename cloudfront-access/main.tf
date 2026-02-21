locals {
  bucket_arn = "arn:aws:s3:::${var.bucket_name}"

  object_arns = length(var.prefixes) == 0 ? ["arn:aws:s3:::${var.bucket_name}/*"] : [for p in var.prefixes : "arn:aws:s3:::${var.bucket_name}/${p}*"]

  principal_role_arns = [
    for p in var.principals : "arn:aws:iam::${p.account_id}:role/${p.role_name}"
  ]

  has_role_principals = length(var.principals) > 0
  has_cloudfront      = var.cloudfront_access != null

  read_object_actions  = ["s3:GetObject", "s3:GetObjectVersion"]
  write_object_actions = var.access == "readwrite" ? ["s3:PutObject", "s3:AbortMultipartUpload", "s3:DeleteObject"] : []
  list_bucket_actions  = var.allow_list ? ["s3:ListBucket"] : []

  existing_policy_json = var.existing_policy_json_path != null ? file(var.existing_policy_json_path) : null
}

data "aws_iam_policy_document" "cross_account_policy" {

  # IAM roles — ListBucket (only if roles exist)
  dynamic "statement" {
    for_each = local.has_role_principals && var.allow_list ? [1] : []
    content {
      sid    = "AllowCrossAccountListBucket"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = local.principal_role_arns
      }

      actions   = local.list_bucket_actions
      resources = [local.bucket_arn]

      dynamic "condition" {
        for_each = length(var.prefixes) == 0 ? [] : [1]
        content {
          test     = "StringLike"
          variable = "s3:prefix"
          values   = [for p in var.prefixes : "${p}*"]
        }
      }
    }
  }

  # IAM roles — Read objects (only if roles exist)
  dynamic "statement" {
    for_each = local.has_role_principals ? [1] : []
    content {
      sid    = "AllowCrossAccountReadObjects"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = local.principal_role_arns
      }

      actions   = local.read_object_actions
      resources = local.object_arns
    }
  }

  # IAM roles — Write objects (only if roles exist AND access=readwrite)
  dynamic "statement" {
    for_each = local.has_role_principals && var.access == "readwrite" ? [1] : []
    content {
      sid    = "AllowCrossAccountWriteObjects"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = local.principal_role_arns
      }

      actions   = local.write_object_actions
      resources = local.object_arns
    }
  }

  # CloudFront statement (only if cloudfront_access provided)
  dynamic "statement" {
    for_each = local.has_cloudfront ? [var.cloudfront_access] : []
    content {
      sid    = "AllowCloudFrontReadObjects"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["cloudfront.amazonaws.com"]
      }

      actions   = statement.value.actions
      resources = local.object_arns

      condition {
        test     = "StringEquals"
        variable = "AWS:SourceAccount"
        values   = [statement.value.source_account_id]
      }

      condition {
        test     = "ArnLike"
        variable = "AWS:SourceArn"
        values = [
          coalesce(
            try(statement.value.source_arn_like, null),
            "arn:aws:cloudfront::${statement.value.source_account_id}:distribution/*"
          )
        ]
      }
    }
  }

}
