output "alb_dns_name" {
  description = "DNS name of the TFE ALB"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the TFE ALB"
  value       = aws_lb.this.zone_id
}

output "alb_arn" {
  description = "ARN of the TFE ALB"
  value       = aws_lb.this.arn
}

output "asg_name" {
  description = "Name of the TFE Auto Scaling Group"
  value       = aws_autoscaling_group.tfe.name
}

output "launch_template_id" {
  description = "ID of the TFE launch template"
  value       = aws_launch_template.tfe.id
}

output "tfe_url" {
  description = "URL to access TFE"
  value       = "https://${var.tfe_hostname}"
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.this.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for TFE logs"
  value       = aws_cloudwatch_log_group.tfe.name
}
