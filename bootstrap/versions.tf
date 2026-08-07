terraform {
  # `use_lockfile` in the S3 backend requires Terraform 1.10 or newer.
  required_version = ">= 1.10.0"

  required_providers {
    # The AWS provider translates Terraform resources into AWS API calls.
    # `~> 6.0` allows compatible 6.x updates, but not a breaking 7.x release.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
