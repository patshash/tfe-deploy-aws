output "s3_bucket_id" {
  description = "ID of the TFE S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "s3_bucket_arn" {
  description = "ARN of the TFE S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "s3_bucket_name" {
  description = "Name of the TFE S3 bucket"
  value       = aws_s3_bucket.this.bucket
}

output "s3_bucket_region" {
  description = "Region of the TFE S3 bucket"
  value       = aws_s3_bucket.this.region
}
