locals {
  bucket_arn = "arn:aws:s3:::${var.bucket_name}"

  object_arns = length(var.prefixes) == 0
    ? ["arn:aws:s3:::${var.bucket_name}/*"]
    : [for p in var.prefixes : "arn:aws:s3:::${var.bucket_name}/${p}*"]

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