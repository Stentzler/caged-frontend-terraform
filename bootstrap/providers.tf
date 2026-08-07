provider "aws" {
  # Every AWS resource in this bootstrap root is created in this Region.
  region = var.aws_region

  default_tags {
    # Terraform automatically adds these tags to all taggable AWS resources.
    tags = local.tags
  }
}
