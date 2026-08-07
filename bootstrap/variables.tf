variable "aws_region" {
  description = "AWS Region that stores the Terraform state bucket."
  type        = string
  default     = "us-east-1"

  validation {
    # Fail early instead of sending an invalid Region name to AWS.
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a valid AWS Region identifier."
  }
}

variable "project_name" {
  description = "Project identifier used in the default state bucket name and tags."
  type        = string
  default     = "caged-frontend"

  validation {
    # This value becomes part of the default S3 bucket name.
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.project_name))
    error_message = "project_name must be 2-31 lowercase letters, numbers, or hyphens and start with a letter."
  }
}

variable "state_bucket_name" {
  description = "Optional globally unique S3 bucket name. When null, Terraform derives one using the current AWS account ID."
  type        = string
  default     = null
  nullable    = true

  validation {
    # The condition permits null (use the derived name) or an S3-compatible name.
    condition = (
      var.state_bucket_name == null ||
      can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    )
    error_message = "state_bucket_name must be a valid 3-63 character lowercase S3 bucket name."
  }
}

variable "common_tags" {
  # These are optional business tags. See locals.tf for mandatory tag protection.
  description = "Additional tags merged with mandatory state-backend tags. Mandatory tags take precedence."
  type        = map(string)
  default     = {}
}
