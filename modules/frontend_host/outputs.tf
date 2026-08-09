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

# The name is safe to share; the SecureString value is never an output.
output "origin_verification_parameter_name" {
  description = "SSM parameter name containing the CloudFront origin-verification secret."
  value       = aws_ssm_parameter.origin_verification.name
}

# Deployment automation needs this name, not the configuration value itself.
output "runtime_environment_parameter_name" {
  description = "SSM parameter name containing the non-secret Next.js runtime environment."
  value       = aws_ssm_parameter.runtime_environment.name
}

# The value is intentionally not output; deployment tooling needs only this
# stable path and obtains the current instance ID through its IAM role.
output "deployment_target_parameter_name" {
  description = "SSM parameter name containing the current frontend deployment target instance ID."
  value       = aws_ssm_parameter.deployment_target.name
}

output "deployment_target_parameter_arn" {
  description = "ARN of the non-secret SSM parameter used to resolve the frontend deployment target."
  value       = aws_ssm_parameter.deployment_target.arn
}

# CloudFront requires a resolvable hostname for its custom origin.
output "origin_domain_name" {
  description = "Public DNS hostname for the Elastic IP used as the CloudFront origin."
  value       = aws_eip.frontend_host.public_dns
}
