variable "friendly_name_prefix" {
  description = "Prefix used for naming all resources. Must be unique per deployment."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,23}$", var.friendly_name_prefix))
    error_message = "Must start with a letter, contain only lowercase letters, numbers, and hyphens, and be 2-24 characters."
  }
}

variable "tfe_hostname" {
  description = "FQDN for the TFE instance (e.g., tfe.example.com)"
  type        = string
}

variable "tfe_license" {
  description = "TFE license string"
  type        = string
  sensitive   = true
}

variable "route53_zone_name" {
  description = "Name of the Route53 hosted zone for DNS records"
  type        = string
}

variable "tfe_image" {
  description = "TFE FDO container image"
  type        = string
  default     = "images.releases.hashicorp.com/hashicorp/terraform-enterprise:latest"
}

variable "tfe_encryption_password" {
  description = "Encryption password for TFE vault. If not provided, one will be generated."
  type        = string
  default     = null
  sensitive   = true
}

# Networking
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Compute
variable "instance_type" {
  description = "EC2 instance type for TFE nodes"
  type        = string
  default     = "m5.xlarge"
}

variable "asg_min_size" {
  description = "Minimum number of TFE instances"
  type        = number
  default     = 2

  validation {
    condition     = var.asg_min_size >= 2
    error_message = "Active/Active requires a minimum of 2 instances."
  }
}

variable "asg_max_size" {
  description = "Maximum number of TFE instances"
  type        = number
  default     = 3
}

# Database
variable "db_instance_class" {
  description = "RDS PostgreSQL instance class"
  type        = string
  default     = "db.r6g.xlarge"
}

# Redis
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.r6g.large"
}

# KMS
variable "kms_key_arn" {
  description = "Existing KMS key ARN. If not provided, a new key will be created."
  type        = string
  default     = null
}

# Tags
variable "tags" {
  description = "Map of tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on ALB and RDS. Set to false for dev/test environments."
  type        = bool
  default     = false
}
