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

# This path is an operation-friendly reference to the one runtime .env file.
# It contains no secret values, but the instance role still reads it by exact ARN.
variable "runtime_environment_parameter_name" {
  description = "SSM parameter name containing the frontend container runtime environment."
  type        = string

  validation {
    # The hyphen is last in this character class, where it means a literal
    # hyphen rather than a range. Paths such as runtime-env are valid SSM names.
    condition     = can(regex("^/[A-Za-z0-9_./-]+$", var.runtime_environment_parameter_name))
    error_message = "runtime_environment_parameter_name must be an absolute SSM parameter path."
  }
}

# GitHub reads this non-secret parameter to discover the current deployment
# target after Terraform replaces the EC2 host.
variable "deployment_target_parameter_name" {
  description = "SSM parameter name containing the current frontend deployment target instance ID."
  type        = string

  validation {
    condition     = can(regex("^/[A-Za-z0-9_./-]+$", var.deployment_target_parameter_name))
    error_message = "deployment_target_parameter_name must be an absolute SSM parameter path."
  }
}

# These public values are runtime configuration, not image build arguments.
# Reject newlines so every value remains exactly one KEY=value env-file line.
variable "site_url" {
  description = "Canonical public site URL used by the frontend for search metadata."
  type        = string

  validation {
    condition     = can(regex("^https://", var.site_url)) && !strcontains(var.site_url, "\n")
    error_message = "site_url must be a single-line HTTPS URL."
  }
}

variable "site_official_source_url" {
  description = "Public official Novo CAGED source URL rendered by the frontend."
  type        = string

  validation {
    condition     = can(regex("^https://", var.site_official_source_url)) && !strcontains(var.site_official_source_url, "\n")
    error_message = "site_official_source_url must be a single-line HTTPS URL."
  }
}

variable "site_cbo_source_url" {
  description = "Public CBO source URL rendered by the frontend."
  type        = string

  validation {
    condition     = can(regex("^https://", var.site_cbo_source_url)) && !strcontains(var.site_cbo_source_url, "\n")
    error_message = "site_cbo_source_url must be a single-line HTTPS URL."
  }
}

variable "site_github_url" {
  description = "Public project or maintainer GitHub URL rendered by the frontend."
  type        = string

  validation {
    condition     = can(regex("^https://", var.site_github_url)) && !strcontains(var.site_github_url, "\n")
    error_message = "site_github_url must be a single-line HTTPS URL."
  }
}

variable "site_contact_email" {
  description = "Public contact email address rendered by the frontend."
  type        = string

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.site_contact_email)) && !strcontains(var.site_contact_email, "\n")
    error_message = "site_contact_email must be a single-line email address."
  }
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
