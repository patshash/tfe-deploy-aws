output "tfe_url" {
  description = "URL to access Terraform Enterprise"
  value       = module.compute.tfe_url
}

output "tfe_hostname" {
  description = "TFE hostname"
  value       = var.tfe_hostname
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.compute.alb_dns_name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.database.db_endpoint
}

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = module.redis.redis_primary_endpoint
}

output "s3_bucket_name" {
  description = "TFE S3 bucket name"
  value       = module.object_storage.s3_bucket_name
}

output "kms_key_arn" {
  description = "KMS key ARN used for encryption"
  value       = local.kms_key_arn
}
