variable "friendly_name_prefix" {
  description = "Prefix for naming resources"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the RDS instance"
  type        = bool
  default     = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.r6g.xlarge"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 50
}

variable "db_max_allocated_storage" {
  description = "Maximum storage for autoscaling in GB"
  type        = number
  default     = 100
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16"
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  type        = string
}

variable "security_group_ids" {
  description = "Security group IDs for the RDS instance"
  type        = list(string)
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption at rest"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
