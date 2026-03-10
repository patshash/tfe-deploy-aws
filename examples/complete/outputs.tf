output "tfe_url" {
  description = "URL to access Terraform Enterprise"
  value       = module.tfe.tfe_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.tfe.vpc_id
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.tfe.alb_dns_name
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.tfe.rds_endpoint
}

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = module.tfe.redis_endpoint
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = module.tfe.s3_bucket_name
}
