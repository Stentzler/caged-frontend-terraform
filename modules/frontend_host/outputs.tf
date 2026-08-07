# The environment root exposes this non-secret name for the upcoming EC2 resource.
output "instance_profile_name" {
  description = "Name of the IAM instance profile for the frontend EC2 host."
  value       = aws_iam_instance_profile.frontend_host.name
}

# This ARN is useful for IAM review without exposing credentials or secrets.
output "instance_role_arn" {
  description = "ARN of the least-privilege IAM role used by the frontend EC2 host."
  value       = aws_iam_role.frontend_host.arn
}

# Deployment automation and Systems Manager use this non-secret identifier.
output "instance_id" {
  description = "ID of the frontend EC2 origin instance."
  value       = aws_instance.frontend_host.id
}

# CloudFront will use this stable origin address; it is not a viewer URL.
output "elastic_ip" {
  description = "Elastic IP address assigned to the frontend origin."
  value       = aws_eip.frontend_host.public_ip
}
