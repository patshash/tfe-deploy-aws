variable "friendly_name_prefix" {
  description = "Prefix for naming resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where TFE will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for TFE EC2 instances"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for the ALB"
  type        = string
}

variable "tfe_security_group_id" {
  description = "Security group ID for TFE instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m5.xlarge"
}

variable "asg_min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 3
}

variable "tfe_hostname" {
  description = "FQDN for TFE"
  type        = string
}

variable "route53_zone_name" {
  description = "Route53 hosted zone name"
  type        = string
}

variable "tfe_user_data" {
  description = "Base64-encoded user data script for TFE instances"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name for TFE instances"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for EBS encryption"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
