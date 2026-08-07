output "vpc_id" {
  description = "ID of the dedicated VPC that contains the frontend origin."
  value       = aws_vpc.this.id
}

output "public_subnet_id" {
  description = "ID of the single public subnet for the MVP frontend host."
  value       = aws_subnet.public.id
}

output "frontend_origin_security_group_id" {
  description = "ID of the CloudFront-only security group for the future EC2 origin."
  value       = aws_security_group.frontend_origin.id
}

output "availability_zone" {
  description = "Availability Zone selected for the one-AZ MVP network."
  value       = aws_subnet.public.availability_zone
}
