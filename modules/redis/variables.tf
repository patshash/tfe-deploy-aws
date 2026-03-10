variable "friendly_name_prefix" {
  description = "Prefix for naming resources"
  type        = string
}

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.r6g.large"
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "subnet_group_name" {
  description = "Name of the ElastiCache subnet group"
  type        = string
}

variable "security_group_ids" {
  description = "Security group IDs for the Redis cluster"
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
