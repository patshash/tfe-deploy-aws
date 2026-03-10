output "tfe_url" {
  description = "URL to access Terraform Enterprise"
  value       = module.tfe.tfe_url
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.tfe.alb_dns_name
}
