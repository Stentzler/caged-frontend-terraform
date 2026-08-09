output "vpc_id" {
  description = "ID of the development VPC, or null when enable_network is 0."
  value       = one(module.network[*].vpc_id)
}

output "public_subnet_id" {
  description = "ID of the development public subnet, or null when enable_network is 0."
  value       = one(module.network[*].public_subnet_id)
}

output "frontend_origin_security_group_id" {
  description = "Security group for the future EC2 origin, or null when enable_network is 0."
  value       = one(module.network[*].frontend_origin_security_group_id)
}

output "frontend_ecr_repository_arn" {
  description = "ARN of the frontend ECR repository, or null when enable_container_registry is 0."
  value       = one(module.container_registry[*].repository_arn)
}

output "frontend_ecr_repository_url" {
  description = "URL used by CI to push frontend images, or null when enable_container_registry is 0."
  value       = one(module.container_registry[*].repository_url)
}

# The next EC2 step will use this profile to receive temporary AWS credentials.
output "frontend_host_instance_profile_name" {
  description = "Name of the frontend host instance profile, or null when enable_frontend_host is 0."
  value       = one(module.frontend_host[*].instance_profile_name)
}

# This ID is for Systems Manager operations and deployment automation, not SSH.
output "frontend_host_instance_id" {
  description = "ID of the frontend EC2 origin, or null when enable_frontend_host is 0."
  value       = one(module.frontend_host[*].instance_id)
}

# Visitors must use CloudFront instead of connecting to this origin address.
output "frontend_host_elastic_ip" {
  description = "Elastic IP of the frontend origin, or null when enable_frontend_host is 0. Do not share it as a viewer URL."
  value       = one(module.frontend_host[*].elastic_ip)
}

# The name is passed to deployment automation; the runtime configuration value
# stays in Parameter Store and is deliberately never a Terraform output.
output "frontend_runtime_environment_parameter_name" {
  description = "SSM parameter name containing the non-secret Next.js runtime environment, or null when enable_frontend_host is 0."
  value       = one(module.frontend_host[*].runtime_environment_parameter_name)
}

# GitHub deployment automation reads this non-secret parameter to find the
# current EC2 target after Terraform replaces the host.
output "frontend_deployment_target_parameter_name" {
  description = "SSM parameter name containing the current frontend deployment target instance ID, or null when enable_frontend_host is 0."
  value       = one(module.frontend_host[*].deployment_target_parameter_name)
}

# This ARN will be associated directly with CloudFront in the next edge step.
output "frontend_waf_web_acl_arn" {
  description = "ARN of the CloudFront WAF web ACL, or null when enable_edge_delivery is 0."
  value       = one(module.edge_delivery[*].web_acl_arn)
}

output "frontend_cloudfront_domain_name" {
  description = "CloudFront viewer hostname, or null when enable_edge_delivery is 0."
  value       = one(module.edge_delivery[*].distribution_domain_name)
}
