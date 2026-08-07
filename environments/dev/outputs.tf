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
