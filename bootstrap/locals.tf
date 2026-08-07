# This data source reads the AWS account ID of the credentials running Terraform.
# It does not create any AWS resource.
data "aws_caller_identity" "current" {}

locals {
  # The default name is unique per AWS account. S3 bucket names are global, so
  # including the account ID prevents collisions with other AWS customers.
  derived_state_bucket_name = "${var.project_name}-terraform-state-${data.aws_caller_identity.current.account_id}"

  # Use an explicit bucket name when supplied; otherwise use the safe default.
  state_bucket_name = coalesce(var.state_bucket_name, local.derived_state_bucket_name)

  # Callers can add tags through `common_tags`, but these mandatory tags always
  # win because they are merged last below.
  mandatory_tags = {
    Environment = "shared"
    ManagedBy   = "terraform"
    Project     = var.project_name
    Repository  = "caged-frontend-terraform"
  }

  # This final map is passed to the AWS provider in providers.tf.
  tags = merge(var.common_tags, local.mandatory_tags)
}
