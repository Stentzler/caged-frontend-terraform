provider "aws" {
  # Regional resources such as the VPC and EC2 instance use this configured Region.
  region = var.aws_region

  default_tags {
    # Every taggable resource receives the mandatory tags defined in locals.tf.
    tags = local.tags
  }
}

# CloudFront-scoped WAF and viewer ACM resources must use us-east-1 later.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.tags
  }
}
