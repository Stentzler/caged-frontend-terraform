variable "project_name" {
  description = "Project identifier used in resource names and mandatory tags."
  type        = string
  default     = "caged-frontend"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.project_name))
    error_message = "project_name must be 2-31 lowercase letters, numbers, or hyphens and start with a letter."
  }
}

variable "environment" {
  description = "Environment identifier used in resource names and mandatory tags."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.environment))
    error_message = "environment must be 2-16 lowercase letters, numbers, or hyphens and start with a letter."
  }
}

variable "aws_region" {
  description = "AWS Region for development resources and the invoked Lambda aliases."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a valid AWS Region identifier."
  }
}

# The certificate is issued only after the owner deliberately enables the
# custom-domain phase. CloudFront certificates must be requested in us-east-1.
variable "viewer_domain_name" {
  description = "Optional fully qualified custom hostname served by CloudFront, such as dataempregos.example.com."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = var.viewer_domain_name == null || (
      var.viewer_domain_name == lower(var.viewer_domain_name) &&
      can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.viewer_domain_name)) &&
      strcontains(var.viewer_domain_name, ".")
    )
    error_message = "viewer_domain_name must be a lowercase fully qualified domain name, such as dataempregos.example.com."
  }

  validation {
    condition     = var.enable_custom_domain == 0 || var.viewer_domain_name != null
    error_message = "viewer_domain_name is required when enable_custom_domain is 1."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block assigned to the dedicated development VPC."
  type        = string
  default     = "10.42.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR block for the single public subnet in the development VPC."
  type        = string
  default     = "10.42.0.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "public_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zone" {
  description = "Optional explicit Availability Zone. When null, Terraform selects the first available zone in aws_region."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.availability_zone == null || can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+[a-z]$", var.availability_zone))
    error_message = "availability_zone must be null or a valid Availability Zone name such as us-east-1a."
  }
}

# The Lambda is owned and released by the backend Terraform repository. Keeping
# its qualified alias ARN as an environment input makes this cross-repository
# dependency explicit and prevents an unqualified function ARN from bypassing
# the backend team's release alias.
variable "query_lambda_alias_arn" {
  description = "Qualified alias ARN of the existing query Lambda invoked by the frontend EC2 role."
  type        = string

  validation {
    condition     = can(regex("^arn:aws(?:-[a-z]+)*:lambda:[a-z]{2}(-gov)?-[a-z]+-[0-9]+:[0-9]{12}:function:[A-Za-z0-9_-]+:[A-Za-z0-9_-]+$", var.query_lambda_alias_arn))
    error_message = "query_lambda_alias_arn must be a qualified Lambda alias ARN, including the alias after the function name."
  }
}

# These values appear in public frontend pages, but they are runtime settings
# rather than Docker build inputs. Real development values belong in ignored
# terraform.tfvars; the committed example uses safe placeholders.
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

# A small burstable instance is appropriate for the low-traffic MVP.
variable "instance_type" {
  description = "EC2 instance type for the single development frontend host."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]+\\.[a-z0-9]+$", var.instance_type))
    error_message = "instance_type must be a non-empty EC2 instance type such as t3.micro."
  }
}

# GP3 keeps low-cost general-purpose root storage configurable.
variable "root_volume_size_gib" {
  description = "Size in GiB of the encrypted GP3 root volume for the frontend host."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size_gib >= 8 && var.root_volume_size_gib <= 100
    error_message = "root_volume_size_gib must be between 8 and 100 GiB for the MVP host."
  }
}

# WAF uses this value for each source IP over the configured evaluation window.
variable "waf_rate_limit" {
  description = "Maximum POST requests per source IP in each WAF evaluation window."
  type        = number
  default     = 15

  validation {
    condition     = var.waf_rate_limit >= 15
    error_message = "waf_rate_limit must be at least 15 requests."
  }
}

# AWS WAF allows a bounded set of windows; 60 seconds keeps this aligned with
# the documented MVP policy and the Nginx second-layer intent.
variable "waf_evaluation_window_seconds" {
  description = "WAF rate-rule evaluation window in seconds."
  type        = number
  default     = 60

  validation {
    condition     = contains([60, 120, 300, 600], var.waf_evaluation_window_seconds)
    error_message = "waf_evaluation_window_seconds must be one of 60, 120, 300, or 600."
  }
}

variable "common_tags" {
  description = "Optional business tags. Mandatory project tags defined in locals.tf take precedence."
  type        = map(string)
  default     = {}
}
