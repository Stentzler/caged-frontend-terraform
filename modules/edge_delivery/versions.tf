terraform {
  # Declaring this provider lets the environment root explicitly pass its
  # us-east-1 configuration for CloudFront-scoped WAF resources.
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
