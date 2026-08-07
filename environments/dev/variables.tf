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

variable "common_tags" {
  description = "Optional business tags. Mandatory project tags defined in locals.tf take precedence."
  type        = map(string)
  default     = {}
}
