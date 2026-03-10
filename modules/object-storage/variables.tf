variable "friendly_name_prefix" {
  description = "Prefix for naming resources"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for S3 server-side encryption"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
