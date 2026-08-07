output "state_bucket_arn" {
  # Useful for future IAM policies that need a resource-level bucket ARN.
  description = "ARN of the protected S3 bucket used for Terraform state."
  value       = aws_s3_bucket.terraform_state.arn
}

output "state_bucket_name" {
  # Copy this value into environments/dev/backend.hcl after the bootstrap apply.
  description = "Name of the protected S3 bucket used for Terraform state."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_region" {
  # The S3 backend configuration must use the same Region as the bucket.
  description = "AWS Region of the protected Terraform state bucket."
  value       = var.aws_region
}
