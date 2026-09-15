output "state_bucket_name" {
  description = "S3 bucket name used by the Terraform remote backend."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_arn" {
  description = "S3 bucket ARN used by the Terraform remote backend."
  value       = aws_s3_bucket.terraform_state.arn
}
