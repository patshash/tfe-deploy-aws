locals {
  kms_key_arn = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.this[0].arn

  common_tags = merge(var.tags, {
    ManagedBy = "terraform"
    Module    = "tfe-fdo-active-active"
  })

  tfe_encryption_password = var.tfe_encryption_password != null ? var.tfe_encryption_password : random_password.enc_password[0].result

  # TFE FDO user data script
  tfe_user_data = base64encode(templatefile("${path.module}/templates/tfe-user-data.sh", {
    tfe_hostname            = var.tfe_hostname
    tfe_license             = var.tfe_license
    tfe_image               = var.tfe_image
    tfe_encryption_password = local.tfe_encryption_password
    db_host                 = module.database.db_host
    db_port                 = module.database.db_port
    db_name                 = module.database.db_name
    db_username             = module.database.db_username
    db_password             = module.database.db_password
    redis_host              = module.redis.redis_primary_endpoint
    redis_port              = module.redis.redis_port
    redis_auth_token        = module.redis.redis_auth_token
    s3_bucket               = module.object_storage.s3_bucket_name
    s3_region               = module.object_storage.s3_bucket_region
    kms_key_arn             = local.kms_key_arn
    log_group               = "/aws/tfe/${var.friendly_name_prefix}"
  }))
}
