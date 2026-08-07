terraform {
  # Native S3 backend lockfiles require Terraform 1.10 or newer.
  required_version = ">= 1.10.0"

  required_providers {
    # Keep the environment and all child modules on the reviewed AWS provider major version.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    # This provider generates the origin secret without committing a value.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
