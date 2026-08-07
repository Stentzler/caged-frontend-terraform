# A stable host name keeps the EC2 role and profile easy to identify in IAM.
variable "host_name" {
  description = "Name used for the frontend host IAM role and instance profile."
  type        = string
}

# The host may pull images only from the frontend repository owned by this root.
variable "frontend_repository_arn" {
  description = "ARN of the private frontend ECR repository the host may pull from."
  type        = string
}

# The qualified alias prevents the host from invoking unreviewed Lambda versions.
variable "query_lambda_alias_arn" {
  description = "Qualified alias ARN of the existing query Lambda the host may invoke."
  type        = string
}

# The EC2 host resides in the existing one-AZ public subnet.
variable "subnet_id" {
  description = "ID of the public subnet containing the frontend EC2 origin."
  type        = string
}

# This group permits port 80 only from CloudFront's origin-facing prefix list.
variable "security_group_id" {
  description = "ID of the CloudFront-only security group attached to the frontend origin."
  type        = string
}

variable "aws_region" {
  description = "AWS Region used by the EC2 bootstrap script and SSM parameter."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the frontend origin."
  type        = string
}

variable "root_volume_size_gib" {
  description = "Size in GiB of the encrypted GP3 root volume."
  type        = number
}

# Tags are supplied by the environment root so every host resource is traceable.
variable "tags" {
  description = "Mandatory and optional tags applied to taggable host resources."
  type        = map(string)
}
